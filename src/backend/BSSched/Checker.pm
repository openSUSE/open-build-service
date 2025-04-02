# Copyright (c) 2015 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package BSSched::Checker;

use strict;
use warnings;

use Digest::MD5 ();

use BSUtil;
use BSSolv;
use BSNotify;
use BSRedisnotify;

use BSSched::ProjPacks;
use BSSched::BuildRepo;
use BSSched::BuildResult;
use BSSched::PublishRepo;
use BSSched::BuildJob;
use BSSched::Access;
use BSSched::Modulemd;
use BSSched::Remote;	# for addrepo_remote
use BSSched::DoD;	# for signalmissing
use BSSched::EventSource::Directory;

use BSSched::BuildJob::Aggregate;
use BSSched::BuildJob::Channel;
use BSSched::BuildJob::DeltaRpm;
use BSSched::BuildJob::Docker;
use BSSched::BuildJob::KiwiImage;
use BSSched::BuildJob::KiwiProduct;
use BSSched::BuildJob::ProductCompose;
use BSSched::BuildJob::Package;
use BSSched::BuildJob::Image;
use BSSched::BuildJob::Patchinfo;
use BSSched::BuildJob::PreInstallImage;
use BSSched::BuildJob::Unknown;


=head1 NAME

 BSSched::Checker

=head1 DESCRIPTION

 Check the status of a project's repository

=cut


my %handlers = (
  'productcompose'      => BSSched::BuildJob::ProductCompose->new(),
  'kiwi-product'    => BSSched::BuildJob::KiwiProduct->new(),
  'kiwi-image'      => BSSched::BuildJob::KiwiImage->new(),
  'docker'          => BSSched::BuildJob::Docker->new(),
  'fissile'         => BSSched::BuildJob::Docker->new(),
  'patchinfo'       => BSSched::BuildJob::Patchinfo->new(),
  'aggregate'       => BSSched::BuildJob::Aggregate->new(),
  'preinstallimage' => BSSched::BuildJob::PreInstallImage->new(),
  'channel'         => BSSched::BuildJob::Channel->new(),
  'mkosi'           => BSSched::BuildJob::Image->new(),
  'appimage'        => BSSched::BuildJob::Image->new(),
  'livebuild'       => BSSched::BuildJob::Image->new(),
  'simpleimage'     => BSSched::BuildJob::Image->new(),
  'unknown'         => BSSched::BuildJob::Unknown->new(),

  'default'	    => BSSched::BuildJob::Package->new(),
);

=head2 new - create a checker context

=cut

sub new {
  my ($class, $gctx, $prp, @conf) = @_;
  my ($projid, $repoid) = split('/', $prp, 2);
  my $myarch = $gctx->{'arch'};
  my $ctx = {
    'gctx' => $gctx,
    'prp' => $prp,
    'project' => $projid,
    'repository' => $repoid,
    'gdst' => "$gctx->{'reporoot'}/$prp/$myarch",
    @conf
  };
  $ctx->{'alllocked'} = 1 if $gctx->{'alllocked'}->{$prp};
  return bless $ctx, $class;
}

sub generate_random_id {
  my ($oldstate) = @_;

  my $random = time();
  $random .= $oldstate->{'oldbuildid'} if defined $oldstate->{'oldbuildid'};
  $random .= $oldstate->{'buildid'} if defined $oldstate->{'buildid'};
  return Digest::MD5::md5_hex($random);
}

=head2 notify - send repo changed notification

=cut

sub notify {
  my ($ctx, $type, $buildid) = @_;

  my $myarch = $ctx->{'gctx'}->{'arch'};
  if (defined($BSConfig::notifyforward) ? $BSConfig::notifyforward : $BSConfig::redisserver) {
    # use the notification/redis forwarder to send the notification
    BSRedisnotify::addforwardjob($type, "project=$ctx->{'project'}", "repo=$ctx->{'repository'}", "arch=$myarch", "buildid=$buildid");
  } else {
    my $body = { project => $ctx->{'project'}, 'repo' => $ctx->{'repository'}, 'arch' => $myarch, 'buildid' => $buildid };
    BSNotify::notify($type, $body);
  }
}

=head2 set_repo_state - update the :schedulerstate file of a prp

=cut

sub set_repo_state {
  my ($ctx, $state, $details) = @_;

  my $gdst = $ctx->{'gdst'};
  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $oldstate = readstr("$gdst/:schedulerstate", 1);
  if ($oldstate) {
    if (substr($oldstate, 0, 4) eq 'pst0') {
      $oldstate = BSUtil::fromstorable($oldstate, 1);
    } else {
      my $details;
      ($oldstate, $details) = split(' ', $oldstate, 2);
      $oldstate = { 'code' => $oldstate };
      $oldstate->{'details'} = $details if $details;
    }
  }
  $oldstate ||= {};
  my $newstate = { %$oldstate, 'code' => $state, 'details' => $details };
  delete $newstate->{'details'} unless $details;

  if ($state eq 'building') {
    # build in progress. send start event if not allready done
    delete $newstate->{'buildid'};
    delete $newstate->{'repostateid'};
    if (!$newstate->{'oldbuildid'}) {
      my $id = generate_random_id($oldstate) . '-inprogress';
      $newstate->{'oldbuildid'} = $id;
      $ctx->notify('REPO_BUILD_STARTED', $id);
    }
  } elsif ($state eq 'finished') {
    # we're done (for now). generate repostateid
    my $repostateid = '';
    my @s = stat("$gdst/:full.solv");
    $repostateid .= " full:$s[9]/$s[7]/$s[1]" if @s;
    @s = stat("$gdst/:bininfo");
    $repostateid .= " bininfo:$s[9]/$s[7]/$s[1]" if @s;
    $repostateid = Digest::MD5::md5_hex($repostateid);

    if (!$newstate->{'oldbuildid'}) {
      # repo was finished before. check for repostateid changes
      if (!$newstate->{'buildid'} || ($newstate->{'repostateid'} || '') ne $repostateid) {
	# but the repo changed, send synthetic event
	print "sending synthetic REPO_BUILD_STARTED event\n";
	my $id = generate_random_id($oldstate) . '-inprogress';
	$ctx->notify('REPO_BUILD_STARTED', $id);
	delete $newstate->{'buildid'};
	$newstate->{'oldbuildid'} = $id;
      }
    }
    if ($newstate->{'oldbuildid'}) {
      my $id = delete $newstate->{'oldbuildid'};
      $id =~ s/-inprogress$//;
      $newstate->{'buildid'} = $id;
      $ctx->notify('REPO_BUILD_FINISHED', $id);
    }
    $newstate->{'repostateid'} = $repostateid;
  }
  my $proj = $ctx->{'project'} ? ($gctx->{'projpacks'} || {})->{$ctx->{'project'}} : undef;
  if ($proj) {
    delete $newstate->{'scmsync'};
    delete $newstate->{'scminfo'};
    if ($proj->{'scmsync'}) {
      $newstate->{'scmsync'} = $proj->{'scmsync'};
      $newstate->{'scminfo'} = $proj->{'scminfo'} if $proj->{'scminfo'};
    }
  }
  unlink("$gdst/:schedulerstate.dirty") if $state eq 'scheduling' || $state eq 'broken' || $state eq 'disabled';
  mkdir_p($gdst) unless -d $gdst;
  BSUtil::store("$gdst/.:schedulerstate", "$gdst/:schedulerstate", $newstate) unless BSUtil::identical($oldstate, $newstate);
}

=head2 wipe - delete this repo

=cut

sub wipeobsoleterepo {
  my ($ctx) = @_;
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $prp = $ctx->{'prp'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};

  # first delete the publish area
  BSSched::PublishRepo::prpfinished($ctx);
  # then delete the build area
  BSSched::BuildResult::wipeobsoleterepo($gctx, $prp);

  $gctx->{'changed_med'}->{$prp} = 2; 
  BSSched::EventSource::Directory::sendrepochangeevent($gctx, $prp);
  BSSched::BuildJob::killbuilding($ctx->{'gctx'}, $prp);

  # now that our arch is gone we can try to remove the prp directory
  my $proj = $gctx->{'projpacks'}->{$projid} || {};
  my $repo = (grep {$_->{'name'} eq $repoid} @{$proj->{'repository'} || []})[0];
  if (!$repo) {
    # this repo doesn't exist any longer!
    my $reporoot = $gctx->{'reporoot'};
    my $others = grep {-d "$reporoot/$prp/$_"} ls("$reporoot/$prp");
    if (!$others) {
      # cannot delete repoinfo because it may contain splitdbg data
      # we rely on the publisher to clean up
      # unlink("$reporoot/$prp/:repoinfo");
      unlink("$reporoot/$prp/.finishedlock");
      rmdir("$reporoot/$prp");
      rmdir("$reporoot/$projid");
    }
  }
}

# see if a remote repository is in an error state
sub check_remote_repo_error {
  my ($gctx, $prpsearchpath) = @_;
  my $remoteprojs = $gctx->{'remoteprojs'};
  for my $aprp (@$prpsearchpath) {
    my ($aprojid) = split('/', $aprp, 2);
    my $error = $remoteprojs->{$aprojid}->{'error'} if $remoteprojs->{$aprojid} && $remoteprojs->{$aprojid}->{'error'};
    if ($error) {
      if ($error =~ /interconnect error:/ || $error =~ /5\d\d remote error:/) {
        $gctx->{'retryevents'}->addretryevent({'type' => 'project', 'project' => $aprojid});
      }
      return "$aprojid: $error";
    }
  }
  return undef;
}

sub neededdodresources {
  my ($ctx, $repotype) = @_;
  return () unless ($repotype || '') eq 'registry';
  my $projpacks = $ctx->{'gctx'}->{'projpacks'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $proj = $projpacks->{$projid} || {};
  my $pdatas = $proj->{'package'} || {};
  my %needed;
  for my $pdata (values %$pdatas) {
    my $info = (grep {$_->{'repository'} eq $repoid} @{$pdata->{'info'} || []})[0];
    next unless $info;
    $needed{$_} = 1 for grep {/^container:/} @{$info->{'dep'} || []};
  }
  return sort keys %needed;
}

sub check_for_running_src_updates {
  my ($ctx) = @_;
  my $gctx = $ctx->{'gctx'};
  my $projid = $ctx->{'project'};
  my $proj = $ctx->{'proj'};
  my $pdatas = $proj->{'package'} || {};
  my @delayed;
  if ($proj->{'missingpackages'}) {
    $gctx->{'retryevents'}->addretryevent({'type' => 'package', 'project' => $projid});
    push @delayed, 'missingpackages';
  }
  for my $packid (@{$ctx->{'packs'} || []}) {
    my $pdata = $pdatas->{$packid};
    my $err = $pdata->{'error'};
    next unless $err;
    if ($err =~ /download in progress/) {
      push @delayed, $packid;
    } elsif ($err =~ /source update running/ || $err =~ /service in progress/) {
      push @delayed, $packid;
    } elsif ($err eq 'delayed startup' || $err =~ /interconnect error:/  || $err =~ /5\d\d remote error:/) {
      $gctx->{'retryevents'}->addretryevent({'type' => 'package', 'project' => $projid, 'package' => $packid});
      push @delayed, $packid;
    }
  }
  return "source update in progress for: ".join(', ',  @delayed) if @delayed;
  return undef;
}

sub setup {
  my ($ctx) = @_;
  my $prp = $ctx->{'prp'};
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};

  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $proj = $projpacks->{$projid};
  return (0, 'project does not exist') unless $proj;
  my $repo = (grep {$_->{'name'} eq $repoid} @{$proj->{'repository'} || []})[0];
  return (0, 'repo does not exist') unless $repo;
  if ($proj->{'error'}) {
    return ('blocked', $proj->{'error'}) if $proj->{'error'} =~ /service in progress/;
    return ('broken', $proj->{'error'});
  }

  my $prpsearchpath = $gctx->{'prpsearchpath'}->{$prp};
  $ctx->{'prpsearchpath'} = $prpsearchpath if $prpsearchpath;

  if ($repo->{'status'} && $repo->{'status'} eq 'disabled') {
    return ('disabled', undef);
  }
  my $suspend = $gctx->{'projsuspended'}->{$projid};
  return ('blocked', join(', ', @$suspend)) if $suspend;
  $ctx->{'repo'} = $repo;

  if ($ctx->{'alllocked'}) {
    # shortcut, do simplified setup
    $ctx->{'conf'} = {};
    my $pdatas = $proj->{'package'} || {};
    $ctx->{'packs'} = [ sort keys %$pdatas ];
    return ('scheduling', undef);
  }

  # set config
  return (0, 'no prpsearchpath?') unless $prpsearchpath;
  my $bconf = BSSched::ProjPacks::getconfig($gctx, $projid, $repoid, $myarch, $prpsearchpath);
  if (!$bconf) {
    my $error = check_remote_repo_error($gctx, $prpsearchpath);
    return (0, $error) if $error;
    my $lastprojid = (split('/', $prpsearchpath->[-1]))[0];
    return ('broken', "no config ($lastprojid)");
  }
  $ctx->{'conf'} = $bconf;
  return ('broken', "project config: $bconf->{'parse_error'}") if $bconf->{'parse_error'} && !$BSConfig::ignore_project_config_errors;
  if ($bconf->{'hostarch'} && !$BSCando::knownarch{$bconf->{'hostarch'}}) {
    return ('broken', "bad hostarch ($bconf->{'hostarch'})");
  }

  # set build type
  my $prptype = $bconf->{'type'};
  if (!$prptype || $prptype eq 'UNDEFINED') {
    # HACK force to channel if we have a channel package
    $prptype = 'channel' if grep {$_->{'channel'}} values(%{$proj->{'package'} || {}});
  }
  if (!$prptype || $prptype eq 'UNDEFINED') {
    # could still do channels/aggregates/patchinfos, but hey...
    my $lastprojid = (split('/', $prpsearchpath->[-1]))[0];
    return ('broken', "no build type ($lastprojid)");
  }
  if ($prptype eq 'excluded' || $prptype eq 'disabled') {
    return ($prptype, undef);
  }
  $ctx->{'prptype'} = $prptype;
  my $pdatas = $proj->{'package'} || {};
  $ctx->{'packs'} = [ sort keys %$pdatas ];

  # set lastcheck
  if (!$gctx->{'lastcheck'}->{$prp}) {
    my $oldlastcheck = BSUtil::retrieve("$gdst/:lastcheck", 1) || {};
    for (keys %$oldlastcheck) {
      # delete old cruft
      delete $oldlastcheck->{$_} unless $pdatas->{$_};
    }
    $gctx->{'lastcheck'}->{$prp} = $oldlastcheck;
  }
  $ctx->{'lastcheck'} = $gctx->{'lastcheck'}->{$prp};

  # configure meta algorithm
  my $genmetaalgo = $bconf->{'buildflags:genmetaalgo'};
  $genmetaalgo = $gctx->{'genmetaalgo'} unless defined $genmetaalgo;
  return ('broken', 'unsupported genmetaalgo') if $genmetaalgo < 0 || $genmetaalgo > $gctx->{'maxgenmetaalgo'};
  BSBuild::setgenmetaalgo($genmetaalgo);
  BSSolv::setgenmetaalgo($genmetaalgo) if $gctx->{'maxgenmetaalgo'};
  $ctx->{'genmetaalgo'} = $genmetaalgo;
  $ctx->{'forcebinaryidmeta'} = 1 if $bconf->{'buildflags:forcebinaryidmeta'};

  # check for package blacklist
  if (exists $bconf->{'buildflags:excludebuild'}) {
    my %excludebuild;
    for (@{$bconf->{'buildflags'} || []}) {
      $excludebuild{$1} = 1 if /^excludebuild:(.*)$/s;
    }
    $ctx->{'excludebuild'} = \%excludebuild if %excludebuild;
  }

  # check for package whitelist
  if (exists $bconf->{'buildflags:onlybuild'}) {
    my %onlybuild;
    for (@{$bconf->{'buildflags'} || []}) {
      $onlybuild{$1} = 1 if /^onlybuild:(.*)$/s;
    }
    $ctx->{'onlybuild'} = \%onlybuild if %onlybuild;
  }

  # sync genbuildreqs from on-disk version
  my $genbuildreqs = {};
  $genbuildreqs = BSUtil::retrieve("$gdst/:genbuildreqs", 1) || {} if -e "$gdst/:genbuildreqs";
  $ctx->{'genbuildreqs'} = $genbuildreqs;
  if (%$genbuildreqs) {
    $gctx->{'genbuildreqs'}->{$prp} = $genbuildreqs;
  } else {
    delete $gctx->{'genbuildreqs'}->{$prp} ;
  }

  my $crosshostarch;
  # FIXME: get it from the searchparth
  if ($repo->{'hostsystem'}) {
    $crosshostarch = $bconf->{'hostarch'} || $myarch;
  }
  # check if the crosshostarch matches our expectations
  if (($repo->{'crosshostarch'} || '') ne ($crosshostarch || '')) {
    delete $repo->{'crosshostarch'};
    $repo->{'crosshostarch'} = $crosshostarch if $crosshostarch;
    BSSched::ProjPacks::get_projpacks_postprocess_projects($gctx, $projid);
    BSSched::Lookat::setchanged($gctx, $prp);
    return (0, 'crosshostarch mismatch');
  }

  # setup host data if doing cross builds
  if ($crosshostarch && $crosshostarch ne $myarch) {
    if (!grep {$_ eq $crosshostarch} @{$repo->{'arch'} || []}) {
      return ('broken', "host arch $crosshostarch missing in repo architectures");
    }
    my $prpsearchpath_host = $gctx->{'prpsearchpath_host'}->{$prp};
    return (0, 'no prpsearchpath_host?') unless $prpsearchpath_host && $prpsearchpath_host->[1];
    $prpsearchpath_host = $prpsearchpath_host->[1];
    my $bconf_host = BSSched::ProjPacks::getconfig($gctx, $projid, $repoid, $bconf->{'hostarch'}, $prpsearchpath_host);
    if (!$bconf_host) {
      my $error = check_remote_repo_error($gctx, $prpsearchpath_host);
      return (0, $error) if $error;
      my $lastprojid = (split('/', $prpsearchpath_host->[-1]))[0];
      return ('broken', "no config ($lastprojid)");
    }
    return ('broken', "cross project config: $bconf_host->{'parse_error'}") if $bconf_host->{'parse_error'} && !$BSConfig::ignore_project_config_errors;
    if ($bconf_host->{'hostarch'} && $bconf_host->{'hostarch'} ne $bconf->{'hostarch'}) {
      return ('broken', "$bconf->{'hostarch'} is not native");
    }
    $ctx->{'prpsearchpath_host'} = $prpsearchpath_host;
    $ctx->{'conf_host'} = $bconf_host;
  }

  # check for modulemd data
  if ($pdatas->{'modulemd'} && $pdatas->{'modulemd'}->{'modulemd'}) {
    my $pdata = $pdatas->{'modulemd'};
    my $modulemd = $pdata->{'modulemd'};
    my $dependency = BSSched::Modulemd::select_dependency($bconf, $modulemd);
    return ('broken', 'cannot build this module') unless $dependency;
    my $errors = BSSched::Modulemd::extend_modules($bconf, $modulemd, $dependency->{'buildrequires'} || []);
    return ('broken', join(', ', @$errors)) if $errors;
    my $ml = BSSched::Modulemd::calc_modularitylabel($bconf, $modulemd, $dependency->{'requires'} || []);
    return ('broken', 'modularitylabel calculation failed') unless $ml;
    my @ml = split(':', $ml, 4);
    $ctx->{'modularity_label'} = $ml;
    $ctx->{'modularity_package'} = 'modulemd';
    $ctx->{'modularity_srcmd5'} = $pdata->{'srcmd5'};
    $ctx->{'modularity_meta'} = Digest::MD5::md5_hex("$ml[0]:$ml[1]:$ml[3]:$pdata->{'srcmd5'}")."  $ctx->{'modularity_package'}";
    $ctx->{'modularity_extramacros'} = $modulemd->{'macros'} if $modulemd->{'macros'};
    $ctx->{'modularity_platform'} = $bconf->{'buildflags:modulemdplatform'};
    $ctx->{'modularity_distindex'} = $modulemd->{'distindex'} if $modulemd->{'distindex'};
  }

  if ($proj->{'scmsync'} && ($repo->{'rebuild'} || '') eq 'local') {
    # Scmsync project with rebuildmethod set to local. We want to support "atomic" switches to a new source state,
    # so delay the scheduler run if source updates are in progess.
    my $err = check_for_running_src_updates($ctx);
    return ('blocked', $err) if $err;
  }

  return ('scheduling', undef);
}

sub wipeobsolete {
  my ($ctx) = @_;

  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $prp = $ctx->{'prp'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid};
  my $myarch = $gctx->{'arch'};
  return if $ctx->{'alllocked'};		# must not wipe anything
  my $linkedbuild = $ctx->{'repo'}->{'linkedbuild'};
  my $pdatas = $proj->{'package'} || {};
  my $dstcache = { 'fullcache' => {}, 'bininfocache' => {} };
  my $hadobsolete;
  my $prjlocked = 0;
  $prjlocked = BSUtil::enabled($repoid, $proj->{'lock'}, $prjlocked, $myarch) if $proj->{'lock'};
  
  for my $packid (grep {!/^[:\.]/} ls($gdst)) {
    next if $packid eq '_volatile';
    my $reason;
    my $pdata = $pdatas->{$packid};
    if (!$pdata) {
      next if $packid eq '_deltas';
      next if $proj->{'missingpackages'};
      $reason = 'obsolete';
    } else {
      if (($pdata->{'error'} || '') eq 'excluded') {
	$reason = 'excluded';
      } else {
	if (exists($pdata->{'originproject'})) {
	  # package from project link
	  if (!$linkedbuild || ($linkedbuild ne 'localdep' && $linkedbuild ne 'all' && $linkedbuild ne 'alldirect')) {
	    $reason = 'excluded';
	  } elsif ($linkedbuild eq 'alldirect' && !grep {$_->{'project'} eq $pdata->{'originproject'}} @{$proj->{'link'}||[]}) {
	    $reason = 'excluded';
          }
	}
	my %info = map {$_->{'repository'} => $_} @{$pdata->{'info'} || []};
	my $info = $info{$repoid};
	$reason = 'excluded' if $info && ($info->{'error'} || '') eq 'excluded';
	my $releasename = $pdata->{'releasename'} || $packid;
	if ($ctx->{'excludebuild'}) {
	  $reason = 'excluded' if $ctx->{'excludebuild'}->{$packid} || $ctx->{'excludebuild'}->{$releasename};
        }
	if ($ctx->{'onlybuild'}) {
	  $reason = 'excluded' unless $ctx->{'onlybuild'}->{$packid} || $ctx->{'onlybuild'}->{$releasename};
	}
	next unless $reason;
      }
    }
    my $locked = $prjlocked;
    $locked = BSUtil::enabled($repoid, $pdata->{'lock'}, $locked, $myarch) if $pdata && $pdata->{'lock'};
    if ($locked) {
      print "      - $packid: $reason, but locked\n";
      next;
    }
    my $allarch = $pdata ? 0 : 1;		# wiping all archs?
    next unless BSSched::BuildResult::wipeobsolete($gctx, $prp, $packid, $dstcache, $reason, $allarch);
    $hadobsolete = 1;
    delete $ctx->{'lastcheck'}->{$packid};
    BSSched::BuildJob::killbuilding($gctx, $prp, $packid);
  }
  BSSched::BuildResult::set_dstcache_prp($gctx, $dstcache);

  if ($hadobsolete) {
    $gctx->{'changed_med'}->{$prp} = 2;
    BSSched::EventSource::Directory::sendrepochangeevent($gctx, $prp);
    unlink("$gdst/:repodone");
  }
}

sub preparehashes {
  my ($pool, $prp, $prpnotready) = @_;
  return $pool->preparehashes($prp, $prpnotready) if defined &BSSolv::pool::preparehashes;
  # slow perl implementation
  $prpnotready ||= {};
  my %dep2src;
  my %dep2pkg;
  my %depislocal;     # used in meta calculation
  my %notready;       # unfinished and will modify :full
  my %subpacks;

  for my $p ($pool->consideredpackages()) {
    my $rprp = $pool->pkg2reponame($p);
    my $n = $pool->pkg2name($p);
    my $sn = $pool->pkg2srcname($p) || $n;
    $sn =~ s/^container://;
    $dep2pkg{$n} = $p;
    $dep2src{$n} = $sn;
    if ($rprp eq $prp) {
      $depislocal{$n} = 1;
    } else {
      $notready{$sn} = 2 if $prpnotready->{$rprp} && $prpnotready->{$rprp}->{$sn};
    }
  }
  push @{$subpacks{$dep2src{$_}}}, $_ for keys %dep2src;
  return (\%dep2pkg, \%dep2src, \%depislocal, \%notready, \%subpacks);
}

sub newpool {
  my ($ctx, $bconf) = @_;
  my $pool = BSSolv::pool->new();
  if ($bconf) {
    $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';
    $pool->settype('arch') if $bconf->{'binarytype'} eq 'arch';
    $pool->settype('apk') if $bconf->{'binarytype'} eq 'apk';
    $pool->setmodules($bconf->{'modules'}) if $bconf->{'modules'} && defined &BSSolv::pool::setmodules;
  }
  return $pool;
}

sub createpool {
  my ($ctx, $bconf, $prpsearchpath, $arch) = @_;

  my $delayed = '';
  my $error;
  my $pool = eval { $ctx->newpool($bconf) };
  if ($@) {
    $error = $@;
    chomp $error;
    return (undef, $error || 'pool creation failed');
  }
  my %missingmods;
  for my $rprp (@$prpsearchpath) {
    if (!$ctx->checkprpaccess($rprp)) {
      $error = "repository '$rprp' is unavailable";
      last;
    }
    my $r = $ctx->addrepo($pool, $rprp, $arch);
    if (!$r) {
      if (defined($r)) {
	$delayed .= ", repository '$rprp' is unavailable";
	next;
      }
      $error = "repository '$rprp' is unavailable";
      last;
    }
    if (defined &BSSolv::repo::missingmodules) {
      my @missing = $r->missingmodules();
      while (@missing) {
	push @{$missingmods{$missing[0]}}, $missing[1];
	splice(@missing, 0, 2);
      }
    }
  }
  return ($pool, substr($delayed, 2), 1) if $delayed;
  return ($pool, $error) if $error;
  if (%missingmods) {
    my $msg = '';
    for my $mod (sort keys %missingmods) {
      my @m = sort(BSUtil::unify(@{$missingmods{$mod}}));
      if (@m > 1) {
	$msg .= ", $mod needs one of ".join(',', @m);
      } else {
	$msg .= ", $mod needs $m[0]";
      }
    }
    return ($pool, substr($msg, 2));
  }
  $pool->createwhatprovides();
  return ($pool);
}

sub preparepool {
  my ($ctx) = @_;
  my $gctx = $ctx->{'gctx'};
  my $bconf = $ctx->{'conf'};
  my $prp = $ctx->{'prp'};

  return ('scheduling', undef) if $ctx->{'alllocked'};		# we do not need a pool
  my ($pool, $error, $delayed) = createpool($ctx, $bconf, $ctx->{'prpsearchpath'});
  if ($error) {
    $ctx->{'havedelayed'} = 1 if $delayed;
    return ('broken', $error);
  }
  my $prpnotready = $gctx->{'prpnotready'};
  $prpnotready = undef if ($ctx->{'repo'}->{'block'} || '') eq 'local';
  ($ctx->{'dep2pkg'}, $ctx->{'dep2src'}, $ctx->{'depislocal'}, $ctx->{'notready'}, $ctx->{'subpacks'}) = preparehashes($pool, $prp, $prpnotready);

  my $pool_host;
  if ($ctx->{'conf_host'}) {
    ($pool_host, $error, $delayed) = createpool($ctx, $ctx->{'conf_host'}, $ctx->{'prpsearchpath_host'}, $ctx->{'repo'}->{'crosshostarch'});
    if ($error) {
      $ctx->{'havedelayed'} = 1 if $delayed;
      return ('broken', $error);
    }
    ($ctx->{'dep2pkg_host'}) = preparehashes($pool_host, $prp, $prpnotready);
  }
  $ctx->{'pool'} = $pool;
  $ctx->{'pool_host'} = $pool_host if $pool_host;
  return ('scheduling', undef);
}

sub unpreparepool {
  my ($ctx) = @_;
  delete $ctx->{'expander'};
  delete $ctx->{'pool'};
  delete $ctx->{'pool_host'};
  delete $ctx->{'pool_local'};
}

sub free_caches {
  my ($ctx) = @_;
  delete $ctx->{'gbininfo_cache'};
  delete $ctx->{'alien_repo_cache'};
  delete $ctx->{'packstatus_cache'};
}

# emulate depsort2 with depsort. This is not very fast,
# please update perl-BSSolv to get depsort2.
sub emulate_depsort2 {
  my ($deps, $dep2src, $pkg2src, $cycles, @packs) = @_;
  my %src2pkg = reverse(%$pkg2src);
  my %pkgdeps;
  my @dups;
  if (keys(%src2pkg) != keys (%$pkg2src)) {
    @dups = grep {$src2pkg{$pkg2src->{$_}} ne $_} reverse(keys %$pkg2src);
  }
  if (@dups) {
    push @dups, grep {defined($_)} map {delete $src2pkg{$pkg2src->{$_}}} @dups;
    @dups = sort(@dups);
    print "src2pkg dups: @dups\n";
    push @{$src2pkg{$pkg2src->{$_}}}, $_ for @dups;
    for my $pkg (keys %$deps) {
      $pkgdeps{$pkg} = [ map {ref($_) ? @$_ : $_} map { $src2pkg{$dep2src->{$_} || $_} || $dep2src->{$_} || $_} @{$deps->{$pkg}} ];
    }
  } else {
    for my $pkg (keys %$deps) {
      $pkgdeps{$pkg} = [ map { $src2pkg{$dep2src->{$_} || $_} || $dep2src->{$_} || $_} @{$deps->{$pkg}} ];
    }
  }
  return BSSolv::depsort(\%pkgdeps, undef, $cycles, @packs);
}

sub expandandsort {
  my ($ctx) = @_;

  $ctx->{'prpchecktime'} = time();	# package checking starts here

  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $bconf = $ctx->{'conf'};
  my $repo = $ctx->{'repo'};
  my $prp = $ctx->{'prp'};

  return ('scheduling', undef) if $ctx->{'alllocked'}; # all deps are empty

  if ($bconf->{'expandflags:preinstallexpand'}) {
    if ($gctx->{'arch'} ne 'local' || !defined($BSConfig::localarch)) {
      return ('broken', 'Build::expandpreinstalls does not exist') unless defined &Build::expandpreinstalls;
      my $err = Build::expandpreinstalls($bconf);
      return ('broken', "unresolvable $err") if $err;
    }
  }
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid};
  my $pdatas = $proj->{'package'} || {};

  my %experrors;
  my %pdeps;
  my %pkg2src;
  my %pkgdisabled;
  my %havepatchinfos;
  my %pkg2buildtype;

  my $subpacks = $ctx->{'subpacks'};
  my $cross = $ctx->{'conf_host'} ? 1 : 0;

  $ctx->{'experrors'} = \%experrors;
  my $packs = $ctx->{'packs'};
  my $genbuildreqs_prp = $ctx->{'genbuildreqs'} || {};
  for my $packid (@$packs) {
    my $pdata = $pdatas->{$packid};

    if ($pdata->{'error'} && $pdata->{'error'} eq 'excluded') {
      $pdeps{$packid} = [];
      next;
    }
    my $info = (grep {$_->{'repository'} eq $repoid} @{$pdata->{'info'} || []})[0];
    # calculate package type
    my $buildtype;
    if ($pdata->{'aggregatelist'}) {
      $buildtype = 'aggregate';
    } elsif ($pdata->{'patchinfo'}) {
      $buildtype = 'patchinfo';
    } elsif ($pdata->{'channel'}) {
      $buildtype = 'channel';
    } elsif ($pdata->{'modulemd'}) {
      $buildtype = 'modulemd';
    } elsif ($info && $info->{'file'}) {
      # directly implement most common types
      if ($info->{'file'} =~ /\.(spec|dsc|kiwi|livebuild|productcompose)$/) {
        $buildtype = $1;
        if ($buildtype eq 'kiwi') {
          $buildtype = $info->{'imagetype'} && ($info->{'imagetype'}->[0] || '') eq 'product' ? 'kiwi-product' : 'kiwi-image';
        }
      } else {
        $buildtype = Build::recipe2buildtype($info->{'file'}) || 'unknown';
      }
    } else {
      $buildtype = 'unknown';
    }
    $pkg2buildtype{$packid} = $buildtype;
    $havepatchinfos{$packid} = 1 if $buildtype eq 'patchinfo';

    if (!$info || !defined($info->{'file'}) || !defined($info->{'name'})) {
      if ($pdata->{'error'} && ($pdata->{'error'} eq 'disabled' || $pdata->{'error'} eq 'locked')) {
	$pkgdisabled{$packid} = 1;
      }
      if ($info && $info->{'error'} && ($info->{'error'} eq 'disabled' || $info->{'error'} eq 'locked')) {
	$pkgdisabled{$packid} = 1;
      }
      $pdeps{$packid} = [];
      next;
    }
    if ($info->{'error'} && $info->{'error'} eq 'excluded') {
      $pdeps{$packid} = [];
      next;
    }
    my $releasename = $pdata->{'releasename'} || $packid;
    if ($ctx->{'excludebuild'}) {
      if ($ctx->{'excludebuild'}->{$packid} || $ctx->{'excludebuild'}->{$releasename}) {
        $pdeps{$packid} = [];
        next;
      }
    }
    if ($ctx->{'onlybuild'}) {
      if (!($ctx->{'onlybuild'}->{$packid} || $ctx->{'onlybuild'}->{$releasename})) {
        $pdeps{$packid} = [];
        next;
      }
    }
    if (exists($pdata->{'originproject'})) {
      # this is a package from a project link
      if (!$repo->{'linkedbuild'} || ($repo->{'linkedbuild'} ne 'localdep' && $repo->{'linkedbuild'} ne 'all' && $repo->{'linkedbuild'} ne 'alldirect')) {
	$pdeps{$packid} = [];
	next;
      } elsif ($repo->{'linkedbuild'} eq 'alldirect' &&  !grep {$_->{'project'} eq $pdata->{'originproject'}} @{$proj->{'link'}||[]}) {
	$pdeps{$packid} = [];
	next;
      }
    }
    $pkg2src{$packid} = $info->{'name'};

    if ($pdata->{'hasbuildenv'} || $info->{'hasbuildenv'}) {
      $pdeps{$packid} = [];
      next;
    }
    my @deps = @{$info->{'dep'} || []};
    my $genbuildreqs = $genbuildreqs_prp->{$packid};
    if ($genbuildreqs) {
      my $verifymd5 = $pdata->{'verifymd5'} || $pdata->{'srcmd5'};
      undef $genbuildreqs if $genbuildreqs->[2] && $genbuildreqs->[2] ne $verifymd5;
      push @deps, @{$genbuildreqs->[1]} if $genbuildreqs;
    }
    my ($eok, @edeps);
    my $handler = $handlers{$buildtype};
    if ($cross && !$handler) {
      # set split_hostdeps and make edeps the expanded sysroot
      my $splitdeps;
      ($splitdeps, $eok, @edeps) = BSSched::BuildJob::Package::expand_sysroot($bconf, $subpacks->{$info->{'name'}}, $info);
      $ctx->{'split_hostdeps'}->{$packid} = $splitdeps;
    } else {
      $handler ||= $handlers{default};
      ($eok, @edeps) = $handler->expand($bconf, $subpacks->{$info->{'name'}}, @deps);
    }
    if (!$eok) {
      $experrors{$packid} = join(', ', @edeps) || '?';
      @edeps = @deps;
    }
    $pdeps{$packid} = \@edeps;
  }

  $ctx->{'edeps'} = \%pdeps;
  $ctx->{'experrors'} = \%experrors;
  $ctx->{'pkg2buildtype'} = \%pkg2buildtype;

  # now sort
  print "    sorting ".@$packs." packages\n";
  my @cycles;
  my @sccs;
  delete $ctx->{'sccs'};
  if (@$packs > 1) {
    if (defined(&BSSolv::depsort2) && defined(&BSSolv::setdepsortsccs)) {
      BSSolv::setdepsortsccs(2);
      @$packs = BSSolv::depsort2(\%pdeps, $ctx->{'dep2src'}, \%pkg2src, \@cycles, @$packs);
      BSSolv::setdepsortsccs(0);
      if (@cycles) {
        push @sccs, shift @cycles while @cycles && @{$cycles[0]};
        shift @cycles;
      }
      $ctx->{'sccs'} = \@sccs;
    } elsif (defined &BSSolv::depsort2) {
      @$packs = BSSolv::depsort2(\%pdeps, $ctx->{'dep2src'}, \%pkg2src, \@cycles, @$packs);
    } else {
      @$packs = emulate_depsort2(\%pdeps, $ctx->{'dep2src'}, \%pkg2src, \@cycles, @$packs);
    }
    # print "cycle: ".join(' -> ', @$_)."\n" for @cycles;
  }
  if (%havepatchinfos) {
    # bring patchinfos to back
    my @packs_patchinfos = grep {$havepatchinfos{$_}} @$packs;
    @$packs = grep {!$havepatchinfos{$_}} @$packs;
    push @$packs, @packs_patchinfos;
  }

  # write dependency information
  if (%pkgdisabled) {
    # leave info of disabled packages untouched
    my $olddepends = BSUtil::retrieve("$gdst/:depends", 1);
    if ($olddepends) {
      for (keys %pkgdisabled) {
	$pdeps{$_} = $olddepends->{'pkgdeps'}->{$_} if $olddepends->{'pkgdeps'}->{$_};
	$pkg2src{$_} = $olddepends->{'pkg2src'}->{$_} if $olddepends->{'pkg2src'}->{$_};
      }
    }
  }
  my %prunedsubpacks;
  for (values %pkg2src) {
    $prunedsubpacks{$_} = $subpacks->{$_} if $subpacks->{$_};
  }
  my $depends = {
    'pkgdeps' => \%pdeps,
    'subpacks' => \%prunedsubpacks,
    'pkg2src' => \%pkg2src,
  };
  $depends->{'cycles'} = \@cycles if @cycles;
  $depends->{'sccs'} = \@sccs if @sccs;
  BSUtil::store("$gdst/.:depends", "$gdst/:depends", $depends);
  %prunedsubpacks = ();
  # remove old entries again
  for (keys %pkgdisabled) {
    $pdeps{$_} = [];
    delete $pkg2src{$_};
  }
  $ctx->{'cycles'} = \@cycles;
  $ctx->{'pkg2src'} = \%pkg2src;
  return ('scheduling', undef);
}

sub calcrelsynctrigger {
  my ($ctx) = @_;
  my $prp = $ctx->{'prp'};
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};

  if ($ctx->{'conf'}->{'buildflags:norelsync'}) {
    $ctx->{'relsynctrigger'} = {};
    $ctx->{'relsyncmax'} = undef;
    return;
  }
  my $relsyncmax;
  my %relsynctrigger;

  my $projpacks = $gctx->{'projpacks'};
  my $pdatas = $projpacks->{$projid}->{'package'} || {};

  if (-s "$gdst/:relsync.max") {
    $relsyncmax = BSUtil::retrieve("$gdst/:relsync.max", 2);
    if ($relsyncmax && -s "$gdst/:relsync") {
      my $relsync = BSUtil::retrieve("$gdst/:relsync", 2);
      for my $packid (sort keys %$pdatas) {
	next unless $relsync->{$packid};
	my $pdata = $pdatas->{$packid};
	my $tag = $pdata->{'bcntsynctag'};
	if (!$tag) {
	  my $info = (grep {$_->{'repository'} eq $repoid} @{$pdata->{'info'} || []})[0];
	  $tag = $info->{'bcntsynctag'} if $info;
	}
	$tag ||= $packid;
	next unless $relsync->{$packid} =~ /(.*)\.(\d+)$/;
	next unless defined($relsyncmax->{"$tag/$1"}) && $2 < $relsyncmax->{"$tag/$1"};
	$relsynctrigger{$packid} = 1;
      }
    }
    if (%relsynctrigger) {
      # filter failed packages
      for (ls("$gdst/:logfiles.fail")) {
	delete $relsynctrigger{$_};
      }
    }
  }
  $ctx->{'relsynctrigger'} = \%relsynctrigger;
  $ctx->{'relsyncmax'} = $relsyncmax;
}

sub prune_packstatus_finished {
  my ($gdst, $building) = @_;

  my $psf = readstr("$gdst/:packstatus.finished", 1);
  return unless $psf;
  my %dispatchdetails;
  for (split("\n", $psf)) {
    my ($code, $rest) = split(' ', $_, 2);
    next unless $code eq 'scheduled';
    my ($packid, $job, $details) = split('/', $rest, 3);
    $dispatchdetails{$packid} = "$_\n" if $job && ($building->{$packid} || '') eq $job;
  }
  if (%dispatchdetails) {
    writestr("$gdst/.:packstatus.finished", "$gdst/:packstatus.finished", join('', sort values %dispatchdetails));
  } else {
    unlink("$gdst/:packstatus.finished");
  }
}

sub handlecycle {
  my ($ctx, $packid, $cpacks, $cycpass) = @_;
  my $cychash = $ctx->{'cychash'};
  return ($packid, 0) unless $cychash->{$packid};
  my $incycle = $cycpass->{$packid} || 0;
  return ($packid, $incycle) if $incycle > 0;	# still in pass
  my @cycp = @{$cychash->{$packid}};
  $incycle = -$incycle + 1;			# start next pass
  $cycpass->{$_} = $incycle for @cycp;
  if ($incycle == 1) {
    unshift @$cpacks, $cycp[0];
    unshift @$cpacks, @cycp;
    $packid = shift @$cpacks;
    $cycpass->{$packid} = -1;			# set pass1 endmarker
  } elsif ($incycle == 2) {
    my $cyclevel = $ctx->{'cyclevel'};
    unshift @$cpacks, sort {($cyclevel->{$a} || 0) <=> ($cyclevel->{$b} || 0)} @cycp;
    $packid = shift @$cpacks;
    $cycpass->{$packid} = -2;			# set pass2 endmarker
  } elsif ($incycle == 3) {
    my $notready = $ctx->{'notready'};
    my $pkg2src = $ctx->{'pkg2src'} || {};
    if (grep {$notready->{$pkg2src->{$_} || $_}} @cycp) {
      $notready->{$pkg2src->{$_} || $_} ||= 1 for @cycp;
    }
    return (undef, 3);
  }
  return ($packid, $incycle);
}

sub cycsort {
  my ($pkg2dep, $dep2src, $pkg2src, @cyc) = @_;
  @cyc = BSUtil::unify(sort(@cyc));
  my %d;
  my %cdeps;
  for my $pkg (@cyc) {
    $d{$dep2src->{$_} || $_}->{$pkg} = 1 for @{$pkg2dep->{$pkg}};
  }
  # remove all bi-directional edges
  my %ign;
  for my $pkg (@cyc) {
    $ign{$pkg}->{$_} = 1 for keys %{$d{$pkg2src->{$pkg}} || {}};
  }
  for my $pkg (@cyc) {
    $_ ne $pkg && !$ign{$_}->{$pkg} and push @{$cdeps{$_}}, $pkg for keys %{$d{$pkg2src->{$pkg}} || {}};
  }
  @cyc = BSSolv::depsort(\%cdeps, undef, undef, @cyc);
  return @cyc;
}

sub checkpkgs {
  my ($ctx) = @_;

  my $prp = $ctx->{'prp'};
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};

  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid};
  my $pdatas = $proj->{'package'} || {};

  # Step 2d: check status of all packages
  print "    checking packages\n";
  my $projbuildenabled = ($proj->{'kind'} || '') eq 'maintenance_release' ? 0 : 1;
  $projbuildenabled = BSUtil::enabled($repoid, $proj->{'build'}, 1, $myarch) if $proj->{'build'};
  my $projlocked = 0;
  $projlocked = BSUtil::enabled($repoid, $proj->{'lock'}, 0, $myarch) if $proj->{'lock'};
  my $prjuseforbuildenabled = 1;
  $prjuseforbuildenabled = BSUtil::enabled($repoid, $proj->{'useforbuild'}, $prjuseforbuildenabled, $myarch) if $proj->{'useforbuild'};

  my %packstatus;
  my $oldpackstatus;
  my %packerror;
  my %cychash;
  my %cycpass;
  my $needed;
  my %building;
  my %unfinished;

  my $notready = $ctx->{'notready'};
  my $experrors = $ctx->{'experrors'};

  $ctx->{'packstatus'} = \%packstatus;
  $ctx->{'cychash'} = \%cychash;
  $ctx->{'nharder'} = 0;
  $ctx->{'building'} = \%building;
  $ctx->{'unfinished'} = \%unfinished;
  $ctx->{'cyclevel'} = {};

  # now build cychash mapping packages to all other cycle members
  for my $cyc (@{$ctx->{'sccs'} || $ctx->{'cycles'} || []}) {
    next if @$cyc < 2;	# just in case
    my @c = map {@{$cychash{$_} || [ $_ ]}} @$cyc;
    @c = cycsort($ctx->{'edeps'}, $ctx->{'dep2src'}, $ctx->{'pkg2src'}, @c);
    $cychash{$_} = \@c for @c;
  }

  if (%cychash) {
    print "      cycle components:\n";
    for (BSUtil::unify(sort(map {$_->[0]} values %cychash))) {
      print "        - @{$cychash{$_}}\n";
    }
  }

  # copy old data over if we have missing packages
  if ($proj->{'missingpackages'}) {
    $gctx->{'retryevents'}->addretryevent({'type' => 'package', 'project' => $projid});
    $oldpackstatus = BSUtil::retrieve("$gdst/:packstatus", 1) || {};
    $oldpackstatus->{'packstatus'} ||= {};
    $oldpackstatus->{'packerror'} ||= {};
    for my $packid (keys %{$oldpackstatus->{'packstatus'}}) {
      next if $pdatas->{$packid};
      $packstatus{$packid} = $oldpackstatus->{'packstatus'}->{$packid};
      $packerror{$packid} = $oldpackstatus->{'packerror'}->{$packid} if $oldpackstatus->{'packerror'}->{$packid};
    }
  }

  my $logfiles_fail;
  my @cpacks = @{$ctx->{'packs'}};
  while (@cpacks) {
    my $packid = shift @cpacks;

    # cycle handling code
    my $incycle = 0;
    if ($cychash{$packid}) {
      ($packid, $incycle) = handlecycle($ctx, $packid, \@cpacks, \%cycpass);
      next if !$packid || ($packstatus{$packid} && $packstatus{$packid} ne 'done' && $packstatus{$packid} ne 'succeeded' && $packstatus{$packid} ne 'failed'); # already decided
    }
    $ctx->{'incycle'} = $incycle;

    # product definitions are never building themself
    if ($packid eq '_product') {
      $packstatus{$packid} = 'excluded';
      next;
    }

    # check if this package is locked
    my $pdata = $pdatas->{$packid};
    if ($pdata->{'lock'}) {
      if (BSUtil::enabled($repoid, $pdata->{'lock'}, $projlocked, $myarch)) {
	$packstatus{$packid} = 'locked';
	next;
      }
    } else {
      if ($projlocked) {
	$packstatus{$packid} = 'locked';
	next;
      }
    }

    # check if this package is excluded by prjconf white and blacklist
    my $releasename = $pdata->{'releasename'} || $packid;
    if ($ctx->{'excludebuild'}) {
      if ($ctx->{'excludebuild'}->{$packid} || $ctx->{'excludebuild'}->{$releasename}) {
        $packstatus{$packid} = 'excluded';
        $packerror{$packid} = 'package blacklist';
        next;
      }
    }
    if ($ctx->{'onlybuild'}) {
      if (!($ctx->{'onlybuild'}->{$packid} || $ctx->{'onlybuild'}->{$releasename})) {
	$packstatus{$packid} = 'excluded';
	$packerror{$packid} = 'package whitelist';
	next;
      }
    }

    # check if this package is project link excluded
    if (exists($pdata->{'originproject'}) && (!$pdata->{'error'} || $pdata->{'error'} eq 'disabled')) {
      # this is a package from a project link
      my $repo = $ctx->{'repo'};
      if (!$repo->{'linkedbuild'} || ($repo->{'linkedbuild'} ne 'localdep' && $repo->{'linkedbuild'} ne 'all' && $repo->{'linkedbuild'} ne 'alldirect')) {
	$packstatus{$packid} = 'excluded';
	$packerror{$packid} = 'project link';
	next;
      } elsif ($repo->{'linkedbuild'} eq 'alldirect' &&  !grep {$_->{'project'} eq $pdata->{'originproject'}} @{$proj->{'link'}||[]}) {
	$packstatus{$packid} = 'excluded';
	$packerror{$packid} = 'project link';
	next;
      }
    }

    # check if this package is broken
    if ($pdata->{'error'}) {
      if ($pdata->{'error'} eq 'disabled' || $pdata->{'error'} eq 'locked' || $pdata->{'error'} eq 'excluded') {
	$packstatus{$packid} = $pdata->{'error'};
	next;
      }
      print "      - $packid ($pdata->{'error'})\n";
      if ($pdata->{'error'} =~ /download in progress/) {
	$packstatus{$packid} = 'blocked';
	$packerror{$packid} = $pdata->{'error'};
	next;
      }
      if ($pdata->{'error'} =~ /source update running/ || $pdata->{'error'} =~ /service in progress/) {
	$packstatus{$packid} = 'blocked';
	$packerror{$packid} = $pdata->{'error'};
	next;
      }
      if ($pdata->{'error'} eq 'delayed startup' || $pdata->{'error'} =~ /interconnect error:/ || $pdata->{'error'} =~ /5\d\d remote error:/) {
	$gctx->{'retryevents'}->addretryevent({'type' => 'package', 'project' => $projid, 'package' => $packid});
	$ctx->{'havedelayed'} = 1;
	$packstatus{$packid} = 'blocked';
	$packerror{$packid} = $pdata->{'error'};
	next;
      }
      $packstatus{$packid} = 'broken';
      $packerror{$packid} = $pdata->{'error'};
      next;
    }

    # check if this package is build disabled
    if ($pdata->{'build'}) {
      if (!BSUtil::enabled($repoid, $pdata->{'build'}, $projbuildenabled, $myarch)) {
	$packstatus{$packid} = 'disabled';
	next;
      }
    } else {
      if (!$projbuildenabled) {
	$packstatus{$packid} = 'disabled';
	next;
      }
    }

    # select correct info again
    my $info = (grep {$_->{'repository'} eq $repoid} @{$pdata->{'info'} || []})[0] || {};

    if ($info->{'error'}) {
      if ($info->{'error'} eq 'disabled' || $info->{'error'} eq 'locked' || $info->{'error'} eq 'excluded') {
	$packstatus{$packid} = $info->{'error'};
	next;
      }
      if ($info->{'error'} =~ /interconnect error:/ || $info->{'error'} =~ /5\d\d remote error:/) {
	$gctx->{'retryevents'}->addretryevent({'type' => 'package', 'project' => $projid, 'package' => $packid});
	$ctx->{'havedelayed'} = 1;
	$packstatus{$packid} = 'blocked';
	$packerror{$packid} = $info->{'error'};
	next;
      }
      print "      - $packid ($info->{'error'})\n";
      $packstatus{$packid} = 'broken';
      $packerror{$packid} = $info->{'error'};
      next;
    }

    # calculate package build type
    my $buildtype = $ctx->{'pkg2buildtype'}->{$packid} || 'unknown';
    if ($buildtype eq 'unknown') {
      print "      - $packid (no recipe file)\n";
      $packstatus{$packid} = 'broken';
      $packerror{$packid} = 'no recipe file';
      next;
    }
    if ($buildtype eq 'modulemd') {
      $packstatus{$packid} = 'excluded';
      next;
    }
    #print "      - $packid ($buildtype)\n";

    # name of src package, needed for block detection
    my $pname = $info->{'name'} || $packid;

    # speedup hack: check if a build is already scheduled
    # hmm, this might be a bad idea...
    my $job = BSSched::BuildJob::jobname($prp, $packid)."-$pdata->{'srcmd5'}";
    my $myjobsdir = $gctx->{'myjobsdir'};
    if ($myjobsdir && -s "$myjobsdir/$job") {
      # print "      - $packid ($buildtype)\n";
      # print "        already scheduled\n";
      my $bconf = $ctx->{'conf'};
      BSSched::BuildJob::add_crossmarker($gctx, $bconf->{'hostarch'}, $job) if $bconf->{'hostarch'};
      my $useforbuildenabled = BSUtil::enabled($repoid, $pdata->{'useforbuild'}, $prjuseforbuildenabled, $myarch);
      $building{$packid} = $job;
      $notready->{$pname} = 1 if $useforbuildenabled;
      $unfinished{$pname} = 1;
      $packstatus{$packid} = 'scheduled';
      # we may also want to set the cyclevel
      next;
    }

    # check for expansion errors
    if ($experrors->{$packid}) {
      #print "      - $packid ($buildtype)\n";
      #print "        unresolvable:\n";
      #print "            $experrors->{$packid}\n";
      $packstatus{$packid} = 'unresolvable';
      $packerror{$packid} = $experrors->{$packid};
      next;
    }

    # check if we have all the dod resources
    if ($ctx->{'missingdodresources'}) {
      my @missing = grep {$ctx->{'missingdodresources'}->{$_}} @{$info->{'dep'} || []};
      if (@missing) {
        $packstatus{$packid} = 'blocked';
        $packerror{$packid} = "waiting for dod resources to appear: @missing";
	next;
      }
    }

    # all checks ok, dispatch to handler
    my $handler = $handlers{$buildtype} || $handlers{default};
    my $edeps = $ctx->{'edeps'}->{$packid} || [];
    my ($astatus, $aerror) = $handler->check($ctx, $packid, $pdata, $info, $buildtype, $edeps);
    if ($astatus eq 'scheduled') {
      # aerror contains rebuild data in this case
      ($astatus, $aerror) = $handler->build($ctx, $packid, $pdata, $info, $aerror);
      if ($astatus eq 'scheduled') {
	$building{$packid} = $aerror || 'job'; # aerror contains jobid in this case
	undef $aerror;
      } elsif ($astatus eq 'delayed') {
	$ctx->{'havedelayed'} = 1;
	($astatus, $aerror) = ('blocked', defined($aerror) ? "delayed: $aerror" : 'delayed');
      }
      unlink("$gdst/:repodone");
    } elsif ($astatus eq 'delayed') {
      $ctx->{'havedelayed'} = 1;
      if (!$oldpackstatus) {
	$oldpackstatus = BSUtil::retrieve("$gdst/:packstatus", 1) || {};
	$oldpackstatus->{'packstatus'} ||= {};
	$oldpackstatus->{'packerror'} ||= {};
      }
      $astatus = $oldpackstatus->{'packstatus'}->{$packid};
      $aerror = $oldpackstatus->{'packerror'}->{$packid};
      ($astatus, $aerror) = ('blocked', 'delayed') unless $astatus;
      $unfinished{$pname} = 1;
    } elsif ($astatus eq 'done') {
      # convert into succeeded/failed depending on :logfiles.fail
      $logfiles_fail ||= { map {$_ => 1} ls ("$ctx->{'gdst'}/:logfiles.fail") };
      $astatus = $logfiles_fail->{$packid} ? 'failed' : 'succeeded';
    }
    $packstatus{$packid} = $astatus;
    $packerror{$packid} = $aerror if defined $aerror;
    if ($astatus eq 'blocked' || $astatus eq 'scheduled') {
      my $useforbuildenabled = BSUtil::enabled($repoid, $pdata->{'useforbuild'}, $prjuseforbuildenabled, $myarch);
      $notready->{$pname} = 1 if $useforbuildenabled;
      $unfinished{$pname} = 1;
    }
  }

  # delete global entries from notready
  for (keys %$notready) {
    delete $notready->{$_} if $notready->{$_} == 2;
  }

  # put local notready into prpnotready if not a leaf
  if (%$notready && $gctx->{'rprpdeps'}->{$prp}) {
    $gctx->{'prpnotready'}->{$prp} = $notready;
  } else {
    delete $gctx->{'prpnotready'}->{$prp};
  }

  # write blocked data into a file so that remote servers can fetch it
  # we don't put it into :packstatus to make retrival fast
  # if we changed the blocked data we also delete the repounchanged flag
  # as remote instances get the blocked data with the repo data.
  my $repounchanged = $gctx->{'repounchanged'}->{$prp} || 0;
  if (%$notready) {
    my $oldstate;
    $oldstate = readxml("$gdst/:repostate", $BSXML::repositorystate, 1) if $repounchanged;
    my @blocked = sort keys %$notready;
    writexml("$gdst/.:repostate", "$gdst/:repostate", {'blocked' => \@blocked}, $BSXML::repositorystate);
    delete $gctx->{'repounchanged'}->{$prp} if $oldstate && join(',', @{$oldstate->{'blocked'} || []}) ne join(',', @blocked);
  } else {
    delete $gctx->{'repounchanged'}->{$prp} if $repounchanged && -e "$gdst/:repostate";
    unlink("$gdst/:repostate");
  }

  # package checking ends here
  $ctx->{'prpchecktime'} = time() - $ctx->{'prpchecktime'};

  # send unblockedevents to other schedulers
  if ($ctx->{'sendunblockedevents'}) {
    my $sendunblocked = delete $ctx->{'sendunblockedevents'};
    for my $prpa (sort keys %{$sendunblocked || {}}) {
      my $type = $sendunblocked->{$prpa} == 1 ? 'lowunblocked' : 'unblocked';
      print "    sending $type event to $prpa\n";
      my ($aprojid, $arepoid, $aarch) = split('/', $prpa, 3);
      BSSched::EventSource::Directory::sendunblockedevent($gctx, "$aprojid/$arepoid", $aarch, $type);
    }
  }

  # send unblockedevents for cross builds if we are the native arch
  if ($myarch ne 'local' && ($ctx->{'repo'}->{'crosshostarch'} || '') eq $myarch) {
    my $type = ($ctx->{'changetype'} || 'med') eq 'low' ? 'lowunblocked' : 'unblocked';
    for my $arch (@{$ctx->{'repo'}->{'arch'} || []}) {
      next if $arch eq $myarch;
      print "    sending $type event to $arch\n";
      BSSched::EventSource::Directory::sendunblockedevent($gctx, "$projid/$repoid", $arch, $type);
    }
  }

  # building jobs may have changed back to excluded, blocked or disabled, remove the jobs
  BSSched::BuildJob::killunwantedjobs($ctx->{'gctx'}, $prp, \%packstatus);

  # write new package status
  my $prpstatus = { 'packstatus' => \%packstatus, 'packerror' => \%packerror };
  if ($proj->{'scmsync'}) {
    $prpstatus->{'scmsync'} = $proj->{'scmsync'};
    $prpstatus->{'scminfo'} = $proj->{'scminfo'};
  }
  BSUtil::store("$gdst/.:packstatus", "$gdst/:packstatus", $prpstatus);
  if (%building) {
    prune_packstatus_finished($gdst, \%building);
  } else {
    unlink("$gdst/:packstatus.finished");
  }
  BSRedisnotify::updateresult("$prp/$myarch", \%packstatus, \%packerror, \%building) if $BSConfig::redisserver;

  # write lastcheck file if we spent more than 2 minutes
  if ($ctx->{'prpchecktime'} > 2 * 60 && $ctx->{'nharder'} > 10 && %{$ctx->{'lastcheck'} || {}}) {
    BSUtil::store("$gdst/.:lastcheck", "$gdst/:lastcheck", $ctx->{'lastcheck'});
  }

  my $schedulerstate;
  if (keys %building) {
    $schedulerstate = 'building';
  } elsif ($ctx->{'havedelayed'} || %unfinished) {
    $schedulerstate = 'blocked';
  } else {
    $schedulerstate = 'finished';
  }
  return ($schedulerstate, undef);
}

sub printstats {
  my ($ctx) = @_;

  my $packstatus = $ctx->{'packstatus'};
  for my $status (sort keys %{{map {$_ => 1} values %$packstatus}}) {
    print "    $status: ".scalar(grep {$_ eq $status} values %$packstatus)."\n";
  }
  print "    looked harder: $ctx->{'nharder'}\n" if $ctx->{'nharder'};
  my $building = $ctx->{'building'};
  my $notready = $ctx->{'notready'};
  my $unfinished = $ctx->{'unfinished'};
  print "    building: ".scalar(keys %$building).", notready: ".scalar(keys %$notready).", unfinished: ".scalar(keys %$unfinished)."\n";
  print "    took $ctx->{'prpchecktime'} seconds to check the packages\n";
}

sub publish {
  my ($ctx, $force) = @_;
  my $prp = $ctx->{'prp'};
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $unfinished = $ctx->{'unfinished'};

  if ($ctx->{'alllocked'}) {
    print "    publishing is locked\n";
    return ('done', undef);
  }

  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid};
  my $pdatas = $proj->{'package'} || {};
  my $packs;
  if ($force) {
    $packs = [ sort keys %$pdatas ];
  } else {
    $packs = $ctx->{'packs'};
  }
  my $locked = 0;
  $locked = BSUtil::enabled($repoid, $proj->{'lock'}, $locked, $myarch) if $proj->{'lock'};
  my $pubenabled = BSUtil::enabled($repoid, $proj->{'publish'}, 1, $myarch);
  if ($force && $pubenabled == 1) {
    print "   force publish of $repoid not possible. Publishing is already enabled\n";
    return;
  }
  my %pubenabled;
  for my $packid (@$packs) {
    my $pdata = $pdatas->{$packid};
    $pubenabled{$packid} = 0;
    next if defined($pdata->{'lock'}) && BSUtil::enabled($repoid, $pdata->{'lock'}, $locked, $myarch);
    next if !defined($pdata->{'lock'}) && $locked;
    if ($pdata->{'publish'}) {
      $pubenabled{$packid} = BSUtil::enabled($repoid, $pdata->{'publish'}, $pubenabled, $myarch);
    } elsif ($force) {
      $pubenabled{$packid} = 1;
    } else {
      $pubenabled{$packid} = $pubenabled;
    }
  }

  # calculate new repodone state
  my $repodonestate = $proj->{'patternmd5'} || '';
  for my $packid (@$packs) {
    $repodonestate .= "\0$packid" if $pubenabled{$packid};
  }
  $repodonestate .= "\0$_" for sort keys %$unfinished;
  $repodonestate = Digest::MD5::md5_hex($repodonestate);
  if (@$packs && !grep {$_} values %pubenabled) {
    # all packages have publish disabled hint
    $repodonestate = "disabled:$repodonestate";
  }

  # compare new repodone state with old state
  unlink("$gdst/:repodone") if $force;
  if (-e "$gdst/:repodone") {
    my $oldrepodone = readstr("$gdst/:repodone", 1) || '';
    unlink("$gdst/:repodone") if $oldrepodone ne $repodonestate;
  }
  if ($locked) {
    print "    publishing is locked\n";
    return ('done', undef);
  }
  if (-e "$gdst/:repodone") {
    return ('done', undef);	# nothing new to publish
  }

  # return right away if publishing is disabled for all packages and nothing is published
  if (!$force && ($repodonestate =~ /^disabled/) && ! -d "$gdst/:repo") {
    print "    publishing is disabled\n";
    mkdir_p($gdst);
    writestr("$gdst/:repodone", undef, $repodonestate) unless %$unfinished;
    return ('done', undef);
  }

  # obey nofailedpackages publish flag
  if ($ctx->{'conf'}->{'publishflags:nofailedpackages'}) {
    my @bad;
    my $packstatus = $ctx->{'packstatus'};
    for my $packid (grep {$pubenabled{$_}} @$packs) {
      my $code = $packstatus->{$packid} || 'broken';
      push @bad, $packid if $code eq 'broken' || $code eq 'failed' || $code eq 'unresolvable';
    }
    return ('broken', "not publishing failed packages: @bad") if @bad;
  }

  # obey keepobsolete publish flag
  my $keepobsolete;
  if ($ctx->{'conf'}->{'publishflags:keepobsolete'} && !$pubenabled) {
    $keepobsolete = 1;
  }

  # update :repo directory
  mkdir_p($gdst);
  my $publisherror = BSSched::PublishRepo::prpfinished($ctx, $packs, \%pubenabled, $force, $keepobsolete);
  if ($publisherror) {
    return ('building', $publisherror) if $publisherror eq 'delta generation: building';
    return ('delayed', substr($publisherror, 8)) if $publisherror eq 'delayed' || $publisherror =~ /^delayed:/;
    warn("    $publisherror\n");
    return ('broken', $publisherror);
  }

  # publishing succeeded (at least the scheduler side)
  writestr("$gdst/:repodone", undef, $repodonestate) unless %$unfinished;
  return ('done', undef);
}

sub xrpc {
  my ($ctx, $resource, $param, @args) = @_;
  return $ctx->{'gctx'}->{'rctx'}->xrpc($ctx, $resource, $param, @args);
}

sub setchanged {
  my ($ctx, $handle) = @_;
  my $gctx = $ctx->{'gctx'};
  die("no gctx in ctx\n") unless $gctx;
  my $changeprp = $handle->{'_changeprp'} || $ctx->{'changeprp'};
  my $changetype = $handle->{'_changetype'} || $ctx->{'changetype'} || 'high';
  my $changelevel = $handle->{'_changelevel'} || $ctx->{'changelevel'} || 1;
  BSSched::Lookat::setchanged($gctx,  $changeprp, $changetype, $changelevel);
}

sub setchanged_unless_othersinprogress {
  my ($ctx, $handle) = @_;
  my $gctx = $ctx->{'gctx'};
  die("no gctx in ctx\n") unless $gctx;
  $ctx->setchanged($handle) unless $gctx->{'rctx'}->xrpc_othersinprogress($handle);
}

sub checkprojectaccess {
  my ($ctx, $projid) = @_;
  return BSSched::Access::checkprpaccess($ctx->{'gctx'}, $projid, $ctx->{'project'});
}

sub checkprpaccess {
  my ($ctx, $prp) = @_;
  return BSSched::Access::checkprpaccess($ctx->{'gctx'}, $prp, $ctx->{'prp'});
}

sub checkdodresources {
  my ($ctx, $prp, $arch, $r) = @_;
  return unless defined &BSSolv::repo::dodresources;
  my $gctx = $ctx->{'gctx'};
  my $dodrepotype = BSSched::ProjPacks::getdodrepotype($gctx, $prp);
  return unless $dodrepotype;
  my $dodresources = $ctx->{'dodresources'}->{$dodrepotype};
  if (!$dodresources) {
    $dodresources = $ctx->{'dodresources'}->{$dodrepotype} = [ neededdodresources($ctx, $dodrepotype) ];
  }
  return unless @{$dodresources || []};
  return if $arch ne $gctx->{'arch'};		# not yet
  my %reporesources = map {$_ => 1} $r->dodresources();
  my @missing = grep {!$reporesources{$_}} @$dodresources;
  return unless @missing;
  print "    missig dod resources: @missing\n";
  $ctx->{'missingdodresources'} = { %{$ctx->{'missingdodresources'} || {}}, map {$_ => 1} @missing };
  my $alldodresources = BSSched::ProjPacks::neededdodresources($gctx, $prp) || [];
  $alldodresources = [ BSUtil::unify(@$alldodresources, @$dodresources) ];
  BSSched::DoD::signalmissing($ctx, $prp, $arch, $alldodresources);
}

sub addrepo {
  my ($ctx, $pool, $prp, $arch) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};

  # first check the cache
  my $r = $gctx->{'repodatas'}->addrepo($pool, $prp, $arch);
  return undef unless defined $r;
  # make sure that we know all of the resources we need
  checkdodresources($ctx, $prp, $arch, $r) if $r && $r->dodurl();
  return $r if $r;

  # not in cache. scan/fetch.
  my ($projid, $repoid) = split('/', $prp, 2);
  my $remoteprojs = $gctx->{'remoteprojs'};
  if ($remoteprojs->{$projid}) {
    return 0 if ($ctx->{'addrepo_remote_inprogress'} || {})->{"$prp/$arch"};	
    $r = BSSched::Remote::addrepo_remote($ctx, $pool, $prp, $arch, $remoteprojs->{$projid});
    $ctx->{'addrepo_remote_inprogress'}->{"$prp/$arch"} = 1 if !$r && defined($r);
  } elsif ($arch ne $gctx->{'arch'}) {
    my $alien_cache = $ctx->{'alien_repo_cache'};
    $alien_cache = $ctx->{'alien_repo_cache'} = {} unless $alien_cache;
    $r = $pool->repofromstr($prp, $alien_cache->{"$prp/$arch"}) if exists $alien_cache->{"$prp/$arch"};
    if (!$r) {
      $r = BSSched::BuildRepo::addrepo_scan($gctx, $pool, $prp, $arch);
      # needs some mem, but it's hopefully worth it
      $alien_cache->{"$prp/$arch"} = $r->tostr() if $r;
    }
  } else {
    $r = BSSched::BuildRepo::addrepo_scan($gctx, $pool, $prp, $arch);
  }
  checkdodresources($ctx, $prp, $arch, $r) if $r && $r->dodurl();
  return $r;
}

sub read_gbininfo {
  my ($ctx, $prp, $arch, $ps) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my ($projid, $repoid) = split('/', $prp, 2);

  # a per ctx cache
  my $gbininfo_cache = $ctx->{'gbininfo_cache'};
  $gbininfo_cache = $ctx->{'gbininfo_cache'} = {} unless $gbininfo_cache;
  my ($gbininfo, $ps2) = @{$gbininfo_cache->{"$prp/$arch"} || []};
  if ($remoteprojs->{$projid}) {
    if (!$gbininfo || !$ps2) {
      return $gbininfo if defined($gbininfo) && !$gbininfo;	# in progress
      $ps2 = $ps ? {} : undef;
      $gbininfo = BSSched::Remote::read_gbininfo_remote($ctx, "$prp/$arch", $remoteprojs->{$projid}, $ps2);
      $gbininfo_cache->{"$prp/$arch"} = [ $gbininfo ] if defined($gbininfo) && !$gbininfo;	# cache "in progress"
      $gbininfo_cache->{"$prp/$arch"} = [ $gbininfo, $ps2 ] if $gbininfo && $ps2;
    }
    if ($gbininfo && $ps) {
      $ps->{$_} = $ps2->{$_} for keys %{$ps2 || {}};
    }
    return $gbininfo;
  }
  if (!$gbininfo) {
    my $reporoot = $gctx->{'reporoot'};
    $gbininfo = BSSched::BuildResult::read_gbininfo("$reporoot/$prp/$arch", $arch eq $gctx->{'arch'} ? 0 : 1);
    $gbininfo_cache->{"$prp/$arch"} = [ $gbininfo ] if $gbininfo;
  }
  return $gbininfo;
}

sub gbininfo_is_delayed {
  my ($ctx, $prp, $arch) = @_;
  my $gc = ($ctx->{'gbininfo_cache'} || {})->{"$prp/$arch"};
  return $gc && defined($gc->[0]) && !$gc->[0] ? 1 : 0;
}

sub rebuild_gbininfo {
  my ($ctx, $prp) = @_;
  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $reporoot = $gctx->{'reporoot'};
  my $dir = "$reporoot/$prp/$myarch";
  my $gbininfo = $ctx->read_gbininfo($prp);
  unlink("$dir/$_/.bininfo") for sort keys %{$gbininfo || {}};
  my $gbininfo_cache = $ctx->{'gbininfo_cache'};
  delete $gbininfo_cache->{"$prp/$myarch"} if $gbininfo_cache;
  BSSched::BuildResult::rebuild_gbininfo($dir);
}

sub read_packstatus {
  my ($ctx, $prp, $arch) = @_;
  my $reporoot = $ctx->{'gctx'}->{'reporoot'};
  my $ps = $ctx->{'packstatus_cache'}->{"$prp/$arch"};
  return $ps if $ps;
  if (-e "$reporoot/$prp/$arch/:packstatus") {
    $ps = BSUtil::retrieve("$reporoot/$prp/$arch/:packstatus", 1);
    if (!$ps) {
      # compat with very old obs versions
      $ps = (readxml("$reporoot/$prp/$arch/:packstatus", $BSXML::packstatuslist, 1) || {})->{'packstatus'} || [];
      $ps = { map {$_->{'name'} => $_->{'status'}} @$ps };
    } else {
      $ps = $ps->{'packstatus'};
    }
  }
  $ps ||= {};
  $ctx->{'packstatus_cache'}->{"$prp/$arch"} = $ps;
  return $ps;
}

sub writejob {
  return BSSched::BuildJob::writejob(@_);
}

sub getconfig {
  my ($ctx, $projid, $repoid, $arch, $configpath) = @_;
  return BSSched::ProjPacks::getconfig($ctx->{'gctx'}, $projid, $repoid, $arch, $configpath);
}

sub append_info_path {
  my ($ctx, $info, $path) = @_;

  my $gctx = $ctx->{'gctx'};
  my $projid = $ctx->{'project'};

  # append path to info
  my @oldpath;
  if ($info->{'extrapathlevel'}) {
    @oldpath = @{$info->{'path'}};	# create copy
    @oldpath = splice(@oldpath, -$info->{'extrapathlevel'});
  }
  if (!BSUtil::identical(\@oldpath, $path)) {
    print "    append_info_path: updating path\n";
    # path has changed. remove old one
    splice(@{$info->{'path'}}, -$info->{'extrapathlevel'}) if $info->{'extrapathlevel'};
    delete $info->{'extrapathlevel'};
    # add new one
    push @{$info->{'path'}}, @$path;
    $info->{'extrapathlevel'} = @$path if @$path;
    # we changed dependencies, trigger a postprocess
    $gctx->{'get_projpacks_postprocess_needed'} = 1;
  }

  # check if we have missing remotemap entries
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $remotemissing = $gctx->{'remotemissing'};
  my $ret = 1;
  my @missing;
  for my $pe (@$path) {
    my $pr = $pe->{'project'};
    next if $pr eq '_obsrepositories';
    next if $projpacks->{$pr} || ($remoteprojs->{$pr} && defined($remoteprojs->{$pr}->{'config'})) || $remotemissing->{$pr};
    $ret = 0;					# entry unknown, delay
    next if defined $remotemissing->{$pr};	# 0: fetch is already in progress
    push @missing, $pr;
  }
  for my $projid (BSUtil::unify(@missing)) {
    my $asyncmode = $gctx->{'asyncmode'};
    my $async;
    if ($asyncmode) {
      $async = {
	'_changeprp' => $ctx->{'changeprp'},
	'_changetype' => $ctx->{'changetype'} || 'high',
	'_changelevel' => $ctx->{'changelevel'} || 1,
      };
    }
    $remotemissing->{$projid} = 0;	# now in progress
    BSSched::ProjPacks::get_remoteproject($gctx, $async, $projid);
  }
  return $ret;
}

# create an estimation about how each package is needed. We put this information
# in the build job so that the dispatcher can use it to priorize needed jobs.
sub create_rebuildpackage_needed {
  my ($ctx) = @_;
  my $needed = $ctx->{'rebuildpackage_needed'} = {};
  my $edeps = $ctx->{'edeps'};
  my $dep2src = $ctx->{'dep2src'};
  for my $p (keys %$edeps) {
    $needed->{$_}++ for map { $dep2src->{$_} || $_ } @{$edeps->{$p}};
  }
  return $needed;
}

1;

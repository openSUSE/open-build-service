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
package BSSched::Remote;

# gctx functions
#   setup_watches
#   updateremoteprojs
#   getchangedremoteprojs
#   remoteprojid
#   fetchremote_sync
#   fetchremoteproj
#   fetchremoteconfig
#   remotemap2remoteprojs
#   addrepo_remote_unpackcpio
#   convertpackagebinarylist
#   cleanup_remotepackstatus

# ctx functions
#   addrepo_remote
#   addrepo_remote_resume
#   read_gbininfo_remote
#   read_gbininfo_remote_resume
#
# gctx usage
#   watchremote
#   projpacks
#   remoteprojs
#   arch
#   remoteproxy
#   obsname
#   asyncmode
#   rctx
#   repodatas
#   remotecache
#   prpnotready
#   remotegbininfos
#   remotepackstatus
#   remotepackstatus_cleanup
#
# ctx usage
#   gctx
#   prp

use strict;
use warnings;

use Digest::MD5 ();

use BSUtil;
use BSSolv;
use BSRPC;
use BSHTTP;
use BSSched::RPC;
use BSConfiguration;
use BSXML;

=head2 setup_watches - create watches for all dependencies on remote projects

 TODO: add description

=cut

sub setup_watches {
  my ($gctx) = @_;

  my $projpacks = $gctx->{'projpacks'};
  my $watchremote = $gctx->{'watchremote'};

  # clear old data
  %{$watchremote} = ();	# reset all watches

  my %needremoteproj;		# we need those projects
  my %needremoterepo;		# we need those repos

  # add watches for all linked packages
  my $projpacks_linked = $gctx->{'projpacks_linked'};
  if (%$projpacks_linked) {
    for my $projid (sort keys %$projpacks_linked) {
      next if $projpacks->{$projid} && !$projpacks->{$projid}->{'remoteurl'};
      my $rproj = remoteprojid($gctx, $projid);
      next unless $rproj;			# not remote, so nothing to watch
      my $remoteurl = $rproj->{'partition'} ? $BSConfig::srcserver : $rproj->{'remoteurl'};

      $needremoteproj{$projid} = $rproj if $rproj->{'partition'};	# we need to keep partition entries so we know where to watch
      my %packids = map {$_->{'package'} => 1} @{$projpacks_linked->{$projid}};
      if ($packids{':*'}) {
	# we watch all packages
        $watchremote->{$remoteurl}->{"package/$rproj->{'remoteproject'}"} = $projid;
      } else {
        for my $packid (sort keys %packids) {
          $watchremote->{$remoteurl}->{"package/$rproj->{'remoteproject'}/$packid"} = $projid;
	}
      }
    }
  }

  # add watches for project links
  my $expandedprojlink = $gctx->{'expandedprojlink'};
  if (%$expandedprojlink) {
    my %watched = map {$_ => 1} map {@$_} values %$expandedprojlink;
    for my $projid (sort keys %watched) {
      next if $projpacks->{$projid} && !$projpacks->{$projid}->{'remoteurl'};
      my $rproj = remoteprojid($gctx, $projid);
      next unless $rproj;			# not remote, so nothing to watch
      my $remoteurl = $rproj->{'partition'} ? $BSConfig::srcserver : $rproj->{'remoteurl'};

      $needremoteproj{$projid} = $rproj;	# we need this one in remoteprojs
      $watchremote->{$remoteurl}->{"project/$rproj->{'remoteproject'}"} = $projid;
    }
  }

  # add watches for all prp dependencies
  # this includes the prpsearchpath plus the extra deps from kiwi/aggregates/...
  # (we just watch the repository for the extra deps as it costs too much to
  # watch every single package)
  my %projdeps;
  my $rprpdeps = $gctx->{'rprpdeps'};
  if (%$rprpdeps) {
    my $myarch = $gctx->{'arch'};
    my $localarch = $myarch eq 'local' && $BSConfig::localarch ? $BSConfig::localarch : undef;
    for my $prp (keys %$rprpdeps) {
      my ($projid, $repoid) = split('/', $prp, 2);
      push @{$projdeps{$projid}}, "$repoid/$myarch";
      push @{$projdeps{$projid}}, "$repoid/$localarch" if $localarch
    }
  }

  # add watches for all the host prpsearchpath
  if (%{$gctx->{'prpsearchpath_host'}}) {
    my $prpsearchpath_host = $gctx->{'prpsearchpath_host'};
    for my $prp (keys %$prpsearchpath_host) {
      my $ent = $prpsearchpath_host->{$prp};
      my $hostarch = $ent->[0];
      for my $aprp (@{$ent->[1]}) {
	my ($aprojid, $arepoid) = split('/', $aprp, 2);
        push @{$projdeps{$aprojid}}, "$arepoid/$hostarch";
      }
    }
  }

  for my $projid (sort keys %projdeps) {
    next if $projpacks->{$projid} && !$projpacks->{$projid}->{'remoteurl'};
    my $rproj = remoteprojid($gctx, $projid);
    next unless $rproj;		# not remote, so nothing to watch
    my $remoteurl = $rproj->{'partition'} ? $BSConfig::srcserver : $rproj->{'remoteurl'};

    # we need the config for all path elements, so we also add a project watch
    # XXX: should make this implicit with the repository watch
    $needremoteproj{$projid} = $rproj;	# we need this one in remoteprojs
    $watchremote->{$remoteurl}->{"project/$rproj->{'remoteproject'}"} = $projid;

    # add watches for the repositories
    for my $repoidarch (sort @{$projdeps{$projid}}) {
      $needremoterepo{"$projid/$repoidarch"} = 1;
      $watchremote->{$remoteurl}->{"repository/$rproj->{'remoteproject'}/$repoidarch"} = $projid;
    }
  }

  # make sure we have the needed project data and delete the entries
  # we no longer need
  updateremoteprojs($gctx, \%needremoteproj);

  # drop unwatched remote repos
  my $repocache = $gctx->{'repodatas'};
  if ($repocache) {
    for my $prpa (grep {!$needremoterepo{$_}} $repocache->getremote()) {
      print "dropping remote cache for $prpa\n";
      my ($projid, $repoid, $arch) = split('/', $prpa, 3);
      $repocache->drop("$projid/$repoid", $arch);
    }
  }
}

=head2 updateremoteprojs - sync remoteprojs with data from watch collection

This function deletes all no longer needed elements from the
remoteprojs hash. It also calls fetchremoteproj for missing
entries, which should actually not happen as the remotemap
should already contain all needed entries.

=cut

sub updateremoteprojs {
  my ($gctx, $needremoteproj) = @_;

  my $remoteprojs = $gctx->{'remoteprojs'};
  my $remotemissing = $gctx->{'remotemissing'};
  for my $projid (keys %$remoteprojs) {
    my $or = $remoteprojs->{$projid};
    my $r = $needremoteproj->{$projid};
    if (!$or || !$r) {
      print "dropping no longer needed remote $projid entry\n";
      delete $remoteprojs->{$projid};
      next;
    }
  }
  for my $projid (keys %$remotemissing) {
    if ($remoteprojs->{$projid} && defined($remoteprojs->{$projid}->{'config'})) {
      print "dropping wrong remotemissing $projid entry\n";
      delete $remotemissing->{$projid};
      next;
    }
    next if $needremoteproj->{$projid};
    print "dropping no longer needed remotemissing $projid entry\n";
    delete $remotemissing->{$projid};
  }
}

=head2 print_remote_stats - print some statistics about the remote projects

 TODO: add description

=cut

sub print_remote_stats {
  my ($gctx) = @_;
  print "remote project data statistics:\n";
  printf "  remote projects: %d\n", scalar(keys %{$gctx->{'remoteprojs'} || {}});
  printf "  remote projects missing: %d\n", scalar(keys %{$gctx->{'remotemissing'} || {}});
  my $watchremote = $gctx->{'watchremote'};
  my $wsum = 0;
  $wsum += keys(%{$watchremote->{$_} || {}} ) for keys %{$watchremote || {}};
  printf "  remote watches: %d %d\n", scalar(keys %{$watchremote || {}}), $wsum;
}

=head2 remoteprojid - TODO: add summary

 TODO: add description

=cut

sub remoteprojid {
  my ($gctx, $projid) = @_;
  my $rsuf = '';
  my $origprojid = $projid;

  # check partition case, all partition projects are already in remoteprojs
  my $remoteprojs = $gctx->{'remoteprojs'};
  return $remoteprojs->{$projid} if $remoteprojs->{$projid} && $remoteprojs->{$projid}->{'partition'};

  # go up hierarchy until we find a remote project
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid};
  if ($proj) {
    return undef unless $proj->{'remoteurl'};
    if (!$proj->{'remoteproject'}) {
      $proj = { %$proj };
      delete $proj->{'remoteurl'};
      return $proj;
    }
    return {
      'name' => $projid,
      'root' => $projid,
      'remoteroot' => $proj->{'remoteproject'},
      'remoteurl' => $proj->{'remoteurl'},
      'remoteproject' => $proj->{'remoteproject'},
    };
  }
  while ($projid =~ /^(.*)(:.*?)$/) {
    $projid = $1;
    $rsuf = "$2$rsuf";
    $proj = $projpacks->{$projid};
    if ($proj) {
      return undef unless $proj->{'remoteurl'};
      if ($proj->{'remoteproject'}) {
	$rsuf = "$proj->{'remoteproject'}$rsuf";
      } else {
	$rsuf =~ s/^://;
      }
      return {
	'name' => $origprojid,
	'root' => $projid,
	'remoteroot' => $proj->{'remoteproject'},
	'remoteurl' => $proj->{'remoteurl'},
	'remoteproject' => $rsuf,
      };
    }
  }

  # nope, not a remote project
  return undef;
}

=head2 remotemap2remoteprojs - update remoteprojs with the remotemap data

 TODO: add description

=cut

sub remotemap2remoteprojs {
  my ($gctx, $remotemap) = @_;

  my $remoteprojs = $gctx->{'remoteprojs'};
  for my $proj (@{$remotemap || []}) {
    my $projid = delete $proj->{'project'};
    my $oproj = $remoteprojs->{$projid};
    if (!$proj->{'remoteurl'} && !$proj->{'error'}) {
      # remote project is gone (partition case)
      delete $remoteprojs->{$projid};
      $gctx->{'remoteprojs_changed'}->{$projid} = 1 if $oproj;
      next;
    }
    BSSched::ProjPacks::trigger_auto_deep_checks($gctx, $projid, $oproj, $proj) if $oproj && defined($oproj->{'config'}) && defined($proj->{'config'}) && $oproj->{'config'} ne $proj->{'config'};
    undef $oproj if $oproj && ($oproj->{'remoteurl'} ne $proj->{'remoteurl'} || $oproj->{'remoteproject'} ne $proj->{'remoteproject'});
    my $c = $proj->{'config'};
    $c = $oproj->{'config'} if !defined($c) && $oproj;
    my $error = delete $proj->{'error'};
    $proj = $oproj if $proj->{'proto'} && $oproj && !$oproj->{'proto'};
    delete $proj->{'config'};
    $proj->{'config'} = $c if defined $c;
    if ($error) {
      $proj->{'error'} = $error;
      $gctx->{'retryevents'}->addretryevent({'type' => 'project', 'project' => $projid}) if $error =~ /interconnect error:/;
    }
    if (!$proj->{'proto'} && !BSUtil::identical($proj, $oproj, {'error' => 1, 'person' => 1, 'group' => 1})) {
      $gctx->{'remoteprojs_changed'}->{$projid} = 1;
    }
    $remoteprojs->{$projid} = $proj;
  }
  # update remotemissing map
  my $projpacks = $gctx->{'projpacks'};
  my $remotemissing = $gctx->{'remotemissing'};
  for my $projid (keys %$remotemissing) {
    if ($projpacks->{$projid}) {
      delete $remotemissing->{$projid};		# no longer missing
    } elsif ($remoteprojs->{$projid}) {
      if (!defined($remoteprojs->{$projid}->{'config'})) {
        next unless $remotemissing->{$projid};	# keep the "in progress" flag
      }
      delete $remotemissing->{$projid};		# no longer missing
    }
  }
}

sub getchangedremoteprojs {
  my ($gctx, $clear) = @_;
  return () unless %{$gctx->{'remoteprojs_changed'} || {}};
  my @changed = sort keys %{$gctx->{'remoteprojs_changed'}};
  %{$gctx->{'remoteprojs_changed'}} = () if $clear;
  return @changed;
}

###########################################################################
###
### remote BuildRepo (aka full tree) support
###

sub addrepo_remote {
  my ($ctx, $pool, $prp, $arch, $remoteproj) = @_;

  my ($projid, $repoid) = split('/', $prp, 2);
  return undef unless $remoteproj;
  if ($remoteproj->{'error'}) {
    print "    remote project $prp/$arch: $remoteproj->{'error'}\n";
    return undef;
  }
  my @modules;
  @modules = $pool->getmodules() if defined &BSSolv::pool::getmodules;
  my $gctx = $ctx->{'gctx'};
  if ($gctx->{'arch'} ne $arch) {
    print "    fetching remote repository state for $prp/$arch\n";
  } else {
    print "    fetching remote repository state for $prp\n";
  }
  my $param = {
    'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$repoid/$arch/_repository",
    'timeout' => 200,
    'receiver' => \&BSHTTP::cpio_receiver,
    'proxy' => $gctx->{'remoteproxy'},
  };
  if ($gctx->{'asyncmode'}) {
    $param->{'async'} = { '_resume' => \&addrepo_remote_resume, '_prp' => $prp, '_arch' => $arch, '_modules' => \@modules };
  }
  my $cpio;
  my $solvok;
  eval {
    die('unsupported view\n') unless $remoteproj->{'partition'} || defined($BSConfig::usesolvstate) && $BSConfig::usesolvstate;
    $param->{'async'}->{'_solvok'} = 1 if $param->{'async'};
    my @args = ('view=solvstate');
    push @args, 'noajax=1' if $remoteproj->{'partition'};
    $cpio = $ctx->xrpc("repository/$prp/$arch", $param, undef, @args);
    $solvok = 1 if $cpio;
  };
  if ($@ && $@ =~ /unsupported view/) {
    $solvok = undef;
    delete $param->{'async'}->{'_solvok'} if $param->{'async'};
    my @args = ('view=cache');
    push @args, map {"module=$_"} @modules;
    eval {
      $cpio = $ctx->xrpc("repository/$prp/$arch", $param, undef, @args);
    };
  }
  if ($@) {
    return addrepo_remote_unpackcpio($ctx->{'gctx'}, $pool, $prp, $arch, $cpio, undef, \@modules, $@);
  }
  return 0 if $param->{'async'} && $cpio;       # hack: false but not undef
  return addrepo_remote_unpackcpio($ctx->{'gctx'}, $pool, $prp, $arch, $cpio, $solvok, \@modules);
}

sub addrepo_remote_resume {
  my ($ctx, $handle, $error, $cpio) = @_;
  my $gctx = $ctx->{'gctx'};
  my $pool = BSSolv::pool->new();
  my $r = addrepo_remote_unpackcpio($gctx, $pool, $handle->{'_prp'}, $handle->{'_arch'}, $cpio, $handle->{'_solvok'}, $handle->{'_modules'}, $error);
  $ctx->setchanged_unless_othersinprogress($handle);
}

sub import_annotation {
  my ($annotation) = @_;
  return $annotation unless ref($annotation);
  my %a;
  for (qw{repo disturl buildtime}) {
    $a{$_} = $annotation->{$_} if exists $annotation->{$_};
  }
  return BSUtil::toxml(\%a, $BSXML::binannotation);
}

sub addrepo_remote_unpackcpio {
  my ($gctx, $pool, $prp, $arch, $cpio, $solvok, $modules, $error) = @_;

  my $myarch = $gctx->{'arch'};
  my $remotecache = $gctx->{'remotecache'};
  my @modules = @{$modules || []};

  my $modulestr = @modules ? '/'.join('/', sort @$modules) : '';
  my $cachemd5 = Digest::MD5::md5_hex("$prp/$arch$modulestr");
  substr($cachemd5, 2, 0, '/');

  my $repocache = $gctx->{'repodatas'};
  my @setcacheargs = ('isremote' => 1, 'modulestr' => $modulestr);

  if ($error) {
    chomp $error;
    warn("$error\n");
    if (BSSched::RPC::is_transient_error($error)) {
      my ($projid, $repoid) = split('/', $prp, 2);
      $gctx->{'retryevents'}->addretryevent({'type' => 'repository', 'project' => $projid, 'repository' => $repoid, 'arch' => $arch});
      my $solvfile = "$remotecache/$cachemd5.solv";
      if (-s $solvfile) {
        # try last solv file
        my $r;
        eval {$r = $pool->repofromfile($prp, $solvfile);};
        if ($r) {
	  $repocache->setcache($prp, $arch, 'solvfile' => $solvfile, @setcacheargs) if $repocache;
	  return $r;
        }
      }
    }
    $repocache->setcache($prp, $arch, 'error' => $error, @setcacheargs) if $repocache;
    return undef;
  }

  my %cpio = map {$_->{'name'} => $_} @{$cpio || []};
  my $repostate = $cpio{'repositorystate'};
  $repostate = BSUtil::fromxml($repostate->{'data'}, $BSXML::repositorystate, 2) if $repostate;
  if ($arch eq $myarch) {
    my $prpnotready = $gctx->{'prpnotready'};
    delete $prpnotready->{$prp};
    if ($repostate && $repostate->{'blocked'}) {
      $prpnotready->{$prp} = { map {$_ => 1} @{$repostate->{'blocked'}} };
    }
  }
  my $r;
  my $isempty;
  if (exists $cpio{'repositorysolv'} && $solvok) {
    eval {$r = $pool->repofromstr($prp, $cpio{'repositorysolv'}->{'data'}); };
    warn($@) if $@;
  } elsif (exists $cpio{'repositorycache'}) {
    my $cache;
    if (defined &BSSolv::thawcache) {
      eval { $cache = BSSolv::thawcache($cpio{'repositorycache'}->{'data'}) };
    } else {
      eval { $cache = BSUtil::fromstorable($cpio{'repositorycache'}->{'data'}) };
    }
    warn($@) if $@;
    return undef unless $cache;
    delete $cache->{'/url'};
    delete $cache->{'/dodcookie'};
    delete $cache->{'/external/'};
    my $repomodules = delete $cache->{'/modules'};

    if (@modules) {
      # intersect requested modules with known modules
      $repomodules ||= [];
      if (@$repomodules) {
	my %repomodules = map {$_ => 1} @$repomodules;
        @modules = grep { $repomodules{$_} } @modules;
      } else {
        @modules = ();
      }
      # update modulestr and cachemd5 with new modules list
      $modulestr = @modules ? '/'.join('/', sort @modules) : '';
      $cachemd5 = Digest::MD5::md5_hex("$prp/$arch$modulestr");
      substr($cachemd5, 2, 0, '/');
      @setcacheargs = ('isremote' => 1, 'modulestr' => $modulestr, 'modules' => $repomodules);
    }

    # postprocess entries
    my $havedod;
    for (values %$cache) {
      $havedod = 1 if ($_->{'hdrmd5'} || '') eq 'd0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0';
      # free some unused entries to save mem
      delete $_->{'path'};
      delete $_->{'id'};
      # import annotations
      $_->{'annotation'} = import_annotation($_->{'annotationdata'} || $_->{'annotation'}) if $_->{'annotation'};
    }
    # add special "havedod" marker
    $cache->{'/dodcookie'} = 'remote repository with dod packages' if $havedod;
    $r = $pool->repofromdata($prp, $cache);
  } else {
    # return empty repo
    $r = $pool->repofrombins($prp, '');
    $repocache->setcache($prp, $arch, 'solv' => $r->tostr(), @setcacheargs) if $repocache;
    $isempty = 1;
  }
  return undef unless $r;
  # write solv file
  mkdir_p("$remotecache/".substr($cachemd5, 0, 2));
  my $solvfile = "$remotecache/$cachemd5.solv";
  BSSched::BuildRepo::writesolv("$solvfile$$", $solvfile, $r);
  $repocache->setcache($prp, $arch, 'solvfile' => $solvfile, @setcacheargs) if $repocache && !$isempty;
  return $r;
}

###########################################################################
###
### packstatus cache handling
###

sub update_remotepackstatus_cache {
  my ($gctx, $prpa, $rpackstatus, $packstatususer) = @_;
  return unless $packstatususer && $gctx->{'asyncmode'};
  my $remotepackstatus = $gctx->{'remotepackstatus'};
  my $remotepackstatus_cleanup = $gctx->{'remotepackstatus_cleanup'};
  $rpackstatus->{'/users'} = [];
  $rpackstatus->{'/users'} = [ @{$remotepackstatus->{$prpa}->{'/users'} || []} ] if $remotepackstatus->{$prpa};
  push @{$rpackstatus->{'/users'}}, $packstatususer unless grep {$_ eq $packstatususer} @{$rpackstatus->{'/users'}};
  push @{$remotepackstatus_cleanup->{$packstatususer}}, $prpa;
  $remotepackstatus->{$prpa} = $rpackstatus;
}

sub read_remotepackstatus_cache {
  my ($gctx, $prpa, $packstatususer) = @_;
  return undef unless $packstatususer && $gctx->{'asyncmode'};
  my $remotepackstatus = $gctx->{'remotepackstatus'};
  my $ps = $remotepackstatus->{$prpa};
  return undef unless $ps;
  return undef unless grep {$_ eq $packstatususer} @{$ps->{'/users'} || []};
  return $ps;
}

sub cleanup_remotepackstatus {
  my ($gctx, $packstatususer) = @_;

  my $remotepackstatus = $gctx->{'remotepackstatus'};
  my $remotepackstatus_cleanup = $gctx->{'remotepackstatus_cleanup'};
  return unless $remotepackstatus_cleanup->{$packstatususer};
  print "    cleaning up remote packstatus\n";
  for my $prpa (@{$remotepackstatus_cleanup->{$packstatususer}}) {
    my $rpackstatus = $remotepackstatus->{$prpa};
    my @users = grep {$_ ne $packstatususer} @{$rpackstatus->{'/users'} || []};
    $rpackstatus->{'/users'} = \@users;
    print "      - $prpa: ".@users." users\n";
    delete $remotepackstatus->{$prpa} unless @users;
  }
  delete $remotepackstatus_cleanup->{$packstatususer};
}

###########################################################################
###
### gbininfo cache handling
###

sub read_gbininfo_remote_cache {
  my ($gctx, $prpa, $packstatus, $rpackstatus) = @_;
  my $remotecache = $gctx->{'remotecache'};
  my $cachemd5 = Digest::MD5::md5_hex($prpa);
  substr($cachemd5, 2, 0, '/');
  return undef unless -s "$remotecache/$cachemd5.bininfo";
  my $gbininfo = BSUtil::retrieve("$remotecache/$cachemd5.bininfo", 1);
  return undef unless $gbininfo;
  if ($packstatus && $rpackstatus) {
    $packstatus->{$_} = $rpackstatus->{$_} for keys %$rpackstatus;
    delete $packstatus->{'/users'};
  }
  return $gbininfo;
}

sub update_gbininfo_remote_cache {
  my ($gctx, $prpa, $gbininfo, $cookie) = @_;
  my $remotecache = $gctx->{'remotecache'};
  my $cachemd5 = Digest::MD5::md5_hex($prpa);
  substr($cachemd5, 2, 0, '/');
  mkdir_p("$remotecache/".substr($cachemd5, 0, 2));
  BSUtil::store("$remotecache/$cachemd5.bininfo.new$$", "$remotecache/$cachemd5.bininfo", $gbininfo);
  my $remotegbininfos = $gctx->{'remotegbininfos'};
  $remotegbininfos->{$prpa} = { 'lastfetch' => time() };
  $remotegbininfos->{$prpa}->{'cookie'} = $cookie if defined $cookie;
}

###########################################################################
###
### remote BuildResult (aka gbininfo) support
###

sub read_gbininfo_remote {
  my ($ctx, $prpa, $remoteproj, $packstatus) = @_;

  return undef unless $remoteproj;
  if ($remoteproj->{'error'}) {
    print "    remote project $prpa: $remoteproj->{'error'}\n";
    return undef;
  }

  my $gctx = $ctx->{'gctx'};
  my $remotegbininfos = $gctx->{'remotegbininfos'};
  my $now = time();

  # first check error case
  if ($remotegbininfos->{$prpa} && $remotegbininfos->{$prpa}->{'error'} && ($remotegbininfos->{$prpa}->{'lastfetch'} || 0) > $now - 3600) {
    print "    remote project binary state for $prpa: $remotegbininfos->{$prpa}->{'error'}\n";
    return undef;
  }

  # check if we can use our packstatus cache
  my $rpackstatus;
  $rpackstatus = read_remotepackstatus_cache($gctx, $prpa, $ctx->{'prp'}) if $packstatus;

  if ((!$packstatus || $rpackstatus) && $remotegbininfos->{$prpa} && ($remotegbininfos->{$prpa}->{'lastfetch'} || 0) > $now - 3600) {
    my $gbininfo = read_gbininfo_remote_cache($gctx, $prpa, $packstatus, $rpackstatus);
    return $gbininfo if $gbininfo;
  }

  # need to fetch new data, first try the packstatus if we have a bininfo cookie
  my ($projid, $repoid, $arch) = split('/', $prpa, 3);
  if ($remoteproj->{'partition'} && $remotegbininfos->{$prpa} && $remotegbininfos->{$prpa}->{'cookie'} && ($packstatus && !$rpackstatus)) {
    print "    fetching remote packstatus for $prpa\n";
    my $param = {
      'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$repoid/$arch",
      'timeout' => 200,
      'proxy' => $gctx->{'remoteproxy'},
    };
    if ($gctx->{'asyncmode'}) {
      $param->{'async'} = { '_resume' => \&read_packstatus_remote_resume, '_prpa' => $prpa };
    }
    my $rpackstatus;
    eval {
      $rpackstatus = $ctx->xrpc("bininfo/$prpa", $param, \&BSUtil::fromstorable, "view=packstatus", "withbininfocookie=1");
    };
    return 0 if !$@ && $rpackstatus && $param->{'async'};
    if ($@) {
      warn($@);
    } elsif ($rpackstatus->{'.bininfocookie'} && $rpackstatus->{'.bininfocookie'} eq ($remotegbininfos->{$prpa}->{'cookie'} || '')) {
      delete $rpackstatus->{'.bininfocookie'};
      update_remotepackstatus_cache($gctx, $prpa, $rpackstatus, $ctx->{'prp'});
      my $gbininfo = read_gbininfo_remote_cache($gctx, $prpa, $packstatus, $rpackstatus);
      return $gbininfo if $gbininfo;
    }
    delete $remotegbininfos->{$prpa}->{'cookie'};
  }

  print "    fetching remote project binary state for $prpa\n";
  my $param = {
    'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$repoid/$arch",
    'timeout' => 200,
    'proxy' => $gctx->{'remoteproxy'},
  };
  if ($gctx->{'asyncmode'}) {
    $param->{'async'} = { '_resume' => \&read_gbininfo_remote_resume, '_prpa' => $prpa };
  }
  my $packagebinarylist;
  eval {
    if ($remoteproj->{'partition'}) {
      $param->{'async'}->{'_isgbininfo'} = 1 if $param->{'async'};
      $packagebinarylist = $ctx->xrpc("bininfo/$prpa", $param, \&BSUtil::fromstorable, "view=gbininfocode", "withbininfocookie=1");
    } else {
      $packagebinarylist = $ctx->xrpc("bininfo/$prpa", $param, $BSXML::packagebinaryversionlist, "view=binaryversionscode");
    }
  };
  if ($@) {
    warn($@);
    my $error = $@;
    $error =~ s/\n$//s;
    ($projid, $repoid) = split('/', $ctx->{'prp'}, 2);
    $gctx->{'retryevents'}->addretryevent({'type' => 'recheck', 'project' => $projid, 'repository' => $repoid}) if BSSched::RPC::is_transient_error($error);
    return undef;
  }
  return 0 if $packagebinarylist && $param->{'async'};
  my $gbininfo;
  ($gbininfo, $rpackstatus) = convertpackagebinarylist($gctx, $prpa, $packagebinarylist, undef, undef, $remoteproj->{'partition'} ? 1 : undef);
  if ($packstatus && $rpackstatus) {
    $packstatus->{$_} = $rpackstatus->{$_} for keys %$rpackstatus;
    delete $packstatus->{'/users'};
    delete $packstatus->{'/bininfocookie'};
  }
  return $gbininfo;
}

sub read_packstatus_remote_resume {
  my ($ctx, $handle, $error, $rpackstatus) = @_;
  my $gctx = $ctx->{'gctx'};
  my $prpa = $handle->{'_prpa'};
  my $remotegbininfos = $gctx->{'remotegbininfos'};
  if ($error) {
    # on error just delete the cookie and retry
    chomp $error;
    warn("$error\n");
    delete $remotegbininfos->{$prpa}->{'cookie'} if $remotegbininfos->{$prpa};
    $ctx->setchanged_unless_othersinprogress($handle);
    return;
  }
  if ($rpackstatus->{'.bininfocookie'} && $rpackstatus->{'.bininfocookie'} eq ($remotegbininfos->{$prpa}->{'cookie'} || '') && $ctx->{'prp'}) {
    # gbininfo matches! update cache
    update_remotepackstatus_cache($gctx, $prpa, $rpackstatus, $ctx->{'prp'});
  } else {
    # sorry, need to do fetch the complete gbininfo. delete the cookie and retry
    delete $remotegbininfos->{$prpa}->{'cookie'} if $remotegbininfos->{$prpa};
  }
  $ctx->setchanged_unless_othersinprogress($handle);
}

sub read_gbininfo_remote_resume {
  my ($ctx, $handle, $error, $packagebinarylist) = @_;
  convertpackagebinarylist($ctx->{'gctx'}, $handle->{'_prpa'}, $packagebinarylist, $error, $ctx->{'prp'}, $handle->{'_isgbininfo'});
  $ctx->setchanged_unless_othersinprogress($handle);
}

sub convertpackagebinarylist {
  my ($gctx, $prpa, $packagebinarylist, $error, $packstatususer, $isgbininfo) = @_;

  if ($error) {
    chomp $error;
    warn("$error\n");
    $error ||= 'internal error';
    if (BSSched::RPC::is_transient_error($error)) {
      my ($projid, $repoid, $arch) = split('/', $prpa, 3);
      $gctx->{'retryevents'}->addretryevent({'type' => 'scanprjbinaries', 'project' => $projid, 'repository' => $repoid, 'arch' => $arch});
    }
    $gctx->{'remotegbininfos'}->{$prpa} = { 'lastfetch' => time(), 'error' => $error };
    return (undef, undef);
  }
  my $gbininfo = {};
  my $rpackstatus = {};
  my $bininfocookie;
  if ($isgbininfo) {
    $gbininfo = $packagebinarylist || {};
    $bininfocookie = delete $gbininfo->{'.bininfocookie'};
    for my $pkg (keys %$gbininfo) {
      my $bi = $gbininfo->{$pkg};
      $rpackstatus->{$pkg} = delete($bi->{'.code'}) if exists $bi->{'.code'};
    }
  } else {
    for my $binaryversionlist (@{$packagebinarylist->{'binaryversionlist'} || []}) {
      my %bins;
      for my $binary (@{$binaryversionlist->{'binary'} || []}) {
        my $filename = $binary->{'name'};
        # XXX: should not rely on the filename here!
        if ($filename =~ /^(?:::import::.*::)?(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/) {
          $bins{$filename} = {'filename' => $filename, 'name' => $1, 'arch' => $2};
        } elsif ($filename =~ /^([^\/]+)_[^\/]*_([^\/]*)\.deb$/) {
          $bins{$filename} = {'filename' => $filename, 'name' => $1, 'arch' => $2};
        } elsif ($filename =~ /^([^\/]+)-[^-]+-[^-]+-([a-zA-Z][^\/\.\-]*)\.pkg\.tar\.(?:gz|xz|zst)$/) {
          $bins{$filename} = {'filename' => $filename, 'name' => $1, 'arch' => $2};
        } elsif ($filename eq '.nouseforbuild') {
          $bins{$filename} = {};
        } else {
          $bins{$filename} = {'filename' => $filename};
        }
        $bins{$filename}->{'hdrmd5'} = $binary->{'hdrmd5'} if $binary->{'hdrmd5'};
        $bins{$filename}->{'leadsigmd5'} = $binary->{'leadsigmd5'} if $binary->{'leadsigmd5'};
        $bins{$filename}->{'md5sum'} = $binary->{'md5sum'} if $binary->{'md5sum'};
      }
      my $pkg = $binaryversionlist->{'package'};
      $gbininfo->{$pkg} = \%bins;
      $rpackstatus->{$pkg} = $binaryversionlist->{'code'} if $binaryversionlist->{'code'};
    }
  }
  update_gbininfo_remote_cache($gctx, $prpa, $gbininfo, $bininfocookie);
  update_remotepackstatus_cache($gctx, $prpa, $rpackstatus, $packstatususer);
  return ($gbininfo, $rpackstatus);
}

1;

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

use BSSched::ProjPacks;
use BSSched::BuildRepo;
use BSSched::BuildResult;
use BSSched::PublishRepo;
use BSSched::BuildJob;
use BSSched::Access;
use BSSched::Remote;	# for addrepo_remote
use BSSched::EventSource::Directory;

use BSSched::BuildJob::Aggregate;
use BSSched::BuildJob::Channel;
use BSSched::BuildJob::DeltaRpm;
use BSSched::BuildJob::KiwiImage;
use BSSched::BuildJob::KiwiProduct;
use BSSched::BuildJob::Docker;
use BSSched::BuildJob::Package;
use BSSched::BuildJob::Patchinfo;
use BSSched::BuildJob::PreInstallImage;
use BSSched::BuildJob::SimpleImage;
use BSSched::BuildJob::Unknown;


=head1 NAME

 BSSched::Checker

=head1 DESCRIPTION

 Check the status of a project's repository

=cut


my %handlers = (
  'kiwi-product'    => BSSched::BuildJob::KiwiProduct->new(),
  'kiwi-image'      => BSSched::BuildJob::KiwiImage->new(),
  'docker'          => BSSched::BuildJob::Docker->new(),
  'fissile'         => BSSched::BuildJob::Docker->new(),
  'patchinfo'       => BSSched::BuildJob::Patchinfo->new(),
  'aggregate'       => BSSched::BuildJob::Aggregate->new(),
  'preinstallimage' => BSSched::BuildJob::PreInstallImage->new(),
  'simpleimage'     => BSSched::BuildJob::SimpleImage->new(),
  'channel'         => BSSched::BuildJob::Channel->new(),
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
  return bless $ctx, $class;
}

=head2 set_repo_state - update the :schedulerstate file of a prp

=cut

sub set_repo_state {
  my ($ctx, $state, $details) = @_;

  my $myarch = $ctx->{'gctx'}->{'arch'};
  my $gdst = $ctx->{'gdst'};
  unlink("$gdst/:schedulerstate.dirty") if $state eq 'scheduling' || $state eq 'broken' || $state eq 'disabled';
  $state .= " $details" if $details;
  mkdir_p($gdst);
  writestr("$gdst/.:schedulerstate", "$gdst/:schedulerstate", $state);
}

=head2 wipe - delete this repo

=cut

sub wipe {
  my ($ctx) = @_;
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $prp = $ctx->{'prp'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  BSSched::PublishRepo::prpfinished($ctx);
  for my $dir (ls($gdst)) {
    # need lock for deleting publish area
    next if $dir eq ':repo' || $dir eq ':repoinfo';
    if (-d "$gdst/$dir") {
      BSUtil::cleandir("$gdst/$dir");
      rmdir("$gdst/$dir") || die("$gdst/$dir: $!\n");
    } else {
      unlink("$gdst/$dir") || die("$gdst/$dir: $!\n");
    }
  }
  $gctx->{'changed_med'}->{$prp} = 2; 
  BSSched::EventSource::Directory::sendrepochangeevent($gctx, $prp);

  BSSched::BuildJob::killbuilding($ctx->{'gctx'}, $prp);
  BSSched::PublishRepo::prpfinished($ctx);
  # now that :repo is gone we can remove the directory
  while (!rmdir($gdst)) {
    die("$gdst: $!\n") unless -e "$gdst/:schedulerstate.dirty";
    print "rep server created dirty file $gdst/:schedulerstate.dirty, retry ...\n";
    unlink("$gdst/:schedulerstate.dirty");
  }
  # XXX this should be rewritten if :repoinfo lives somewhere else
  my $repo = (grep {$_->{'name'} eq $repoid} @{($ctx->{'gctx'}->{'projpacks'}->{$projid} || {})->{'repository'} || []})[0];
  if (!$repo) {
    # this repo doesn't exist any longer!
    my $reporoot = $gctx->{'reporoot'};
    my $others;
    for (ls("$reporoot/$prp")) {
      next unless -d $_;
      $others = 1;
    }
    if (!$others) {
      # cannot delete repoinfo because it may contain splitdbg data
      # we rely on the publisher to clean up
      # unlink("$reporoot/$prp/:repoinfo");
      unlink("$reporoot/$prp/.finishedlock");
      rmdir("$reporoot/$prp");
    }
  }
}

sub setup {
  my ($ctx) = @_;
  my $prp = $ctx->{'prp'};
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  my $prpsearchpath = $gctx->{'prpsearchpath'}->{$prp};
  return (0, 'no prpsearchpath?') unless $prpsearchpath;
  $ctx->{'prpsearchpath'} = $prpsearchpath if $prpsearchpath;

  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $repo = (grep {$_->{'name'} eq $repoid} @{$projpacks->{$projid}->{'repository'} || []})[0];
  return (0, 'no repo?') unless $repo;
  if ($repo->{'status'} && $repo->{'status'} eq 'disabled') {
    return ('disabled', undef);
  }
  if ($gctx->{'projsuspended'}->{$projid}) {
    return ('blocked', $gctx->{'projsuspended'}->{$projid});
  }
  $ctx->{'repo'} = $repo;

  # set config
  my $bconf = BSSched::ProjPacks::getconfig($gctx, $projid, $repoid, $myarch, $prpsearchpath);
  if (!$bconf) {
    # see if it is caused by a remote error
    my $remoteprojs = $gctx->{'remoteprojs'};
    for my $aprp (@$prpsearchpath) {
      my ($aprojid) = split('/', $aprp, 2);
      my $error = $remoteprojs->{$aprojid}->{'error'} if $remoteprojs->{$aprojid} && $remoteprojs->{$aprojid}->{'error'};
      if ($error) {
        if ($error =~ /interconnect error:/) {
          $gctx->{'retryevents'}->addretryevent({'type' => 'project', 'project' => $aprojid});
        }
	return (0, "$aprojid: $error");
      }
    }
    my $lastprojid = (split('/', $prpsearchpath->[-1]))[0];
    return ('broken', "no config ($lastprojid)");
  }
  $ctx->{'conf'} = $bconf;
  if ($bconf->{'hostarch'} && !$BSCando::knownarch{$bconf->{'hostarch'}}) {
    return ('broken', "bad hostarch ($bconf->{'hostarch'})");
  }

  # set build type
  my $prptype = $bconf->{'type'};
  if (!$prptype || $prptype eq 'UNDEFINED') {
    # HACK force to channel if we have a channel package
    $prptype = 'channel' if grep {$_->{'channel'}} values(%{$projpacks->{$projid}->{'package'} || {}});
  }
  if (!$prptype || $prptype eq 'UNDEFINED') {
    # could still do channels/aggregates/patchinfos, but hey...
    my $lastprojid = (split('/', $prpsearchpath->[-1]))[0];
    return ('broken', "no build type ($lastprojid)");
  }
  $ctx->{'prptype'} = $prptype;
  my $pdatas = $projpacks->{$projid}->{'package'} || {};
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

  my $genmetaalgo = $bconf->{'buildflags:genmetaalgo'};
  $genmetaalgo = $gctx->{'genmetaalgo'} unless defined $genmetaalgo;
  return ('broken', 'unsupported genmetaalgo') if $genmetaalgo < 0 || $genmetaalgo > $gctx->{'maxgenmetaalgo'};
  BSBuild::setgenmetaalgo($genmetaalgo);
  BSSolv::setgenmetaalgo($genmetaalgo) if $gctx->{'maxgenmetaalgo'};
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
  my $myarch = $gctx->{'arch'};
  my $pdatas = $projpacks->{$projid}->{'package'} || {};
  my $dstcache = { 'fullcache' => {}, 'bininfocache' => {} };
  my $hadobsolete;
  for my $packid (grep {!/^[:\.]/} ls($gdst)) {
    next if $packid eq '_volatile';
    my $reason;
    if (!$pdatas->{$packid}) {
      next if $packid eq '_deltas';
      next if $projpacks->{$projid}->{'missingpackages'};
      $reason = 'obsolete';
    } else {
      my $pdata = $pdatas->{$packid};
      if (($pdata->{'error'} || '') eq 'excluded') {
	$reason = 'excluded';
      } else {
	my %info = map {$_->{'repository'} => $_} @{$pdata->{'info'} || []};
	my $info = $info{$repoid};
	next unless $info && ($info->{'error'} || '') eq 'excluded';
	$reason = 'excluded';
      }
    }
    my @files = ls("$gdst/$packid");
    my @ifiles = grep {/^::import::/ || /^\.meta\.success\.import\./} @files;
    if (@ifiles) {
      # only imported stuff?
      next unless grep {$_ ne '.bininfo' && !(/^::import::/ || /^\.meta\.success\.import\./)} @files;
    }
    print "      - $packid: is $reason\n";
    $hadobsolete = 1;
    delete $ctx->{'lastcheck'}->{$packid};
    # delete full entries
    my $useforbuildenabled = 1;
    $useforbuildenabled = BSUtil::enabled($repoid, $projpacks->{$projid}->{'useforbuild'}, $useforbuildenabled, $myarch);
    # hmm, need to exclude patchinfos here. cheating.
    $useforbuildenabled = 0 if -s "$gdst/$packid/.updateinfodata";
    # don't wipe imports if we're excluded
    my $importarch = $pdatas->{$packid} && @ifiles ? '' : undef;
    BSSched::BuildResult::update_dst_full($gctx, $prp, $packid, undef, undef, $useforbuildenabled, $ctx->{'prpsearchpath'}, $dstcache, $importarch);
    # delete other files
    unlink("$gdst/:logfiles.success/$packid");
    unlink("$gdst/:logfiles.fail/$packid");
    unlink("$gdst/:meta/$packid");
    if (@ifiles) {
      for (@files) {
	next if $_ eq '.bininfo';
	next if /^::import::/ || /^\.meta\.success\.import\./;
	unlink("$gdst/$packid/$_");
      }
    } else {
      BSUtil::cleandir("$gdst/$packid");
    }
    rmdir("$gdst/$packid");
    BSSched::BuildJob::killbuilding($gctx, $prp, $packid);
  }
  BSSched::BuildResult::set_dstcache_prp($gctx, $dstcache);

  if ($hadobsolete) {
    $gctx->{'changed_med'}->{$prp} = 2;
    BSSched::EventSource::Directory::sendrepochangeevent($gctx, $prp);
    unlink("$gdst/:repodone");
  }
}

sub preparepool {
  my ($ctx) = @_;
  my $gctx = $ctx->{'gctx'};
  my $bconf = $ctx->{'conf'};
  my $prp = $ctx->{'prp'};

  my $pool = BSSolv::pool->new();
  $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';
  $pool->settype('arch') if $bconf->{'binarytype'} eq 'arch';
  $ctx->{'pool'} = $pool;

  my $prpsearchpath = $ctx->{'prpsearchpath'};
  my $delayed;
  my $error;
  for my $rprp (@$prpsearchpath) {
    if (!$ctx->checkprpaccess($rprp)) {
      $error = "repository '$rprp' is unavailable";
      last;
    }
    my $r = $ctx->addrepo($pool, $rprp);
    if (!$r) {
      $delayed = 1 if defined $r;
      $error = "repository '$rprp' is unavailable";
      last;
    }
  }
  if ($error) {
    $ctx->{'havedelayed'} = 1 if $delayed;
    return ('broken', $error);
  }
  $pool->createwhatprovides();

  my $prpnotready = $gctx->{'prpnotready'};
  $prpnotready = undef if ($ctx->{'repo'}->{'block'} || '') eq 'local';

  # if we have the fast preparehashes helper function, use it.
  if (defined &BSSolv::pool::preparehashes) {
    ($ctx->{'dep2pkg'}, $ctx->{'dep2src'}, $ctx->{'depislocal'}, $ctx->{'notready'}, $ctx->{'subpacks'}) = $pool->preparehashes($prp, $prpnotready);
    return ('scheduling', undef);
  }

  # old code
  my %dep2src;
  my %dep2pkg;
  my %depislocal;     # used in meta calculation
  my %notready;       # unfinished and will modify :full
  my %subpacks;

  $prpnotready ||= {};
  for my $p ($pool->consideredpackages()) {
    my $rprp = $pool->pkg2reponame($p);
    my $n = $pool->pkg2name($p);
    my $sn = $pool->pkg2srcname($p) || $n;
    $dep2pkg{$n} = $p;
    $dep2src{$n} = $sn;
    if ($rprp eq $prp) {
      $depislocal{$n} = 1;
    } else {
      $notready{$sn} = 2 if $prpnotready->{$rprp} && $prpnotready->{$rprp}->{$sn};
    }
  }
  push @{$subpacks{$dep2src{$_}}}, $_ for keys %dep2src;

  $ctx->{'notready'} = \%notready;
  $ctx->{'dep2pkg'} = \%dep2pkg;
  $ctx->{'dep2src'} = \%dep2src;
  $ctx->{'depislocal'} = \%depislocal;
  $ctx->{'subpacks'} = \%subpacks;
  return ('scheduling', undef);
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
  if ($bconf->{'expandflags:preinstallexpand'}) {
    return ('broken', 'Build::expandpreinstalls does not exist') unless defined &Build::expandpreinstalls;
    my $err = Build::expandpreinstalls($bconf);
    return ('broken', "unresolvable $err") if $err;
  }
  my $projpacks = $gctx->{'projpacks'};
  my $pdatas = $projpacks->{$projid}->{'package'} || {};

  my %experrors;
  my %pdeps;
  my %pkg2src;
  my %pkgdisabled;
  my %havepatchinfos;
  my %pkg2buildtype;

  my $subpacks = $ctx->{'subpacks'};

  $ctx->{'experrors'} = \%experrors;
  my $packs = $ctx->{'packs'};
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
    } elsif ($info && $info->{'file'}) {
      # directly implement most common types
      if ($info->{'file'} =~ /\.(spec|dsc|kiwi|livebuild)$/) {
        $buildtype = $1;
        if ($buildtype eq 'kiwi') {
          $buildtype = $info->{'imagetype'} && $info->{'imagetype'}->[0] eq 'product' ? 'kiwi-product' : 'kiwi-image';
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
    if (exists($pdata->{'originproject'})) {
      # this is a package from a project link
      if (!$repo->{'linkedbuild'} || ($repo->{'linkedbuild'} ne 'localdep' && $repo->{'linkedbuild'} ne 'all')) {
	$pdeps{$packid} = [];
	next;
      }
    }
    $pkg2src{$packid} = $info->{'name'};

    if ($pdata->{'hasbuildenv'}) {
      $pdeps{$packid} = [];
      next;
    }
    my @deps = @{$info->{'dep'} || []};
    my $handler = $handlers{$buildtype} || $handlers{default};
    my ($eok, @edeps) = $handler->expand($bconf, $subpacks->{$info->{'name'}}, @deps);
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
  if (@$packs > 1) {
    if (defined &BSSolv::depsort2) {
      @$packs = BSSolv::depsort2(\%pdeps, $ctx->{'dep2src'}, \%pkg2src, \@cycles, @$packs);
    } else {
      @$packs = emulate_depsort2(\%pdeps, $ctx->{'dep2src'}, \%pkg2src, \@cycles, @$packs);
    }
    if (@cycles) {
      print "cycle: ".join(' -> ', @$_)."\n" for @cycles;
    }
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
  BSUtil::store("$gdst/.:depends", "$gdst/:depends", {
    'pkgdeps' => \%pdeps,
    'subpacks' => \%prunedsubpacks,
    'pkg2src' => \%pkg2src,
    'cycles' => \@cycles,
  });
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

  my $relsyncmax;
  my %relsynctrigger;

  my $projpacks = $gctx->{'projpacks'};
  my $pdatas = $projpacks->{$projid}->{'package'} || {};

  if (-s "$gdst/:relsync.max") {
    $relsyncmax = BSUtil::retrieve("$gdst/:relsync.max", 2);
    if ($relsyncmax && -s "$gdst/:relsync") {
      my $relsync = BSUtil::retrieve("$gdst/:relsync", 2);
      for my $packid (sort keys %$pdatas) {
	my $tag = $pdatas->{$packid}->{'bcntsynctag'} || $packid;
	next unless $relsync->{$packid};
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

sub checkpkgs {
  my ($ctx) = @_;

  my $prp = $ctx->{'prp'};
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};

  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  my $pdatas = $projpacks->{$projid}->{'package'} || {};

  # Step 2d: check status of all packages
  print "    checking packages\n";
  my $projbuildenabled = 1;
  $projbuildenabled = BSUtil::enabled($repoid, $projpacks->{$projid}->{'build'}, 1, $myarch) if $projpacks->{$projid}->{'build'};
  my $projlocked = 0;
  $projlocked = BSUtil::enabled($repoid, $projpacks->{$projid}->{'lock'}, 0, $myarch) if $projpacks->{$projid}->{'lock'};
  my $prjuseforbuildenabled = 1;
  $prjuseforbuildenabled = BSUtil::enabled($repoid, $projpacks->{$projid}->{'useforbuild'}, $prjuseforbuildenabled, $myarch) if $projpacks->{$projid}->{'useforbuild'};

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

  # now build cychash mapping packages to all other cycle members
  for my $cyc (@{$ctx->{'cycles'} || []}) {
    next if @$cyc < 2;	# just in case
    my @c = map {@{$cychash{$_} || [ $_ ]}} @$cyc;
    @c = BSUtil::unify(sort(@c));
    $cychash{$_} = \@c for @c;
  }

  if (%cychash) {
    print "      cycle components:\n";
    for (BSUtil::unify(sort(map {$_->[0]} values %cychash))) {
      print "        - @{$cychash{$_}}\n";
    }
  }

  # copy old data over if we have missing packages
  if ($projpacks->{$projid}->{'missingpackages'}) {
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

  my @cpacks = @{$ctx->{'packs'}};
  while (@cpacks) {
    my $packid = shift @cpacks;

    # cycle handling code
    my $incycle = 0;
    if ($cychash{$packid}) {
      # do every package in the cycle twice:
      # pass1: only build source changes
      # pass2: normal build, but block if a pass1 package is building
      # pass3: ignore
      $incycle = $cycpass{$packid};
      if (!$incycle) {
	# starting pass 1	(incycle == 1)
	my @cycp = @{$cychash{$packid}};
	unshift @cpacks, $cycp[0];	# pass3
	unshift @cpacks, @cycp;		# pass2
	unshift @cpacks, @cycp;		# pass1
	$packid = shift @cpacks;
	$incycle = 1;
	$cycpass{$_} = $incycle for @cycp;
	$cycpass{$packid} = -1;		# pass1 ended
      } elsif ($incycle == -1) {
	# starting pass 2	(incycle will be 2 or 3)
	my @cycp = @{$cychash{$packid}};
	$incycle = (grep {$building{$_}} @cycp) ? 3 : 2;
	$cycpass{$_} = $incycle for @cycp;
	$cycpass{$packid} = -2;		# pass2 ended
      } elsif ($incycle == -2) {
	# starting pass 3	(incycle == 4)
	my @cycp = @{$cychash{$packid}};
	$incycle = 4;
	$cycpass{$_} = $incycle for @cycp;
	# propagate notready/unfinished to all cycle packages
	my $pkg2src = $ctx->{'pkg2src'} || {};
	if (grep {$notready->{$pkg2src->{$_} || $_}} @cycp) {
	  $notready->{$pkg2src->{$_} || $_} ||= 1 for @cycp;
	}
	if (grep {$unfinished{$pkg2src->{$_} || $_}} @cycp) {
	  $unfinished{$pkg2src->{$_} || $_} ||= 1 for @cycp;
	}
      }
      next if $incycle == 4;	# ignore after pass1/2
      next if $packstatus{$packid} && $packstatus{$packid} ne 'done'; # already decided
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
      if ($pdata->{'error'} eq 'delayed startup' || $pdata->{'error'} =~ /interconnect error:/) {
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

    # check if this package is project link excluded
    if (exists($pdata->{'originproject'})) {
      # this is a package from a project link
      my $repo = $ctx->{'repo'};
      if (!$repo->{'linkedbuild'} || ($repo->{'linkedbuild'} ne 'localdep' && $repo->{'linkedbuild'} ne 'all')) {
	$packstatus{$packid} = 'excluded';
	$packerror{$packid} = 'project link';
	next;
      }
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

    # all checks ok, dispatch to handler
    my $handler = $handlers{$buildtype} || $handlers{default};
    my ($astatus, $aerror) = $handler->check($ctx, $packid, $pdata, $info, $buildtype);
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

  # building jobs may have changed back to excluded, blocked or disabled, remove the jobs
  BSSched::BuildJob::killunwantedjobs($ctx->{'gctx'}, $prp, \%packstatus);

  # write new package status
  BSUtil::store("$gdst/.:packstatus", "$gdst/:packstatus", {
    'packstatus' => \%packstatus,
    'packerror' => \%packerror,
  });
  if (%building) {
    prune_packstatus_finished($gdst, \%building);
  } else {
    unlink("$gdst/:packstatus.finished");
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
  my ($ctx, $schedulerstate, $schedulerdetails, $force) = @_;
  my $prp = $ctx->{'prp'};
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $unfinished = $ctx->{'unfinished'};

  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  my $pdatas = $projpacks->{$projid}->{'package'} || {};
  my $packs;
  if ($force) {
    $packs = [ sort keys %$pdatas ];
  } else {
    $packs = $ctx->{'packs'};
  }
  my $locked = 0;
  $locked = BSUtil::enabled($repoid, $projpacks->{$projid}->{'lock'}, $locked, $myarch) if $projpacks->{$projid}->{'lock'};
  my $pubenabled = BSUtil::enabled($repoid, $projpacks->{$projid}->{'publish'}, 1, $myarch);
  if ($force && $pubenabled == 1) {
    print "   force publish of $repoid not possible. Publishing is already enabled\n";
    return;
  }
  my %pubenabled;
  for my $packid (@$packs) {
    my $pdata = $pdatas->{$packid};
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
  my $repodonestate = $projpacks->{$projid}->{'patternmd5'} || '';
  for my $packid (@$packs) {
    $repodonestate .= "\0$packid" if $pubenabled{$packid};
  }
  $repodonestate .= "\0$_" for sort keys %$unfinished;
  $repodonestate = Digest::MD5::md5_hex($repodonestate);
  if (@$packs && !grep {$_} values %pubenabled) {
    # all packages have publish disabled hint
    $repodonestate = "disabled:$repodonestate";
  }
  if (-e "$gdst/:repodone") {
    my $oldrepodone = readstr("$gdst/:repodone", 1) || '';
    unlink("$gdst/:repodone") if ($oldrepodone ne $repodonestate || $force);
  }
  if ($locked) {
    print "    publishing is locked\n";
  } elsif (! -e "$gdst/:repodone") {
    my $publisherror;
    if (($force) || (($repodonestate !~ /^disabled/) || -d "$gdst/:repo")) {
      mkdir_p($gdst);
      $publisherror = BSSched::PublishRepo::prpfinished($ctx, $packs, \%pubenabled);
    } else {
      print "    publishing is disabled\n";
    }
    writestr("$gdst/:repodone", undef, $repodonestate) unless $publisherror || %$unfinished;
    if ($publisherror) {
      $schedulerstate = 'broken';
      $schedulerstate = 'building' if $publisherror eq 'delta generation: building';
      $schedulerdetails = $publisherror;
      warn("    $publisherror\n") if $schedulerstate eq 'broken';
    }
  }
  return ($schedulerstate, $schedulerdetails);
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

sub checkprojectaccess {
  my ($ctx, $projid) = @_;
  return BSSched::Access::checkprpaccess($ctx->{'gctx'}, $projid, $ctx->{'project'});
}

sub checkprpaccess {
  my ($ctx, $prp) = @_;
  return BSSched::Access::checkprpaccess($ctx->{'gctx'}, $prp, $ctx->{'prp'});
}

sub addrepo {
  my ($ctx, $pool, $prp, $arch) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  # first check the cache
  my $r = $gctx->{'repodatas'}->addrepo($pool, $prp, $arch);
  return $r if $r || !defined($r);
  # not in cache. scan/fetch.
  my ($projid, $repoid) = split('/', $prp, 2);
  my $remoteprojs = $gctx->{'remoteprojs'};
  if ($remoteprojs->{$projid}) {
    return BSSched::Remote::addrepo_remote($ctx, $pool, $prp, $arch, $remoteprojs->{$projid});
  }
  if ($arch ne $gctx->{'arch'}) {
    my $alien_cache = $ctx->{'alien_repo_cache'};
    $alien_cache = $ctx->{'alien_repo_cache'} = {} unless $alien_cache;
    $r = $pool->repofromstr($prp, $alien_cache->{"$prp/$arch"}) if exists $alien_cache->{"$prp/$arch"};
    if (!$r) {
      # needs some mem, but it's hopefully worth it
      $r = BSSched::BuildRepo::addrepo_scan($gctx, $pool, $prp, $arch);
      $alien_cache->{"$prp/$arch"} = $r->tostr() if $r;
    }
    return $r;
  }
  return BSSched::BuildRepo::addrepo_scan($gctx, $pool, $prp, $arch);
}

sub read_gbininfo {
  my ($ctx, $prp, $arch, $ps) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my ($projid, $repoid) = split('/', $prp, 2);
  if ($remoteprojs->{$projid}) {
    return BSSched::Remote::read_gbininfo_remote($ctx, "$prp/$arch", $remoteprojs->{$projid}, $ps);
  }
  # a per ctx cache
  my $gbininfo_cache = $ctx->{'gbininfo_cache'};
  $gbininfo_cache = $ctx->{'gbininfo_cache'} = {} unless $gbininfo_cache;
  my $gbininfo = $gbininfo_cache->{"$prp/$arch"};
  if (!$gbininfo) {
    my $reporoot = $gctx->{'reporoot'};
    $gbininfo = BSSched::BuildResult::read_gbininfo("$reporoot/$prp/$arch", $arch eq $gctx->{'arch'} ? 0 : 1);
    $gbininfo_cache->{"$prp/$arch"} = $gbininfo if $gbininfo;
  }
  return $gbininfo;
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
    print "append_info_path: different path\n";
    # path has changed. remove old one
    splice(@{$info->{'path'}}, -$info->{'extrapathlevel'}) if $info->{'extrapathlevel'};
    delete $info->{'extrapathlevel'};
    # add new one
    push @{$info->{'path'}}, @$path;
    $info->{'extrapathlevel'} = @$path if @$path;
    # we changed dependencies, trigger a postprocess
    $gctx->{'get_projpacks_postprocess_needed'} = 1;
  } else {
    print "append_info_path: same path\n";
  }

  # check if we have missing remotemap entries
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $remotemissing = $gctx->{'remotemissing'};
  my $ret = 1;
  my @missing;
  for my $pe (@$path) {
    my $pr = $pe->{'project'};
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

1;

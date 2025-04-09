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

package BSSched::EventHandler;

use strict;
use warnings;

use Data::Dumper;
use Storable;

use BSUtil;
use BSXML;
use BSConfiguration;
use BSSolv;
use BSRedisnotify;
use BSSched::Checker;
use BSSched::BuildResult;
use BSSched::BuildRepo;
use BSSched::ProjPacks;
use BSSched::Lookat;
use BSSched::BuildJob;
use BSSched::BuildJob::Upload;
use BSSched::BuildJob::Import;

our %event_handlers = (
  'built'           => \&BSSched::EventHandler::event_built,
  'uploadbuild'     => \&BSSched::EventHandler::event_built,
  'import'          => \&BSSched::EventHandler::event_built,

  'srcevent'        => \&BSSched::EventHandler::event_package,
  'package'         => \&BSSched::EventHandler::event_package,

  'project'         => \&BSSched::EventHandler::event_project,
  'projevent'       => \&BSSched::EventHandler::event_project,
  'lowprioproject'  => \&BSSched::EventHandler::event_project,
  'repository'      => \&BSSched::EventHandler::event_repository,
  'repoinfo'        => \&BSSched::EventHandler::event_repository,
  'rebuild'         => \&BSSched::EventHandler::event_check,
  'recheck'         => \&BSSched::EventHandler::event_check,
  'admincheck'      => \&BSSched::EventHandler::event_check,
  'unblocked'       => \&BSSched::EventHandler::event_check_med,
  'lowunblocked'    => \&BSSched::EventHandler::event_check_med,
  'relsync'         => \&BSSched::EventHandler::event_check_med,
  'scanrepo'        => \&BSSched::EventHandler::event_scanrepo,
  'scanprjbinaries' => \&BSSched::EventHandler::event_scanprjbinaries,
  'dumprepo'        => \&BSSched::EventHandler::event_dumprepo,
  'wipenotyet'      => \&BSSched::EventHandler::event_wipenotyet,
  'wipe'            => \&BSSched::EventHandler::event_wipe,
  'wipeallarch'     => \&BSSched::EventHandler::event_wipe,
  'exit'            => \&BSSched::EventHandler::event_exit,
  'exitcomplete'    => \&BSSched::EventHandler::event_exit,
  'restart'         => \&BSSched::EventHandler::event_exit,
  'dumpstate'       => \&BSSched::EventHandler::event_exit,
  'useforbuild'     => \&BSSched::EventHandler::event_useforbuild,
  'configuration'   => \&BSSched::EventHandler::event_configuration,
  'suspendproject'  => \&BSSched::EventHandler::event_suspendproject,
  'resumeproject'   => \&BSSched::EventHandler::event_resumeproject,
  'memstats'        => \&BSSched::EventHandler::event_memstats,
  'dumppmat'        => \&BSSched::EventHandler::event_dumppmat,
  'projectstats'    => \&BSSched::EventHandler::event_projectstats,
  'dispatchdetails' => \&BSSched::EventHandler::event_dispatchdetails,
  'force_publish'   => \&BSSched::EventHandler::event_force_publish,
);

=head1 NAME

 BSSched::EventHandler

=head1 DESCRIPTION

 scheduler event handling

=head1 FUNCTIONS

=cut

=head2 event_built - TODO: add summary

 TODO: add description

=cut

sub event_built {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $job = $ev->{'job'};
  local *F;
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $js = BSUtil::lockopenxml(\*F, '<', "$myjobsdir/$job:status", $BSXML::jobstatus, 1);
  if (!$js) {
    print "  - $job is gone\n";
    close F;
    return;
  }
  if ($js->{'code'} ne 'finished') {
    print "  - $job is not finished: $js->{'code'}\n";
    close F;
    return;
  }
  my $info = readxml("$myjobsdir/$job", $BSXML::buildinfo, 1);
  if (!$info) {
    print "  - $job has bad info\n";
  } elsif ($info->{'arch'} ne $myarch && $ev->{'type'} ne 'import') {
    print "  - $job has bad arch\n";
  } else {
    if ($ev->{'type'} eq 'built') {
      BSSched::BuildJob::jobfinished($ectx, $job, $info, $js);
    } elsif ($ev->{'type'} eq 'uploadbuild') {
      BSSched::BuildJob::Upload::jobfinished($ectx, $job, $info, $js);
    } elsif ($ev->{'type'} eq 'import') {
      BSSched::BuildJob::Import::jobfinished($ectx, $job, $info, $js);
    }
    my $prp = "$info->{'project'}/$info->{'repository'}";
    BSRedisnotify::updatejobstatus("$prp/$myarch", $job) if $BSConfig::redisserver && !$info->{'packstatus_patched'};
  }
  BSSched::BuildJob::purgejob($gctx, $job);
  close F;
}

=head2 event_package - TODO: add summary

 TODO: add description

=cut

sub event_package {
  my ($ectx, $ev) = @_;

  my $fetchprojpacks = $ectx->{'fetchprojpacks'};
  my $deepcheck = $ectx->{'deepcheck'};
  my $projid = $ev->{'project'};
  return unless defined $projid;
  my $packid = $ev->{'package'};
  push @{$fetchprojpacks->{$projid}}, $packid;
  $deepcheck->{$projid} = 1 if !defined $packid;
  if (!defined($packid) && $ectx->{'gctx'}->{'projsuspended'}->{$projid}) {
    print "resuming project $projid\n";
    delete $ectx->{'gctx'}->{'projsuspended'}->{$projid};
  }
}

=head2 event_project - TODO: add summary

 TODO: add description

=cut

sub event_project {
  my ($ectx, $ev) = @_;

  my $fetchprojpacks = $ectx->{'fetchprojpacks'};
  my $lowprioproject = $ectx->{'lowprioproject'};
  my $projid = $ev->{'project'};
  return unless defined $projid;
  push @{$fetchprojpacks->{$projid}}, undef;
  $lowprioproject->{$projid} = 1 if $ev->{'type'} eq 'lowprioproject';
}

=head2 event_repository - TODO: add summary

 TODO: add description

=cut

sub event_repository {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $changed_med = $gctx->{'changed_med'};
  my $projid = $ev->{'project'};
  my $repoid = $ev->{'repository'};
  my $arch = $ev->{'arch'} || $gctx->{'arch'};
  my $prp = "$projid/$repoid";
  $changed_med->{$prp} = 2;
  my $repounchanged = $gctx->{'repounchanged'};
  if ($ev->{'type'} eq 'repository') {
    # full tree and maybe bininfo changed
    $gctx->{'repodatas'}->drop($prp, $arch);
    delete $repounchanged->{$prp} if $arch eq $gctx->{'arch'};
  } elsif ($ev->{'type'} eq 'repoinfo') {
    # only bininfo changed
    $repounchanged->{$prp} = 2 if $repounchanged->{$prp} && $arch eq $gctx->{'arch'};
  }
}

=head2 event_check - TODO: add summary

 TODO: add description

=cut

sub event_check {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $changed_high = $gctx->{'changed_high'};
  my $changed_dirty = $gctx->{'changed_dirty'};
  my $prps = $gctx->{'prps'};
  my $projid = $ev->{'project'};
  my $repoid = $ev->{'repository'};
  my %admincheck;
  if (!defined($projid)) {
    my $changed_low = $gctx->{'changed_low'};
    for my $prp (@$prps) {
      $changed_low->{$prp} ||= 1;
    }
    return;
  }
  if (defined($repoid)) {
    my $prp = "$projid/$repoid";
    $changed_high->{$prp} ||= 1;
    $changed_dirty->{$prp} = 1;
    $admincheck{$prp} = 1 if $ev->{'type'} eq 'admincheck';
  } else {
    for my $prp (@$prps) {
      if ((split('/', $prp, 2))[0] eq $projid) {
        $changed_high->{$prp} ||= 1;
        $changed_dirty->{$prp} = 1;
        $admincheck{$prp} = 1 if $ev->{'type'} eq 'admincheck';
      }
    }
    $changed_high->{$projid} ||= 1;
  }
  if (%admincheck) {
    my $lookat_high = $gctx->{'lookat_high'};
    @$lookat_high = grep {!$admincheck{$_}} @$lookat_high;
    unshift @$lookat_high, sort keys %admincheck;
    BSSched::Lookat::setdelayed($gctx, $_, 0) for sort keys %admincheck;
    $gctx->{'notlow'} = 0;
    $gctx->{'notmed'} = 0;
  }
}

=head2 event_check_med - TODO: add summary

 TODO: add description

=cut

sub event_check_med {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $changed = $ev->{'type'} eq 'lowunblocked' ?  $gctx->{'changed_low'} : $gctx->{'changed_med'};
  my $projid = $ev->{'project'};
  my $repoid = $ev->{'repository'};
  return unless defined($projid) && defined($repoid);
  my $prp = "$projid/$repoid";
  print "$prp is $ev->{'type'}\n";
  $changed->{$prp} ||= 1;
}

=head2 event_scanrepo - TODO: add summary

 TODO: add description

=cut

sub event_scanrepo {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $changed_high = $gctx->{'changed_high'};
  my $projid = $ev->{'project'};
  my $repoid = $ev->{'repository'};
  if (!defined($projid) && !defined($repoid)) {
    print "flushing all repository data\n";
    $gctx->{'repodatas'}->drop();
    return;
  }
  if (defined($projid) && defined($repoid)) {
    my $prp = "$projid/$repoid";
    print "reading packages of repository $prp\n";
    $gctx->{'repodatas'}->drop($prp, $gctx->{'arch'});
    my $ctx = BSSched::Checker->new($gctx, $prp);
    my $pool = BSSolv::pool->new();
    $ctx->addrepo($pool, $prp);
    undef $pool;
    $changed_high->{$prp} = 2;
    delete $gctx->{'repounchanged'}->{$prp};
  }
}

=head2 event_scanprjbinaries - TODO: add summary

 TODO: add description

=cut

sub event_scanprjbinaries {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $changed_high = $gctx->{'changed_high'};
  my $projid = $ev->{'project'};
  my $repoid = $ev->{'repository'};
  my $packid = $ev->{'package'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  if (defined($projid) && defined($repoid)) {
    my $prp = "$projid/$repoid";
    my $arch = $ev->{'arch'} || $myarch;
    delete $gctx->{'remotegbininfos'}->{"$prp/$arch"};
    if ($remoteprojs->{$projid}) {
      if ($ev->{'arch'}) {
        # remote gbininfo retry event
        my $changed_med = $gctx->{'changed_med'};
        $changed_med->{$prp} = 2;
      }
      return;
    }
    if (defined($packid)) {
      unlink("$prp/$myarch/$packid/.bininfo");
    } else {
      for my $packid (grep {!/^[:\.]/} ls("$prp/$myarch")) {
        next if $packid eq '_deltas';
        next unless -d "$prp/$myarch/$packid";
        unlink("$prp/$myarch/$packid/.bininfo");
      }
    }
    my $reporoot = $gctx->{'reporoot'};
    print "reading project binary state of repository $projid/$repoid\n";
    BSSched::BuildResult::rebuild_gbininfo("$reporoot/$prp/$myarch");
    $changed_high->{$prp} = 1;
  }
}

=head2 event_dumprepo - TODO: add summary

 TODO: add description

=cut

sub event_dumprepo {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $prp = "$ev->{'project'}/$ev->{'repository'}";
  my $arch = $ev->{'arch'} || $gctx->{'arch'};
  my $repodata = $gctx->{'repodatas'}->{"$prp/$arch"} || {};
  local *F;
  open(F, '>', "/tmp/repodump");
  print F "# repodump for $prp\n\n";
  print F Dumper($repodata);
  close F;
}

=head2 event_wipenotjet - TODO: add summary

 TODO: add description

=cut

sub event_wipenotyet {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  BSSched::Lookat::setdelayed($gctx, "$ev->{'project'}/$ev->{'repository'}", 0);
}

=head2 event_wipe - TODO: add summary

 TODO: add description

=cut

sub event_wipe {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $changed_high = $gctx->{'changed_high'};
  my $changed_dirty = $gctx->{'changed_dirty'};

  my $projid = $ev->{'project'};
  my $repoid = $ev->{'repository'};
  my $packid = $ev->{'package'};
  return unless defined($projid) && defined($repoid) && defined($packid);
  my $prp = "$projid/$repoid";
  my $reporoot = $gctx->{'reporoot'};
  my $gdst = "$reporoot/$prp/$myarch";
  print "wiping $prp $packid\n";
  my $allarch = $ev->{'type'} eq 'wipeallarch' ? 1 : undef;
  BSSched::BuildResult::wipe($gctx, $prp, $packid, $ectx->{'dstcache'}, $allarch) if -d "$gdst/$packid";
  BSSched::BuildJob::set_genbuildreqs($gctx, $prp, $packid, undef);
  for $prp (@{$gctx->{'prps'}}) {
    if ((split('/', $prp, 2))[0] eq $projid) {
      $changed_high->{$prp} = 2;
      $changed_dirty->{$prp} = 1;
    }
  }
  $changed_high->{$projid} = 2;
}

=head2 event_useforbuild - TODO: add summary

 TODO: add description

=cut

sub event_useforbuild {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $changed_high = $gctx->{'changed_high'};
  my $changed_dirty = $gctx->{'changed_dirty'};
  my $reporoot = $gctx->{'reporoot'};

  my $projid = $ev->{'project'};
  my $repoid = $ev->{'repository'};
  return unless defined($projid) && defined($repoid);
  my $projpacks = $gctx->{'projpacks'};
  my $prp = "$projid/$repoid";
  my $proj = $projpacks->{$projid} || {};
  my $packs = $proj->{'package'} || {};
  my @packs;
  if ($ev->{'package'}) {
    @packs = ($ev->{'package'});
  } else {
    BSSched::BuildRepo::forcefullrebuild($gctx, $prp);
  }
  for my $packid (@packs) {
    my $gdst = "$reporoot/$prp/$myarch";
    next unless -d "$gdst/$packid";
    my $meta = "$gdst/:meta/$packid";
    undef $meta unless -s $meta;
    BSSched::BuildResult::update_dst_full($gctx, $prp, $packid, "$gdst/$packid", $meta);
  }
  for $prp (@{$gctx->{'prps'}}) {
    if ((split('/', $prp, 2))[0] eq $projid) {
      if ((split('/', $prp, 2))[0] eq $projid) {
        $changed_high->{$prp} = 2 if (split('/', $prp, 2))[0] eq $projid;
        $changed_dirty->{$prp} = 1;
      }
    }
  }
  $changed_high->{$projid} = 2;
}

=head2 event_exit - TODO: add summary

 TODO: add description

=cut

sub event_exit {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  print "exiting...\n" if $ev->{'type'} eq 'exit';
  print "exiting (with complete info)...\n" if $ev->{'type'} eq 'exitcomplete';
  print "restarting...\n" if $ev->{'type'} eq 'restart';
  print "dumping scheduler state...\n" if $ev->{'type'} eq 'dumpstate';
  print "dumping emergency state...\n" if $ev->{'type'} eq 'emergencydump';
  my $lookat_next = $gctx->{'lookat_next'} || {};
  my @new_lookat = @{$gctx->{'lookat_low'} || []};
  push @new_lookat, grep {$lookat_next->{$_}} @{$gctx->{'prps'}};
  # here comes our scheduler state
  my $schedstate = {};
  if ($ev->{'type'} eq 'exitcomplete' || $ev->{'type'} eq 'restart' || $ev->{'type'} eq 'emergencydump' || $ev->{'type'} eq 'dumpstate') {
    $schedstate->{'projpacks'} = $gctx->{'projpacks'};
    $schedstate->{'remoteprojs'} = $gctx->{'remoteprojs'};
  }
  $schedstate->{'prps'} = $gctx->{'prps'};
  $schedstate->{'changed_low'} = $gctx->{'changed_low'};
  $schedstate->{'changed_med'} = $gctx->{'changed_med'};
  $schedstate->{'changed_high'} = $gctx->{'changed_high'};
  $schedstate->{'lookat'} = \@new_lookat;
  $schedstate->{'lookat_oob'} = $gctx->{'lookat_med'};
  $schedstate->{'lookat_oobhigh'} = $gctx->{'lookat_high'};
  $schedstate->{'prpfinished'} = $gctx->{'prpfinished'};
  $schedstate->{'globalnotready'} = $gctx->{'prpnotready'};
  $schedstate->{'repounchanged'} = $gctx->{'repounchanged'};
  $schedstate->{'projsuspended'} = $gctx->{'projsuspended'};
  $schedstate->{'delayedfetchprojpacks'} = $gctx->{'delayedfetchprojpacks'};
  $schedstate->{'watchremote_start'} = $gctx->{'watchremote_start_copy'} || $gctx->{'watchremote_start'};
  $schedstate->{'fetchprojpacks'} = $ectx->{'fetchprojpacks'} if %{$ectx->{'fetchprojpacks'} || {}};
  # collect all running async projpack requests
  my $running = BSSched::ProjPacks::runningfetchprojpacks($gctx);
  for my $projid (sort keys %{$running || {}}) {
    $schedstate->{'fetchprojpacks'} ||= {};
    $schedstate->{'fetchprojpacks'}->{$projid} = [ @{$schedstate->{'fetchprojpacks'}->{$projid} || []}, @{$running->{$projid}} ];
  }
  my @retryevents = $gctx->{'retryevents'}->events();
  $schedstate->{'retryevents'} = \@retryevents if @retryevents;

  my $rundir = $gctx->{'rundir'};
  unlink("$rundir/bs_sched.$myarch.state");
  my $statefile = "$rundir/bs_sched.$myarch.state";
  $statefile = "$rundir/bs_sched.$myarch.dead" if $ev->{'type'} eq 'emergencydump';
  BSUtil::store("$statefile.new", $statefile, $schedstate);
  if ($ev->{'type'} eq 'exit' || $ev->{'type'} eq 'exitcomplete') {
    BSUtil::printlog("bye.");
    exit(0);
  }
  if ($ev->{'type'} eq 'restart') {
    exec $0, $myarch;
    warn("$0: $!\n");
  }
}

=head2 event_configuration - TODO: add summary

 TODO: add description

=cut

sub event_configuration {
  my ($ectx, $ev) = @_;
  my $gctx = $ectx->{'gctx'};
  print "updating configuration\n";
  BSConfiguration::update_from_configuration();
  $gctx->{'obsname'} = $BSConfig::obsname;
  $gctx->{'remoteproxy'} = $BSConfig::proxy;
}

sub event_suspendproject {
  my ($ectx, $ev) = @_;
  my $projid = $ev->{'project'};
  my $gctx = $ectx->{'gctx'};
  my $evjob = $ev->{'job'};
  return unless $evjob;
  print "suspending project $projid: @{$gctx->{'projsuspended'}->{$projid} || []} + $evjob\n";
  push @{$gctx->{'projsuspended'}->{$projid}}, $evjob;

  my $suspend = $gctx->{'projsuspended'}->{$projid};
  # try to set the repo state right away
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid};
  return unless $proj;
  for my $repo (@{$proj->{'repository'} || []}) {
    next unless grep {$_ eq $gctx->{'arch'}} @{$repo->{'arch'} || []};
    my $ctx = BSSched::Checker->new($gctx, "$projid/$repo->{'name'}");
    $ctx->set_repo_state('blocked', join(', ', @$suspend));
  }
}

sub event_resumeproject {
  my ($ectx, $ev) = @_;
  my $projid = $ev->{'project'};
  my $gctx = $ectx->{'gctx'};
  my $evjob = $ev->{'job'} || '';
  my $suspend = $gctx->{'projsuspended'}->{$projid};
  if (!$suspend) {
    print "ignoring resumeproject for project $projid ($evjob)\n";
    return;
  }
  if (@$suspend > 1) {
    print "not yet resuming project $projid: @$suspend - $evjob\n";
    my $first = 0;
    # remove first matching element; if not found pop last element
    @$suspend = grep {$_ ne $evjob || $first++} @$suspend;
    pop @$suspend unless $first;
    return;
  }
  print "resuming project $projid: @$suspend - $evjob\n";
  delete $gctx->{'projsuspended'}->{$projid};
  my $changed_high = $gctx->{'changed_high'};
  my $changed_dirty = $gctx->{'changed_dirty'};
  $changed_high->{$projid} ||= 1;
  for my $prp (@{$gctx->{'prps'}}) {
    if ((split('/', $prp, 2))[0] eq $projid) {
      $changed_high->{$prp} ||= 1;
      $changed_dirty->{$prp} = 1;
    }
  }
}

=head2 event_uploadbuildimport_delay - check if an upload event needs to be delayed

 TODO: add description

=cut

sub event_uploadbuildimport_delay {
  my ($ectx, $ev) = @_;

  my $gctx = $ectx->{'gctx'};
  # have to be extra careful with those. if the package is in
  # (delayed)fetchprojpacks, delay event processing until we
  # updated the projpack data.
  my $fetchprojpacks = $ectx->{'fetchprojpacks'};
  my $fetchprojpacks_nodelay = $ectx->{'fetchprojpacks_nodelay'};
  my $delayedfetchprojpacks = $gctx->{'delayedfetchprojpacks'};

  return 0 unless $ev->{'job'};
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $info = readxml("$myjobsdir/$ev->{'job'}", $BSXML::buildinfo, 1) || {};
  my $projid = $info->{'project'};
  my $packid = $info->{'package'};
  if ($packid =~ /(?<!^_product)(?<!^_patchinfo):./) {
    # remove multibuild flavor
    $packid =~ s/(?<!^_product)(?<!^_patchinfo):.*//;
  }
  return 0 unless defined($projid);
  return 1 if $gctx->{'rctx'}->xrpc_busy($projid);      # delay if getprojpack in progress
  return 0 unless defined($packid);
  if (grep {!defined($_) || $_ eq $packid} (@{$fetchprojpacks->{$projid} || []}, @{$delayedfetchprojpacks->{$projid} || []})) {
    push @{$fetchprojpacks->{$projid}}, $packid;
    # remove package from delayedfetchprojpacks to prevent looping
    $delayedfetchprojpacks->{$projid} = [ grep {$_ ne $packid} @{$delayedfetchprojpacks->{$projid} || []} ];
    delete $delayedfetchprojpacks->{$projid} unless @{$delayedfetchprojpacks->{$projid}};
    $fetchprojpacks_nodelay->{$projid} = 1;
    return 1;
  }
  return 0;
}

sub event_memstats {
  my ($ectx, $ev) = @_;
  eval {
    require Devel::Mallinfo;
    print Devel::Mallinfo::malloc_info_string(0);
    Devel::Mallinfo::malloc_stats();
  };
  my $gctx = $ectx->{'gctx'};
  my %gctx = %$gctx;
  %$gctx = ();
  eval{
    my %m = %gctx;
    for my $q ('rctx') {
      my $qq = delete $m{$q};
      $m{"${q}_$_"} = $qq->{$_} for keys %$qq;
    }

    %m = %{$m{$ev->{'job'}} || {}} if $ev->{'job'};

    my %mm;
    local $Storable::forgive_me = 1;
    local $SIG{__WARN__} = sub {};
    for my $k (sort keys %m) {
      next unless ref $m{$k};
      my $l = length(Storable::nfreeze($m{$k}));
      $mm{$k} = $l;
    }
    my @k = sort {$mm{$b} <=> $mm{$a}} keys %mm;
    @k = splice(@k, 0, 10) if $ev->{'job'};	# top 10 only
    for my $k (@k) {
      my $l = int($mm{$k} / 1024);
      print "$k: $l KB\n" if $l || $ev->{'job'};
    }
  };
  warn($@) if $@;
  %$gctx = %gctx;
}

sub event_dumppmat {
  my ($ectx, $ev) = @_;
  my $gctx = $ectx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $rundir = $gctx->{'rundir'};
  eval {
    require Devel::MAT::Dumper;
    Devel::MAT::Dumper::dump("$rundir/bs_sched.$myarch.pmat");
  };
  warn($@) if $@;
}

sub event_projectstats {
  my ($ectx, $ev) = @_;
  my $gctx = $ectx->{'gctx'};
  BSSched::ProjPacks::print_project_stats($gctx);
}

sub event_dispatchdetails {
  my ($ectx, $ev) = @_;
  my $gctx = $ectx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $reporoot = $gctx->{'reporoot'};
  my $info = readxml("$myjobsdir/$ev->{'job'}", $BSXML::buildinfo, 1);
  return unless $info;
  return if -e "$myjobsdir/$ev->{'job'}:status";
  my $gdst = "$reporoot/$info->{'project'}/$info->{'repository'}/$myarch";
  BSUtil::appendstr("$gdst/:packstatus.finished", "scheduled $info->{'package'}/$ev->{'job'}/$ev->{'details'}\n");
}

sub event_force_publish {
  my ($ectx, $ev) = @_;
  my $gctx = $ectx->{'gctx'};
  my $repoid = $ev->{'repository'};
  my $projid = $ev->{'project'};
  my $ctx = BSSched::Checker->new($gctx, "$projid/$repoid");
  $ctx->publish(1);
}

1;

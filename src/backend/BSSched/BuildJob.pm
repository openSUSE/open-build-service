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

package BSSched::BuildJob;

# gctx functions
#   init_ourjobs
#   purgejob
#   killjob
#   killscheduled
#   killbuilding
#   killunwantedjobs
#   writejob
#   add_crossmarker
#   update_buildavg
#   patchpackstatus
#   addjobhist
#   path2buildinfopath
#
# ectx functions
#   jobfinished
#
# ctx functions
#   fakejobfinished
#   fakejobfinished_nouseforbuild
#   nextbcnt
#   create
#   metacheck
#
# static functions
#   jobname
#   sortedmd5toreason
#   diffsortedmd5
#
# gctx usage
#   myjobsdir
#   jobsdir
#   arch
#   buildavg		[rw]
#   changed_med		[rw]
#   projpacks
#   reporoot
#   prpsearchpath
#   repounchanged	[rw]
#   obsname
#   remoteprojs
#
# ctx usage
#   gctx
#   project
#   repository
#   gdst
#   relsyncmax
#   conf
#   prpsearchpath
#   sysbuild_$buildtype	[rw]
#   pool
#   prp
#
# ectx usage
#   gctx
#   fullcache

use strict;
use warnings;

use Data::Dumper;
use Digest::MD5 ();

use BSUtil;
use BSXML;
use BSFileDB;
use BSConfiguration;
use BSSched::DoD;	                # for dodcheck
use BSSched::Access;	            	# for checkaccess
use BSSched::EventSource::Directory; 	# for sendevent
use Build;
use BSRPC;
use BSCando;

=head1 NAME

BSSched::BuildJob

=head1 SYNOPSIS

 TODO

=head1 DESCRIPTION

 This library contains functions to handle jobs in openbuild-service

=cut

=head1 FUNCTIONS / METHODS

=cut

# history of succeeded builds
my $historylay = [qw{versrel bcnt srcmd5 rev time duration}];


# scheduled jobs (does not need to be exact)
my %ourjobs;	# XXX: move into gctx?

my $workersrcserver = $BSConfig::workersrcserver ? $BSConfig::workersrcserver : $BSConfig::srcserver;
my $workerreposerver = $BSConfig::workerreposerver ? $BSConfig::workerreposerver : $BSConfig::reposerver;


=head2 init_ourjobs - intialize ourjobs hash on startup

 This function is used to initialize the ourjobs hash on scheduler startup.

=cut

sub init_ourjobs {
  my ($gctx) = @_;
  my $myjobsdir = $gctx->{'myjobsdir'};
  for my $job (grep {!/(?::dir|:status)$/} ls($myjobsdir)) {
     $ourjobs{$1}->{$job} = 1 if $job =~ /^(:.+?|[^:].*?::.+?)::/s;
  }
}

=head2 purgejob - remove a job and all of its artifacts

 should hold the job lock when called

=cut

sub purgejob {
  my ($gctx, $job) = @_;
  my $myjobsdir = $gctx->{'myjobsdir'};
  if (-d "$myjobsdir/$job:dir") {
    unlink("$myjobsdir/$job:dir/$_") for ls("$myjobsdir/$job:dir");
    rmdir("$myjobsdir/$job:dir");
  }
  unlink("$myjobsdir/$job");
  unlink("$myjobsdir/$job:status");
  delete (($ourjobs{$1} || {})->{$job}) if $job =~ /^(:.+?|[^:].*?::.+?)::/s;
}

=head2 killjob - kill a single build job

 input: $job - job identificator

=cut

sub killjob {
  my ($gctx, $job) = @_;

  my $myjobsdir = $gctx->{'myjobsdir'};
  local *F;
  if (! -e "$myjobsdir/$job:status") {
    # create locked status
    my $js = {'code' => 'deleting'};
    if (BSUtil::lockcreatexml(\*F, "$myjobsdir/.sched.$$", "$myjobsdir/$job:status", $js, $BSXML::jobstatus)) {
      print "        (job was not building)\n";
      purgejob($gctx, $job);
      close F;
      return;
    }
  }
  my $js = BSUtil::lockopenxml(\*F, '<', "$myjobsdir/$job:status", $BSXML::jobstatus, 1);
  if (!$js) {
    # can't happen actually
    print "        (job was not building)\n";
    purgejob($gctx, $job);
    return;
  }
  if ($js->{'code'} eq 'building') {
    print "        (job was building on $js->{'workerid'})\n";
    my $req = {
      'uri' => "$js->{'uri'}/discard",
      'timeout' => 60,
    };
    eval {
      BSRPC::rpc($req, undef, "jobid=$js->{'jobid'}");
    };
    warn("kill $job: $@") if $@;
  }
  purgejob($gctx, $job);
  close(F);
}


=head2  killscheduled - kill a single build job if it is scheduled but not building

 input: $job - job identificator

=cut

sub killscheduled {
  my ($gctx, $job) = @_;

  my $myjobsdir = $gctx->{'myjobsdir'};
  return if -e "$myjobsdir/$job:status";
  local *F;
  my $js = {'code' => 'deleting'};
  if (BSUtil::lockcreatexml(\*F, "$myjobsdir/.sched.$$", "$myjobsdir/$job:status", $js, $BSXML::jobstatus)) {
    purgejob($gctx, $job);
    close F;
  }
}


=head2  killbuilding - kill build jobs

 used if a project/package got deleted to kill all running jobs

 input: $prp    - prp we are working on
        $packid - just kill the builds of the package
=cut

sub killbuilding {
  my ($gctx, $prp, $packid) = @_;

  my $myjobsdir = $gctx->{'myjobsdir'};
  my @jobs;
  if (defined $packid) {
    my $f = jobname($prp, $packid);
    @jobs = grep {$_ eq $f || /^\Q$f\E-[0-9a-f]{32}$/} ls($myjobsdir);
  } else {
    my $f = jobname($prp, '');
    @jobs = grep {/^\Q$f\E/} ls($myjobsdir);
    @jobs = grep {!/(?::dir|:status)$/} @jobs;
  }
  for my $job (@jobs) {
    print "        killing obsolete job $job\n";
    killjob($gctx, $job);
  }
}


=head2 killunwantedjobs - kill all jobs where the packagestatus is excluded/disabled

 TODO

=cut

sub killunwantedjobs {
  my ($gctx, $prp, $packstatus) = @_;

  my $job1 = $prp;
  $job1 =~ s/\//::/s;
  my $job2 = ':'.Digest::MD5::md5_hex($prp);
  return unless $ourjobs{$job1} || $ourjobs{$job2};
  my $myjobsdir = $gctx->{'myjobsdir'};
  for my $job (keys %{$ourjobs{$job1} || {}}, keys %{$ourjobs{$job2} || {}}) {
    if ($job =~ /^(?:\Q$job1\E|\Q$job2\E)::(.*)-[0-9a-f]{32}$/s) {
      my $status = $packstatus->{$1} || '';
      next if $status eq 'scheduled';
      if (! -e "$myjobsdir/$job") {
        delete(($ourjobs{$1} || {})->{$job}) if $job =~ /^(:.+?|[^:].*?::.+?)::/s;
	next;
      }
      if ($status eq 'disabled' || $status eq 'excluded' || $status eq 'locked') {
	print "        killing old job $job, now in disabled/excluded/locked state\n";
	killjob($gctx, $job);
      } elsif ($status eq 'blocked' || $status eq 'unresolvable' || $status eq 'broken') {
	# blocked jobs get removed, if they are currently not building. building jobs
	# stay since they may become valid again
	killscheduled($gctx, $job);
      }
    }
  }
  delete $ourjobs{$job1} unless %{$ourjobs{$job1} || {}};
  delete $ourjobs{$job2} unless %{$ourjobs{$job2} || {}};
}

=head2 writejob - write a new job to disc

After writing the dispatcher will pick up the job and dispatch it
to a free worker.

=cut

sub writejob {
  my ($ctx, $job, $binfo, $reason) = @_;

  # jay! ready for building, write status, reason, and job info
  my $gctx = $ctx->{'gctx'};
  $binfo->{'job'} = $job if $job;
  $binfo->{'readytime'} = time();
  if ($reason) {
    $binfo->{'reason'} = $reason->{'explain'};
    my $dst = "$ctx->{'gdst'}/$binfo->{'package'}";
    mkdir_p($dst);
    my $now = $binfo->{'readytime'};
    writexml("$dst/.status", "$dst/status", { 'status' => 'scheduled', 'readytime' => $now, 'job' => $job}, $BSXML::buildstatus);
    # And store reason and time
    $reason->{'time'} = $now;
    writexml("$dst/.reason", "$dst/reason", $reason, $BSXML::buildreason);
  }

  $binfo->{'srcserver'} ||= $workersrcserver;
  $binfo->{'reposerver'} ||= $workerreposerver;
  $binfo->{'genmetaalgo'} = $gctx->{'genmetaalgo'} if $gctx->{'genmetaalgo'};

  my $myjobsdir = $gctx->{'myjobsdir'};
  $ctx->{'otherjobscache'} ||= [ grep {/-[0-9a-f]{32}$/} grep {!/^\./} ls($myjobsdir) ];
  writexml("$myjobsdir/.$job", "$myjobsdir/$job", $binfo, $BSXML::buildinfo);
  add_crossmarker($gctx, $binfo->{'hostarch'}, $job) if $binfo->{'hostarch'};
  $ourjobs{$1}->{$job} = 1 if $job =~ /^(:.+?|[^:].*?::.+?)::/s;
  push @{$ctx->{'otherjobscache'}}, $job;
}

=head2 find_otherjobs - find all jobs for the same build

Note that the job must not contain the srcmd5

=cut

sub find_otherjobs {
  my ($ctx, $jobprefix) = @_;
  my $myjobsdir = $ctx->{'gctx'}->{'myjobsdir'};
  $ctx->{'otherjobscache'} ||= [ grep {/-[0-9a-f]{32}$/} grep {!/^\./} ls($myjobsdir) ];
  my @otherjobs = grep {/^\Q$jobprefix\E-[0-9a-f]{32}$/} @{$ctx->{'otherjobscache'}};
  @otherjobs = BSUtil::unify(grep {-e "$myjobsdir/$_"} @otherjobs) if @otherjobs;
  return @otherjobs;
}

=head2 add_crossmarker - add a marker into a foreign jobdir

 TODO

=cut

sub add_crossmarker {
  my ($gctx, $hostarch, $job) = @_;
  my $myarch = $gctx->{'arch'};
  return if $hostarch eq $myarch;
  return unless $BSCando::knownarch{$hostarch};
  my $markerdir = "$gctx->{'jobsdir'}/$hostarch";
  my $marker = "$markerdir/$job:$myarch:cross";
  return if -e $marker;
  mkdir_p($markerdir);
  BSUtil::touch($marker);
}

=head2 update_buildavg - incorporate the jobtime into the buildavg statistics

 TODO

=cut

sub update_buildavg {
  my ($gctx, $jobtime) = @_;

  my $buildavg = $gctx->{'buildavg'} || 0;
  my $weight = 0.1;
  $buildavg = ($weight * $jobtime) + ((1 - $weight) * $buildavg);
  $gctx->{'buildavg'} = $buildavg;
}

=head2 jobfinished - called when a build job is finished

 - move artifacts into built result dir
 - move built binaries into :full tree
 - set changed flag

 input: $job       - job identification
        $js        - job status information (BSXML::jobstatus)
        $changed   - reference to changed hash, mark prp if
                     we changed the repository
        $fullcache - store data for delayed writing of :full.solv

=cut

sub jobfinished {
  my ($ectx, $job, $js) = @_;

  my $gctx = $ectx->{'gctx'};
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $info = readxml("$myjobsdir/$job", $BSXML::buildinfo, 1);
  my $jobdatadir = "$myjobsdir/$job:dir";
  if (!$info || ! -d $jobdatadir) {
    print "  - $job is bad\n";
    return;
  }
  # dispatch to specialized versions for aggregates and deltas
  if ($info->{'file'} eq '_aggregate') {
    BSSched::BuildJob::Aggregate::jobfinished($ectx, $job, $js);
    return ;
  }
  if ($info->{'file'} eq '_delta') {
    BSSched::BuildJob::DeltaRpm::jobfinished($ectx, $job, $js);
    return ;
  }

  my $myarch = $gctx->{'arch'};
  my $changed = $gctx->{'changed_med'};

  my $projid = $info->{'project'};
  my $repoid = $info->{'repository'};
  my $packid = $info->{'package'};
  my $prp = "$projid/$repoid";

  my $now = time(); # ensure that we use the same time in all logs
  if ($info->{'arch'} ne $myarch) {
    print "  - $job has bad arch\n";
    return;
  }
  my $projpacks = $gctx->{'projpacks'};
  if (!$projpacks->{$projid}) {
    print "  - $job belongs to an unknown project\n";
    return;
  }
  my $pdata = ($projpacks->{$projid}->{'package'} || {})->{$packid};
  if (!$pdata) {
    print "  - $job belongs to an unknown package, discard\n";
    return;
  }
  my $reporoot = $gctx->{'reporoot'};
  my $gdst = "$reporoot/$prp/$myarch";
  my $dst = "$gdst/$packid";
  my $status = readxml("$dst/status", $BSXML::buildstatus, 1);
  if ($status && (!$status->{'job'} || $status->{'job'} ne $job)) {
    print "  - $job is outdated\n";
    return;
  }
  $status ||= {'readytime' => $info->{'readytime'} || $info->{'starttime'}};
  # calculate exponential weighted average
  my $myjobtime = time() - $status->{'readytime'};
  update_buildavg($gctx, $myjobtime);

  delete $status->{'job'};      # no longer building

  delete $status->{'arch'};     # obsolete
  delete $status->{'uri'};      # obsolete

  my $code = $js->{'result'};
  $code = 'failed' unless $code eq 'succeeded' || $code eq 'unchanged';

  my @all = ls($jobdatadir);
  my %all = map {$_ => 1} @all;
  @all = map {"$jobdatadir/$_"} @all;

  mkdir_p($dst);
  mkdir_p("$gdst/:meta");
  mkdir_p("$gdst/:logfiles.fail");
  mkdir_p("$gdst/:logfiles.success");
  unlink("$gdst/:repodone");
  if (!$all{'meta'}) {
    if ($code eq 'succeeded') {
      print "  - $job claims success but there is no meta\n";
      return;
    }
    # severe failure, create src change fake...
    my $verifymd5 = $info->{'verifymd5'} || $info->{'srcmd5'};
    writestr("$jobdatadir/meta", undef, "$verifymd5  $packid\nfake to detect source changes...  fake\n");
    push @all, "$jobdatadir/meta";
    $all{'meta'} = 1;
  }

  # update packstatus so that it doesn't fall back to scheduled
  patchpackstatus($gctx, $prp, $packid, $code);

  my $meta = $all{'meta'} ? "$jobdatadir/meta" : undef;
  if ($code eq 'unchanged') {
    print "  - $job: build result is unchanged\n";
    if ( -e "$gdst/:logfiles.success/$packid" ){
      # make sure to use the last succeeded logfile matching to these binaries
      link("$gdst/:logfiles.success/$packid", "$dst/logfile.dup");
      rename("$dst/logfile.dup", "$dst/logfile");
      unlink("$dst/logfile.dup");
    }
    if (open(F, '+>>', "$dst/logfile")) {
      # Add a comment to logfile from last real build
      print F "\nRetried build at ".localtime(time())." returned same result, skipped";
      close(F);
    }
    unlink("$gdst/:logfiles.fail/$packid");
    rename($meta, "$gdst/:meta/$packid") if $meta;
    unlink($_) for @all;
    rmdir($jobdatadir);
    addjobhist($gctx, $prp, $info, $status, $js, 'unchanged');
    $status->{'status'} = 'succeeded';
    writexml("$dst/.status", "$dst/status", $status, $BSXML::buildstatus);
    $changed->{$prp} ||= 1;     # package is no longer blocking
    return;
  }
  if ($code eq 'failed') {
    print "  - $job: build failed\n";
    link("$jobdatadir/logfile", "$jobdatadir/logfile.dup");
    rename("$jobdatadir/logfile", "$dst/logfile");
    rename("$jobdatadir/logfile.dup", "$gdst/:logfiles.fail/$packid");
    rename($meta, "$gdst/:meta/$packid") if $meta;
    unlink($_) for @all;
    rmdir($jobdatadir);
    $status->{'status'} = 'failed';
    addjobhist($gctx, $prp, $info, $status, $js, 'failed');
    writexml("$dst/.status", "$dst/status", $status, $BSXML::buildstatus);
    $changed->{$prp} ||= 1;     # package is no longer blocking
    return;
  }
  print "  - $prp: $packid built: ".(@all). " files\n";
  mkdir_p("$gdst/:logfiles.success");
  mkdir_p("$gdst/:logfiles.fail");

  unlink("$jobdatadir/.preinstallimage");
  BSUtil::touch("$jobdatadir/.preinstallimage") if $info->{'file'} eq '_preinstallimage';
  my $useforbuildenabled = 1;
  $useforbuildenabled = BSUtil::enabled($repoid, $projpacks->{$projid}->{'useforbuild'}, $useforbuildenabled, $myarch);
  $useforbuildenabled = BSUtil::enabled($repoid, $pdata->{'useforbuild'}, $useforbuildenabled, $myarch);
  my $prpsearchpath = $gctx->{'prpsearchpath'}->{$prp};
  my $fullcache = $ectx->{'fullcache'};
  BSSched::BuildResult::update_dst_full($gctx, $prp, $packid, $jobdatadir, $meta, $useforbuildenabled, $prpsearchpath, $fullcache);
  $changed->{$prp} = 2 if $useforbuildenabled;
  my $repounchanged = $gctx->{'repounchanged'};
  delete $repounchanged->{$prp} if $useforbuildenabled;
  $repounchanged->{$prp} = 2 if $repounchanged->{$prp};
  $changed->{$prp} ||= 1;

  # save meta file
  rename($meta, "$gdst/:meta/$packid") if $meta;

  # write new status
  $status->{'status'} = 'succeeded';
  addjobhist($gctx, $prp, $info, $status, $js, 'succeeded');
  writexml("$dst/.status", "$dst/status", $status, $BSXML::buildstatus);

  # write history file
  my $duration = 0;
  $duration = $js->{'endtime'} - $js->{'starttime'} if $js->{'endtime'} && $js->{'starttime'};;
  my $h = {'versrel' => $info->{'versrel'}, 'bcnt' => $info->{'bcnt'}, 'time' => $now, 'srcmd5' => $info->{'srcmd5'}, 'rev' => $info->{'rev'}, 'reason' => $info->{'reason'}, 'duration' => $duration};
  BSFileDB::fdb_add("$dst/history", $historylay, $h);

  # update relsync file (use relsync.merge if relsync is too big)
  if (((-s "$gdst/:relsync") || 0) < 8192 && ! -e "$gdst/:relsync.merge") {
    my $relsync = BSUtil::retrieve("$gdst/:relsync", 1) || {};
    $relsync->{$packid} = "$info->{'versrel'}.$info->{'bcnt'}";
    BSUtil::store("$gdst/.:relsync", "$gdst/:relsync", $relsync);
  } else {
    my $relsync = BSUtil::retrieve("$gdst/:relsync.merge", 1) || {};
    $relsync->{$packid} = "$info->{'versrel'}.$info->{'bcnt'}";
    BSUtil::store("$gdst/.:relsync.merge", "$gdst/:relsync.merge", $relsync);
  }

  # save logfile
  link("$jobdatadir/logfile", "$jobdatadir/logfile.dup");
  rename("$jobdatadir/logfile", "$dst/logfile");
  rename("$jobdatadir/logfile.dup", "$gdst/:logfiles.success/$packid");
  unlink("$gdst/:logfiles.fail/$packid");
}


=head2 fakejobfinished - fake a built job

 Used for aggregates, as they do not get built on a worker, but
 by the scheduler itself.

=cut

sub fakejobfinished {
  my ($ctx, $packid, $job, $code, $buildinfoskel, $needsign) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  local *F;
  # directly go into the finished state
  my $jobstatus = {
    'code' => 'finished',
    'result' => $code,
  };
  my $myjobsdir = $gctx->{'myjobsdir'};
  if (!BSUtil::lockcreatexml(\*F, "$myjobsdir/.$job", "$myjobsdir/$job:status", $jobstatus, $BSXML::jobstatus)) {
    die("job lock failed\n");
  }
  my $binfo = {
    'project' => $ctx->{'project'},
    'repository' => $ctx->{'repository'},
    'package' => $packid,
    'arch' => $myarch,
    'job' => $job,
    %{$buildinfoskel || {}},
  };
  writejob($ctx, $job, $binfo);
  close(F);
  my $ev = {'type' => 'built', 'arch' => $myarch, 'job' => $job};
  if ($needsign) {
    BSSched::EventSource::Directory::sendevent($gctx, $ev, 'signer', "finished:$myarch:$job");
  } else {
    BSSched::EventSource::Directory::sendevent($gctx, $ev, $myarch, "finished:$job");
  }
}

##########################################################################

=head2 fakejobfinished_nouseforbuild - fake a nouseforbuild built job

 used for channel and patchinfo builds. They do not need signing and do
 not go into the full tree. Thus we do not need to generate an event,
 but can directly move the result into the build directory.

=cut

sub fakejobfinished_nouseforbuild {
  my ($ctx, $packid, $job, $code, $bininfo, $pdata) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $prp = "$projid/$repoid";
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  my $dst = "$gdst/$packid";
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $jobdatadir = "$myjobsdir/$job:dir";
  mkdir_p($dst);
  mkdir_p("$gdst/:meta");
  mkdir_p("$gdst/:logfiles.fail");
  mkdir_p("$gdst/:logfiles.success");
  unlink("$gdst/:repodone");
  if (-e "$jobdatadir/logfile") {
    link("$jobdatadir/logfile", "$jobdatadir/logfile.dup");
    if ($code eq 'failed') {
      rename("$jobdatadir/logfile.dup", "$gdst/:logfiles.fail/$packid");
    } else {
      rename("$jobdatadir/logfile.dup", "$gdst/:logfiles.success/$packid");
      unlink("$gdst/:logfiles.fail/$packid");
    }
    rename("$jobdatadir/logfile", "$dst/logfile");
  }
  rename("$jobdatadir/meta", "$gdst/:meta/$packid");
  if ($code eq 'succeeded') {
    $bininfo ||= {};
    # fixup filename entries
    for (keys %$bininfo) {
      die("job $job contains imported files\n") if /^::import::/;
      if (defined($bininfo->{$_}->{'filename'}) && $bininfo->{$_}->{'filename'} ne $_) {
        $bininfo->{$_} = { %{$bininfo->{$_}}, 'filename' => $_ };
      }
    }
    # commit job and
    BSUtil::cleandir($dst);
    for my $f (ls($jobdatadir)) {
      rename("$jobdatadir/$f", "$dst/$f") || die("rename $jobdatadir/$f $dst/$f: $!\n");
    }
    if (!BSSched::Access::checkaccess($ctx->{'gctx'}, 'sourceaccess', $projid, $packid, $repoid)) {
      BSUtil::touch("$dst/.nosourceaccess");
      $bininfo->{'.nosourceaccess'} = {};
    }
    $bininfo->{'.nouseforbuild'} = {};
    BSUtil::store("$dst/.bininfo.new", "$dst/.bininfo", $bininfo);
    my @bininfo_s = stat("$dst/.bininfo");
    $bininfo->{'.bininfo'} = {'id' => "$bininfo_s[9]/$bininfo_s[7]/$bininfo_s[1]"} if @bininfo_s;
    my $gbininfo = {};
    $gbininfo = BSUtil::retrieve("$gdst/:bininfo.merge", 1) if -e "$gdst/:bininfo.merge";
    if ($gbininfo) {
      $gbininfo->{$packid} = $bininfo;
      BSUtil::store("$gdst/.:bininfo.merge", "$gdst/:bininfo.merge", $gbininfo);
    } else {
      writestr("$gdst/.:bininfo.merge", "$gdst/:bininfo.merge", '');    # corrupt file, mark
    }
    delete $bininfo->{'.bininfo'};
    # write history file
    my $h = {'versrel' => $pdata->{'versrel'}, 'bcnt' => "0", 'time' => time(), 'srcmd5' => $pdata->{'srcmd5'}, 'rev' => $pdata->{'rev'}, 'reason' => "", 'duration' => "0"};
    BSFileDB::fdb_add("$dst/history", $historylay, $h);
  }
  BSUtil::cleandir($jobdatadir);
  rmdir($jobdatadir);
}

##########################################################################

=head2 patchpackstatus - TODO: add summary

 patch the packstatus entry of package $packid so that it reflects the finished state
 and does not revert back to scheduled

=cut

sub patchpackstatus {
  my ($gctx, $prp, $packid, $code) = @_;

  my $reporoot = $gctx->{'reporoot'};
  my $myarch = $gctx->{'arch'};
  my $gdst = "$reporoot/$prp/$myarch";
  $code ||= 'unknown';
  BSUtil::appendstr("$gdst/:packstatus.finished", "$code $packid\n");
  # touch mtime to make watchers see a change
  utime(time, time, "$gdst/:packstatus");
}


=head2 addjobhist - add a new job entry to :jobhistory file

 TODO: add description

=cut

sub addjobhist {
  my ($gctx, $prp, $info, $status, $js, $code) = @_;
  my $jobhist = {};
  $jobhist->{'code'} = $code;
  $jobhist->{$_} = $js->{$_} for qw{readytime starttime endtime uri workerid hostarch};
  $jobhist->{$_} = $info->{$_} for qw{package rev srcmd5 versrel bcnt reason};
  $jobhist->{'verifymd5'} = $info->{'verifymd5'} if $info->{'verifymd5'};
  $jobhist->{'readytime'} ||= $status->{'readytime'};   # backward compat
  my $myarch = $gctx->{'arch'};
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  mkdir_p($gdst);
  BSFileDB::fdb_add("$gdst/:jobhistory", $BSXML::jobhistlay, $jobhist);
}


=head2 nextbcnt - calculate the build counter for the next build

 TODO: add description

=cut

sub nextbcnt {
  my ($ctx, $packid, $pdata) = @_;

  return undef unless defined $packid;
  return 1 unless exists $pdata->{'versrel'},;
  my $h;
  my $gdst = $ctx->{'gdst'};
  my $relsyncmax = $ctx->{'relsyncmax'};
  my $dst = "$gdst/$packid";
  if (-e "$dst/history") {
    $h = BSFileDB::fdb_getmatch("$dst/history", $historylay, 'versrel', $pdata->{'versrel'}, 1);
  }
  $h = {'bcnt' => 0} unless $h;

  # max with sync data
  my $tag = $pdata->{'bcntsynctag'} || $packid;
  if ($relsyncmax && $relsyncmax->{"$tag/$pdata->{'versrel'}"}) {
    if ($h->{'bcnt'} + 1 < $relsyncmax->{"$tag/$pdata->{'versrel'}"}) {
      $h->{'bcnt'} = $relsyncmax->{"$tag/$pdata->{'versrel'}"} - 1;
    }
  }
  return $h->{'bcnt'} + 1;
}

=head2 filljobdata - create a job skel

 TODO: add description

=cut

sub create_jobdata {
  my ($ctx, $packid, $pdata, $info, $subpacks) = @_;

  my $gctx = $ctx->{'gctx'};
  my $bconf = $ctx->{'conf'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $binfo = {
    'project' => $projid,
    'repository' => $repoid,
    'arch' => $myarch,
    'subpack' => $subpacks || [],
  };
  $binfo->{'package'} = $packid if defined $packid;
  $binfo->{'rev'} = $pdata->{'rev'} if $pdata->{'rev'};
  $binfo->{'srcmd5'} = $pdata->{'srcmd5'} if $pdata->{'srcmd5'};
  $binfo->{'verifymd5'} = $pdata->{'verifymd5'} || $pdata->{'srcmd5'} if $pdata->{'verifymd5'} || $pdata->{'srcmd5'};
  $binfo->{'file'} = $info->{'file'} if defined $info->{'file'};
  $binfo->{'imagetype'} = $info->{'imagetype'} if $info->{'imagetype'};
  $binfo->{'nodbgpkgs'} = $info->{'nodbgpkgs'} if $info->{'nodbgpkgs'};
  $binfo->{'nosrcpkgs'} = $info->{'nosrcpkgs'} if $info->{'nosrcpkgs'};
  $binfo->{'hostarch'} = $bconf->{'hostarch'} if $bconf->{'hostarch'};
  my $obsname = $gctx->{'obsname'};
  $binfo->{'disturl'} = "obs://$obsname/$projid/$repoid/$pdata->{'srcmd5'}-$packid" if defined($obsname) && defined($packid);
  if (defined($packid) && exists($pdata->{'versrel'})) {
    $binfo->{'versrel'} = $pdata->{'versrel'};
    # find the last build count we used for this version/release
    my $bcnt = nextbcnt($ctx, $packid, $pdata);
    $binfo->{'bcnt'} = $bcnt;
    my $release = $pdata->{'versrel'};
    $release = '0' unless defined $release;
    $release =~ s/.*-//;
    if (exists($bconf->{'release'})) {
      if (defined($bconf->{'release'})) {
	$binfo->{'release'} = $bconf->{'release'};
	$binfo->{'release'} =~ s/\<CI_CNT\>/$release/g;
	$binfo->{'release'} =~ s/\<B_CNT\>/$bcnt/g;
      }
    } else {
      $binfo->{'release'} = "$release.$bcnt" if $ctx->{'dobuildinfo'};
    }
  }
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid};
  my $debuginfo = $bconf->{'debuginfo'};
  $debuginfo = BSUtil::enabled($repoid, $proj->{'debuginfo'}, $debuginfo, $myarch);
  $debuginfo = BSUtil::enabled($repoid, $pdata->{'debuginfo'}, $debuginfo, $myarch);
  $binfo->{'debuginfo'} = 1 if $debuginfo;
  return $binfo;
}

=head2 add_expanddebug - add debug data from the expander

 input:  $ctx           - prp context
         $type          - expandsion type information 
         $xp            - expander (optional)

=cut

sub add_expanddebug {
  my ($ctx, $type, $xp) = @_;
  my $expanddebug = $ctx->{'expanddebug'};
  return unless ref($expanddebug);
  $xp ||= $ctx->{'expander'};
  return unless $xp;
  return unless defined &BSSolv::expander::debugstr;
  my $dbg = $xp->debugstr();
  return unless $dbg;
  $dbg = substr($dbg, $ctx->{"xp_cut_hack$xp"}) if $ctx->{"xp_cut_hack$xp"};
  return unless $dbg;
  $$expanddebug .= "\n" if $$expanddebug;
  $$expanddebug .= "=== $type\n";
  $$expanddebug .= $dbg;
  $dbg = $xp->debugstr();
  $ctx->{"xp_cut_hack$xp"} = length($dbg) if $dbg;	# sigh
}

=head2 create - create a new build job

 input:  $ctx           - prp context
         $packid        - package to be built
         $pdata         - package data
         $info          - file and dependency information
         $subpacks      - all subpackages of this package we know of
         $edeps         - expanded build dependencies
         $reason        - what triggered the build
         $needed        - packages blocked by this job

 output: $state         - scheduled, broken
         $job/error     - the job or the error

 check if this job is already building, if yes, do nothing.
 otherwise calculate and expand build dependencies, kill all
 other jobs of the same prp/package, write status and job info.
 not that hard, was it?

=cut

sub create {
  my ($ctx, $packid, $pdata, $info, $subpacks, $edeps, $reason, $needed) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $bconf = $ctx->{'conf'};
  my $gdst = $ctx->{'gdst'};
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid};
  my $prp = "$projid/$repoid";
  my $srcmd5 = $pdata->{'srcmd5'};
  my $jobprefix = $packid ? jobname($prp, $packid) : undef;
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $dobuildinfo = $ctx->{'dobuildinfo'};

  if ($myjobsdir) {
    if (-s "$myjobsdir/$jobprefix-$srcmd5") {
      add_crossmarker($gctx, $bconf->{'hostarch'}, "$jobprefix-$srcmd5") if $bconf->{'hostarch'};	# just in case...
      return ('scheduled', "$jobprefix-$srcmd5");
    }
    return ('scheduled', $jobprefix) if -s "$myjobsdir/$jobprefix";   # obsolete
  }
  my $job = $jobprefix;
  $job .= "-$srcmd5" if defined($job) && $srcmd5;

  # a new one. expand usedforbuild. write info file.
  my $buildtype = $pdata->{'buildtype'} || Build::recipe2buildtype($info->{'file'});

  my $kiwimode;
  $kiwimode = $buildtype if $buildtype eq 'kiwi' || $buildtype eq 'docker' || $buildtype eq 'fissile';

  my $syspath;
  my $searchpath = path2buildinfopath($gctx, $ctx->{'prpsearchpath'});
  if ($kiwimode) {
    # switch searchpath to kiwi info path
    $syspath = $searchpath if @$searchpath;
    $searchpath = path2buildinfopath($gctx, [ expandkiwipath($info, $ctx->{'prpsearchpath'}) ]);
  }

  my $expanddebug = $ctx->{'expanddebug'};

  # calculate sysdeps (cannot cache in the kiwi case)
  my @sysdeps;
  if ($buildtype eq 'kiwi') {
    my $kiwitype = '';
    $kiwitype = $info->{'imagetype'} && $info->{'imagetype'}->[0] eq 'product' ? 'kiwi-product' : 'kiwi-image';
    @sysdeps = grep {/^kiwi-.*:/} @{$info->{'dep'} || []};
    @sysdeps = Build::get_sysbuild($bconf, $kiwitype, [ @sysdeps,  @{$ctx->{'extradeps'} || []} ]);
  } else {
    $ctx->{"sysbuild_$buildtype"} ||= [ Build::get_sysbuild($bconf, $buildtype) ];
    @sysdeps = @{$ctx->{"sysbuild_$buildtype"}};
  }
  add_expanddebug($ctx,'sysdeps expansion') if $expanddebug && @sysdeps;

  # calculate packages needed for building
  my @bdeps = grep {!/^\// || $bconf->{'fileprovides'}->{$_}} @{$info->{'prereq'} || []};
  unshift @bdeps, '--directdepsend--' if @bdeps;
  unshift @bdeps, @{$info->{'dep'} || []}, @{$ctx->{'extradeps'} || []};
  push @bdeps, '--ignoreignore--' if @sysdeps;

  if ($kiwimode || $buildtype eq 'buildenv') {
    @bdeps = (1, @$edeps);      # reuse edeps packages, no need to expand again
  } else {
    @bdeps = Build::get_build($bconf, $subpacks, @bdeps);
    add_expanddebug($ctx, 'build expansion') if $expanddebug;
  }
  if (!shift(@bdeps)) {
    if ($ctx->{'verbose'}) {
      print "        unresolvable:\n";
      print "          $_\n" for @bdeps;
    }
    return ('unresolvable', join(', ', @bdeps));
  }
  if (@sysdeps && !shift(@sysdeps)) {
    if ($ctx->{'verbose'}) {
      print "        unresolvable:\n";
      print "          $_\n" for @sysdeps;
    }
    return ('unresolvable', join(', ', @sysdeps));
  }

  my $pool = $ctx->{'pool'};
  my @pdeps = Build::get_preinstalls($bconf);
  my @vmdeps = Build::get_vminstalls($bconf);

  # do DoD checking
  if (!$ctx->{'isreposerver'} && $BSConfig::enable_download_on_demand) {
    my $dods;
    if ($kiwimode) {
      # image packages are already checked (they come from a different pool anyway)
      $dods = BSSched::DoD::dodcheck($ctx, $pool, $myarch, @pdeps, @vmdeps, @sysdeps);
    } else {
      $dods = BSSched::DoD::dodcheck($ctx, $pool, $myarch, @pdeps, @vmdeps, @bdeps, @sysdeps);
    }
    if ($dods) {
      print "        blocked: $dods\n" if $ctx->{'verbose'};
      return ('blocked', $dods);
    }
  }

  # make sure we have the preinstalls and vminstalls
  my @missing = grep {!$ctx->{'dep2pkg'}->{$_}} (@pdeps, @vmdeps);
  if (@missing) {
    @missing = sort(BSUtil::unify(@missing));
    return ('unresolvable', "missing pre/vminstalls: ".join(', ', @missing));
  }

  # kill those ancient other jobs
  if ($myjobsdir) {
    my @otherjobs = find_otherjobs($ctx, $jobprefix);
    for my $otherjob (@otherjobs) {
      print "        killing old job $otherjob\n" if $ctx->{'verbose'};
      killjob($gctx, $otherjob);
    }
  }

  # create bdep section
  my %runscripts = map {$_ => 1} Build::get_runscripts($bconf);
  my %bdeps = map {$_ => 1} @bdeps;
  my %pdeps = map {$_ => 1} @pdeps;
  my %vmdeps = map {$_ => 1} @vmdeps;
  my %edeps = map {$_ => 1} @$edeps;
  my %sysdeps = map {$_ => 1} @sysdeps;

  my $needextradata = $dobuildinfo || $ctx->{'unorderedrepos'};
  @bdeps = BSUtil::unify(@pdeps, @vmdeps, @$edeps, @bdeps, @sysdeps);
  @bdeps = () if $buildtype eq 'buildenv';
  for (@bdeps) {
    my $n = $_;
    $_ = {'name' => $_};
    $_->{'preinstall'} = 1 if $pdeps{$n};
    $_->{'vminstall'} = 1 if $vmdeps{$n};
    $_->{'runscripts'} = 1 if $runscripts{$n};
    $_->{'notmeta'} = 1 unless $edeps{$n};
    if (@sysdeps) {
      $_->{'installonly'} = 1 if $sysdeps{$n} && !$bdeps{$n} && !$kiwimode;
      $_->{'noinstall'} = 1 if $bdeps{$n} && !($sysdeps{$n} || $vmdeps{$n} || $pdeps{$n});
    }
    if ($needextradata) {
      my $p = $ctx->{'dep2pkg'}->{$n};
      my $prp = $pool->pkg2reponame($p);
      ($_->{'project'}, $_->{'repository'}) = split('/', $prp, 2) if $prp;
      if ($dobuildinfo) {
        my $d = $pool->pkg2data($p);
        $_->{'epoch'}      = $d->{'epoch'} if $d->{'epoch'};
        $_->{'version'}    = $d->{'version'};
        $_->{'release'}    = $d->{'release'} if defined $d->{'release'};
        $_->{'arch'}       = $d->{'arch'} if $d->{'arch'};
        $_->{'preimghdrmd5'} = $d->{'hdrmd5'} if !$_->{'noinstall'} &&  $d->{'hdrmd5'};
      }
    }
  }
  if ($info->{'extrasource'}) {
    push @bdeps, map {{
      'name' => $_->{'file'}, 'version' => '', 'repoarch' => 'src',
      'project' => $_->{'project'}, 'package' => $_->{'package'}, 'srcmd5' => $_->{'srcmd5'},
    }} @{$info->{'extrasource'}};
  }
  unshift @bdeps, @{$ctx->{'extrabdeps'}} if $ctx->{'extrabdeps'};

  # fill job data
  my $binfo = create_jobdata($ctx, $packid, $pdata, $info, $subpacks);
  $binfo->{'bdep'} = \@bdeps;
  $binfo->{'path'} = $searchpath;
  $binfo->{'syspath'} = $syspath if $syspath;
  $binfo->{'containerpath'} = path2buildinfopath($gctx, $ctx->{'containerpath'}) if $ctx->{'containerpath'};
  $binfo->{'containerannotation'} = $ctx->{'containerannotation'} if $ctx->{'containerannotation'};
  $binfo->{'needed'} = $needed;
  $binfo->{'constraintsmd5'} = $pdata->{'constraintsmd5'} if $pdata->{'constraintsmd5'};
  $binfo->{'prjconfconstraint'} = $bconf->{'constraint'} if @{$bconf->{'constraint'} || []};
  $binfo->{'nounchanged'} = 1 if $info->{'nounchanged'};
  if ($pdata->{'revtime'}) {
    $binfo->{'revtime'} = $pdata->{'revtime'};
    # use max of revtime for interproject links
    for (@{$pdata->{'linked'} || []}) {
      last if $_->{'project'} ne $projid || !$proj->{'package'};
      my $lpdata = $proj->{'package'}->{$_->{'package'}} || {};
      $binfo->{'revtime'} = $lpdata->{'revtime'} if ($lpdata->{'revtime'} || 0) > $binfo->{'revtime'};
    }
  }
  $ctx->writejob($job, $binfo, $reason);

  # all done. the dispatcher will now pick up the job and send it
  # to a worker.
  return ('scheduled', $job);
}


=head2 jobname - calculate the first part of the name of a new build job

 input:  $prp    - prp the job belongs to
         $packid - package we are building
 output: first part of job identification

 append srcmd5 for full identification

=cut

sub jobname {
  my ($prp, $packid) = @_;
  my $job = "$prp/$packid";
  $job =~ s/\//::/g;
  $job = ':'.Digest::MD5::md5_hex($prp).'::'.(length($packid) > 160 ? ':'.Digest::MD5::md5_hex($packid) : $packid) if length($job) > 200;
  return $job;
}


=head2 path2buildinfopath - TODO: add summary

 TODO: add description

=cut

sub path2buildinfopath {
  my ($gctx, $path) = @_;
  my $remoteprojs = $gctx->{'remoteprojs'};
  my @ret;
  for (@{$path || []}) {
    my @pr = split('/', $_, 2);
    my $server = $workerreposerver;
    if ($remoteprojs->{$pr[0]}) {
      $server = $workersrcserver;
      my $par = $remoteprojs->{$pr[0]}->{'partition'};
      if ($par) {
        # XXX: should also come from src server
	if ($BSConfig::workerpartitionservers) {
          $server = $BSConfig::workerpartitionservers->{$par} || $remoteprojs->{$pr[0]}->{'remoteurl'};
	} else {
          $server = $remoteprojs->{$pr[0]}->{'remoteurl'};
	}
      }
    }
    push @ret, {'project' => $pr[0], 'repository' => $pr[1], 'server' => $server};
  }
  return \@ret;
}


=head2 metacheck - check if the old meta is different to the new meta

 TODO: add description

=cut

sub metacheck {
  my ($ctx, $packid, $pdata, $buildtype, $new_meta, $data) = @_;

  my $gdst = $ctx->{'gdst'};
  return ('scheduled', [ @$data, {'explain' => 'buildinfo generation'} ]) if $ctx->{'isreposerver'};
  unshift @$new_meta, ($pdata->{'verifymd5'} || $pdata->{'srcmd5'})."  $packid";
  my @meta = split("\n", (readstr("$gdst/:meta/$packid", 1) || ''));
  if (!@meta) {
    if ($ctx->{'verbose'}) {
      print "      - $packid ($buildtype)\n";
      print "        no former build, start build\n";
    }
    return ('scheduled', [ @$data, {'explain' => 'new build'} ]);
  }
  if ($meta[0] ne $new_meta->[0]) {
    if ($ctx->{'verbose'}) {
      print "      - $packid ($buildtype)\n";
      print "        src change, start build\n";
    }
    return ('scheduled', [ @$data, {'explain' => 'source change', 'oldsource' => substr($meta[0], 0, 32)} ]);
  }
  if (@meta == 2 && $meta[1] =~ /^fake/) {
    my @s = stat("$gdst/:meta/$packid");
    if (!@s || $s[9] + 14400 > time()) {
      if ($ctx->{'verbose'}) {
        print "      - $packid ($buildtype)\n";
        print "        buildsystem setup failure\n";
      }
      return ('failed')
    }
    if ($ctx->{'verbose'}) {
      print "      - $packid ($buildtype)\n";
      print "        retrying bad build\n";
    }
    return ('scheduled', [ @$data, { 'explain' => 'retrying bad build' } ]);
  }
  if (join('\n', @meta) eq join('\n', @$new_meta)) {
    if (($buildtype eq 'kiwi-image' || $buildtype eq 'kiwi-product') && $ctx->{'relsynctrigger'}->{$packid}) {
      if ($ctx->{'verbose'}) {
        print "      - $packid ($buildtype)\n";
        print "        rebuild counter sync\n";
      }
      return ('scheduled', [ @$data, {'explain' => 'rebuild counter sync'} ]);
    }
    #print "      - $packid ($buildtype)\n";
    #print "        nothing changed\n";
    return ('done');
  }
  my $repo = $ctx->{'repo'};
  if ($buildtype eq 'kiwi-image' || $buildtype eq 'kiwi-product') {
    my $rebuildmethod = $repo->{'rebuild'} || 'transitive';
    if ($rebuildmethod eq 'local') {
      #print "      - $packid ($buildtype)\n";
      #print "        nothing changed\n";
      return ('done');
    }
  }
  my @diff = diffsortedmd5(\@meta, $new_meta);
  if ($ctx->{'verbose'}) {
    print "      - $packid ($buildtype)\n";
    print "        $_\n" for @diff;
    print "        meta change, start build\n";
  }
  return ('scheduled', [ @$data, {'explain' => 'meta change', 'packagechange' => sortedmd5toreason(@diff)} ]);
}

=head2 sortedmd5toreason - convert the diffsortedmd5 output to a reason string

 TODO: add description

=cut

sub sortedmd5toreason {
  my @res;
  for my $line (@_) {
    my $tag = substr($line, 0, 1); # just the first char
    $tag = 'md5sum' if $tag eq '!';
    $tag = 'added' if $tag eq '+';
    $tag = 'removed' if $tag eq '-';
    push @res, { 'change' => $tag, 'key' => substr($line, 1) };
  }
  return \@res;
}

=head2 diffsortedmd5 - diff two meta arrays

 TODO: add description

=cut

sub diffsortedmd5 {
  my ($fromp, $top) = @_;

  my @ret;
  my @from = map {[$_, substr($_, 34)]} @$fromp;
  my @to   = map {[$_, substr($_, 34)]} @$top;
  @from = sort {$a->[1] cmp $b->[1] || $a->[0] cmp $b->[0]} @from;
  @to   = sort {$a->[1] cmp $b->[1] || $a->[0] cmp $b->[0]} @to;

  for my $f (@from) {
    if (@to && $f->[1] eq $to[0]->[1]) {
      push @ret, "!$f->[1]" if $f->[0] ne $to[0]->[0];
      shift @to;
      next;
    }
    if (!@to || $f->[1] lt $to[0]->[1]) {
      push @ret, "-$f->[1]";
      next;
    }
    while (@to && $f->[1] gt $to[0]->[1]) {
      push @ret, "+$to[0]->[1]";
      shift @to;
    }
    redo;
  }
  push @ret, "+$_->[1]" for @to;
  return @ret;
}

=head2 expandkiwipath - TODO: add summary

 TODO: add description

=cut

sub expandkiwipath {
  my ($info, $prpsearchpath, $prios) = @_;
  my @path;
  for (@{$info->{'path'} || []}) {
    if ($_->{'project'} eq '_obsrepositories') {
      push @path, @{$prpsearchpath || []}; 
    } else {
      my $prp = "$_->{'project'}/$_->{'repository'}";
      push @path, $prp;
      if ($prios) {
        my $prio = $_->{'priority'} || 0;
        $prios->{$prp} = $prio if !defined($prios->{$prp}) || $prio > $prios->{$prp};
      }
    }
  }
  return @path;
}

=head2 getcontainerannotation - get the annotation from a container package

 Also add annotation to container bdep if provided as argument.

=cut

sub getcontainerannotation {
  my ($pool, $p, $bdep) = @_;
  return undef unless defined &BSSolv::pool::pkg2annotation;
  my $annotation = $pool->pkg2annotation($p);
  return undef unless $annotation;
  $annotation = BSUtil::fromxml($annotation, $BSXML::binannotation, 1);
  return undef unless $annotation;
  if ($bdep) {
    # add extra data from the package data
    my $data = $pool->pkg2data($p);
    $annotation->{'hdrmd5'} = $data->{'hdrmd5'} if $data->{'hdrmd5'};
    $annotation->{'package'} = $1 if $data->{'path'} && $data->{'path'} =~ /^\.\.\/([^\/]+)\//;
    $annotation->{'epoch'} = $data->{'epoch'} if $data->{'epoch'};
    $annotation->{'version'} = $data->{'version'};
    $annotation->{'release'} = $data->{'release'} if defined $data->{'release'};
    $annotation->{'binaryarch'} = $data->{'arch'} if $data->{'arch'};
    $bdep->{'annotation'} = BSUtil::toxml($annotation, $BSXML::binannotation);
  }
  return $annotation;
}

1;


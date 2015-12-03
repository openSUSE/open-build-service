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

use strict;
use warnings;

use Data::Dumper;
use Digest::MD5 ();

use BSUtil;
use BSXML;
use BSFileDB;
use BSConfiguration;
use BSSched::DoD;	# for dodcheck
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
  %ourjobs = map {$_ => 1} grep {!/(?::dir|:status)$/} ls($myjobsdir);
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
  delete $ourjobs{$job};
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

  my $myjobsdir = $gctx->{'myjobsdir'};
  my $prpjobs = jobname($prp, '');
  for my $job (grep {/^\Q$prpjobs\E/} sort keys %ourjobs) {
    if ($job =~ /^\Q$prpjobs\E(.*)-[0-9a-f]{32}$/) {
      my $status = $packstatus->{$1} || '';
      next if $status eq 'scheduled';
      if (! -e "$myjobsdir/$job") {
	delete $ourjobs{$job};
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
}

=head2 writejob - write a new job to disc

After writing the dispatcher will pick up the job and dispatch it
to a free worker.

=cut

sub writejob {
  my ($gctx, $job, $binfo) = @_;

  my $myjobsdir = $gctx->{'myjobsdir'};
  writexml("$myjobsdir/.$job", "$myjobsdir/$job", $binfo, $BSXML::buildinfo);
  add_crossmarker($gctx, $binfo->{'hostarch'}, $job) if $binfo->{'hostarch'};
  $ourjobs{$job} = 1;
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

  my $myjobsdir = $ectx->{'gctx'}->{'myjobsdir'};
  my $info = readxml("$myjobsdir/$job", $BSXML::buildinfo, 1);
  my $jobdatadir = "$myjobsdir/$job:dir";
  if (!$info || ! -d $jobdatadir) {
    print "  - $job is bad\n";
    return;
  }
  # specialized versiosn for aggregates and deltas
  if ($info->{'file'} eq '_aggregate') {
    main::aggregatefinished($ectx, $job, $js);
    return ;
  }
  if ($info->{'file'} eq '_delta') {
    main::deltafinished($ectx, $job, $js);
    return ;
  }
  my $fullcache = $ectx->{'fullcache'};
  my $gctx = $ectx->{'gctx'};
  my $changed = $gctx->{'changed_med'};

  my $projid = $info->{'project'};
  my $repoid = $info->{'repository'};
  my $packid = $info->{'package'};
  my $prp = "$projid/$repoid";
  my $myarch = $gctx->{'arch'};

  BSSched::BuildRepo::sync_fullcache($gctx, $fullcache) if $fullcache && $fullcache->{'prp'} && $fullcache->{'prp'} ne $prp;    # hey!

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
  unlink($_) for @all;
  rmdir($jobdatadir);
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
  writejob($gctx, $job, $binfo);
  close(F);
  my $ev = {'type' => 'built', 'arch' => $myarch, 'job' => $job};
  if ($needsign) {
    main::sendevent($gctx, $ev, 'signer', "finished:$myarch:$job");
  } else {
    main::sendevent($gctx, $ev, $myarch, "finished:$job");
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
    if (!main::checkaccess($ctx->{'gctx'}, 'sourceaccess', $projid, $packid, $repoid)) {
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
  my $relsyncmax = $ctx->{'relsyncmax'};
  my $prp = "$projid/$repoid";
  my $srcmd5 = $pdata->{'srcmd5'};
  my $job = jobname($prp, $packid);
  my $myjobsdir = $gctx->{'myjobsdir'};
  if (-s "$myjobsdir/$job-$srcmd5") {
    add_crossmarker($gctx, $bconf->{'hostarch'}, "$job-$srcmd5") if $bconf->{'hostarch'};	# just in case...
    return ('scheduled', "$job-$srcmd5");
  }
  return ('scheduled', $job) if -s "$myjobsdir/$job";   # obsolete
  my @otherjobs = grep {/^\Q$job\E-[0-9a-f]{32}$/} ls($myjobsdir);
  $job = "$job-$srcmd5";

  # a new one. expand usedforbuild. write info file.
  my $buildtype = Build::recipe2buildtype($info->{'file'});

  my $syspath;
  my $searchpath = path2buildinfopath($gctx, $ctx->{'prpsearchpath'});
  if ($buildtype eq 'kiwi') {
    # switch searchpath to kiwi info path
    $syspath = $searchpath if @$searchpath;
    $searchpath = path2buildinfopath($gctx, [ main::expandkiwipath($info, $ctx->{'prpsearchpath'}) ]);
  }

  # calculate sysdeps (cannot cache in the kiwi case)
  my @sysdeps;
  if ($buildtype eq 'kiwi') {
    @sysdeps = Build::get_sysbuild($bconf, 'kiwi-image', [ grep {/^kiwi-.*:/} @{$info->{'dep'} || []} ]);
  } else {
    $ctx->{"sysbuild_$buildtype"} ||= [ Build::get_sysbuild($bconf, $buildtype) ];
    @sysdeps = @{$ctx->{"sysbuild_$buildtype"}};
  }

  # calculate packages needed for building
  my @bdeps = grep {!/^\// || $bconf->{'fileprovides'}->{$_}} @{$info->{'prereq'} || []};
  unshift @bdeps, '--directdepsend--' if @bdeps;
  unshift @bdeps, @{$info->{'dep'} || []};
  push @bdeps, '--ignoreignore--' if @sysdeps;

  if ($buildtype eq 'kiwi') {
    @bdeps = (1, @$edeps);      # reuse edeps packages, no need to expand again
  } else {
    @bdeps = Build::get_build($bconf, $subpacks, @bdeps);
  }
  if (!shift(@bdeps)) {
    print "        unresolvable:\n";
    print "          $_\n" for @bdeps;
    return ('unresolvable', join(', ', @bdeps));
  }
  if (@sysdeps && !shift(@sysdeps)) {
    print "        unresolvable:\n";
    print "          $_\n" for @sysdeps;
    return ('unresolvable', join(', ', @sysdeps));
  }
  if ($BSConfig::enable_download_on_demand) {
    my $dods = BSSched::DoD::dodcheck($ctx, $ctx->{'pool'}, $myarch, Build::get_preinstalls($bconf), Build::get_vminstalls($bconf), @bdeps, @sysdeps);
    if ($dods) {
      print "        blocked: $dods\n";
      return ('blocked', $dods);
    }
  }

  my $dst = "$gdst/$packid";
  # find the last build count we used for this version/release
  mkdir_p($dst);
  my $h;
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

  # kill those ancient other jobs
  for my $otherjob (@otherjobs) {
    print "        killing old job $otherjob\n";
    killjob($gctx, $otherjob);
  }

  # jay! ready for building, write status and job info
  my $now = time();
  writexml("$dst/.status", "$dst/status", { 'status' => 'scheduled', 'readytime' => $now, 'job' => $job}, $BSXML::buildstatus);
  # And store reason and time
  $reason->{'time'} = $now;
  writexml("$dst/.reason", "$dst/reason", $reason, $BSXML::buildreason);

  my @pdeps = Build::get_preinstalls($bconf);
  my @vmdeps = Build::get_vminstalls($bconf);
  my %runscripts = map {$_ => 1} Build::get_runscripts($bconf);
  my %bdeps = map {$_ => 1} @bdeps;
  my %pdeps = map {$_ => 1} @pdeps;
  my %vmdeps = map {$_ => 1} @vmdeps;
  my %edeps = map {$_ => 1} @$edeps;
  my %sysdeps = map {$_ => 1} @sysdeps;
  @bdeps = unify(@pdeps, @vmdeps, @$edeps, @bdeps, @sysdeps);
  for (@bdeps) {
    my $n = $_;
    $_ = {'name' => $_};
    $_->{'preinstall'} = 1 if $pdeps{$n};
    $_->{'vminstall'} = 1 if $vmdeps{$n};
    $_->{'runscripts'} = 1 if $runscripts{$n};
    $_->{'notmeta'} = 1 unless $edeps{$n};
    if (@sysdeps) {
      $_->{'installonly'} = 1 if $sysdeps{$n} && !$bdeps{$n} && $buildtype ne 'kiwi';
      $_->{'noinstall'} = 1 if $bdeps{$n} && !($sysdeps{$n} || $vmdeps{$n} || $pdeps{$n});
    }
  }
  if ($info->{'extrasource'}) {
    push @bdeps, map {{
      'name' => $_->{'file'}, 'version' => '', 'repoarch' => 'src',
      'project' => $_->{'project'}, 'package' => $_->{'package'}, 'srcmd5' => $_->{'srcmd5'},
    }} @{$info->{'extrasource'}};
  }

  my $vmd5 = $pdata->{'verifymd5'} || $pdata->{'srcmd5'};
  my $binfo = {
    'project' => $projid,
    'repository' => $repoid,
    'package' => $packid,
    'srcserver' => $workersrcserver,
    'reposerver' => $workerreposerver,
    'job' => $job,
    'arch' => $myarch,
    'reason' => $reason->{'explain'},
    'readytime' => $now,
    'srcmd5' => $pdata->{'srcmd5'},
    'verifymd5' => $vmd5,
    'rev' => $pdata->{'rev'},
    'file' => $info->{'file'},
    'versrel' => $pdata->{'versrel'},
    'bcnt' => $h->{'bcnt'} + 1,
    'subpack' => ($subpacks || []),
    'bdep' => \@bdeps,
    'path' => $searchpath,
    'needed' => $needed,
  };
  my $obsname = $gctx->{'obsname'};
  $binfo->{'disturl'} = "obs://$obsname/$projid/$repoid/$pdata->{'srcmd5'}-$packid";
  $binfo->{'syspath'} = $syspath if $syspath;
  $binfo->{'hostarch'} = $bconf->{'hostarch'} if $bconf->{'hostarch'};
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
  $binfo->{'imagetype'} = $info->{'imagetype'} if $info->{'imagetype'};
  my $release = $pdata->{'versrel'};
  $release = '0' unless defined $release;
  $release =~ s/.*-//;
  my $bcnt = $h->{'bcnt'} + 1;
  if (defined($bconf->{'release'})) {
    $binfo->{'release'} = $bconf->{'release'};
    $binfo->{'release'} =~ s/\<CI_CNT\>/$release/g;
    $binfo->{'release'} =~ s/\<B_CNT\>/$bcnt/g;
  }
  my $debuginfo = $bconf->{'debuginfo'};
  $debuginfo = BSUtil::enabled($repoid, $proj->{'debuginfo'}, $debuginfo, $myarch);
  $debuginfo = BSUtil::enabled($repoid, $pdata->{'debuginfo'}, $debuginfo, $myarch);
  $binfo->{'debuginfo'} = 1 if $debuginfo;

  writejob($gctx, $job, $binfo);
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

1;


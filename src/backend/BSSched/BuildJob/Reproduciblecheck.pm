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

package BSSched::BuildJob::Reproduciblecheck;

use Digest::MD5 (); 

use BSUtil;
use BSSched::BuildJob;
use BSSched::EventSource::Directory;

use strict;

=head1 NAME

BSSched::BuildJob::Reproduciblecheck - A Class to handle reproducible build verification

=head1 SYNOPSIS

my $h = BSSched::BuildJob::Reproduciblecheck->new()

$h->check();

$h->expand();

$h->rebuild();

=cut

=head2 new - TODO: add summary

 TODO: add description

=cut

sub new {
  return bless({}, $_[0]);
}

=head2 expand - TODO: add summary

 TODO: add description

=cut

sub expand {
  return 1, splice(@_, 3);
}

=head2 check - check if we should start a new build

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info, $buildtype, $edeps) = @_;
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $prp = $ctx->{'prp'};
  return('broken', 'confused reprorepo setup') unless $ctx->{'isreprorepo'} && $ctx->{'isreprorepo'} ne $ctx->{'repository'};
  my $dst = "$gdst/$packid";
  if (! -e "$dst/.reprojob") {
    if (-e "$dst/.reprojob.success") {
      rename("$dst/.reprojob.success", "$dst/.reprojob") || die("rename $dst/.reprojob.success $dst/.reprojob: $!\n");
    } else {
      return ('blocked', 'waiting for repro job');
    }
  }
  my $jobxml = readstr("$dst/.reprojob");
  my $reprojobid  = Digest::MD5::md5_hex($jobxml);

  my $jobprefix = $packid ? BSSched::BuildJob::jobname($prp, $packid) : undef;
  my $job = $jobprefix."-$reprojobid";
  my $myjobsdir = $gctx->{'myjobsdir'};

  if ($myjobsdir && -s "$myjobsdir/$job") {
    if (-e "$myjobsdir/$job:dir/.needcompare") {
      if ($ctx->{'verbose'}) {
	print "      - $packid ($buildtype)\n";
        print "        start reproducible check job\n";
      }
      # here comes the tricky part: generate the compare job
      return ('scheduled', [ $jobxml, $reprojobid, $job, $jobprefix, 1 ]);
    }
    my $origprp = "$ctx->{'project'}/$ctx->{'isreprorepo'}";
    my $origjob = BSSched::BuildJob::jobname($origprp, $packid)."-$reprojobid";
    if (!-s "$myjobsdir/$origjob" && -e "$myjobsdir/$job:dir/.isfinished") {
      # generate a synthetic finished event
      my $ev = {'type' => 'built', 'arch' => $gctx->{'arch'}, 'job' => $job};
      BSSched::EventSource::Directory::sendevent($gctx, $ev, $gctx->{'arch'}, "finished:$job");
    }
    return ('building', $job);
  }

  my $oldmeta = readstr("$gdst/:meta/$packid", 1) || '';
  my @oldmeta = split("\n", $oldmeta);
  if ($oldmeta[0] && $oldmeta[0] eq "$reprojobid  $packid") {
    print "      - $packid ($buildtype)\n";
    print "        no change\n";
    return ('done');
  }
  if ($ctx->{'verbose'}) {
    print "      - $packid ($buildtype)\n";
    if ($oldmeta[0]) {
      print "        changed job, start build\n";
    } else {
      print "        no meta, start build\n";
    }
  }
  return ('scheduled', [ $jobxml, $reprojobid, $job, $jobprefix, 0 ]);
}

sub build_docompare {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my ($jobxml, $reprojobid, $job, $jobprefix, $docompare) = @$data;
  my $gctx = $ctx->{'gctx'};
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $jobdatadir = "$myjobsdir/$job:dir";
  return ('broken', 'jobdatadir is missing') unless -d $jobdatadir;
  BSUtil::cp("$gctx->{'obssrcdir'}/templates/obs-reproduciblecheck.spec", "$jobdatadir/reproduciblecheck.spec");
  writestr("$jobdatadir/meta", undef, "$reprojobid  $packid\n");
  my $pdata_job = { 'srcmd5' => $reprojobid, 'buildtype' => 'reproduciblecheck' };
  my $info_job = { 'file' => '_reproduciblecheck', 'nouseforbuild' => 1 };
  my $reason = {'explain' => 'new build'};
  my ($status, $error) = BSSched::BuildJob::create($ctx, $packid, $pdata_job, $info_job, [], [], $reason, 0);
  unlink("$myjobsdir/$job:status") if $status eq 'scheduled';
  if ($status ne 'scheduled' && $status ne 'blocked') {
    BSSched::BuildJob::purgejob($gctx, $job);
  }
  return ($status, $error);
}

=head2 build - start a new build

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my ($jobxml, $reprojobid, $job, $jobprefix, $docompare) = @$data;
  return build_docompare($self, $ctx, $packid, $pdata, $info, $data) if $docompare;
  my $gctx = $ctx->{'gctx'};
  my $binfo = BSUtil::fromxml($jobxml, $BSXML::buildinfo, 1);
  if (!$binfo) {
    return ('broken', 'could not parse job');
  }
  if ($binfo->{'reprojobid'} || $binfo->{'repository'} ne $ctx->{'isreprorepo'}) {
    return ('broken', 'internal repro error');
  }
  $binfo->{'reprorepoid'} = $binfo->{'repository'};
  $binfo->{'repository'} = $ctx->{'repository'};
  $binfo->{'reprojobid'} = $reprojobid;
  $binfo->{'nouseforbuild'} = 1;
  $binfo->{'nounchanged'} = 1;
  $binfo->{'job'} = $job;
  BSSched::BuildJob::kill_otherjobs($ctx, $jobprefix);
  my $myjobsdir = $gctx->{'myjobsdir'};
  if ($myjobsdir) {
    my $dst = "$ctx->{'gdst'}/$binfo->{'package'}";
    mkdir_p($dst);
    my $now = $binfo->{'readytime'};
    writexml("$dst/.status", "$dst/status", { 'status' => 'scheduled', 'readytime' => $now, 'job' => $job}, $BSXML::buildstatus);
    my $reason = {'explain' => 'new build'};
    $reason->{'time'} = $now;
    writexml("$dst/.reason", "$dst/reason", $reason, $BSXML::buildreason);
    writexml("$myjobsdir/.$job", "$myjobsdir/$job", $binfo, $BSXML::buildinfo);
    BSSched::BuildJob::add_crossmarker($gctx, $binfo->{'hostarch'}, $job) if $binfo->{'hostarch'};
  }
  return ('scheduled', $job);
}

=head2 jobfinished - reproducible job finished event handler

 TODO

=cut

sub jobfinished {
  my ($ectx, $job, $info, $js) = @_;

  my $gctx = $ectx->{'gctx'};
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $jobdatadir = "$myjobsdir/$job:dir";
  if (! -d $jobdatadir) {
    print "  - $job has no data dir\n";
    return;
  }

  my $reprorepoid = $info->{'reprorepoid'};
  my $reprojobid = $info->{'reprojobid'};
  if (!$reprorepoid || !$reprojobid) {
    print "  - $job is not a repro job\n";
    return;
  }

  my $myarch = $gctx->{'arch'};
  my $changed = $gctx->{'changed_med'};

  my $projid = $info->{'project'};
  my $repoid = $info->{'repository'};
  my $packid = $info->{'package'};
  my $prp = "$projid/$repoid";
  my $origprp = "$projid/$reprorepoid";

  # this is tricky, guess the name of the original job
  my $origjob = BSSched::BuildJob::jobname($origprp, $packid)."-$info->{'srcmd5'}";
  if (-s "$myjobsdir/$origjob") {
    # still building, wait until finished
    print "  - $job: repro target is still building\n";
    #writexml("$myjobsdir/.$job:status", "$myjobsdir/$job:status", $js, $BSXML::jobstatus);
    BSUtil::touch("$jobdatadir/.isfinished");
    $info->{'job_is_waiting'} = 1;
    return;
  }
  unlink("$jobdatadir/.isfinished");

  my $reporoot = $gctx->{'reporoot'};
  my $gdst = "$reporoot/$prp/$myarch";
  my $dst = "$gdst/$packid";

  my $now = time(); # ensure that we use the same time in all logs
  my $projpacks = $gctx->{'projpacks'};
  if (!$projpacks->{$projid}) {
    print "  - $job belongs to an unknown project ($projid/$packid)\n";
    return;
  }
  my $pdata = ($projpacks->{$projid}->{'package'} || {})->{$packid};
  if (!$pdata) {
    print "  - $job belongs to an unknown package ($projid/$packid)\n";
    return;
  }
  my $status = readxml("$dst/status", $BSXML::buildstatus, 1);
  if ($status && (!$status->{'job'} || $status->{'job'} ne $job)) {
    print "  - $job is outdated\n";
    return;
  }

  my $code = $js->{'result'};
  $code = 'failed' unless $code eq 'succeeded';

  my $jobxml = readstr("$dst/.reprojob", 1) || '';
  if (!$jobxml || Digest::MD5::md5_hex($jobxml) ne $info->{'reprojobid'}) {
    print "$job: repro job is obsolete\n";
    $changed->{$prp} ||= 1;
    BSSched::BuildJob::patchpackstatus($gctx, $prp, $packid, $code, $job);
    $info->{'packstatus_patched'} = 1; 
    return;
  }

  my $origdst = "$reporoot/$projid/$reprorepoid/$myarch/$packid";
  my $statistics  = readxml("$origdst/_statistics", $BSXML::buildstatistics, 1) || {};
  if ((($statistics->{'info'} || {})->{'jobid'} || '') ne $reprojobid) {
    print "$job: repro job does not match target build result\n";
    unlink("$dst/status");	# what else can we do?
    if (-s "$dst/.reprojob.success") {
      rename("$dst/.reprojob.success", "$dst/.reprojob") || die("rename $dst/.reprojob.success $dst/.reprojob: $!\n");
    } else {
      unlink("$dst/.reprojob");	# what else can we do?
    }
    $changed->{$prp} ||= 1;
    # update packstatus so that it doesn't fall back to scheduled
    BSSched::BuildJob::patchpackstatus($gctx, $prp, $packid, $code, $job);
    $info->{'packstatus_patched'} = 1; 
    return;
  }

  if ($code eq 'succeeded' && $info->{'file'} ne '_reproduciblecheck') {
    # prepare followup job. unfortunatelly this must be done by the checker
    BSUtil::touch("$jobdatadir/.needcompare");
    unlink("$jobdatadir/.isfinished");	# just in case
    unlink("$jobdatadir/meta");		# we do not need it
    unlink("$jobdatadir/.bininfo");	# we do not need it
    for my $file (ls($jobdatadir)) {
      next if $file eq 'logfile' || $file eq '_statistics' || $file eq '.needcompare';
      rename("$jobdatadir/$file", "$jobdatadir/b_$file");
    }
    for my $file (ls($origdst)) {
      next if $file eq 'logfile' || $file eq '_statistics' || $file eq 'meta' || $file eq 'status' || $file =~ /^\./;
      next if $file eq 'history' || $file eq 'reason' || $file eq 'rpmlint.log';
      next if $file =~ /^::import/;
      BSUtil::cp("$origdst/$file", "$jobdatadir/a_$file");
    }
    $changed->{$prp} ||= 1;
    $info->{'job_is_waiting'} = 1;	# keep job
    return;
  }

  $status ||= {'readytime' => $info->{'readytime'} || $info->{'starttime'}};
  # calculate exponential weighted average
  my $myjobtime = time() - $status->{'readytime'};
  BSSched::BuildJob::update_buildavg($gctx, $myjobtime);

  delete $status->{'job'};      # no longer building
  delete $status->{'arch'};     # obsolete
  delete $status->{'uri'};      # obsolete

  mkdir_p($dst);
  mkdir_p("$gdst/:meta");
  mkdir_p("$gdst/:logfiles.fail");
  mkdir_p("$gdst/:logfiles.success");
  unlink("$gdst/:repodone");

  # write meta file
  my $meta = "$jobdatadir/meta";
  writestr($meta, undef, "$reprojobid  $packid\n");

  my $checkresult;
  if ($code eq 'succeeded') {
    my $checklog = "$jobdatadir/reproduciblecheck.log";
    if (-e $checklog) {
      my $fd;
      my $log = "\n";
      if (open($fd, '<', $checklog)) {
	sysseek($fd, -4096, 2);
	sysread($fd, $log, 4096, 1);
	close($fd);
      }
      $checkresult = uc($1) if $log =~ /\nResult:\s+(\S+)/;
    }
    if (!defined($checkresult)) {
      BSUtil::appendstr("$jobdatadir/logfile", "\nERROR: could not parse reproduciblecheck.log\n");
      $code = 'failed';
    }
  }
  
  # update packstatus so that it doesn't fall back to scheduled
  BSSched::BuildJob::patchpackstatus($gctx, $prp, $packid, $code, $job);
  $info->{'packstatus_patched'} = 1; 

  if ($code ne 'succeeded') {
    print "  - $job: build failed\n";
    link("$jobdatadir/logfile", "$jobdatadir/logfile.dup");
    rename("$jobdatadir/logfile", "$dst/logfile");
    rename("$jobdatadir/logfile.dup", "$gdst/:logfiles.fail/$packid");
    rename($meta, "$gdst/:meta/$packid");
    $status->{'status'} = 'failed';
    my $jobhist = BSSched::BuildJob::makejobhist($info, $status, $js, 'failed');
    BSSched::BuildJob::addjobhist($gctx, $prp, $jobhist);
    writexml("$dst/.status", "$dst/status", $status, $BSXML::buildstatus);
    $changed->{$prp} ||= 1;
    return;
  }

  # ok, integrate this result
  print "  - $prp: $packid built\n";

  BSUtil::touch("$jobdatadir/.nouseforbuild");
  unlink("$jobdatadir/.preinstallimage");

  my $jobhist = BSSched::BuildJob::makejobhist($info, $status, $js, 'succeeded');
  BSSched::BuildJob::addbuildstats($jobdatadir, $dst, $jobhist) if -e "$jobdatadir/_statistics";

  # save reproduciblecheck.log if not PASS
  if ($checkresult ne 'PASS') {
    mkdir_p("$gdst/:reproduciblecheck.fail");
    unlink("$jobdatadir/reproduciblecheck.dup");
    link("$jobdatadir/reproduciblecheck.log", "$jobdatadir/reproduciblecheck.dup");
    rename("$jobdatadir/reproduciblecheck.dup", "$gdst/:reproduciblecheck.fail/$packid");
  } else {
    unlink("$gdst/:reproduciblecheck.fail/$packid");
  }

  # update build result directory and full tree
  my $dstcache = $ectx->{'dstcache'};
  BSSched::BuildResult::update_dst_full($gctx, $prp, $packid, $jobdatadir, $meta, $dstcache);
  # restore the .reprojob
  writestr("$dst/.reprojob.new", "$dst/.reprojob", $jobxml);
  $changed->{$prp} ||= 1;

  # save meta file
  rename($meta, "$gdst/:meta/$packid");

  # write new status
  $status->{'status'} = 'succeeded';
  BSSched::BuildJob::addjobhist($gctx, $prp, $jobhist);
  writexml("$dst/.status", "$dst/status", $status, $BSXML::buildstatus);

  # write history file
  my $duration = 0;
  $duration = $js->{'endtime'} - $js->{'starttime'} if $js->{'endtime'} && $js->{'starttime'};
  BSSched::BuildJob::addsucceededhist($dst, $info, $now, $duration);

  # save logfile
  link("$jobdatadir/logfile", "$jobdatadir/logfile.dup");
  rename("$jobdatadir/logfile", "$dst/logfile");
  rename("$jobdatadir/logfile.dup", "$gdst/:logfiles.success/$packid");
  unlink("$gdst/:logfiles.fail/$packid");
}

1;

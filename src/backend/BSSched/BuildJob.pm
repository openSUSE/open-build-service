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
#   dstcache

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
use BSRedisnotify;

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
  my ($gctx, $prp, $job) = @_;

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
  BSRedisnotify::updatejobstatus("$prp/$gctx->{'arch'}", $job) if $BSConfig::redisserver;
  purgejob($gctx, $job);
  close(F);
}


=head2  killscheduled - kill a single build job if it is scheduled but not building

 input: $job - job identificator

=cut

sub killscheduled {
  my ($gctx, $prp, $job) = @_;

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
    killjob($gctx, $prp, $job);
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
	killjob($gctx, $prp, $job);
      } elsif ($status eq 'blocked' || $status eq 'unresolvable' || $status eq 'broken') {
	# blocked jobs get removed, if they are currently not building. building jobs
	# stay since they may become valid again
	killscheduled($gctx, $prp, $job);
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
  $binfo->{'genmetaalgo'} = $ctx->{'genmetaalgo'} if $ctx->{'genmetaalgo'};
  $binfo->{'forcebinaryidmeta'} = $ctx->{'forcebinaryidmeta'} if $ctx->{'forcebinaryidmeta'};

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

sub set_genbuildreqs {
  my ($gctx, $prp, $packid, $file, $verifymd5) = @_;
  my $myarch = $gctx->{'arch'};
  my $reporoot = $gctx->{'reporoot'};
  my $gdst = "$reporoot/$prp/$myarch";
  my $filecontent = $file ? readstr($file, 1) : undef;
  my $genbuildreqs = $gctx->{'genbuildreqs'}->{$prp};
  if (!$genbuildreqs && -e "$gdst/:genbuildreqs") {
    $genbuildreqs = BSUtil::retrieve("$gdst/:genbuildreqs", 1) || {};
    $gctx->{'genbuildreqs'}->{$prp} = $genbuildreqs if %$genbuildreqs;
  }
  if (defined $filecontent) {
    my $md5 = Digest::MD5::md5_hex($filecontent);
    return if $genbuildreqs && ($genbuildreqs->{$packid} || [''])->[0] eq $md5 && (($genbuildreqs->{$packid} || [])->[2] || '') eq ($verifymd5 || '');
    $genbuildreqs = $gctx->{'genbuildreqs'}->{$prp} = {} unless $genbuildreqs;
    $genbuildreqs->{$packid} = [ $md5, [ split("\n", $filecontent) ], $verifymd5 ];
  } else {
    return if !$genbuildreqs || !delete($genbuildreqs->{$packid});
    delete($gctx->{'genbuildreqs'}->{$prp}) if !%$genbuildreqs;
  }
  if (%{$genbuildreqs || {}}) {
    mkdir_p($gdst);
    BSUtil::store("$gdst/.:genbuildreqs", "$gdst/:genbuildreqs", $genbuildreqs);
  } else {
    unlink("$gdst/:genbuildreqs");
  }
}


=head2 flat_hash - utility function

  my $a = {'accesslevels1' => {
                  'content1' => 'val1',
                  'content2' => 'val2',
                  'accesslevels2' => {
                      'content1' => 'val1',
                      'content2' => 'val2'
                  },

      },
  };

  my $x = flat_hash($a);
  print Dumper($x);

  $VAR1 = {
            'accesslevels1_accesslevels2_content2' => 'val2',
            'accesslevels1_content1' => 'val1',
            'accesslevels1_content2' => 'val2',
            'accesslevels1_accesslevels2_content1' => 'val1'
          };


=cut

sub flat_hash {
  my ($hsh, $key, $ret) = @_;
  $ret ||= {};
  $key = defined($key) && $key ne '' ? $key.'_' : '';
  for my $k (keys %$hsh){
    if (ref($hsh->{$k}) eq 'HASH') {
      flat_hash($hsh->{$k}, $key.$k, $ret);
    } else {
      $ret->{$key.$k} = $hsh->{$k};
    }
  }
  return $ret;
}


=head2 jobfinished - called when a build job is finished

 - move artifacts into built result dir
 - move built binaries into :full tree
 - set changed flag

 input: $job       - job identification
        $js        - job status information (BSXML::jobstatus)
        $changed   - reference to changed hash, mark prp if
                     we changed the repository
        $dstcache  - store data for delayed writing of :full.solv/bininfo

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
  # dispatch to specialized versions for aggregates and deltas
  if ($info->{'file'} eq '_aggregate') {
    BSSched::BuildJob::Aggregate::jobfinished($ectx, $job, $info, $js);
    return ;
  }
  if ($info->{'file'} eq '_delta') {
    BSSched::BuildJob::DeltaRpm::jobfinished($ectx, $job, $info, $js);
    return ;
  }

  my $myarch = $gctx->{'arch'};
  my $changed = $gctx->{'changed_med'};

  my $projid = $info->{'project'};
  my $repoid = $info->{'repository'};
  my $packid = $info->{'package'};
  my $prp = "$projid/$repoid";

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
  $code = 'failed' unless $code eq 'succeeded' || $code eq 'unchanged' || $code eq 'genbuildreqs';

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
  patchpackstatus($gctx, $prp, $packid, $code, $job);
  $info->{'packstatus_patched'} = 1;

  my $meta = $all{'meta'} ? "$jobdatadir/meta" : undef;
  if ($code eq 'unchanged') {
    print "  - $job: build result is unchanged\n";
    if ( -e "$gdst/:logfiles.success/$packid" ){
      # make sure to use the last succeeded logfile matching to these binaries
      link("$gdst/:logfiles.success/$packid", "$dst/logfile.dup");
      rename("$dst/logfile.dup", "$dst/logfile");
      unlink("$dst/logfile.dup");
    }
    # Add a comment to logfile from last real build
    BSUtil::appendstr("$dst/logfile", "\nRetried build at ".localtime(time())." returned same result, skipped\n");
    my $jobhist = makejobhist($info, $status, $js, 'unchanged');
    addbuildstats($jobdatadir, $dst, $jobhist) if $all{'_statistics'};

    my $ccachetar = "$jobdatadir/_ccache.tar";
    my $occachetar = "$dst/_ccache.tar";
    rename($ccachetar, $occachetar) if $all{'_ccache.tar'} && !-e $occachetar;

    unlink("$gdst/:logfiles.fail/$packid");
    rename($meta, "$gdst/:meta/$packid") if $meta;
    unlink($_) for @all;
    rmdir($jobdatadir);
    addjobhist($gctx, $prp, $jobhist);
    $status->{'status'} = 'succeeded';
    writexml("$dst/.status", "$dst/status", $status, $BSXML::buildstatus);
    $changed->{$prp} ||= 1;     # package is no longer blocking
    # update the .nouseforbuild status if it changed
    my $oldnouseforbuild = -e "$dst/.nouseforbuild" ? 1 : 0;
    if ($oldnouseforbuild != ($info->{'nouseforbuild'} ? 1 : 0)) {
      print "updateing nouseforbuild flag\n";
      unlink("$dst/.nouseforbuild");
      BSUtil::touch("$dst/.nouseforbuild") if $info->{'nouseforbuild'};
      my $dstcache = $ectx->{'dstcache'};
      # recreate bininfo to pick up the change
      unlink("$dst/.bininfo");
      my $bininfo = read_bininfo($dst, 1);
      BSSched::BuildResult::update_bininfo_merge($gdst, $packid, $bininfo, $dstcache);
      # integrate into :full
      BSSched::BuildRepo::checkuseforbuild($gctx, $prp, $dstcache);
      $changed->{$prp} = 2;
      delete $gctx->{'repounchanged'}->{$prp};
    }
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
    my $jobhist = makejobhist($info, $status, $js, 'failed');
    addjobhist($gctx, $prp, $jobhist);
    writexml("$dst/.status", "$dst/status", $status, $BSXML::buildstatus);
    $changed->{$prp} ||= 1;     # package is no longer blocking
    return;
  }
  if ($code eq 'genbuildreqs') {
    print "  - $job: build has different generated build requires\n";
    my $verifymd5 = $info->{'verifymd5'} || $info->{'srcmd5'};
    set_genbuildreqs($gctx, $prp, $packid, "$jobdatadir/_generated_buildreqs", $verifymd5);
    unlink($_) for @all;
    rmdir($jobdatadir);
    $changed->{$prp} ||= 1;     # package is no longer blocking
    return;
  }
  print "  - $prp: $packid built: ".(@all). " files\n";
  mkdir_p("$gdst/:logfiles.success");
  mkdir_p("$gdst/:logfiles.fail");

  unlink("$jobdatadir/.nouseforbuild");
  BSUtil::touch("$jobdatadir/.nouseforbuild") if $info->{'nouseforbuild'};
  unlink("$jobdatadir/.preinstallimage");
  BSUtil::touch("$jobdatadir/.preinstallimage") if $info->{'file'} eq '_preinstallimage';
  my $jobhist = makejobhist($info, $status, $js, 'succeeded');
  addbuildstats($jobdatadir, $dst, $jobhist) if ($all{'_statistics'});

  # update build result directory and full tree
  my $dstcache = $ectx->{'dstcache'};
  my $changed_full = BSSched::BuildResult::update_dst_full($gctx, $prp, $packid, $jobdatadir, $meta, $dstcache);
  $changed->{$prp} ||= 1;
  $changed->{$prp} = 2 if $changed_full;
  my $repounchanged = $gctx->{'repounchanged'};
  delete $repounchanged->{$prp} if $changed_full;
  $repounchanged->{$prp} = 2 if $repounchanged->{$prp};

  # save meta file
  rename($meta, "$gdst/:meta/$packid") if $meta;

  # write new status
  $status->{'status'} = 'succeeded';
  addjobhist($gctx, $prp, $jobhist);
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
    'code' => $needsign ? 'signing' : 'finished',
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
    my $evname = "finished:$myarch:$job";
    $evname = "finished:::".Digest::MD5::md5_hex($evname) if length($evname) > 240;
    $ev->{'time'} = time();
    BSSched::EventSource::Directory::sendevent($gctx, $ev, 'signer', $evname);
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
    BSSched::BuildResult::update_bininfo_merge($gdst, $packid, $bininfo);
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
  my ($gctx, $prp, $packid, $code, $job) = @_;

  my $reporoot = $gctx->{'reporoot'};
  my $myarch = $gctx->{'arch'};
  my $gdst = "$reporoot/$prp/$myarch";
  $code ||= 'unknown';
  BSUtil::appendstr("$gdst/:packstatus.finished", "$code $packid\n");
  # touch mtime to make watchers see a change
  utime(time, time, "$gdst/:packstatus");
  BSRedisnotify::updateoneresult("$prp/$myarch", $packid, "finished:$code", $job) if $BSConfig::redisserver;
}


sub addbuildstats {
  my ($jobdatadir, $dst, $jobhist) = @_;
  my $bstat = readxml("$jobdatadir/_statistics", $BSXML::buildstatistics, 1) || {};
  my $data = flat_hash({ 'stats' => $jobhist, 'stats_buildstatistics' => $bstat });
  BSFileDB::fdb_add("$dst/.stats", $BSXML::buildstatslay, $data);
}

=head2 makejobhist - return jobhistlay comaptible hash

 The returned hash can be reused.

=cut

sub makejobhist {
  my ($info, $status, $js, $code) = @_;
  my $jobhist = {};
  $jobhist->{'code'} = $code;
  $jobhist->{$_} = $js->{$_} for qw{readytime starttime endtime uri workerid hostarch};
  $jobhist->{$_} = $info->{$_} for qw{package rev srcmd5 versrel bcnt reason};
  $jobhist->{'verifymd5'} = $info->{'verifymd5'} if $info->{'verifymd5'};
  $jobhist->{'readytime'} ||= $status->{'readytime'};   # backward compat
  return $jobhist
}

=head2 addjobhist - add a new job entry to :jobhistory file

 TODO: add description

=cut

sub addjobhist {
  my ($gctx, $prp, $jobhist ) = @_;
  my $myarch = $gctx->{'arch'};
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  mkdir_p($gdst);
  BSFileDB::fdb_add("$gdst/:jobhistory", $BSXML::jobhistlay, $jobhist);
  my $dst = "$gdst/$jobhist->{'package'}";
  if ($jobhist->{'code'} eq 'failed') {
    mkdir_p($dst);
    BSFileDB::fdb_add_i("$dst/.failhistory", [ 'failcount', @$BSXML::jobhistlay ] , { %$jobhist });
  } else {
    unlink("$dst/.failhistory");
  }
}


=head2 nextbcnt - calculate the build counter for the next build

 TODO: add description

=cut

sub nextbcnt {
  my ($ctx, $packid, $pdata, $info) = @_;

  return undef unless defined $packid;
  return 1 unless exists $pdata->{'versrel'};
  my $h;
  my $gdst = $ctx->{'gdst'};
  my $relsyncmax = $ctx->{'relsyncmax'};
  my $dst = "$gdst/$packid";
  if (-e "$dst/history") {
    $h = BSFileDB::fdb_getmatch("$dst/history", $historylay, 'versrel', $pdata->{'versrel'}, 1);
  }
  $h = {'bcnt' => 0} unless $h;

  # max with sync data
  my $tag = $pdata->{'bcntsynctag'} || ($info || {})->{'bcntsynctag'} || $packid;
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
  my ($ctx, $packid, $pdata, $info, $buildtype, $subpacks) = @_;

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
  $binfo->{'crossarch'} = $bconf->{'hostarch'} if $bconf->{'hostarch'} && $ctx->{'conf_host'};
  $binfo->{'module'} = $bconf->{'modules'} if $bconf->{'modules'};
  my $obsname = $gctx->{'obsname'};
  $binfo->{'disturl'} = "obs://$obsname/$projid/$repoid/$pdata->{'srcmd5'}-$packid" if defined($obsname) && defined($packid);
  $binfo->{'vcs'} = $pdata->{'scmsync'} if $pdata->{'scmsync'};

  # no release/debuginfo for patchinfo and deltarpm builds
  return $binfo if $buildtype eq 'patchinfo' || $buildtype eq 'deltarpm';

  if (defined($packid) && exists($pdata->{'versrel'})) {
    $binfo->{'versrel'} = $pdata->{'versrel'};
    # find the last build count we used for this version/release
    my $bcnt = nextbcnt($ctx, $packid, $pdata, $info);
    $binfo->{'bcnt'} = $bcnt;
    my $release = $pdata->{'versrel'};
    $release = '0' unless defined $release;
    $release =~ s/.*-//;
    if (exists($bconf->{'release'})) {
      my $bconfrelease = $bconf->{'release'};
      if (@{$bconf->{'release@'} || []} > 1) {
	my @bconfrelease = @{$bconf->{'release@'}};
	$bconfrelease = shift @bconfrelease;
	for (@bconfrelease) {
	  $bconfrelease = $1 if /^\Q$buildtype\E:(.*)/;
	}
      }
      if (defined($bconfrelease)) {
	$binfo->{'release'} = $bconfrelease;
	$binfo->{'release'} =~ s/\<CI_CNT\>/$release/g;
	$binfo->{'release'} =~ s/\<B_CNT\>/$bcnt/g;
      }
    }
    $binfo->{'release'} = "$release.$bcnt" if $ctx->{'dobuildinfo'} && !defined($binfo->{'release'});
  }
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid};
  my $debuginfo = $bconf->{'debuginfo'};
  $debuginfo = BSUtil::enabled($repoid, $proj->{'debuginfo'}, $debuginfo, $myarch);
  $debuginfo = BSUtil::enabled($repoid, $pdata->{'debuginfo'}, $debuginfo, $myarch);
  $binfo->{'debuginfo'} = 1 if $debuginfo;
  if ($ctx->{'modularity_label'}) {
    my $distindex = $ctx->{'modularity_distindex'} || $binfo->{'bcnt'} || 1;
    $binfo->{'modularity_package'} = $ctx->{'modularity_package'};
    $binfo->{'modularity_srcmd5'} = $ctx->{'modularity_srcmd5'};
    $binfo->{'modularity_meta'} = $ctx->{'modularity_meta'};
    $binfo->{'modularity_platform'} = $ctx->{'modularity_platform'};
    $binfo->{'modularity_label'} = $ctx->{'modularity_label'};
    $binfo->{'modularity_macros'} = BSSched::Modulemd::calc_macros($bconf, $ctx->{'modularity_label'}, $distindex, $ctx->{'modularity_extramacros'});
  }
  return $binfo;
}

=head2 add_expanddebug - add debug data from the expander

 input:  $ctx           - prp context
         $type          - expandsion type information 
         $xp            - expander (optional)

=cut

sub add_expanddebug {
  my ($ctx, $type, $xp, $pool) = @_;
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
  $$expanddebug .= "path: ".join(' ', map {$_->name()} $pool->repos())."\n" if $pool;
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
  my $verifymd5 = $pdata->{'verifymd5'} || $srcmd5;
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
  if ($buildtype eq 'kiwi') {	# split kiwi buildtype into kiwi-image and kiwi-product
    $buildtype = $info->{'imagetype'} && $info->{'imagetype'}->[0] eq 'product' ? 'kiwi-product' : 'kiwi-image';
  }

  my $kiwimode;
  $kiwimode = $buildtype if $buildtype eq 'kiwi-image' || $buildtype eq 'kiwi-product' || $buildtype eq 'docker' || $buildtype eq 'fissile' || $buildtype eq 'productcompose';
  my $ccache;

  my $syspath;
  my $searchpath = path2buildinfopath($gctx, $ctx->{'prpsearchpath'});
  $syspath = path2buildinfopath($gctx, $ctx->{'prpsearchpath_host'}) if $ctx->{'crossmode'};
  if ($kiwimode) {
    # switch searchpath to kiwi info path
    $syspath = $searchpath if @$searchpath && !$ctx->{'crossmode'};
    $searchpath = path2buildinfopath($gctx, [ expandkiwipath($ctx, $info) ]);
  }

  my $expanddebug = $ctx->{'expanddebug'};

  # calculate build time service debs
  my @btdeps;
  if ($info->{'buildtimeservice'}) {
    for my $service (@{$info->{'buildtimeservice'} || []}) {
      if ($bconf->{'substitute'}->{"obs-service:$service"}) {
	push @btdeps, @{$bconf->{'substitute'}->{"obs-service:$service"}};
      } else {
	my $pkgname = "obs-service-$service";
	$pkgname =~ s/_/-/g if $bconf->{'binarytype'} eq 'deb';
	push @btdeps, $pkgname;
      }
    }
    @btdeps = BSUtil::unify(@btdeps);
  }

  # calculate sysdeps
  my @sysdeps = @btdeps;
  push @sysdeps, @{$ctx->{'extradeps'} || []} if $kiwimode;
  if ($buildtype eq 'kiwi-image' || $buildtype eq 'kiwi-product') {
    unshift @sysdeps, grep {/^kiwi-.*:/} @{$info->{'dep'} || []};
  }
  if (@sysdeps) {
    @sysdeps = Build::get_sysbuild($bconf, $buildtype, [ @sysdeps ]);	# cannot cache...
  } else {
    $ctx->{"sysbuild_$buildtype"} ||= [ Build::get_sysbuild($bconf, $buildtype) ];
    @sysdeps = @{$ctx->{"sysbuild_$buildtype"}};
  }
  add_expanddebug($ctx, 'sysdeps expansion', undef, $ctx->{'pool'}) if $expanddebug && @sysdeps;
  @btdeps = () if @sysdeps;	# already included in sysdeps

  # calculate packages needed for building
  my $genbuildreqs = ($ctx->{'genbuildreqs'} || {})->{$packid};
  undef $genbuildreqs if $genbuildreqs && $genbuildreqs->[2] && $genbuildreqs->[2] ne $verifymd5;
  my @bdeps = grep {!/^\// || $bconf->{'fileprovides'}->{$_}} @{$info->{'prereq'} || []};
  unshift @bdeps, '--directdepsend--' if @bdeps;
  unshift @bdeps, @{$genbuildreqs->[1]} if $genbuildreqs;
  unshift @bdeps, @{$info->{'dep'} || []}, @btdeps, @{$ctx->{'extradeps'} || []};
  push @bdeps, '--ignoreignore--' if @sysdeps || $buildtype eq 'simpleimage';
  # enable ccache support if requested
  if ($buildtype eq 'arch' || $buildtype eq 'spec' || $buildtype eq 'dsc') {
    my @enable_ccache = grep {/^--enable-ccache/} Build::do_subst($bconf, @{$info->{'dep'} || []});
    if (@enable_ccache) {
      $ccache = $bconf->{'buildflags:ccachetype'} || 'ccache';
      $ccache = $1 if $enable_ccache[0] =~ /--enable-ccache=(.+)$/;
    } elsif ($packid && exists($bconf->{'buildflags:useccache'})) {
      my $opackid = $packid;
      $opackid = $pdata->{'releasename'} if $pdata->{'releasename'};
      if (grep {$_ eq "useccache:$opackid" || $_ eq "useccache:$packid"} @{$bconf->{'buildflags'} || []}) {
        $ccache = $bconf->{'buildflags:ccachetype'} || 'ccache';
      }
    }
    push @bdeps, @{$bconf->{'substitute'}->{"build-packages:$ccache"} || [ $ccache ] } if $ccache;
  }

  if ($kiwimode || $buildtype eq 'buildenv') {
    @bdeps = (1, @$edeps);      # reuse edeps packages, no need to expand again
  } else {
    @bdeps = Build::get_build($bconf, $subpacks, @bdeps);
    add_expanddebug($ctx, 'build expansion', undef, $ctx->{'pool'}) if $expanddebug;
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
  if (!$ctx->{'isreposerver'}) {
    my $dods;
    my $arch = $bconf->{'hostarch'} && $ctx->{'conf_host'} ? $bconf->{'hostarch'} : $myarch;
    if ($kiwimode) {
      # image packages are already checked (they come from a different pool anyway)
      $dods = BSSched::DoD::dodcheck($ctx, $pool, $arch, @pdeps, @vmdeps, @sysdeps);
    } else {
      $dods = BSSched::DoD::dodcheck($ctx, $pool, $arch, @pdeps, @vmdeps, @bdeps, @sysdeps);
    }
    if ($dods) {
      print "        blocked: $dods\n" if $ctx->{'verbose'};
      return ('blocked', $dods);
    }
  }

  # make sure we have the preinstalls and vminstalls
  my @missing = grep {!$ctx->{'dep2pkg'}->{$_}} (@pdeps, @vmdeps);
  if (@missing) {
    my $missing = join(', ', sort(BSUtil::unify(@missing)));
    print "        missing pre/vminstalls: $missing\n" if $ctx->{'verbose'};
    return ('unresolvable', "missing pre/vminstalls: $missing");
  }

  # kill those ancient other jobs
  if ($myjobsdir) {
    my @otherjobs = find_otherjobs($ctx, $jobprefix);
    for my $otherjob (@otherjobs) {
      print "        killing old job $otherjob\n" if $ctx->{'verbose'};
      killjob($gctx, $prp, $otherjob);
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
        $_->{'hdrmd5'}     = $d->{'hdrmd5'} if $d->{'hdrmd5'};
        $_->{'preimghdrmd5'} = $d->{'hdrmd5'} if !$_->{'noinstall'} && $d->{'hdrmd5'};
	$_->{'repoarch'}   = $BSConfig::localarch if $myarch eq 'local' && $BSConfig::localarch;
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
  my $binfo = create_jobdata($ctx, $packid, $pdata, $info, $buildtype, $subpacks);
  $binfo->{'bdep'} = \@bdeps;
  $binfo->{'path'} = $searchpath;
  $binfo->{'syspath'} = $syspath if $syspath;
  $binfo->{'containerpath'} = path2buildinfopath($gctx, $ctx->{'containerpath'}) if $ctx->{'containerpath'};
  $binfo->{'containerannotation'} = $ctx->{'containerannotation'} if $ctx->{'containerannotation'};
  $binfo->{'needed'} = $needed;
  $binfo->{'constraintsmd5'} = $pdata->{'constraintsmd5'} if $pdata->{'constraintsmd5'};
  $binfo->{'prjconfconstraint'} = $bconf->{'constraint'} if @{$bconf->{'constraint'} || []};
  $binfo->{'nounchanged'} = 1 if $info->{'nounchanged'};
  $binfo->{'constraint'} = $info->{'constraint'} if $info->{'constraint'};
  $binfo->{'ccache'} = $ccache if $ccache;
  if (!$ctx->{'isreposerver'} && ($proj->{'kind'} || '') eq 'maintenance_incident' && $pdata->{'releasename'}) {
    $binfo->{'releasename'} = $pdata->{'releasename'};
  }
  if ($pdata->{'revtime'}) {
    $binfo->{'revtime'} = $pdata->{'revtime'};
    # use max of revtime for interproject links
    for (@{$pdata->{'linked'} || []}) {
      last if $_->{'project'} ne $projid || !$proj->{'package'};
      my $lpdata = $proj->{'package'}->{$_->{'package'}} || {};
      $binfo->{'revtime'} = $lpdata->{'revtime'} if ($lpdata->{'revtime'} || 0) > $binfo->{'revtime'};
    }
  }
  if (!$ctx->{'isreposerver'}) {
    $binfo->{'logidlelimit'} = $bconf->{'buildflags:logidlelimit'} if $bconf->{'buildflags:logidlelimit'};
    $binfo->{'genbuildreqs'} = $genbuildreqs->[0] if $genbuildreqs;
    if ($bconf->{'buildflags:obsgendiff'} && @{$ctx->{'repo'}->{'releasetarget'} || []}) {
       # use the first obsgendiff marked release target or the first with any trigger one as fallback
       my @gendifftargets = grep {$_->{'trigger'} && $_->{'trigger'} eq 'obsgendiff'} @{$ctx->{'repo'}->{'releasetarget'}};
       my $releasetarget = @gendifftargets ? $gendifftargets[0] : $ctx->{'repo'}->{'releasetarget'}->[0];

       $binfo->{'obsgendiff'} = { 'project' => $releasetarget->{'project'},
                                  'repository' => $releasetarget->{'repository'} };

    }
    $binfo->{'slsaprovenance'} = 1 if $BSConfig::slsaprovenance && grep { $prp =~ /^$_/} @$BSConfig::slsaprovenance;
    if ($binfo->{'slsaprovenance'}) {
      $binfo->{'slsabuilder'} = $BSConfig::api_url || "obs://".$BSConfig::obsname;
      if ($BSConfig::sourcepublish_downloadurl) {
	$binfo->{'slsadownloadurl'} = "$BSConfig::sourcepublish_downloadurl/_slsa";
      } elsif ($BSConfig::api_url) {
	$binfo->{'slsadownloadurl'} = $BSConfig::api_url;
      }
    }
    my $signflavor = $BSConfig::sign_flavor ? $bconf->{'buildflags:signflavor'} : undef;
    return ('broken', "illegal sign flavor '$signflavor'") if $signflavor && !grep {$_ eq $signflavor} @$BSConfig::sign_flavor;
    $binfo->{'signflavor'} = $signflavor if $signflavor;
    $binfo->{'nouseforbuild'} = 1 if $info->{'nouseforbuild'};
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
    if (($buildtype eq 'kiwi-image' || $buildtype eq 'kiwi-product' || $buildtype eq 'docker' || $buildtype eq 'productcompose') && $ctx->{'relsynctrigger'}->{$packid}) {
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
  if ($buildtype eq 'kiwi-image' || $buildtype eq 'kiwi-product' || $buildtype eq 'docker') {
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

=head2 createextrapool - create a pool of nonstandard repositories

 TODO: add description

=cut

sub createextrapool {
  my ($ctx, $bconf, $prps, $unorderedrepos, $prios, $arch) = @_;
  my $pool = eval { $ctx->newpool($bconf) };
  return (undef, 'extra pool creation failed') unless $pool;
  my $delayed = '';
  for my $prp (@{$prps || []}) {
    return (undef, "repository '$prp' is unavailable") if !$ctx->checkprpaccess($prp);
    my $r = $ctx->addrepo($pool, $prp, $arch);
    if (!$r) {
      my $error = "repository '$prp' is unavailable";
      return (undef, $error) unless defined $r;
      $delayed .= ", $error";
    }
  }
  return (undef, substr($delayed, 2), 1) if $delayed;
  if ($unorderedrepos) {
    return(undef, 'perl-BSSolv does not support unordered repos') unless defined &BSSolv::repo::setpriority;
    $_->setpriority($prios->{$_->name()} || 0) for $pool->repos();
    $pool->createwhatprovides(1);
  } else {
    $pool->createwhatprovides();
  }
  return $pool;
}

=head2 expandkiwipath - turn the path from the info into a kiwi searchpath

 TODO: add description

=cut

sub expandkiwipath {
  my ($ctx, $info, $prios) = @_;
  my @path;
  for (@{$info->{'path'} || []}) {
    if ($_->{'project'} eq '_obsrepositories') {
      push @path, @{$ctx->{'prpsearchpath'} || []}; 
      next;
    }
    my $prp = "$_->{'project'}/$_->{'repository'}";
    push @path, $prp;
    if ($prios) {
      my $prio = $_->{'priority'} || 0;
      $prios->{$prp} = $prio if !defined($prios->{$prp}) || $prio > $prios->{$prp};
    }
  }
  return BSUtil::unify(@path);
}

=head2 getcontainerannotation - get the annotation from a container package

 Also add annotation to container bdep if provided as argument.

=cut

sub getcontainerannotation {
  my ($pool, $p, $bdep) = @_;
  return undef unless $p;
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

=head2 add_container_deps - add container data to the context

 This adds the container bdeps as extrabdeps and sets the containerpath and
 containerannotation.

 We also strip out the package ids from the bdeps as side effect.

 Note that the context should be cloned before calling this so that the data does
 not leak.

=cut

sub add_container_deps {
  my ($ctx, $cbdeps) = @_;
  return unless @{$cbdeps || []};
  delete $_->{'p'} for @$cbdeps;	# strip package ids
  push @{$ctx->{'extrabdeps'}}, @$cbdeps;
  $ctx->{'containerpath'} = [ BSUtil::unify(map {"$_->{'project'}/$_->{'repository'}"} grep {$_->{'project'}} @$cbdeps) ];
  $ctx->{'containerannotation'} = delete $_->{'annotation'} for @$cbdeps;
}

1;


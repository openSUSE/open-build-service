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

package BSSched::BuildJob::DeltaRpm;

use strict;
use warnings;

use Digest::MD5 ();
use Build;
use Build::Rpm;

use BSUtil;
use BSSched::BuildJob;


=head1 NAME

BSSched::BuildJob::DeltaRpm - A Class to handle deltarpm builds

=head1 SYNOPSIS

my $h = BSSched::BuildJob::DeltaRpm->new()

$h->build();

=cut

=head2 new - TODO: add summary

 TODO: add description

=cut

sub new {
  return bless({}, $_[0]);
}

=head2 build - create a deltarpm job

 $data->[0] - jobsuffix to use
 $data->[1] - list of needed deltas, each delta is [ oldfile, newfile, deltaid ]

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;

  my ($suffix, $needdelta) = @$data;

  my $gctx = $ctx->{'gctx'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $myarch = $gctx->{'arch'};
  my $job = BSSched::BuildJob::jobname("$projid/$repoid", $packid);
  $job .= "-$suffix" if defined $suffix;
  my $myjobsdir = $gctx->{'myjobsdir'};
  if (-e "$myjobsdir/$job") {
    return (undef, 'building'); # delta creation already in progress
  }
  # invent some srcmd5
  my $srcmd5 = '';
  $srcmd5 .= $_->[2] for @$needdelta;
  $srcmd5 = Digest::MD5::md5_hex($srcmd5);
  my $jobdatadir = "$myjobsdir/$job:dir";
  mkdir_p($jobdatadir);
  BSUtil::cleandir($jobdatadir);
  return (undef, "could not create jobdir $jobdatadir") unless -d $jobdatadir;
  for my $delta (@$needdelta) {
    #print Dumper($delta);
    my $deltaid = $delta->[2];
    link($delta->[0], "$jobdatadir/$deltaid.old") || return (undef, "link $delta->[0] $jobdatadir/$deltaid.old: $!");
    link($delta->[1], "$jobdatadir/$deltaid.new") || return (undef, "link $delta->[1] $jobdatadir/$deltaid.new: $!");
    my $qold = Build::Rpm::query("$jobdatadir/$deltaid.old", 'evra' => 1);
    my $qnew = Build::Rpm::query("$jobdatadir/$deltaid.new", 'evra' => 1);
    return (undef, "bad rpms id $deltaid") unless $qold && $qnew;
    return (undef, "name/arch mismatch id $deltaid") if $qold->{'name'} ne $qnew->{'name'} || $qold->{'arch'} ne $qnew->{'arch'};
    $qold->{'epoch'} = '' unless defined $qold->{'epoch'};
    $qnew->{'epoch'} = '' unless defined $qnew->{'epoch'};
    my $info = '';
    $info .= ucfirst($_).": $qnew->{$_}\n" for qw{name epoch version release arch};
    $info .= "Old".ucfirst($_).": $qold->{$_}\n" for qw{name epoch version release arch};
    writestr("$jobdatadir/$deltaid.info", undef, $info);
  }
  # create job
  my $bconf = $ctx->{'conf'};
  my ($eok, @bdeps) = Build::get_build($bconf, [], "deltarpm");
  if (!$eok) {
    print "        unresolvable:\n";
    print "          $_\n" for @bdeps;
    return (undef, "unresolvable: ".join(', ', @bdeps));
  }
  my $now = time();
  my @pdeps = Build::get_preinstalls($bconf);
  my @vmdeps = Build::get_vminstalls($bconf);
  my %runscripts = map {$_ => 1} Build::get_runscripts($bconf);
  my %bdeps = map {$_ => 1} @bdeps;
  my %pdeps = map {$_ => 1} @pdeps;
  my %vmdeps = map {$_ => 1} @vmdeps;
  @bdeps = BSUtil::unify(@pdeps, @vmdeps, @bdeps);
  for (@bdeps) {
    $_ = {'name' => $_};
    $_->{'preinstall'} = 1 if $pdeps{$_->{'name'}};
    $_->{'vminstall'} = 1 if $vmdeps{$_->{'name'}};
    $_->{'runscripts'} = 1 if $runscripts{$_->{'name'}};
    $_->{'notmeta'} = 1;
  }
  my $searchpath = BSSched::BuildJob::path2buildinfopath($gctx, $ctx->{'prpsearchpath'});
  my $binfo = {
    'project' => $projid,
    'repository' => $repoid,
    'package' => $packid,
    'file' => '_delta',
    'srcmd5' => $srcmd5,
    'reason' => 'source change',
    'job' => $job,
    'arch' => $myarch,
    'readytime' => $now,
    'bdep' => \@bdeps,
    'path' => $searchpath,
    'needed' => 0,
  };
  my $obsname = $gctx->{'obsname'};
  $binfo->{'disturl'} = "obs://$obsname/$projid/$repoid/$srcmd5-$packid";
  $binfo->{'hostarch'} = $bconf->{'hostarch'} if $bconf->{'hostarch'};
  $binfo->{'prjconfconstraint'} = $bconf->{'constraint'} if @{$bconf->{'constraint'} || []};
  BSSched::BuildJob::writejob($ctx, $job, $binfo);
  print "    created deltajob...\n";
  return $job;
}


=head2 jobfinished - delta job finished event handler

 TODO

=cut

sub jobfinished {
  my ($ectx, $job, $info, $js) = @_;

  my $gctx = $ectx->{'gctx'};

  my $changed = $gctx->{'changed_med'};
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $myarch = $gctx->{'arch'};
  my $jobdatadir = "$myjobsdir/$job:dir";
  if (! -d $jobdatadir) {
    print "  - $job has no data dir\n";
    return;
  }
  my $projid = $info->{'project'};
  my $repoid = $info->{'repository'};
  my $packid = $info->{'package'};
  my $projpacks = $gctx->{'projpacks'};
  if (!$projpacks->{$projid}) {
    print "  - $job belongs to an unknown project\n";
    return;
  }
  my $prp = "$projid/$repoid";
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  my $dst = "$gdst/$packid";
  mkdir_p($dst);
  my $code = $js->{'result'} || 'failed';
  my $status = {'readytime' => $info->{'readytime'} || $info->{'starttime'}};
  my $jobhist = BSSched::BuildJob::makejobhist($info, $status, $js, $code);
  BSSched::BuildJob::addjobhist($gctx, $prp, $jobhist);
  if ($code ne 'succeeded') {
    print "  - $job: build failed\n";
    unlink("$dst/logfile");
    # keep the logfile so that users can see the errors
    rename("$jobdatadir/logfile", "$dst/logfile");
    $changed->{$prp} ||= 1;
    unlink("$gdst/:repodone");
    return;
  }
  my @all = sort(ls($jobdatadir));
  print "  - $prp: $packid built: ".(@all). " files\n";
  for my $f (@all) {
    next unless $f =~ /^(.*)\.(drpm|out|dseq)$/s;
    my $deltaid = $1;
    if ($2 ne 'dseq') {
      rename("$jobdatadir/$f", "$dst/$deltaid");
    } else {
      rename("$jobdatadir/$f", "$dst/$deltaid.dseq");
    }
  }
  $changed->{$prp} ||= 1;
  unlink("$gdst/:repodone");
  unlink("$dst/logfile");
  rename("$jobdatadir/logfile", "$dst/logfile");
}

1;

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

package BSSched::BuildJob::Import;

use strict;
use warnings;

use BSOBS;
use BSUtil;
use BSXML;
use BSSched::BuildResult;
use BSSched::EventSource::Directory; # for sendimportevent
my $exportcnt = 0;

my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

=head1 NAME

BSSched::BuildJob::Import - A Class to handle import jobs

=head1 SYNOPSIS

=cut

=head2 createexportjob - export binaries to another scheduler architecture

 $arch - target scheduler architecture

=cut

sub createexportjob {
  my ($gctx, $prp, $arch, $packid, $jobrepo, $dst, $oldrepo, $meta, @exports) = @_;

  my $myarch = $gctx->{'arch'};

  # create unique id
  my $now = time();
  # create prefix so that sorting by jobname creates the correct ordering
  my $prefix = sprintf("%08x-%08x-", $now, $exportcnt);
  my $job = "import-$prefix".Digest::MD5::md5_hex("$exportcnt.$$.$myarch.$now");
  $exportcnt++;

  local *F;
  my $jobstatus = {
    'code' => 'finished',
    'result' => 'succeeded',
  };
  my $ajobsdir = "$gctx->{'jobsdir'}/$arch";
  mkdir_p($ajobsdir) unless -d $ajobsdir;
  if (!BSUtil::lockcreatexml(\*F, "$ajobsdir/.$job", "$ajobsdir/$job:status", $jobstatus, $BSXML::jobstatus)) {
    print "job lock failed!\n";
    return;
  }

  my ($projid, $repoid) = split('/', $prp, 2);
  my $info = {
    'project' => $projid,
    'repository' => $repoid,
    'package' => ($packid || ':import'),
    'arch' => $myarch,	# use hostarch instead?
    'job' => $job,
  };
  writexml("$ajobsdir/.$job", "$ajobsdir/$job", $info, $BSXML::buildinfo);
  my $dir = "$ajobsdir/$job:dir";
  mkdir_p($dir);
  if ($meta) {
    link($meta, "$meta.dup");
    rename("$meta.dup", "$dir/meta");
    unlink("$meta.dup");
  }
  my %seen;
  while (@exports) {
    my ($rp, $r) = splice(@exports, 0, 2);
    next unless $r->{'source'};
    link("$dst/$rp", "$dir/$rp") || warn("link $dst/$rp $dir/$rp: $!\n");
    $seen{$r->{'id'}} = 1;
  }
  my @replaced;
  for my $rp (sort keys %$oldrepo) {
    my $r = $oldrepo->{$rp};
    next unless $r->{'source'};	# no src rpms in full tree
    next if $r->{'imported'};	# imported stuff never was re-exported
    next if $seen{$r->{'id'}};
    my $suf;
    $suf = $1 if $rp =~ /\.($binsufsre)$/;
    push @replaced, {'name' => "$r->{'name'}.$suf", 'id' => $r->{'id'}} if $suf;
  }
  if (@replaced) {
    writexml("$dir/replaced.xml", undef, {'name' => 'replaced', 'entry' => \@replaced}, $BSXML::dir);
  }
  # free the lock
  close F;
  # send event
  BSSched::EventSource::Directory::sendimportevent($gctx, $job, $arch);
}


=head2 jobfinished - process an import job

 TODO: add description

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
  my $importarch = $info->{'arch'} || 'unknown';
  my $prp = "$projid/$repoid";
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  my @all = ls($jobdatadir);
  my %all = map {$_ => 1} @all;
  my $meta = $all{'meta'} ? "$jobdatadir/meta" : undef;
  @all = map {"$jobdatadir/$_"} @all;
  my $pdata = ($projpacks->{$projid}->{'package'} || {})->{$packid} || {};
  print "  - $prp: $packid imported from $importarch\n";

  my $changed_full = BSSched::BuildResult::update_dst_full($gctx, $prp, $packid, $jobdatadir, $meta, undef, $importarch);
  $changed->{$prp} ||= 1;
  $changed->{$prp} = 2 if $changed_full;
  my $repounchanged = $gctx->{'repounchanged'};
  delete $repounchanged->{$prp} if $changed_full;
  $repounchanged->{$prp} = 2 if $repounchanged->{$prp};
  unlink("$gdst/:repodone");
}

1;

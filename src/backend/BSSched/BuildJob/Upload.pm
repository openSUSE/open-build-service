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

package BSSched::BuildJob::Upload;

use strict;
use warnings;

use BSUtil;
use BSSched::BuildResult;

=head1 NAME

BSSched::BuildJob::Upload - A Class to handle upload jobs

=head1 SYNOPSIS

=cut

=head2 jobfinished - process an upload job

 TODO: add description

=cut

sub jobfinished {
  my ($ectx, $job, $info, $js) = @_;

  my $gctx = $ectx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $changed = $gctx->{'changed_med'};
  my $myjobsdir = $gctx->{'myjobsdir'};
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
  my $pdata = ($projpacks->{$projid}->{'package'} || {})->{$packid};
  if (!$pdata) {
    print "  - $job belongs to an unknown package, discard\n";
    return;
  }
  my $prp = "$projid/$repoid";
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  my $dst = "$gdst/$packid";
  mkdir_p($dst);
  # find the meta for the successful build
  my $meta;
  $meta = "$jobdatadir/.meta.success" if -e "$jobdatadir/.meta.success";
  $meta = "$jobdatadir/meta" if !$meta && -e "$jobdatadir/meta";
  print "  - $prp: $packid uploaded\n";

  my $changed_full = BSSched::BuildResult::update_dst_full($gctx, $prp, $packid, $jobdatadir, $meta);
  $changed->{$prp} ||= 1;
  $changed->{$prp} = 2 if $changed_full;
  my $repounchanged = $gctx->{'repounchanged'};
  delete $repounchanged->{$prp} if $changed_full;
  $repounchanged->{$prp} = 2 if $repounchanged->{$prp};
  unlink("$gdst/:repodone");

  if (-e "$jobdatadir/.logfile.success") {
    mkdir_p("$gdst/:logfiles.success");
    rename("$jobdatadir/.logfile.success", "$gdst/:logfiles.success/$packid");
  }
  if (-e "$jobdatadir/.logfile.fail") {
    mkdir_p("$gdst/:logfiles.fail");
    rename("$jobdatadir/.logfile.fail", "$gdst/:logfiles.fail/$packid");
  }
  if (-e "$jobdatadir/meta") {
    mkdir_p("$gdst/:meta");
    rename("$jobdatadir/meta", "$gdst/:meta/$packid");
  }
  rename("$jobdatadir/logfile", "$dst/logfile") if -e "$jobdatadir/logfile";
}

1;

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

package BSSched::BuildJob::PreInstallImage;

use strict;
use warnings;

use Digest::MD5 ();

use BSUtil;
use BSSched::BuildJob;
use Build;
use BSSolv;		# for gen_meta
use Build;

=head1 NAME

BSSched::BuildJob::PreInstallImage - A Class to handle preinstall image builds

=head1 SYNOPSIS

my $h = BSSched::BuildJob::PreInstallImage->new()

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
  shift;
  goto &Build::get_deps;
}

=head2 check - check if a preinstall image needs to be rebuilt

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info) = @_;

  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};

  # check if we're blocked
  my $edeps = $ctx->{'edeps'}->{$packid} || [];
  my $notready = $ctx->{'notready'};
  my $dep2src = $ctx->{'dep2src'};
  my $dep2pkg = $ctx->{'dep2pkg'};
  my @blocked = grep {$notready->{$dep2src->{$_}}} @$edeps;
  return ('blocked', join(', ', @blocked)) if @blocked;

  # expand like in BSSched::BuildJob::create, so that we have all used packages
  # in the meta file
  my $bconf = $ctx->{'conf'};
  my ($eok, @bdeps) = Build::get_build($bconf, [], @{$info->{'dep'} || []});
  if (!$eok) {
    print "      - $packid (preinstallimage)\n";
    print "        unresolvable:\n";
    print "          $_\n" for @bdeps;
    return ('unresolvable', join(', ', @bdeps));
  }
  my @pdeps = Build::get_preinstalls($bconf);
  my @vmdeps = Build::get_vminstalls($bconf);
  @bdeps = BSUtil::unify(@pdeps, @vmdeps, @bdeps);

  # create meta
  my $pool = $ctx->{'pool'};
  my @new_meta;
  for my $dep (@bdeps) {
    my $p = $dep2pkg->{$dep};
    if (!$p) {
      print "      - $packid (preinstallimage)\n";
      print "        unresolvable:\n          $dep\n";
      return ('unresolvable', $dep);
    }
    push @new_meta, $pool->pkg2pkgid($p)."  $dep";
  }
  @new_meta = BSSolv::gen_meta([], @new_meta);

  unshift @new_meta, ($pdata->{'verifymd5'} || $pdata->{'srcmd5'})."  $packid";
  return BSSched::BuildJob::metacheck($ctx, $packid, 'preinstallimage', \@new_meta, [ \@bdeps ]);
}

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my $bdeps = $data->[0];
  my $reason = $data->[1];
  return BSSched::BuildJob::create($ctx, $packid, $pdata, $info, [], $bdeps, $reason, 0);
}

1;

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

package BSSched::BuildJob::Image;

use strict;

=head1 NAME

BSSched::BuildJob::Image - A class to handle standard image builds

=head1 SYNOPSIS

my $h = BSSched::BuildJob::Image->new()

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

=head2 expand - expand the dependencies of an image

 TODO: add description

=cut

sub expand {
  shift;
  push @_, '--ignoreignore--';
  goto &Build::get_build;
}

=head2 check - check if an image needs to be rebuilt

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info, $buildtype, $edeps) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $repo = $ctx->{'repo'};

  # check if we're blocked
  my $notready = $ctx->{'notready'};
  my $dep2src = $ctx->{'dep2src'};
  my $dep2pkg = $ctx->{'dep2pkg'};
  my @blocked = grep {$notready->{$dep2src->{$_}}} @$edeps;
  @blocked = () if $repo->{'block'} && $repo->{'block'} eq 'never';
  if (@blocked) {
    splice(@blocked, 10, scalar(@blocked), '...') if @blocked > 10;
    return ('blocked', join(', ', @blocked));
  }
  
  # create meta and compare to old version
  my $pool = $ctx->{'pool'};
  my @new_meta;
  for my $dep (sort @$edeps) {
    my $p = $dep2pkg->{$dep};
    push @new_meta, $pool->pkg2pkgid($p)."  $dep";
  }
  return BSSched::BuildJob::metacheck($ctx, $packid, $pdata, $buildtype, \@new_meta, [ $edeps ]);
}

=head2 build - create a build job for an image

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my ($edeps, $reason) = @$data;
  local $ctx->{'forcebinaryidmeta'} = 1;	# force using the pkgid in the meta
  my ($state, $job) = BSSched::BuildJob::create($ctx, $packid, $pdata, $info, [], $edeps, $reason, 0);
  return ($state, $job);
}

1;

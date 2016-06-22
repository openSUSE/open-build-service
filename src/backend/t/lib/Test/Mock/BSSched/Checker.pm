# Copyright (c) 2016 SUSE LLC
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
package Test::Mock::BSSched::Checker;

our @ISA = 'BSSched::Checker';

use BSSched::Checker;

sub addrepo {
  my ($ctx, $pool, $prp, $arch) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  return $pool->repofromfile($prp, "$gctx->{'reporoot'}/$prp/$arch/:full.solv");
}

sub writejob {
  my ($ctx, $job, $binfo, $reason) = @_;
  $binfo->{'job'} = $job if $job;
  $binfo->{'reason'} = $reason->{'explain'} if $reason;
  $binfo->{'srcserver'} ||= 'srcserver';
  $binfo->{'reposerver'} ||= 'reposerver';
  $ctx->{'buildinfo'} = $binfo;
  $ctx->{'reason'} = $reason;
}

1;

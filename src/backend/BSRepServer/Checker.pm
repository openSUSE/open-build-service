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

package BSRepServer::Checker;

use BSRPC ':https';

use strict;

sub new {
  my ($class, $gctx, @conf) = @_;
  my $ctx = { 'gctx' => $gctx, @conf };
  $ctx->{'prp'} = "$ctx->{'project'}/$ctx->{'package'}";
  $ctx->{'gdst'} = "$gctx->{'reporoot'}/$ctx->{'prp'}/$gctx->{'arch'}";
  return bless $ctx, $class;
}

sub xrpc {
  my ($ctx, $resource, $param, @args) = @_;
  return BSRPC::rpc($param, @args);
}

sub addrepo {
  my ($ctx, $pool, $prp, $arch) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  my ($projid, $repoid) = split('/', $prp, 2);
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $r;
  if ($remoteprojs->{$projid}) {
    $r = BSRepServer::addrepo_remote($pool, $prp, $arch, $remoteprojs->{$projid});
  } else {
    $r = BSRepServer::addrepo_scan($pool, $prp, $arch);
  }
  die("repository $prp not available\n") unless $r;
  return $r;
}

sub read_gbininfo {
  my ($ctx, $prp, $arch) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  my ($projid, $repoid) = split('/', $prp, 2);
  my $remoteprojs = $gctx->{'remoteprojs'};
  if ($remoteprojs->{$projid}) {
    return BSRepServer::read_gbininfo_remote("$prp/$arch", $remoteprojs->{$projid});
  }
  my $reporoot = $gctx->{'reporoot'};
  return BSRepServer::read_gbininfo("$reporoot/$prp/$arch");
}

1;


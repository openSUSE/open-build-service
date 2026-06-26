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
package Test::Mock::BSRepServer::Checker;

use BSRepServer::Checker;
use Test::OBS::Utils;


*BSRepServer::Checker::addrepo = sub {
  my ($ctx, $pool, $prp, $arch) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  my ($projid, $repoid) = split('/', $prp, 2);
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $r;
  if ($remoteprojs->{$projid}) {
    $r = BSRepServer::Remote::addrepo_remote($pool, $prp, $arch, $remoteprojs->{$projid});
  } else {
    my $d = Test::OBS::Utils::readstrxz("$gctx->{'reporoot'}/$prp/$arch/:full.solv", 1);
    if ($d) {
      $r = $pool->repofromstr($prp, $d);
    } else {
      $r = $pool->repofrombins($prp, '.');
    }
  }
  return $r;
};

1;

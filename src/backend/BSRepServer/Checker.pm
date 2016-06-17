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
  $ctx->{'prp'} = "$ctx->{'project'}/$ctx->{'repository'}";
  $ctx->{'gdst'} = "$gctx->{'reporoot'}/$ctx->{'prp'}/$gctx->{'arch'}";
  return bless $ctx, $class;
}

sub xrpc {
  my ($ctx, $resource, $param, @args) = @_;
  return BSRPC::rpc($param, @args);
}

sub setup {
  my ($ctx) = @_;

  my $gctx = $ctx->{'gctx'};
  my $projpacks = $gctx->{'projpacks'};
  my $projid = $ctx->{'project'};
  my $myarch = $gctx->{'arch'};
  my $repoid = $ctx->{'repository'};
  my $repo = (grep {$_->{'name'} eq $repoid} @{$projpacks->{$projid}->{'repository'} || []})[0];
  die("no repo $repoid in project $projid?\n") unless $repo;
  $ctx->{'repo'} = $repo;
  my $bconf = BSRepServer::getconfig($projid, $repoid, $myarch, $ctx->{'configpath'});
  $ctx->{'conf'} = $bconf;
}

sub preparepool {
  my ($ctx, $pname, $ldepfile) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $bconf = $ctx->{'conf'};
  my $pool = BSSolv::pool->new();
  $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';
  $ctx->{'pool'} = $pool;

  if ($ldepfile) {
    my $data = {};
    Build::readdeps({ %$bconf }, $data, $ldepfile);
    delete $data->{'/url'};
    delete $data->{'/external/'};
    my $r = $ctx->{pool}->repofromdata('', $data);
    die("ldepfile repo add failed\n") unless $r;
  }

  my $prpsearchpath = $ctx->{'prpsearchpath'};
  for my $rprp (@$prpsearchpath) {
    $ctx->addrepo($pool, $rprp, $myarch);
  }
  $pool->createwhatprovides();
  my %dep2src;
  my %dep2pkg;
  my %subpacks;
  for my $p ($pool->consideredpackages()) {
    my $n = $pool->pkg2name($p);
    $dep2pkg{$n} = $p; 
    $dep2src{$n} = $pool->pkg2srcname($p);
  }
  $ctx->{'dep2pkg'} = \%dep2pkg;
  $ctx->{'dep2src'} = \%dep2src;
  my @subpacks = grep {defined($dep2src{$_}) && $dep2src{$_} eq $pname} keys %dep2src;
  @subpacks = () if $bconf->{'type'} eq 'kiwi';
  $ctx->{'subpacks'} = { $pname => \@subpacks };
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


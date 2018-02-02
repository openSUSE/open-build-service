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
use Build;

use strict;

use BSRepServer::Remote;

use BSSched::BuildJob;
use BSSched::BuildJob::Package;
use BSSched::BuildJob::KiwiImage;
use BSSched::BuildJob::KiwiProduct;
use BSSched::BuildJob::Docker;
use BSSched::BuildJob::Unknown;
use BSSched::BuildJob::BuildEnv;

my %handlers = (
  'kiwi-product'    => BSSched::BuildJob::KiwiProduct->new(),
  'kiwi-image'      => BSSched::BuildJob::KiwiImage->new(),
  'docker'          => BSSched::BuildJob::Docker->new(),
  'fissile'         => BSSched::BuildJob::Docker->new(),
  'buildenv'        => BSSched::BuildJob::BuildEnv->new(),
  'unknown'         => BSSched::BuildJob::Unknown->new(),
  'default'         => BSSched::BuildJob::Package->new(),
);

sub new {
  my ($class, $gctx, @conf) = @_;
  my $ctx = { 'gctx' => $gctx, @conf };
  $ctx->{'prp'} = "$ctx->{'project'}/$ctx->{'repository'}";
  $ctx->{'gdst'} = "$gctx->{'reporoot'}/$ctx->{'prp'}/$gctx->{'arch'}";
  $ctx->{'isreposerver'} = 1;
  return bless $ctx, $class;
}

sub xrpc {
  my ($ctx, $resource, $param, @args) = @_;
  return BSRPC::rpc($param, @args);
}

sub getconfig {
  my ($ctx, $projid, $repoid, $arch, $configpath) = @_;
  return BSRepServer::ProjPacks::getconfig($ctx->{'gctx'}, $projid, $repoid, $arch, $configpath);
}

sub append_info_path {
  my ($ctx, $info, $path) = @_;
  # make sure we know about the path elements
  BSRepServer::ProjPacks::get_path_projpacks($ctx->{'gctx'}, $ctx->{'project'}, $path);
  # append path to info
  splice(@{$info->{'path'}}, -$info->{'extrapathlevel'}) if $info->{'extrapathlevel'};
  delete $info->{'extrapathlevel'};
  push(@{$info->{'path'}}, @$path);
  $info->{'extrapathlevel'} = @$path if @$path;
  return 1;
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
  my $bconf = $ctx->getconfig($projid, $repoid, $myarch, $ctx->{'prpsearchpath'});
  $ctx->{'conf'} = $bconf;
}

sub preparepool {
  my ($ctx, $pname, $ldepfile) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $bconf = $ctx->{'conf'};
  my $pool = BSSolv::pool->new();
  $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';
  $pool->settype('arch') if $bconf->{'binarytype'} eq 'arch';
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
  @subpacks = () if $bconf->{'type'} eq 'kiwi' || $bconf->{'type'} eq 'docker';
  $ctx->{'subpacks'} = { $pname => \@subpacks };
}

# see checkpks in BSSched::Checker
sub buildinfo {
  my ($ctx, $packid, $pdata, $info) = @_;

  my $expanddebug = $ctx->{'expanddebug'};
  local $Build::expand_dbg = 1 if $expanddebug;
  my $xp = BSSolv::expander->new($ctx->{'pool'}, $ctx->{'conf'});
  $ctx->{'expander'} = $xp;
  no warnings 'redefine';
  local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
  use warnings 'redefine';
  my $bconf = $ctx->{'conf'};
  my $buildtype = $bconf->{'type'};
  $buildtype = $info->{'imagetype'} && $info->{'imagetype'}->[0] eq 'product' ? 'kiwi-product' : 'kiwi-image' if $buildtype eq 'kiwi';
  $buildtype ||= 'unknown';
  my $handler = $handlers{$buildtype} || $handlers{'default'};
  $handler = $handlers{'buildenv'} if $pdata->{'buildenv'};
  die("$pdata->{'error'}\n") if $pdata->{'error'};
  die("$info->{'error'}\n") if $info->{'error'};
  my ($eok, @edeps) = $handler->expand($bconf, $ctx->{'subpacks'}->{$info->{'name'}}, @{$info->{'dep'} || []});
  BSSched::BuildJob::add_expanddebug($ctx, 'meta deps expansion') if $expanddebug;
  die("unresolvable: ".join(", ", @edeps)."\n") unless $eok;
  $info->{'edeps'} = \@edeps;
  my ($status, $error) = $handler->check($ctx, $packid, $pdata, $info, $bconf->{'type'});
  die("$status: $error\n") if $status ne 'scheduled';
  ($status, $error) = $handler->build($ctx, $packid, $pdata, $info, $error);
  die("$status: $error\n") if $status ne 'scheduled';
  die("no buildinfo in ctx\n") unless $ctx->{'buildinfo'};
  return $ctx->{'buildinfo'};
}

sub addrepo {
  my ($ctx, $pool, $prp, $arch) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  my ($projid, $repoid) = split('/', $prp, 2);
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $r;
  if ($remoteprojs->{$projid}) {
    $r = BSRepServer::Remote::addrepo_remote($pool, $prp, $arch, $remoteprojs->{$projid});
  } else {
    $r = BSRepServer::addrepo_scan($pool, $prp, $arch);
  }
  die("repository $prp not available\n") unless $r;
  return $r;
}

sub read_gbininfo {
  my ($ctx, $prp, $arch, $withevr) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  my ($projid, $repoid) = split('/', $prp, 2);
  my $remoteprojs = $gctx->{'remoteprojs'};
  if ($remoteprojs->{$projid}) {
    return BSRepServer::Remote::read_gbininfo_remote("$prp/$arch", $remoteprojs->{$projid}, $withevr);
  }
  my $reporoot = $gctx->{'reporoot'};
  return BSRepServer::read_gbininfo("$reporoot/$prp/$arch");
}

sub writejob {
  my ($ctx, $job, $binfo, $reason) = @_;
  $ctx = $ctx->{'realctx'} if $ctx->{'realctx'};
  $ctx->{'buildinfo'} = $binfo;
}

sub checkprpaccess {
  return 1;
}

1;


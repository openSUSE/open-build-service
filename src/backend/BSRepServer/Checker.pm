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
use Build::Rpm;

use strict;

use BSRepServer::Remote;

use BSSched::Modulemd;
use BSSched::BuildJob;
use BSSched::BuildJob::Package;
use BSSched::BuildJob::KiwiImage;
use BSSched::BuildJob::KiwiProduct;
use BSSched::BuildJob::ProductCompose;
use BSSched::BuildJob::Docker;
use BSSched::BuildJob::Unknown;
use BSSched::BuildJob::BuildEnv;

my %handlers = (
  'productcompose'  => BSSched::BuildJob::ProductCompose->new(),
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

sub setup_modulemd {
  my ($ctx, $modulemdpackid, $pdata) = @_;
  my $modulemd = $pdata->{'modulemd'};
  die("$modulemdpackid: not a modulemd package\n") unless $modulemd;
  my $bconf = $ctx->{'conf'};
  my $dependency = BSSched::Modulemd::select_dependency($bconf, $modulemd);
  die("cannot build this module\n") unless $dependency;
  my $errors = BSSched::Modulemd::extend_modules($bconf, $modulemd, $dependency->{'buildrequires'} || []);
  die(join(', ', @$errors)."\n") if $errors;
  my $ml = BSSched::Modulemd::calc_modularitylabel($bconf, $modulemd, $dependency->{'requires'} || []);
  die("modularitylabel calculation failed\n") unless $ml;
  my @ml = split(':', $ml, 4);
  $ctx->{'modularity_label'} = $ml;
  $ctx->{'modularity_package'} = $modulemdpackid;
  $ctx->{'modularity_srcmd5'} = $pdata->{'srcmd5'};
  $ctx->{'modularity_meta'} = Digest::MD5::md5_hex("$ml[0]:$ml[1]:$ml[3]:$pdata->{'srcmd5'}")."  $ctx->{'modularity_package'}";
  $ctx->{'modularity_extramacros'} = $modulemd->{'macros'} if $modulemd->{'macros'};
  $ctx->{'modularity_platform'} = $bconf->{'buildflags:modulemdplatform'};
  $ctx->{'modularity_distindex'} = $modulemd->{'distindex'} if $modulemd->{'distindex'};
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
  die("project config: $bconf->{'parse_error'}\n") if $bconf->{'parse_error'} && !$BSConfig::ignore_project_config_errors;
  $ctx->{'conf'} = $bconf;
  my $crosshostarch;
  if ($repo->{'hostsystem'}) {
    $crosshostarch = $bconf->{'hostarch'} || $myarch;
  }
  die("crosshostarch mismatch\n") if ($repo->{'crosshostarch'} || '') ne ($crosshostarch || '');
  if ($crosshostarch && $crosshostarch ne $myarch) {
    my $bconf_host = $ctx->getconfig($projid, $repoid, $crosshostarch, $ctx->{'prpsearchpath_host'});
    die("cross project config: $bconf_host->{'parse_error'}\n") if $bconf_host->{'parse_error'} && !$BSConfig::ignore_project_config_errors;
    $ctx->{'conf_host'} = $bconf_host;
  }
  my $pdatas = $projpacks->{$projid}->{'package'};
  setup_modulemd($ctx, 'modulemd', $pdatas->{'modulemd'}) if $pdatas->{'modulemd'} && $pdatas->{'modulemd'}->{'modulemd'};
}

sub depstotestcaseformat {
  my ($d) = @_;
  for my $dep (@$d) {
    $dep = Build::Rpm::testcaseformat($dep) if $dep =~ /^\(/s;
  }
}

sub addldeprepo {
  my ($pool, $bconf, $ldepfile) = @_;
  my $data = {};
  if (defined &Build::parse_depfile) {
    my $nofiledeps = %{$bconf->{'fileprovides'} || {}} ? 0 : 1;
    $data = Build::parse_depfile($ldepfile, [], 'testcaseformat' => 1, 'nofiledeps' => $nofiledeps);
    $data = { map {$_ => $_} @$data };	# convert from array to hash
  } else {
    Build::readdeps({ %$bconf }, $data, $ldepfile);
    # repofromdata expects testcase format, so convert rich dependencies
    if (defined &Build::Rpm::testcaseformat) {
      for my $p (values %$data) {
        for ('requires', 'conflicts', 'recommends', 'supplements') {
	  depstotestcaseformat($p->{$_}) if $p->{$_};
        }
      }
    }
  }
  delete $data->{'/url'};
  delete $data->{'/external/'};
  my $r = $pool->repofromdata('', $data);
  die("ldepfile repo add failed\n") unless $r;
}

sub preparehashes {
  my ($pool, $bconf, $pname) = @_;
  my %dep2src;
  my %dep2pkg;
  my %subpacks;
  for my $p ($pool->consideredpackages()) {
    my $n = $pool->pkg2name($p);
    $dep2pkg{$n} = $p; 
    $dep2src{$n} = $pool->pkg2srcname($p);
  }
  if (defined($pname)) {
    my @subpacks = grep {defined($dep2src{$_}) && $dep2src{$_} eq $pname} keys %dep2src;
    @subpacks = () if $bconf->{'type'} eq 'kiwi' || $bconf->{'type'} eq 'docker';
    $subpacks{$pname} = \@subpacks;
  }
  return (\%dep2pkg, \%dep2src, \%subpacks);
}

sub newpool {
  my ($ctx, $bconf) = @_;
  my $pool = BSSolv::pool->new();
  if ($bconf) {
    $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';
    $pool->settype('arch') if $bconf->{'binarytype'} eq 'arch';
    $pool->settype('apk') if $bconf->{'binarytype'} eq 'apk';
    $pool->setmodules($bconf->{'modules'}) if $bconf->{'modules'} && defined &BSSolv::pool::setmodules;
  }
  return $pool;
}

sub createpool {
  my ($ctx, $bconf, $prpsearchpath, $arch, $ldepfile) = @_;
  my $pool = $ctx->newpool($bconf);
  addldeprepo($pool, $bconf, $ldepfile) if $ldepfile;
  for my $rprp (@$prpsearchpath) {
    $ctx->addrepo($pool, $rprp, $arch);
  }
  $pool->createwhatprovides();
  return $pool;
}

sub preparepool {
  my ($ctx, $pname, $ldepfile) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $bconf = $ctx->{'conf'};

  my $pool = $ctx->createpool($bconf, $ctx->{'prpsearchpath'}, $myarch, $ldepfile);
  $ctx->{'pool'} = $pool;
  ($ctx->{'dep2pkg'}, $ctx->{'dep2src'}, $ctx->{'subpacks'}) = preparehashes($pool, $bconf, $pname);
  if ($ctx->{'conf_host'}) {
    $pool = $ctx->createpool($ctx->{'conf_host'}, $ctx->{'prpsearchpath_host'}, $ctx->{'repo'}->{'crosshostarch'});
    $ctx->{'pool_host'} = $pool;
    ($ctx->{'dep2pkg_host'}) = preparehashes($pool, $bconf, $pname);
  }
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
  my $cross = $ctx->{'conf_host'} ? 1 : 0;
  my $handler = $handlers{$buildtype};
  $handler = $handlers{'buildenv'} if $pdata->{'buildenv'};
  die("$pdata->{'error'}\n") if $pdata->{'error'};
  die("$info->{'error'}\n") if $info->{'error'};
  my ($eok, @edeps);
  if ($cross && !$handler) {
    $handler ||= $handlers{default};
    my $splitdeps;
    ($splitdeps, $eok, @edeps) = BSSched::BuildJob::Package::expand_sysroot($bconf, $ctx->{'subpacks'}->{$info->{'name'}}, $info);
    $info->{'split_hostdeps'} = $splitdeps;
  } else {
    $handler ||= $handlers{default};
    ($eok, @edeps) = $handler->expand($bconf, $ctx->{'subpacks'}->{$info->{'name'}}, @{$info->{'dep'} || []});
  }
  BSSched::BuildJob::add_expanddebug($ctx, 'meta deps expansion') if $expanddebug;
  die("unresolvable: ".join(", ", @edeps)."\n") unless $eok;
  $info->{'edeps'} = \@edeps;
  my ($status, $error) = $handler->check($ctx, $packid, $pdata, $info, $bconf->{'type'}, \@edeps);
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

sub read_packstatus {
  my ($ctx, $prp, $arch) = @_;
  return {};
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


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

package BSRepServer::BuildInfo;

use strict;
use warnings;

use Data::Dumper;

use BSConfiguration;
use BSRPC ':https';
use BSUtil;
use BSXML;
use BSUrlmapper;
use Build;

use BSRepServer;
use BSRepServer::Checker;
use BSRepServer::ProjPacks;
use BSSched::BuildJob;		# create_jobdata

#
# options:
#   - pdata:     parsed package data (from buildinfo POST requests)
#   - debug:     attach expanddebug
#   - add:       also install those packages
#   - internal:  generate job data instead of buildinfo
#
sub buildinfo {
  my ($projid, $repoid, $arch, $packid, %opts) = @_;

  # create global context
  my $gctx = {
    arch        => $arch,
    reporoot    => "$BSConfig::bsdir/build",
    #extrepodir  => "$BSConfig::bsdir/repos",
    #extrepodb   => "$BSConfig::bsdir/db/published",
    remoteproxy => $BSConfig::proxy,
    projpacks   => {},
    remoteprojs => {},
  };

  # get needed info from the src server
  my $pdata = $opts{'pdata'};
  my $kiwipath;
  if ($pdata && $pdata->{'info'} && $pdata->{'info'}->[0]) {
    $kiwipath = $pdata->{'info'}->[0]->{'path'};
  }
  BSRepServer::ProjPacks::get_projpacks($gctx, $projid, $repoid, $packid, !$pdata, $kiwipath);
  my $proj = $gctx->{'projpacks'}->{$projid};
  die("did not get project back from src server\n") unless $proj;
  my $repo = (grep {$_->{'name'} eq $repoid} @{$proj->{'repository'} || []})[0];
  die("did not get repository back from src server\n") unless $repo;
  $repo->{'block'} = 'never';	# buildinfo never blocks

  # take pdata from projpacks if we don't have it
  if (!$pdata) {
    $pdata = $proj->{'package'}->{$packid};
    die("no such package\n") unless $pdata;
    $pdata->{'buildenv'} = BSUtil::fromxml(delete $pdata->{'hasbuildenv'}, $BSXML::buildinfo) if $pdata->{'hasbuildenv'};
  }
  delete $pdata->{'hasbuildenv'};
  die("$pdata->{'error'}\n") if $pdata->{'error'};
  die("$pdata->{'buildenv'}->{'error'}\n") if $pdata->{'buildenv'} && $pdata->{'buildenv'}->{'error'};

  # take debuginfo flags from package meta if we have it
  $pdata->{'debuginfo'} ||= $proj->{'package'}->{$packid}->{'debuginfo'} if $packid;

  # get info
  my $info = $pdata->{'info'}->[0];
  die("bad info\n") unless $info && $info->{'repository'} eq $repoid;

  # find build type
  my $buildtype = $pdata->{'buildtype'} || Build::recipe2buildtype($info->{'file'}) || 'spec';
  $pdata->{'buildtype'} = $buildtype;

  # create checker
  my $ctx = BSRepServer::Checker->new($gctx, project => $projid, repository => $repoid);
  $ctx->{'dobuildinfo'} = 1 unless $opts{'internal'};
  $ctx->{'extradeps'} = $opts{'add'} if $opts{'add'};
  my $debugoutput = '';
  $ctx->{'expanddebug'} = \$debugoutput if $opts{'debug'};

  # set prpsearchpath
  my $pathelement;
  $pathelement = 'hostsystem' if $repo->{'crosshostarch'} && $repo->{'crosshostarch'} eq $arch;
  my @prpsearchpath = BSRepServer::ProjPacks::expandsearchpath($ctx->{'gctx'}, $projid, $repo, $pathelement);
  $ctx->{'prpsearchpath'} = \@prpsearchpath;
  if ($repo->{'crosshostarch'} && $repo->{'crosshostarch'} ne $arch) {
    $pathelement = 'hostsystem' if $repo->{'crosshostarch'} && $repo->{'crosshostarch'} eq $arch;
    my @prpsearchpath_host = BSRepServer::ProjPacks::expandsearchpath($ctx->{'gctx'}, $projid, $repo, 'hostsystem');
    $ctx->{'prpsearchpath_host'} = \@prpsearchpath_host;
  }

  # setup config
  $ctx->setup();
  my $bconf = $ctx->{'conf'};
  $bconf->{'type'} = $buildtype;

  # simple expansion hack for Steffen's installation_image
  simple_expansion_hack($bconf) if grep {$_ eq '-simple_expansion_hack'} @{$info->{'dep'} || []};

  # add repositories
  $ctx->preparepool($info->{'name'}, $pdata->{'ldepfile'});

  # create buildinfo
  my $binfo;
  eval {
    $binfo = $ctx->buildinfo($packid, $pdata, $info);
  };
  if ($@) {
    $binfo = BSSched::BuildJob::create_jobdata($ctx, $packid, $pdata, $info, $ctx->{'subpacks'}->{$info->{'name'} || ''});
    $binfo->{'error'} = $@;
    chomp($binfo->{'error'});
  }

  fixupbuildinfo($ctx, $binfo, $info) if $ctx->{'dobuildinfo'};
  return $binfo;
}

sub simple_expansion_hack {
  my ($bconf) = @_;
  delete $bconf->{'ignore'};
  delete $bconf->{'ignoreh'};
  $bconf->{'preinstall'} = [];
  $bconf->{'vminstall'} = [];
  $bconf->{'required'} = [];
  $bconf->{'support'} = [];
}

sub addpreinstallimg {
  my ($ctx, $binfo, $preimghdrmd5s) = @_;
  return unless $preimghdrmd5s && %$preimghdrmd5s;
  my $projid = $binfo->{'project'};
  my $repoid = $binfo->{'repository'};
  my $packid= $binfo->{'package'};
  my $arch = $binfo->{'arch'};
  my @prpas = map {$_->name() . "/$arch"} $ctx->{'pool'}->repos();
  my $bestimgn = 2; 
  my $bestimg;

  for my $prpa (@prpas) {
    my $images = BSRepServer::getpreinstallimages($prpa);
    next unless $images;
    for my $img (@$images) {
      next if @{$img->{'hdrmd5s'} || []} < $bestimgn;
      next unless $img->{'sizek'} && $img->{'hdrmd5'};
      next if grep {!$preimghdrmd5s->{$_}} @{$img->{'hdrmd5s'} || []}; 
      next if $prpa eq "$projid/$repoid/$arch" && $packid && $img->{'package'} eq $packid;
      $img->{'prpa'} = $prpa;
      $bestimg = $img;
      $bestimgn = @{$img->{'hdrmd5s'} || []}; 
   }
  }
  return unless $bestimg;
  my $pi = {'package' => $bestimg->{'package'}, 'filename' => "_preinstallimage.$bestimg->{'hdrmd5'}", 'binary' => $bestimg->{'bins'}, 'hdrmd5' => $bestimg->{'hdrmd5'}};
  ($pi->{'project'}, $pi->{'repository'}) = split('/', $bestimg->{'prpa'}, 3);
  my $rurl = BSUrlmapper::get_downloadurl("$pi->{'project'}/$pi->{'repository'}");
  $pi->{'url'} = $rurl if $rurl;
  $binfo->{'preinstallimage'} = $pi;
}

sub addurltopath {
  my ($ctx, $binfo) = @_;
  my $remoteprojs = $ctx->{'gctx'}->{'remoteprojs'};
  for my $r (@{$binfo->{'path'}}) {
    delete $r->{'server'};
    # what to do with projects from remote instances?
    next if $remoteprojs->{$r->{'project'}} && !$remoteprojs->{$r->{'project'}}->{'partition'};
    my $rurl = BSUrlmapper::get_downloadurl("$r->{'project'}/$r->{'repository'}");
    $r->{'url'} = $rurl if $rurl;
  }
}

sub getmodulemddata {
  my ($buildinfo) = @_;
  my @args;
  push @args, "project=$buildinfo->{'project'}";
  push @args, "package=$buildinfo->{'modularity_package'}";
  push @args, "srcmd5=$buildinfo->{'modularity_srcmd5'}";
  push @args, "arch=$buildinfo->{'arch'}";
  push @args, map {"module=$_"} @{$buildinfo->{'module'} || []};
  push @args, "modularityplatform=$buildinfo->{'modularity_platform'}";
  push @args, "modularitylabel=$buildinfo->{'modularity_label'}";
  push @args, "view=yaml";
  return BSRPC::rpc({
    'uri' => "$BSConfig::srcserver/getmodulemd",
    'timeout' => 300,
  }, undef, @args);
}

sub fixupbuildinfo {
  my ($ctx, $binfo, $info) = @_;

  delete $binfo->{$_} for qw{job needed constraintsmd5 prjconfconstraint nounchanged revtime reason nodbgpkgs nosrcpkgs};
  delete $binfo->{'reason'};
  $binfo->{'specfile'} = $binfo->{'file'} if $binfo->{'file'};	# compat
  if ($binfo->{'syspath'}) {
    $binfo->{'syspath'} = [] if grep {$_->{'project'} eq '_obsrepositories'} @{$info->{'path'} || []};
    unshift @{$binfo->{'path'}}, @{delete $binfo->{'syspath'}};
  }
  if ($binfo->{'containerpath'}) {
    unshift @{$binfo->{'path'}}, @{delete $binfo->{'containerpath'}};
  }
  addurltopath($ctx, $binfo);
  # never use the subpacks calculated from the full tree
  $binfo->{'subpack'} = $info->{'subpacks'} if $info->{'subpacks'};
  $binfo->{'subpack'} = [ sort @{$binfo->{'subpack'} } ] if $binfo->{'subpack'};
  $binfo->{'downloadurl'} = $BSConfig::repodownload if defined $BSConfig::repodownload;
  $binfo->{'debuginfo'} ||= 0;	# XXX: why?
  my %preimghdrmd5s = map {delete($_->{'preimghdrmd5'}) => 1} grep {$_->{'preimghdrmd5'}} @{$binfo->{'bdep'}};
  addpreinstallimg($ctx, $binfo, \%preimghdrmd5s);
  $binfo->{'expanddebug'} = ${$ctx->{'expanddebug'}} if $ctx->{'expanddebug'};
  $binfo->{'modularity_yaml'} = getmodulemddata($binfo) if $binfo->{'modularity_label'};
}

# callback for the recipe parser
sub parse_recipe_includecallback {
  my ($files, $fn) = @_;
  my %files = %$files;
  if ($files{'_service'}) {
    for (sort keys %files) {
      next unless /^_service:.*:(.*?)$/s;
      $files{$1} = delete($files{$_}) if $files{$_};
    }
  }
  $fn =~ s/.*\///;
  $fn = $files{$fn};
  return undef unless $fn;
  my @s = stat($fn);
  return undef if !@s || $s[7] > 100000;
  return readstr($fn);
}

# this is similar to the getprojpack code in bs_srcserver
sub parse_recipe {
  my ($bconf, $recipefile, $files) = @_;
  my $type = $bconf->{'type'};
  local $Build::Rpm::includecallback = sub { parse_recipe_includecallback($files, @_) };
  my $d = Build::parse_typed($bconf, $recipefile, $type);
  die("unknown repository type $type\n") unless $d;
  die("could not parse build description ($type): $d->{'error'}\n") if $d->{'error'};
  die("could not parse name in build description ($type)\n") unless defined $d->{'name'};

  # build info from parsed data
  my $info = { 'name' => $d->{'name'}, 'dep' => $d->{'deps'} };
  $info->{'subpacks'} = $d->{'subpacks'} if $d->{'subpacks'};
  if ($d->{'prereqs'}) {
    my %deps = map {$_ => 1} (@{$d->{'deps'} || []}, @{$d->{'subpacks'} || []});
    my @prereqs = grep {!$deps{$_} && !/^%/} @{$d->{'prereqs'}};
    $info->{'prereq'} = \@prereqs if @prereqs;
  }
  $info->{'path'} = $d->{'path'} if $d->{'path'};
  $info->{'containerpath'} = $d->{'containerpath'} if $d->{'containerpath'};
  if ($type eq 'kiwi' || $type eq 'productcompose') {
    $info->{'imagetype'} = $d->{'imagetype'} if $d->{'imagetype'};
    $info->{'imagearch'} = $d->{'exclarch'} if $d->{'exclarch'};
    my $imagetype = $type eq 'kiwi' && $d->{'imagetype'} ? ($d->{'imagetype'}->[0] || '') : '';
    if ($type eq 'productcompose' || $imagetype eq 'product') {
      $info->{'nodbgpkgs'} = 1 if defined($d->{'debugmedium'}) && $d->{'debugmedium'} <= 0;
      $info->{'nosrcpkgs'} = 1 if defined($d->{'sourcemedium'}) && $d->{'sourcemedium'} <= 0;
    }
  }
  if ($files->{'_service'}) {
    my $services = readxml($files->{'_service'}, $BSXML::services);
    for my $service (@{$services->{'service'} || []}) {
       next unless $service->{'mode'} && $service->{'mode'} eq 'buildtime';
       push @{$info->{'buildtimeservice'}}, $service->{'name'};
     }
  }
  return $info;
}

1;

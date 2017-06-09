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

  my @prpsearchpath = BSRepServer::ProjPacks::expandsearchpath($ctx->{'gctx'}, $projid, $repo);
  $ctx->{'prpsearchpath'} = \@prpsearchpath;

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
  my $rprp = "$pi->{'project'}/$pi->{'repository'}";
  my $rprp_ext = $rprp;
  $rprp_ext =~ s/:/:\//g;
  my $rurl = BSRepServer::get_downloadurl($rprp, $rprp_ext);
  $pi->{'url'} = $rurl if $rurl;
  $binfo->{'preinstallimage'} = $pi;
}

sub addurltopath {
  my ($ctx, $binfo) = @_;
  my $remoteprojs = $ctx->{'gctx'}->{'remoteprojs'};
  for my $r (@{$binfo->{'path'}}) {
    delete $r->{'server'};
    next if $remoteprojs->{$r->{'project'}};	# what to do with those?
    my $rprp = "$r->{'project'}/$r->{'repository'}";
    my $rprp_ext = $rprp;
    $rprp_ext =~ s/:/:\//g;
    my $rurl = BSRepServer::get_downloadurl($rprp, $rprp_ext);
    $r->{'url'} = $rurl if $rurl;
  }
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
  # never use the subpacks from the full tree
  $binfo->{'subpack'} = $info->{'subpacks'} if $info->{'subpacks'};
  $binfo->{'subpack'} = [ sort @{$binfo->{'subpack'} } ] if $binfo->{'subpack'};
  $binfo->{'downloadurl'} = $BSConfig::repodownload if defined $BSConfig::repodownload;
  $binfo->{'debuginfo'} ||= 0;	# XXX: why?
  my %preimghdrmd5s = map {delete($_->{'preimghdrmd5'}) => 1} grep {$_->{'preimghdrmd5'}} @{$binfo->{'bdep'}};
  addpreinstallimg($ctx, $binfo, \%preimghdrmd5s);
  $binfo->{'expanddebug'} = ${$ctx->{'expanddebug'}} if $ctx->{'expanddebug'};
}

1;

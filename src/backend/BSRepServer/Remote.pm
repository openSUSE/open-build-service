# Copyright (c) 2016-2018 SUSE LLC
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

package BSRepServer::Remote;

use strict;

use BSConfiguration;
use BSRPC ':https';
use BSUtil;
use BSXML;

my $proxy;
$proxy = $BSConfig::proxy if defined($BSConfig::proxy);

sub import_annotation {
  my ($annotation) = @_;
  return $annotation unless ref($annotation);
  my %a;
  for (qw{repo disturl buildtime registry_refname registry_digest registry_fatdigest}) {
    $a{$_} = $annotation->{$_} if exists $annotation->{$_};
  }
  return BSUtil::toxml(\%a, $BSXML::binannotation);
}

sub addrepo_remote {
  my ($pool, $prp, $arch, $remoteproj) = @_;

  my ($projid, $repoid) = split('/', $prp, 2);
  return undef unless $remoteproj;
  my @modules;
  @modules = $pool->getmodules() if defined &BSSolv::pool::getmodules;
  print "fetching remote repository state for $prp/$arch\n";
  my $param = {
    'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$repoid/$arch/_repository",
    'timeout' => 200,
    'receiver' => \&BSHTTP::cpio_receiver,
    'proxy' => $proxy,
  };
  my @args;
  if ($remoteproj->{'partition'}) {
    push @args, 'view=solvstate', 'noajax=1';
  } else {
    push @args, 'view=cache';
    push @args, map {"module=$_"} @modules;
  }
  my $cpio = BSRPC::rpc($param, undef, @args);
  my %cpio = map {$_->{'name'} => $_} @{$cpio || []};
  if ($remoteproj->{'partition'} && $cpio{'repositorysolv'}) {
    return $pool->repofromstr($prp, $cpio{'repositorysolv'}->{'data'});
  } elsif ($cpio{'repositorycache'}) {
    my $cache = BSUtil::fromstorable($cpio{'repositorycache'}->{'data'}, 2);
    delete $cpio{'repositorycache'};    # free mem
    return undef unless $cache;
    # postprocess entries
    delete $cache->{'/external/'};
    delete $cache->{'/url'};
    delete $cache->{'/modules'};
    for (values %$cache) {
      # free some unused entries to save mem
      delete $_->{'path'};
      delete $_->{'id'};
      # import annotations
      $_->{'annotation'} = import_annotation($_->{'annotationdata'} || $_->{'annotation'}) if $_->{'annotation'};
    }
    return $pool->repofromdata($prp, $cache);
  } else {
    # return empty repo
    return $pool->repofrombins($prp, '');
  }
}

sub read_gbininfo_remote {
  my ($prpa, $remoteproj, $withevr) = @_;

  my ($projid, $repoid, $arch) = split('/', $prpa, 3);
  print "fetching remote project binary state for $prpa\n";
  if ($remoteproj->{'partition'}) {
    my $param = {
      'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$repoid/$arch",
      'timeout' => 200,
    };
    my $gbininfo = eval { BSRPC::rpc($param, \&BSUtil::fromstorable, 'view=gbininfo') };
    if ($@) {
      return {} if $@ =~ /^404/;
      die($@);
    }
    return $gbininfo;
  }
  my $param = {
    'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$repoid/$arch",
    'timeout' => 200,
    'proxy' => $proxy,
  };
  my $packagebinarylist = eval { BSRPC::rpc($param, $BSXML::packagebinaryversionlist, 'view=binaryversions') };
  if ($@) {
    return {} if $@ =~ /^404/;
    die($@);
  }
  my $gbininfo = {};
  for my $binaryversionlist (@{$packagebinarylist->{'binaryversionlist'} || []}) {
   my %bins;
   for my $binary (@{$binaryversionlist->{'binary'} || []}) {
     if ($withevr) {
       # XXX: rpm filenames don't have the epoch...
       next unless $binary->{'name'} =~ /^(?:::import::.*::)?(.+)-(?:(\d+?):)?([^-]+)-([^-]+)\.([a-zA-Z][^\.\-]*)\.rpm$/;
       $bins{$binary->{'name'}} = {'filename' => $binary->{'name'}, 'name' => $1, 'arch' => $5, 'epoch' => $2, 'version' => $3, 'release' => $4, 'hdrmd5' => $binary->{'hdrmd5'}};
     } else {
       next unless $binary->{'name'} =~ /^(?:::import::.*::)?(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/;
       $bins{$binary->{'name'}} = {'filename' => $binary->{'name'}, 'name' => $1, 'arch' => $2};
     }
   }
   $gbininfo->{$binaryversionlist->{'package'}} = \%bins;
  }
  return $gbininfo;
}

sub remotemap2remoteprojs {
  my ($gctx, $remotemap) = @_;

  my $remoteprojs = $gctx->{'remoteprojs'} || {};
  $gctx->{'remoteprojs'} = $remoteprojs;
  for my $proj (@{$remotemap || []}) {
    my $projid = delete $proj->{'project'};
    $remoteprojs->{$projid} = $proj;
  }
}

1;

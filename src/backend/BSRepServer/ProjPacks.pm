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

package BSRepServer::ProjPacks;

use BSUtil;
use BSRPC;
use BSXML;
use BSConfiguration;
use BSRepServer::Remote;

use strict;

sub get_projpacks {
  my ($gctx, $projid, $repoid, $packid, $withdeps, $path) = @_;
  my @args;
  push @args, "project=$projid";
  push @args, "repository=$repoid";
  push @args, "arch=$gctx->{'arch'}";
  push @args, "package=$packid" if defined $packid;
  push @args, "withdeps=1" if $withdeps;
  push @args, 'buildinfo=1';
  if ($path) {
    my @xprojs = ($projid);
    for (@$path) {
      # _obsrepositories needs no handling, projects are already used
      push @xprojs, $_->{'project'} if $_->{'project'} ne '_obsrepositories';
    }
    @xprojs = BSUtil::unify(@xprojs);
    push @args, map {"project=$_"} splice(@xprojs, 1);
  }
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
  my $projpacksin = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, @args);
  update_projpacks($gctx, $projpacksin);
}

sub get_path_projpacks {
  my ($gctx, $projid, $path) = @_;
  my @args;

  my $projpacks = $gctx->{'projpacks'} || {};
  my $remoteprojs = $gctx->{'remoteprojs'} || {};
  for (@$path) {
    my $p = $_->{'project'};
    next if $p eq '_obsrepositories' || $p eq $projid;
    if ($remoteprojs->{$p}) {
      next if defined $remoteprojs->{$p}->{'config'};
    } elsif ($projpacks->{$p}) {
      next if defined $projpacks->{$p}->{'config'};
    }
    push @args, "project=$p";
  }
  return unless @args;
  @args = BSUtil::unify(@args);
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
  unshift @args, "withconfig=1";
  unshift @args, "withremotemap=1";
  my $projpacksin = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, @args);
  for my $proj (@{$projpacksin->{'project'} || []}) {
    next if $proj->{'name'} eq $projid;
    $projpacks->{delete $proj->{'name'}} = $proj;
  }
  BSRepServer::Remote::remotemap2remoteprojs($gctx, $projpacksin->{'remotemap'}) if $projpacksin->{'remotemap'};
}

sub update_projpacks {
  my ($gctx, $projpacksin) = @_;
  my $projpacks = {};
  $gctx->{'projpacks'} = $projpacks;
  for my $proj (@{$projpacksin->{'project'} || []}) {
    $projpacks->{delete $proj->{'name'}} = $proj;
    my $packages = {};
    for my $pack (@{$proj->{'package'} || []}) {
      $packages->{delete $pack->{'name'}} = $pack;
    }
    $proj->{'package'} = $packages;
    delete $proj->{'package'} unless %$packages;
  }
  BSRepServer::Remote::remotemap2remoteprojs($gctx, $projpacksin->{'remotemap'}) if $projpacksin->{'remotemap'};
}

sub expandsearchpath {
  my ($gctx, $projid, $repo, $pathelement) = @_;

  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  $pathelement ||= 'path';
  my %done;
  my @ret;
  my @path = @{$repo->{$pathelement} || $repo->{'path'} || []}; 
  # our own repository is not included in the path,
  # so put it infront of everything
  unshift @path, {'project' => $projid, 'repository' => $repo->{'name'}};
  while (@path) {
    my $t = shift @path;
    my $prp = "$t->{'project'}/$t->{'repository'}";
    push @ret, $prp unless $done{$prp};
    $done{$prp} = 1; 
    if (!@path) {
      last if $done{"/$prp"};
      my ($pid, $rid) = ($t->{'project'}, $t->{'repository'});
      my $proj = $remoteprojs->{$pid} || $projpacks->{$pid};
      next unless $proj;
      $done{"/$prp"} = 1;       # mark expanded
      my @repo = grep {$_->{'name'} eq $rid} @{$proj->{'repository'} || []}; 
      push @path, @{$repo[0]->{$pathelement} || $repo[0]->{'path'} || []} if @repo;
    }    
  }
  return @ret;
}

sub getconfig {
  my ($gctx, $projid, $repoid, $arch, $path) = @_;
  my $extraconfig = '';
  my $config = "%define _project $projid\n";
  if ($BSConfig::extraconfig) {
    for (sort keys %{$BSConfig::extraconfig}) {
      $extraconfig .= $BSConfig::extraconfig->{$_} if $projid =~ /$_/;
    }
  }
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my ($old_is_this_project, $old_is_in_project) = (-1, -1);
  for my $prp (reverse @$path) {
    my ($p, $r) = split('/', $prp, 2);
    my $proj = $remoteprojs->{$p} || $projpacks->{$p} || {};
    my $c = $proj->{'config'};
    next unless defined $c;
    $config .= "\n### from $p\n";
    $config .= "%define _repository $r\n";
    my $new_is_this_project = $p eq $projid ? 1 : 0; 
    my $new_is_in_project = $new_is_this_project || substr($projid, 0, length($p) + 1) eq "$p:" ? 1 : 0;
    $config .= "%define _is_this_project $new_is_this_project\n" if $new_is_this_project ne $old_is_this_project;
    $config .= "%define _is_in_project $new_is_in_project\n" if $new_is_in_project ne $old_is_in_project;
    ($old_is_this_project, $old_is_in_project) = ($new_is_this_project, $new_is_in_project);

    # get rid of the Macros sections
    my $s1 = '^\s*macros:\s*$.*?^\s*:macros\s*$';
    my $s2 = '^\s*macros:\s*$.*\Z';
    $c =~ s/$s1//gmsi;
    $c =~ s/$s2//gmsi;
    $config .= $c;
  }
  return undef unless $config ne '';
  $config .= "\n$extraconfig" if $extraconfig;
  my @c = split("\n", $config);
  my $c = Build::read_config($arch, \@c);
  $c->{'repotype'} = [ 'rpm-md' ] unless @{$c->{'repotype'}};
  $c->{'binarytype'} ||= 'UNDEFINED';
  return $c;
}

1;

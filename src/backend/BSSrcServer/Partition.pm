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
package BSSrcServer::Partition;

use strict;
use warnings;

use BSConfiguration;
use BSRevision;
use BSUtil;

sub projid2reposerver {
  my ($projid) = @_;
  return $BSConfig::reposerver unless $BSConfig::partitionservers;
  my @p = @{$BSConfig::partitioning || []}; 
  my $par;
  while (@p) {
    if ($projid =~ /^$p[0]/) {
      $par = $p[1];
      last;
    }    
    splice(@p, 0, 2);
  }
  $par = $BSConfig::partition unless defined $par;
  die("cannot determine partition for $projid\n") unless defined $par;
  die("partition '$par' from partitioning does not exist\n") unless $BSConfig::partitionservers->{$par};
  return $BSConfig::partitionservers->{$par};
}

sub allreposervers {
  return ($BSConfig::reposerver) unless $BSConfig::partitionservers;
  return sort(BSUtil::unify(values(%$BSConfig::partitionservers)));
}

sub projid2partition {
  my ($projid) = @_;
  return undef unless $BSConfig::partitioning;
  my @p = @{$BSConfig::partitioning || []}; 
  my $par;
  while (@p) {
    if ($projid =~ /^$p[0]/) {
      $par = $p[1];
      last;
    }    
    splice(@p, 0, 2);
  }
  $par = $BSConfig::partition unless defined $par;
  die("cannot determine partition for $projid\n") unless defined $par;
  die("partition '$par' from partitioning does not exist\n") unless $BSConfig::partitionservers->{$par};
  return $par;
}

sub checkpartition {
  my ($remotemap, $projid, $proj) = @_;
  $remotemap->{':partitions'}->{$projid} = 1;
  return if $remotemap->{$projid};
  my @p = @{$BSConfig::partitioning || []};
  my $par;
  while (@p) {
    if ($projid =~ /^$p[0]/) {
      $par = $p[1];
      last;
    }
    splice(@p, 0, 2);
  }
  $par = $BSConfig::partition unless defined $par;
  die("cannot determine partition for $projid\n") unless defined $par;
  return if $par eq $remotemap->{':partition'};
  my $reposerver = $BSConfig::reposerver;
  if ($BSConfig::partitionservers) {
    $reposerver = $BSConfig::partitionservers->{$par};
    die("partition '$par' from partitioning does not exist\n") unless $reposerver;
  }
  $remotemap->{$projid} = {
    'name' => $projid, 'remoteurl' => $reposerver, 'remoteproject' => $projid, 'partition' => $par,
  };
  $proj ||= BSRevision::readproj_loacal($projid, 1);
  if (!$proj) {
    $remotemap->{$projid} = { 'name' => $projid };      # gone!
    return;
  }
  $remotemap->{$projid}->{'repository'} = $proj->{'repository'} if $proj->{'repository'};
  $remotemap->{$projid}->{'kind'} = $proj->{'kind'} if $proj->{'kind'};
  if ($proj->{'access'}) {
    for ('access', 'publish', 'person', 'group') {
      $remotemap->{$projid}->{$_} = $proj->{$_} if exists $proj->{$_};
    }
  }
}

1;

# Copyright (c) 2018 SUSE LLC
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
package BSSrcServer::Registry;

use strict;

use BSConfiguration;
use BSUtil;
use BSSrcServer::Partition;

my $registrydir = "$BSConfig::bsdir/registry";

sub ownrepo {
  my ($prp, $repo) = @_;
  my $registries = BSUtil::retrieve("$registrydir/:repos", 1);
  return $registries->{$repo} if $registries->{$repo};
  # new entry... lock...
  mkdir_p($registrydir) unless -d $registrydir;
  my $lck;
  BSUtil::lockopen($lck, '>>', "$registrydir/:repos");
  if (! -s "$registrydir/:repos") {
    $registries = {};
  } else {
    $registries = BSUtil::retrieve("$registrydir/:repos");
  }
  if (!$registries->{$repo}) {
    $registries->{$repo} = $prp;
    BSUtil::store("$registrydir/:repos.new.$$", "$registrydir/:repos", $registries);
  }
  close($lck);
  return $registries->{$repo};
}

sub disownrepo {
  my ($prp, $repo, $dodir) = @_;
  my $lck;
  BSUtil::lockopen($lck, '>>', "$registrydir/:repos");
  my $registries = BSUtil::retrieve("$registrydir/:repos");
  die("repository '$repo' is owned by $registries->{$repo}\n") if $registries->{$repo} && $registries->{$repo} ne $prp;
  delete $registries->{$repo};
  BSUtil::store("$registrydir/:repos.new.$$", "$registrydir/:repos", $registries);
  close($lck);
}

sub catalog {
  my $registries = BSUtil::retrieve("$registrydir/:repos", 1) || {};
  return sort keys %$registries;
}

sub rootinfo {
  my $registries = BSUtil::retrieve("$registrydir/:repos", 1) || {};
  my $info = {
    'owners' => $registries,
  };
  return $info;
}

sub regrepo2reposerver {
  my ($repo) = @_;
  my $registries = BSUtil::retrieve("$registrydir/:repos", 1) || {};
  my $prp = $registries->{$repo};
  return undef unless $prp;
  my ($projid) = split('/', $prp, 2);
  my $reposerver = $BSConfig::partitioning ? BSSrcServer::Partition::projid2reposerver($projid) : $BSConfig::reposerver;
  return $reposerver;
}

1;

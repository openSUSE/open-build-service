# Copyright (c) 2019 SUSE LLC
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

package BSRepServer::YMP;

use strict;

use BSConfiguration;
use BSOBS;
use BSRPC ':https';
use BSUtil;
use BSHTTP;
use BSXML;
use BSUrlmapper;
use Build;

my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

# find a binary given a binary name. Note that the binary
# name can contain a version
sub findympbinary {
  my ($binarydir, $binaryname) = @_;
  for my $b (ls($binarydir)) {
    next unless $b =~ /\.(?:$binsufsre)$/;
    next unless $b =~ /^\Q$binaryname\E/;
    if ($b =~ /(.+)-[^-]+-[^-]+\.[a-zA-Z][^\.\-]*\.rpm$/) {
      my $bn = $1;
      next unless $binaryname =~ /^\Q$bn\E/;
    }
    my $data = Build::query("$binarydir/$b", 'evra' => 1);
    if ($data->{'name'} eq $binaryname || "$data->{'name'}-$data->{'version'}" eq $binaryname) {
      return "$binarydir/$b";
    }
  }
  return undef;
}

sub getconfig {
  my ($projpacks, $projid, $repoid, $arch, $path) = @_;
  my $config = "%define _project $projid\n";
  for my $pa (reverse @$path) {
    my $proj = $projpacks->{$pa->{'project'}} || {};
    my $c = $proj->{'config'};
    next unless defined $c;
    $config .= "\n### from $pa->{'project'}\n";
    $config .= "%define _repository $pa->{'repository'}\n";
    my $s1 = '^\s*macros:\s*$.*?^\s*:macros\s*$';
    my $s2 = '^\s*macros:\s*$.*\Z';
    $c =~ s/$s1//gmsi;
    $c =~ s/$s2//gmsi;
    $config .= $c;
  }
  my @c = split("\n", $config);
  my $c = Build::read_config($arch, \@c);
  $c->{'repotype'} = [ 'rpm-md' ] unless @{$c->{'repotype'}};
  $c->{'binarytype'} ||= 'UNDEFINED';
  return $c;
}

sub makeymp {
  my ($projid, $repoid, $binary, $projpackin) = @_;

  my $binaryname;
  my $data;
  if ($binary =~ /(?:^|\/)([^\/]+)-[^-]+-[^-]+\.[a-zA-Z][^\/\.\-]*\.rpm$/) {
    $binaryname = $1;
  } elsif ($binary =~ /(?:^|\/)([^\/]+)_([^\/]*)_[^\/]*\.deb$/) {
    $binaryname = $1;
  } elsif ($binary =~ /(?:^|\/)([^\/]+)\.(?:rpm|deb)$/) {
    $binaryname = $1;
  } else {
    # just the binary name given. use findympbinary to get the path
    my $binarydir;
    ($binarydir, $binaryname) = $binary =~ /^(.*)\/([^\/]*)$/;
    $binary = findympbinary($binarydir, $binaryname) || $binary;
  }
  $data = Build::query($binary, 'description' => 1);
  my $projpack;
  if ($projpackin && $projpackin->{'project'}->[0]->{'name'} eq $projid) {
    $projpack = $projpackin;
  } else {
    my @args = ("project=$projid", "repository=$repoid");
    $projpack = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, 'withrepos', 'expandedrepos', 'withconfig', 'nopackages', @args);
  }
  my $proj = $projpack->{'project'}->[0];
  die("no such project\n") unless $proj && $proj->{'name'} eq $projid;
  my $repo = $proj->{'repository'}->[0];
  die("no such repository\n") unless $repo && $repo->{'name'} eq $repoid;
  my @nprojids = grep {$_ ne $projid} map {$_->{'project'}} @{$repo->{'path'} || []};
  my %nprojpack;
  if ($projpackin) {
    $nprojpack{$_->{'name'}} ||= $_ for @{$projpackin->{'project'} || []};
  }
  @nprojids = grep {!$nprojpack{$_}} @nprojids;
  if (@nprojids) {
    my @args = map {"project=$_"} @nprojids;
    my $nprojpack = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, 'nopackages', 'withconfig', @args);
    $nprojpack{$_->{'name'}} ||= $_ for @{$nprojpack->{'project'} || []};
  }
  my $bconf = getconfig(\%nprojpack, $projid, $repoid, 'noarch', $repo->{'path'} || []);
  my @ympdist;
  for (@{$bconf->{'publishflags'} || []}) {
    push @ympdist, BSHTTP::urldecode($1) if /^ympdist:(.*)$/s;
  }
  @ympdist = BSUtil::unify(@ympdist) if @ympdist;
  my $ymp = {};
  $ymp->{'xmlns:os'} = 'http://opensuse.org/Standards/One_Click_Install';
  $ymp->{'xmlns'} = 'http://opensuse.org/Standards/One_Click_Install';
  my @group;
  $ymp->{'group'} = \@group;
  my @repos;
  my @pa = @{$repo->{'path'} || []};
  while (@pa) {
    my $pa = shift @pa;
    my $r = {};
    $r->{'recommended'} = @pa || !@repos ? 'true' : 'false';
    $r->{'name'} = $pa->{'project'};
    if ($pa->{'project'} eq $projid) {
      $r->{'summary'} = $proj->{'title'};
      $r->{'description'} = $proj->{'description'};
    } elsif ($nprojpack{$pa->{'project'}}) {
      $r->{'summary'} = $nprojpack{$pa->{'project'}}->{'title'};
      $r->{'description'} = $nprojpack{$pa->{'project'}}->{'description'};
    }
    my $url = BSUrlmapper::get_downloadurl("$pa->{'project'}/$pa->{'repository'}");
    next unless defined $url;
    $r->{'url'} = $url;
    push @repos, $r;
  }
  my $pkg = {};
  $pkg->{'name'} = str2utf8xml($data ? $data->{'name'} : $binaryname);
  $pkg->{'description'} = str2utf8xml($data && defined($data->{'description'}) ? $data->{'description'} : "The $pkg->{'name'} package");
  $pkg->{'summary'} = str2utf8xml($data && defined($data->{'summary'}) ? $data->{'summary'} : "The $pkg->{'name'} package");
  my $inner_group = {};
  $inner_group->{'repositories'} = {'repository' => \@repos };
  $inner_group->{'software'} = {'item' => [$pkg]};
  for my $ympdist (@ympdist) {
    push @group, { %$inner_group, 'distversion' => $ympdist };
  }
  push @group, $inner_group unless @group;
  return $ymp;
}

1;

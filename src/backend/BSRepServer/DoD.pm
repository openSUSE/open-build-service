# Copyright (c) 2015 SUSE LLC
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
package BSRepServer::DoD;

use Digest::SHA ();

use BSOBS;
use BSWatcher ':https';
use BSVerify;
use BSHandoff;
use BSStdServer;
use BSUtil;

use Build;

use strict;
use warnings;

my $proxy;
$proxy = $BSConfig::proxy if defined($BSConfig::proxy);

my $maxredirects = 10;

my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

sub remove_dot_segments {
  my ($url) = @_;
  return $url unless $url =~ /^([^:\/]+:\/\/[^\/]+\/)(.*$)/;
  my ($intro, $path) = ($1, $2);
  my $trail= '';
  $trail = $1 if $path =~ s/([#\?].*$)//;
  my @p;
  for (split('/', $path)) {
    next if $_ eq '.' || $_ eq '';
    pop @p if $_ eq '..';
    push @p, $_ if $_ ne '..';
  }
  $path = join('/', @p);
  return "$intro$path$trail";
}

sub is_wanted_dodbinary {
  my ($pool, $p, $path, $doverify) = @_;
  my @opts = ('evra' => 1);
  if ($doverify && $path =~ /\.apk$/) {
    push @opts, 'verifyapkdatasection' => 1;
    my $hdrid = defined(&BSSolv::pool::pkg2hdrid) ? $pool->pkg2hdrid($p) : undef;
    if ($hdrid) {
      $hdrid =~ s/^sha1:/X1/;
      $hdrid =~ s/^sha256:/X2/;
      push @opts, 'verifyapkchksum' => $hdrid;
    }
  }
  my $q = eval { Build::query($path, @opts) };
  warn("binary query of $path: $@") if $@;
  return 0 unless $q;
  my $data = $pool->pkg2data($p);
  $data->{'arch'} = $q->{'arch'} if $path =~ /\.apk$/;	# apk metadata has wrong arch
  $data->{'release'} = '__undef__' unless defined $data->{'release'};
  $q->{'release'} = '__undef__' unless defined $q->{'release'};
  return 0 if $data->{'name'} ne $q->{'name'} ||
	      ($data->{'arch'} || '') ne ($q->{'arch'} || '') ||
	      ($data->{'epoch'} || 0) != ($q->{'epoch'} || 0) ||
	      $data->{'version'} ne $q->{'version'} ||
	      $data->{'release'} ne $q->{'release'};
  BSVerify::verify_nevraquery($q) if $doverify;		# just in case
  return 1;
}

sub is_wanted_dodcontainer {
  my ($pool, $p, $path, $doverify) = @_;
  my $q = BSUtil::retrieve("$path.obsbinlnk", 1);
  return 0 unless $q;
  my $data = $pool->pkg2data($p);
  return 0 if $data->{'name'} ne $q->{'name'} || $data->{'version'} ne $q->{'version'};
  BSVerify::verify_nevraquery($q) if $doverify;		# just in case
  return 1;
}

sub fetchdodcontainer {
  my ($gdst, $pool, $repo, $p, $handoff) = @_;

  my $pkgname = $pool->pkg2name($p);
  $pkgname =~ s/^container://;
  BSVerify::verify_filename($pkgname);
  BSVerify::verify_simple($pkgname);
  my $dir = "$gdst/:full";

  if (-e "$dir/$pkgname.obsbinlnk" && -e "$dir/$pkgname.containerinfo") {
    # package exists, why are we called? verify that it matches our expectations
    return "$dir/$pkgname.tar" if is_wanted_dodcontainer($pool, $p, "$dir/$pkgname");
  }
  # we really need to download, handoff to ajax if not already done
  BSHandoff::handoff_part('dod', @$handoff) if $handoff && !$BSStdServer::isajax;

  # download all missing blobs
  my $path = $pool->pkg2path($p);
  die("bad DoD container path: $path\n") unless $path =~ /^(.*)\?(.*?)$/;
  my $regrepo = $1;
  my @blobs = split(',', $2);
  return undef unless BSRepServer::Registry::download_blobs($dir, $repo->dodurl(), $regrepo, \@blobs, $proxy, $maxredirects);

  # write containerinfo and obsbinlnk files
  my $data = $pool->pkg2data($p);
  BSRepServer::Registry::construct_containerinfo($dir, $pkgname, $data, \@blobs);
  return "$dir/$pkgname.tar";
}

sub fetchdodbinary {
  my ($gdst, $pool, $repo, $p, $handoff) = @_;

  die($repo->name()." is no dod repo\n") unless $repo->dodurl();
  my $pkgname = $pool->pkg2name($p);
  return fetchdodcontainer($gdst, $pool, $repo, $p, $handoff) if $pkgname =~ /^container:/;
  my $path = $pool->pkg2path($p);
  die("$path has an unsupported suffix\n") unless $path =~ /\.($binsufsre)$/;
  my $suf = $1;
  if (defined(&BSSolv::pool::pkg2inmodule) && $pool->pkg2inmodule($p)) {
    $pkgname .= '-' . $pool->pkg2evr($p) . '.' . $pool->pkg2arch($p);
  }
  $pkgname .= ".$suf";
  BSVerify::verify_filename($pkgname);
  BSVerify::verify_simple($pkgname);
  my $localname = "$gdst/:full/$pkgname";
  if (-e $localname) {
    # package exists, why are we called? verify that it matches our expectations
    return $localname if is_wanted_dodbinary($pool, $p, $localname);
  }
  # we really need to download, handoff to ajax if not already done
  BSHandoff::handoff_part('dod', @$handoff) if $handoff && !$BSStdServer::isajax;
  my $url = $repo->dodurl();
  $url .= '/' unless $url =~ /\/$/;
  $url .= $pool->pkg2path($p);
  my $tmp = "$gdst/:full/.dod.$$.$pkgname";
  # fix url
  $url = remove_dot_segments $url;
  #print "fetching: $url\n";
  my $param = {'uri' => $url, 'filename' => $tmp, 'receiver' => \&BSHTTP::file_receiver, 'proxy' => $proxy};
  $param->{'maxredirects'} = $maxredirects if defined $maxredirects;
  my $r;
  eval { $r = BSWatcher::rpc($param); };
  if ($@) {
    $@ =~ s/(\d* *)/$1$url: /;
    die($@);
  }
  return unless defined $r;
  my $checksum;
  $checksum = $pool->pkg2checksum($p) if defined &BSSolv::pool::pkg2checksum;
  eval {
    # verify the checksum if we know it
    die("checksum error for $tmp, expected $checksum\n") if $checksum && !$pool->verifypkgchecksum($p, $tmp);
    # also make sure that the evra matches what we want
    die("downloaded package is not the one we want\n") unless is_wanted_dodbinary($pool, $p, $tmp, 1);
  };
  if ($@) {
    unlink($tmp);
    die($@);
  }
  rename($tmp, $localname) || die("rename $tmp $localname: $!\n");
  return $localname;
}

sub setmissingdodresources {
  my ($gdst, $id, $dodresources) = @_;
  my $dir = "$gdst/:full";
  die("no doddata\n") unless -s "$dir/doddata";
  my @dr = sort(BSUtil::unify(@$dodresources));
  my $needed = BSUtil::retrieve("$dir/doddata.needed", 1);
  return if $needed && BSUtil::identical($needed->{$id} || [], \@dr);
  my $fd;
  if (!BSUtil::lockopen($fd, '>>', "$dir/doddata.needed", 1)) {
    warn("$dir/doddata.needed: $!\n");
    return;
  }
  $needed = {};
  $needed = BSUtil::retrieve("$dir/doddata.needed", 1) || {} if -s "$dir/doddata.needed";
  if (!@dr) {
    delete $needed->{$id};
    delete $needed->{''}->{$id} if $needed->{''}; 
  } else {
    $needed->{$id} = \@dr;
    $needed->{''}->{$id} = time();
  }
  BSUtil::store("$dir/.doddata.needed", "$dir/doddata.needed", $needed);
  close($fd);
}

1;

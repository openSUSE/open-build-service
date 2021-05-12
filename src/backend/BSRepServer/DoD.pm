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

use BSWatcher ':https';
use BSVerify;
use BSHandoff;
use BSStdServer;

use Build;

use strict;
use warnings;

my $proxy;
$proxy = $BSConfig::proxy if defined($BSConfig::proxy);

my $maxredirects = 3;

my @binsufs = qw{rpm deb pkg.tar.gz pkg.tar.xz pkg.tar.zst};
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

sub is_wanted_dodbinary {
  my ($pool, $p, $path, $doverify) = @_;
  my $q;
  eval { $q = Build::query($path, 'evra' => 1) };
  return 0 unless $q;
  my $data = $pool->pkg2data($p);
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

sub fetchdodbinary {
  my ($gdst, $pool, $repo, $p, $handoff) = @_;

  die($repo->name()." is no dod repo\n") unless $repo->dodurl();
  my $path = $pool->pkg2path($p);
  die("$path has an unsupported suffix\n") unless $path =~ /\.($binsufsre)$/;
  my $suf = $1;
  my $pkgname = $pool->pkg2name($p);
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
  BSHandoff::handoff(@$handoff) if $handoff && !$BSStdServer::isajax;
  my $url = $repo->dodurl();
  $url .= '/' unless $url =~ /\/$/;
  $url .= $pool->pkg2path($p);
  my $tmp = "$gdst/:full/.dod.$$.$pkgname";
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

1;

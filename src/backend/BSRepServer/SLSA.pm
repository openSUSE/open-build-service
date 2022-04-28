# Copyright (c) 2022 SUSE LLC
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
package BSRepServer::SLSA;

use strict;

use BSConfiguration;
use BSUtil;
use BSSQLite;
use Digest::SHA ();
use Data::Dumper;

use DBI qw(:sql_types);

my $reporoot = "$BSConfig::bsdir/build";
my $slsadir = "$BSConfig::bsdir/slsa";

sub sha256file {
  my ($fn) = @_;
  my $fd;
  open($fd, '<', $fn) || die("$fn: $!\n");
  my $ctx = Digest::SHA->new(256);
  $ctx->addfile($fd);
  close($fd);
  return $ctx->hexdigest();
}

sub connectdb {
  my ($prpa) = @_;
  mkdir_p("$slsadir/$prpa");
  my $h = BSSQLite::connectdb("$slsadir/$prpa/refs");
  create_tables($h);
  return $h;
}

sub create_tables {
  my ($h) = @_;
  BSSQLite::dbdo($h, <<'EOS');
CREATE TABLE IF NOT EXISTS refs(
  prpa TEXT,
  digest BLOB
)
EOS
  BSSQLite::dbdo($h, 'CREATE INDEX IF NOT EXISTS refs_idx_prpa on refs(prpa)');
  BSSQLite::dbdo($h, 'CREATE INDEX IF NOT EXISTS refs_idx_digest on refs(digest)');
}

sub read_gbininfo {
  my ($prpa) = @_;
  my $gdst = "$reporoot/$prpa";
  my $gbininfo = BSUtil::retrieve("$gdst/:bininfo", 1) || {};
  return $gbininfo unless  -e "$gdst/:bininfo.merge";
  my $gbininfo_m = BSUtil::retrieve("$gdst/:bininfo.merge", 1);
  $gbininfo_m = undef if $gbininfo_m && $gbininfo_m->{'/outdated'};
  if ($gbininfo_m) {
    for (keys %$gbininfo_m) {
      if ($gbininfo_m->{$_}) {
	$gbininfo->{$_} = $gbininfo_m->{$_};
      } else {
	delete $gbininfo->{$_};
      }
    }
  }
  return $gbininfo;
}

sub link_binary {
  my ($prpa, $gbininfo, $hint, $digest, $tmp) = @_;
 
  my $binname1 = '';
  my $binname2 = '';
  $binname1 = $hint;
  $binname1 =~ s/\.[^\.]+$//;
  $binname2 = $1 if $hint =~ /(.*)-([^-]+)-([^-]+)\.([^-]+)\.rpm$/;
  for my $packid (sort keys %$gbininfo) {
    for my $k (sort keys %{$gbininfo->{$packid}}) {
      my $ent = $gbininfo->{$packid}->{$k};
      next unless $ent->{'name'} && ($ent->{'name'} eq $binname1 || $ent->{'name'} eq $binname2);
      unlink($tmp);
      next unless link("$reporoot/$prpa/$packid/$ent->{'filename'}", $tmp);
      unlink("$tmp.prov");
      link("$reporoot/$prpa/$packid/_slsa_provenance_stmt.json", "$tmp.prov");
      return 1 if sha256file($tmp) eq $digest;
      unlink($tmp);
      unlink("$tmp.prov");
    }
  }
  return 0;
}

sub link_binaries {
  my ($prpa, $digests) = @_;

  my $gbininfo;
  for my $digest (sort keys %$digests) {
    next if -e "$slsadir/$prpa/$digest";
    mkdir_p("$slsadir/$prpa");
    $gbininfo ||= read_gbininfo($prpa);
    my $tmp = "$slsadir/$prpa/.incoming$$";
    die("404 binary $digests->{$digest} digest $digest does not exist in $prpa\n") unless link_binary($prpa, $gbininfo, $digests->{$digest}, $digest, $tmp);
    if (!link($tmp, "$slsadir/$prpa/$digest")) {
      my $err = "link $slsadir/$prpa/.incoming$$ $slsadir/$prpa/$digest: $!";
      unlink($tmp);
      unlink("$tmp.prov");
      die("$err\n") unless -e "$slsadir/$prpa/$digest";
    } else {
      link("$tmp.prov", "$slsadir/$prpa/$digest.prov");
      unlink($tmp);
      unlink("$tmp.prov");
    }
  }
}

sub add_references {
  my ($prpa, $refprpa, $digests) = @_;

  link_binaries($prpa, $digests);
  my $h = connectdb($prpa);
  BSSQLite::begin_work($h);
  my $got = $h->selectcol_arrayref("SELECT digest FROM refs WHERE prpa = ?", undef, $refprpa) || die($h->errstr);
  my %got = map {unpack("H*", $_) => 1} @$got;
  for my $digest (grep {!$got{$_}} sort keys %$digests) {
    BSSQLite::dbdo_bind($h, 'INSERT INTO refs(prpa,digest) VALUES(?,?)', [ $refprpa ], [ pack("H*", $digest), SQL_BLOB ]);
  }
  BSSQLite::commit($h);
}

sub set_references {
  my ($prpa, $refprpa, $digests) = @_;

  link_binaries($prpa, $digests) if $digests;
  my $h = connectdb($prpa);
  BSSQLite::begin_work($h);
  my $got = $h->selectcol_arrayref("SELECT digest FROM refs WHERE prpa = ?", undef, $refprpa) || die($h->errstr);
  my %got = map {unpack("H*", $_) => 1} @$got;
  for my $digest (grep {!$got{$_}} sort keys %$digests) {
    BSSQLite::dbdo_bind($h, 'INSERT INTO refs(prpa,digest) VALUES(?,?)', [ $refprpa ], [ pack("H*", $digest), SQL_BLOB ]);
  }
  delete $got{$_} for keys %$digests;
  for my $digest (sort keys %$got) {
    BSSQLite::dbdo_bind($h, 'DELETE FROM refs WHERE prpa = ? AND digest = ?', [ $refprpa ], [ pack("H*", $digest), SQL_BLOB ]);
  }
  BSSQLite::commit($h);
}

1;

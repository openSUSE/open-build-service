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

use Digest::SHA ();
use Data::Dumper;
use DBI qw(:sql_types);

use BSConfiguration;
use BSUtil;
use BSSQLite;
use BSRepServer::Containertar;


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
      if ($ent->{'filename'} =~ /\.obsbinlnk$/ && $hint =~ /\.tar$/) {
	my $fn = "$reporoot/$prpa/$packid/$ent->{'filename'}";
	$fn =~ s/\.obsbinlnk/\.tar/;
	next unless BSRepServer::Containertar::write_container($fn, $tmp, undef, $digest);
      } else {
        next unless link("$reporoot/$prpa/$packid/$ent->{'filename'}", $tmp);
      }
      unlink("$tmp.prov");
      link("$reporoot/$prpa/$packid/_slsa_provenance.json", "$tmp.prov");
      return 1 if sha256file($tmp) eq $digest;
      unlink($tmp);
      unlink("$tmp.prov");
    }
  }

  # if this is a dod repo check the full tree
  return link_binary_from_full($prpa, $hint, $digest, $tmp) if -e "$reporoot/$prpa/:full/doddata";

  return 0;
}

sub link_binary_from_full {
  my ($prpa, $hint, $digest, $tmp) = @_;

  $hint =~ s/^container:(.*\.tar)$/$1/;		# see fetchdodcontainer() in DoD.pm
  my $binname1 = '';
  my $binname2 = '';
  $binname1 = $hint;
  $binname1 =~ s/\.[^\.]+$//;
  $binname2 = $1 if $hint =~ /(.*)-([^-]+)-([^-]+)\.([^-]+)\.rpm$/;
  for my $bin (sort(ls("$reporoot/$prpa/:full"))) {
    if (($binname1 && $bin =~ /^\Q$binname1\E[-_\.]/) || ($binname2 && $bin =~ /^\Q$binname2\E[-_\.]/)) {
      unlink($tmp);
      if ($bin =~ /\.obsbinlnk$/ && $hint =~ /\.tar$/) {
	my $fn = "$reporoot/$prpa/:full/$bin";
	$fn =~ s/\.obsbinlnk/\.tar/;
	next unless BSRepServer::Containertar::write_container($fn, $tmp, undef, $digest);
      } else {
        next unless link("$reporoot/$prpa/:full/$bin", $tmp);
      }
      unlink("$tmp.prov");
      return 1 if sha256file($tmp) eq $digest;
    }
  }
  return 0;
}

sub link_binaries {
  my ($prpa, $digests, $configs) = @_;

  my $gbininfo;
  for my $digest (sort keys %$digests) {
    my $ddir = substr($digest, 0, 2);
    my $ddigest = "$ddir/$digest";
    next if -e "$slsadir/$prpa/$ddigest";
    mkdir_p("$slsadir/$prpa/$ddir");
    my $tmp = "$slsadir/$prpa/.incoming$$";
    my $filename = $digests->{$digest};
    if ($filename eq '_config') {
      if ($configs && $configs->{$digest} && Digest::SHA::sha256_hex($configs->{$digest}) eq $digest) {
	writestr($tmp, "$slsadir/$prpa/$ddigest", $configs->{$digest});
	next;
      }
      die("404 a config with digest $digest does not exist in $prpa\n");
    }
    $gbininfo ||= read_gbininfo($prpa);
    die("404 binary $digests->{$digest} digest $digest does not exist in $prpa\n") unless link_binary($prpa, $gbininfo, $filename, $digest, $tmp);
    if (!link($tmp, "$slsadir/$prpa/$ddigest")) {
      my $err = "link $slsadir/$prpa/.incoming$$ $slsadir/$prpa/$ddigest: $!";
      unlink($tmp);
      unlink("$tmp.prov");
      die("$err\n") unless -e "$slsadir/$prpa/$ddigest";
    } else {
      link("$tmp.prov", "$slsadir/$prpa/$ddigest.prov");
      unlink($tmp);
      unlink("$tmp.prov");
    }
  }
}

sub add_references {
  my ($prpa, $refprpa, $digests, $configs) = @_;

  link_binaries($prpa, $digests, $configs);
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

sub get_references {
  my ($prpa, $digest) = @_;
  my $ddigest = substr($digest, 0, 2).'/'.$digest;
  die("404: unknown file in $prpa digest $digest\n") unless -e "$slsadir/$prpa/$ddigest";
  my $h = connectdb($prpa);
  BSSQLite::begin_work($h);
  my $dig = pack("H*", $digest);
  my $sh = BSSQLite::dbdo_bind($h, 'SELECT prpa FROM refs WHERE digest = ?', [ $dig, SQL_BLOB ]);
  my ($refprpa);
  $sh->bind_columns(\$refprpa);
  my @refs;
  push @refs, $refprpa while $sh->fetch();
  die($sh->errstr) if $sh->err();
  BSSQLite::commit($h);
  return @refs;
}

sub openfile {
  my ($prpa, $digest, $filename) = @_;
  my $fd;
  my $ddigest = substr($digest, 0, 2).'/'.$digest;
  if ($filename =~ /slsa_provenance\.json$/) {
    open($fd, '<', "$slsadir/$prpa/$ddigest.prov") || die("404: unknown provenance file $prpa/$filename for digest $digest\n");
  } else {
    open($fd, '<', "$slsadir/$prpa/$ddigest") || die("404: unknown file $prpa/$filename with digest $digest\n");
  }
  return $fd;
}

1;

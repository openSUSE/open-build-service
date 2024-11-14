#
# Copyright (c) 2016 Michael Schroeder, Novell Inc.
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
################################################################
#
# PGP packet parsing functions
#

package BSPGP;

use MIME::Base64 ();
use Digest::SHA ();

use strict;

sub pkdecodetaglenoff {
  my ($pkg) = @_;
  my $tag = unpack('C', $pkg);
  die("not a pgp packet\n") unless $tag & 128;
  my $len;
  my $off = 1;
  if ($tag & 64) {
    # new packet format
    $tag &= 63;
    $len = unpack('C', substr($pkg, 1));
    if ($len < 192) {
      $off = 2;
    } elsif ($len >= 192 && $len < 224) {
      $len = (($len - 192) << 8) + unpack('C', substr($pkg, 2)) + 192;
      $off = 3;
    } elsif ($len == 255) {
      $len = unpack('N', substr($pkg, 2));
      $off = 6;
    } else {
      die("can't deal with partial body lengths\n");
    }
  } else {
    # old packet format
    if (($tag & 3) == 0) {
      $len = unpack('C', substr($pkg, 1));
      $off = 2;
    } elsif (($tag & 3) == 1) {
      $len = unpack('n', substr($pkg, 1));
      $off = 3;
    } elsif (($tag & 3) == 2) {
      $len = unpack('N', substr($pkg, 1));
      $off = 5;
    } else {
      die("cannot deal with unspecified packet length\n");
    }
    $tag = ($tag & 60) >> 2;
  }
  die("truncated pgp packet\n") if length($pkg) < $off + $len;
  return ($tag, $len, $off);
}

sub pkdecodepacket {
  my ($pk) = @_;
  my ($tag, $len, $off) = pkdecodetaglenoff($pk);
  return ($tag, substr($pk, $off, $len), substr($pk, $len + $off));
}

sub pkdecodesubpacket {
  my ($pk) = @_;
  my ($tag, $len, $off) = pkdecodetaglenoff(pack('C', 0xc0).$pk);
  return (unpack('C', substr($pk, $off - 1, 1)), substr($pk, $off, $len - 1), substr($pk, $len + $off - 1));
}

sub pkencodepacket {
  my ($tag, $d) = @_;
  # always uses the old format
  my $l = length($d);
  die if $tag < 0 || $tag >= 16;
  return pack('CC', 128 + 4 * $tag, $l).$d if $l < 256;
  return pack('Cn', 128 + 4 * $tag + 1, $l).$d if $l < 65536;
  return pack('CN', 128 + 4 * $tag + 2, $l).$d;
}

sub pk2times {
  my ($pk) = @_;
  my ($kct, $kex, $rct);
  my ($tag, $pack);
  ($tag, $pack, $pk) = pkdecodepacket($pk);
  die("not a public key\n") unless $tag == 6;
  $kct = unpack('N', substr($pack, 1, 4));
  while ($pk ne '') {
    ($tag, $pack, $pk) = pkdecodepacket($pk);
    next if $tag != 2;				# signature
    my ($sver, $stype) = unpack('CC', substr($pack, 0, 2));
    next unless $sver == 4 && $stype == 19;	# positive certification of userid and pubkey
    my $plen = unpack('n', substr($pack, 4, 2));
    $pack = substr($pack, 6, $plen);
    my ($ct, $ex, $stag, $spack);
    while ($pack ne '') {
      ($stag, $spack, $pack) = pkdecodesubpacket($pack);
      $stag -= 128 if $stag >= 128;	# mask critical bit
      $ct = unpack('N', $spack) if $stag == 2;
      $ex = unpack('N', $spack) if $stag == 9;
    }
    $kex = $ex if defined($ex) && (!defined($kex) || $kex > $ex);
    $rct = $ct if defined($ct) && (!defined($rct) || $rct > $ct);
  }
  my $d = {};
  $d->{'key_create'} = $kct if defined $kct;
  $d->{'selfsig_create'} = $rct if defined $rct;
  $d->{'key_expire'} = $rct + $kex if defined($rct) && defined($kex);
  return $d;
}

sub pk2userid {
  my ($pk) = @_;
  my ($tag, $pack);
  ($tag, $pack, $pk) = pkdecodepacket($pk);
  die("not a public key\n") unless $tag == 6;
  while ($pk ne '') {
    ($tag, $pack, $pk) = pkdecodepacket($pk);
    return $pack if $tag == 13;
  }
  return undef;
}

sub pk2expire {
  my ($pk) = @_;
  my $d = pk2times($pk) || {};
  return $d->{'key_expire'};
}

sub pk2keydata {
  my ($pk) = @_;
  my ($tag, $pack);
  ($tag, $pack, $pk) = pkdecodepacket($pk);
  die("not a public key\n") unless $tag == 6;
  my $ver = unpack('C', substr($pack, 0, 1));
  if ($ver == 3) {
    $pack = substr($pack, 7);
  } elsif ($ver == 4) {
    $pack = substr($pack, 5);
  } else {
    die("unknown pubkey version\n");
  }
  my $algo = unpack('C', $pack);
  my $nmpi;
  if ($algo == 1) {
    $algo = 'rsa';
    $nmpi = 2;
  } elsif ($algo == 17) {
    $algo = 'dsa';
    $nmpi = 4;
  } elsif ($algo == 19) {
    $algo = 'ecdsa';
    $nmpi = 1;
  } elsif ($algo == 22) {
    $algo = 'eddsa';
    $nmpi = 1;
  } else {
    die("unknown pubkey algorithm\n");
  }
  $pack = substr($pack, 1);
  my $curve;
  if ($algo eq 'ecdsa' || $algo eq 'eddsa') {
    my $clen = unpack('C', $pack);
    die("bad curve len\n") if $clen == 0 || $clen == 255;
    $curve = unpack('H*', substr($pack, 1, $clen));
    $curve = 'ed25519' if $curve eq '2b06010401da470f01';
    $curve = 'nistp256' if $curve eq '2a8648ce3d030107';
    $curve = 'nistp384' if $curve eq '2b81040022';
    $curve = 'ed448' if $curve eq '2b6571';
    $pack = substr($pack, 1 + $clen);
  }
  my @mpis;
  while ($nmpi-- > 0) {
    my $bits = unpack('n', $pack);
    my $bytes = ($bits + 7) >> 3;
    push @mpis, { 'bits' => $bits, 'data' => substr($pack, 2, $bytes) };
    $pack = substr($pack, $bytes + 2);
  }
  my $keysize = ($mpis[0]->{'bits'} + 31) & ~31;
  $keysize = $mpis[0]->{'bits'} - 7 if $algo eq 'eddsa';
  $keysize = ($mpis[0]->{'bits'} - 3) / 2 if $algo eq 'ecdsa';
  my $data = { 'algo' => $algo, 'mpis' => \@mpis, 'keysize' => $keysize };
  $data->{'curve'} = $curve if $curve;
  return $data;
}

sub pk2algo {
  my ($pk) = @_;
  my $d = pk2keydata($pk);
  return $d->{'algo'};
}

sub pk2keysize {
  my ($pk) = @_;
  my $d = pk2keydata($pk);
  return $d->{'keysize'};
}


sub pk2fingerprint_keyid {
  my ($pk) = @_;
  my ($tag, $pack);
  ($tag, $pack, $pk) = pkdecodepacket($pk);
  die("not a public key\n") unless $tag == 6;
  my $ver = unpack('C', substr($pack, 0, 1));
  die("fingerprint calculation needs at least V4 keys\n") if $ver < 4;
  my $fp = Digest::SHA::sha1_hex(pack('Cn', 0x99, length($pack)).$pack);
  return $fp, substr($fp, -16, 16), $ver;
}

sub pk2fingerprint {
  return (pk2fingerprint_keyid(@_))[0];
}

sub pk2sigdata {
  my ($pk) = @_; 
  my ($tag, $pack);
  ($tag, $pack, $pk) = pkdecodepacket($pk);
  die("not a signature\n") unless $tag == 2;
  my $d = {};
  my ($type, $algo, $hash);
  my $ver = unpack('C', substr($pack, 0, 1));
  if ($ver == 3) {
    $type = unpack('C', substr($pack, 2, 1));
    $d->{'signtime'} = unpack('N', substr($pack, 3, 4));
    $d->{'issuer'} = unpack('H*', substr($pack, 7, 8));
    $algo = unpack('C', substr($pack, 15, 1));
    $hash = unpack('C', substr($pack, 16, 1));
  } elsif ($ver == 4) {
    ($type, $algo, $hash) = unpack('CCC', substr($pack, 1, 3));
    my $plen = unpack('n', substr($pack, 4, 2));
    my $pack2 = substr($pack, 6 + $plen + 2, unpack('n', substr($pack, 6 + $plen, 2)));
    $pack = substr($pack, 6, $plen);
    for my $hashed (1, 0) {
      while ($pack ne '') {
        my ($stag, $spack);
        ($stag, $spack, $pack) = pkdecodesubpacket($pack);
        $stag -= 128 if $stag >= 128;	# mask critical bit
        $d->{'signtime'} = unpack('N', $spack) if $stag == 2 && $hashed;
        $d->{'issuer'} = unpack('H*', substr($spack, 0, 8)) if $stag == 16;
      }
      $pack = $pack2;
    }
  } else {
    die("unknown sig version\n");
  }
  $d->{'algo'} = 'rsa' if $algo == 1;
  $d->{'algo'} = 'dsa' if $algo == 17;
  $d->{'algo'} = 'ecdsa' if $algo == 19;
  $d->{'algo'} = 'eddsa' if $algo == 22;
  $d->{'hash'} = 'md5' if $hash == 1;
  $d->{'hash'} = 'sha1' if $hash == 2;
  $d->{'hash'} = 'sha256' if $hash == 8;
  $d->{'hash'} = 'sha384' if $hash == 9;
  $d->{'hash'} = 'sha512' if $hash == 10;
  $d->{'hash'} = 'sha224' if $hash == 11;
  $d->{'pgptype'} = $type;
  $d->{'pgpalgo'} = $algo;
  $d->{'pgphash'} = $hash;
  return $d;
}

sub pk2signtime {
  my ($pk) = @_; 
  my $d = pk2sigdata($pk);
  return $d->{'signtime'};
}

sub unarmor {
  my ($str) = @_;
  $str =~ s/\n+$//s;
  $str =~ s/.*\n\n//s;
  $str =~ s/\n=.*/\n/s;
  my $pk = MIME::Base64::decode($str);
  die("unarmor failed\n") unless $pk;
  return $pk;
}

sub onepass_signed_message {
  my ($data, $sig, $fn, $t) = @_;
  die("filename too long\n") if length($fn) > 255;
  my $sd = pk2sigdata($sig);
  die("no issuer in signature\n") unless $sd->{'issuer'};
  my $onepass_sig = pack('CCCCH16C', 3, $sd->{'pgptype'}, $sd->{'pgphash'}, $sd->{'pgpalgo'}, $sd->{'issuer'}, 1);
  $t ||= $sd->{'signtime'} || time();
  my $literal_data = pack('CCa*N', 0x62, length($fn), $fn, $t).$data;
  return pkencodepacket(4, $onepass_sig).pkencodepacket(11, $literal_data).$sig;
}

1;

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
use Digest;

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
    } elsif ($len != 255) {
      $len = (($len - 192) << 8) + unpack('C', substr($pkg, 2)) + 192; 
      $off = 3; 
    } else {
      $len = unpack('N', substr($pkg, 2)); 
      $off = 5; 
    }    
  } else {
    # old packet format
    if (($tag & 3) == 0) { 
      $len = unpack('C', substr($pkg, 1)); 
      $off = 2; 
    } elsif (($tag & 3) == 1) { 
      $len = unpack('n', substr($pkg, 1)); 
      $off = 3; 
    } elsif (($tag & 3) == 1) { 
      $len = unpack('N', substr($pkg, 1)); 
      $off = 6; 
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
  } else {
    die("unknown pubkey algorithm\n");
  }
  $pack = substr($pack, 1);
  my @mpis;
  while ($nmpi-- > 0) {
    my $bits = unpack('n', $pack);
    my $bytes = ($bits + 7) >> 3;
    push @mpis, { 'bits' => $bits, 'data' => substr($pack, 2, $bytes) };
    $pack = substr($pack, $bytes + 2);
  }
  my $keysize = ($mpis[0]->{'bits'} + 31) & ~31;
  return { 'algo' => $algo, 'mpis' => \@mpis, 'keysize' => $keysize };
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


sub pk2fingerprint {
  my ($pk) = @_;
  my ($tag, $pack);
  ($tag, $pack, $pk) = pkdecodepacket($pk);
  die("not a public key\n") unless $tag == 6;
  my $ver = unpack('C', substr($pack, 0, 1));
  die("fingerprint calculation needs at least V4 keys\n") if $ver < 4;
  my $ctx = Digest->new("SHA-1");
  $ctx->add(pack('Cn', 0x99, length($pack)).$pack);
  return $ctx->hexdigest();
}

sub pk2sigdata {
  my ($pk) = @_; 
  my ($tag, $pack);
  ($tag, $pack, $pk) = pkdecodepacket($pk);
  die("not a signature\n") unless $tag == 2;
  my $d = {};
  my $algo;
  my $ver = unpack('C', substr($pack, 0, 1));
  if ($ver == 3) {
    $d->{'signtime'} = unpack('N', substr($pack, 3, 4));
    $d->{'issuer'} = unpack('H*', substr($pack, 7, 8));
    $algo = unpack('C', substr($pack, 15, 1));
  } elsif ($ver == 4) {
    $algo = unpack('C', substr($pack, 2, 1));
    my $plen = unpack('n', substr($pack, 4, 2));
    my $pack2 = substr($pack, 6 + $plen + 2, unpack('n', substr($pack, 6 + $plen, 2)));
    $pack = substr($pack, 6, $plen);
    for my $hashed (1, 0) {
      while ($pack ne '') {
        my ($stag, $spack);
        ($stag, $spack, $pack) = pkdecodesubpacket($pack);
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

1;

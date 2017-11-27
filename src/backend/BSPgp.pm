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
# Pgp packet parsing functions
#

package BSPgp;

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
      die("can't deal with unspecified packet length\n");
    }    
    $tag = ($tag & 60) >> 2;
  }
  return ($tag, $len, $off);
}

sub pk2times {
  my ($pk) = @_;
  my ($kct, $kex, $rct);
  my ($tag, $len, $off) = pkdecodetaglenoff($pk);
  die("not a public key\n") unless $tag == 6;
  $kct = unpack('N', substr($pk, $off + 1, 4));
  $pk = substr($pk, $len + $off);
  while ($pk ne '') {
    ($tag, $len, $off) = pkdecodetaglenoff($pk);
    my $pack = substr($pk, $off, $len);
    $pk = substr($pk, $len + $off);
    next if $tag != 2;
    my $sver = unpack('C', substr($pack, 0, 1));
    next unless $sver == 4;
    my $stype = unpack('C', substr($pack, 1, 1));
    next unless $stype == 19; # positive certification of userid and pubkey
    my $plen = unpack('n', substr($pack, 4, 2));
    $pack = substr($pack, 6, $plen);
    my ($ct, $ex);
    while ($pack ne '') {
      $pack = pack('C', 0xc0).$pack;
      my ($stag, $slen, $soff) = pkdecodetaglenoff($pack);
      my $spack = substr($pack, $soff, $slen);
      $pack = substr($pack, $slen + $soff);
      $stag = unpack('C', substr($spack, 0, 1));
      $ct = unpack('N', substr($spack, 1, 4)) if $stag == 2;
      $ex = unpack('N', substr($spack, 1, 4)) if $stag == 9;
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
  my ($tag, $len, $off) = pkdecodetaglenoff($pk);
  die("not a public key\n") unless $tag == 6;
  my $pack = substr($pk, $off, $len);
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
  return { 'algo' => $algo, 'mpis' => \@mpis };
}

sub pk2algo {
  my ($pk) = @_;
  my $d = pk2keydata($pk);
  return $d->{'algo'};
}

sub pk2keysize {
  my ($pk) = @_;
  my $d = pk2keydata($pk);
  return ($d->{'mpis'}->[0]->{'bits'} + 15) & ~15;
}


sub pk2fingerprint {
  my ($pk) = @_;
  my ($tag, $len, $off) = pkdecodetaglenoff($pk);
  die("not a public key\n") unless $tag == 6;
  my $pack = substr($pk, $off, $len);
  my $ver = unpack('C', substr($pack, 0, 1));
  die("fingerprint calculation needs at least V4 keys\n") if $ver < 4;
  my $ctx = Digest->new("SHA-1");
  $ctx->add(pack('Cn', 0x99, $len)."$pack");
  return $ctx->hexdigest();
}

sub pk2signtime {
  my ($pk) = @_; 
  my ($tag, $len, $off) = pkdecodetaglenoff($pk);
  die("not a signature\n") unless $tag == 2;
  my $pack = substr($pk, $off, $len);
  my $sver = unpack('C', substr($pack, 0, 1));
  return unpack('N', substr($pack, 3, 4)) if $sver == 3;
  die("unsupported sig version\n") if $sver != 4;
  my $plen = unpack('n', substr($pack, 4, 2));
  $pack = substr($pack, 6, $plen);
  while ($pack ne '') {
    $pack = pack('C', 0xc0).$pack;
    ($tag, $len, $off) = pkdecodetaglenoff($pack);
    my $spack = substr($pack, $off, $len);
    $pack = substr($pack, $len + $off);
    $tag = unpack('C', substr($spack, 0, 1));
    return unpack('N', substr($spack, 1, 4)) if $tag == 2;
  }
  return undef;
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

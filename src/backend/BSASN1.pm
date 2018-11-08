#
# Copyright (c) 2017 SUSE Inc.
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
# ASN1 helper functions
#

package BSASN1;

use Encode;
use MIME::Base64 ();

use strict;

our $UNIV 	= 0x00;
our $APPL	= 0x40;
our $CONT	= 0x80;
our $PRIV	= 0xc0;

our $CONS	= 0x20;

our $BOOLEAN	= 0x01;
our $INTEGER	= 0x02;
our $BIT_STRING	= 0x03;
our $OCTET_STRING = 0x04;
our $NULL	= 0x05;
our $OBJ_ID	= 0x06;
our $REAL	= 0x09;
our $ENUMERATED	= 0x0a;
our $UTF8STRING	= 0x0c;
our $SEQUENCE	= 0x10;
our $SET	= 0x11;
our $NUMERICSTRING = 0x12;
our $PRINTABLESTRING = 0x13;
our $IA5STRING = 0x16;
our $UTCTIME	= 0x17;
our $GENTIME	= 0x18;
our $UNIVERSALSTRING = 0x1c;
our $BMPSTRING	= 0x1e;

sub utctime {
  my ($t) = @_;
  my @gt = gmtime($t || time());
  return sprintf "%02d%02d%02d%02d%02d%02dZ", $gt[5] % 100, $gt[4] + 1, @gt[3,2,1,0];
}

sub gentime {
  my ($t) = @_;
  my @gt = gmtime($t || time());
  return sprintf "%04d%02d%02d%02d%02d%02dZ", $gt[5] + 1900, $gt[4] + 1, @gt[3,2,1,0];
}

sub der2pem {
  my ($in, $what) = @_;
  my $ret = MIME::Base64::encode_base64($in, '');
  $ret =~ s/(.{64})/$1\n/g;
  $ret =~ s/\n$//s;
  return "-----BEGIN $what-----\n$ret\n-----END $what-----\n";
}

sub pem2der {
  my ($in, $what) = @_;
  return undef unless $in =~ s/^.*?-----BEGIN \Q$what\E-----\n//s;
  return undef unless $in =~ s/\n-----END \Q$what\E-----.*$//s;
  return MIME::Base64::decode_base64($in);
}

# raw packing/unpacking helpers
sub asn1_pack {
  my ($tag, @data) = @_;
  my $data = join('', @data);
  my $l = length($data);
  return pack("CC", $tag, $l) . $data if $l < 128;
  my $ll = $l >> 8 ? $l >> 16 ? $l >> 24 ? 4 : 3 : 2 : 1;
  return pack("CCa*", $tag, $ll | 0x80,  substr(pack("N", $l), -$ll)) . $data;
}

sub asn1_unpack {
  my ($in, $allowed, $optional, $exact) = @_;
  $allowed = [ $allowed ] if $allowed && !ref($allowed);
  if (length($in) < 2) {
    return ($in, undef, '', '') if $optional || grep {!defined($_)} @{$allowed || []};
    die("unexpected end of asn1 data\n");
  }
  my ($tag, $l) = unpack("CC", $in);
  if ($allowed) {
    if (!grep {defined($_) && $tag == $_}  @$allowed) {
      return ($in, undef, '', '') if $optional || grep {!defined($_)} @{$allowed || []};
      die("unexpected tag $tag, expected @$allowed\n");
    }
  }
  my $off = 2;
  if ($l >= 128) {
    $l -= 128;
    $off += $l;
    die("unsupported asn1 length $l\n") if $l < 1 || $l > 4;
    $l = unpack("\@${l}N", pack('xxxx').substr($in, 2, 4));
  }
  die("unexpected end of asn1 data\n") if length($in) < $off + $l;
  die("tailing data at end of asn1 element\n") if $exact && length($in) != $off + $l;
  return (substr($in, $off + $l), $tag, substr($in, $off, $l), substr($in, 0, $off + $l));
}

# little pack helpers
sub asn1_null {
  return asn1_pack($NULL);
}

sub asn1_boolean {
  return asn1_pack($BOOLEAN, pack('C', $_[0] ? 255 : 0));
}

sub asn1_integer {
  return asn1_pack($INTEGER, pack('c', $_[0])) if $_[0] >= -128 && $_[0] <= 127;
  return asn1_pack($INTEGER, substr(pack('N', $_[0]), 3 - (length(sprintf('%b', $_[0] >= 0 ? $_[0] : ~$_[0])) >> 3)));
}

sub asn1_integer_mpi {
  my $mpi = $_[0];
  $mpi = pack('C', 0) if length($mpi) == 0;
  $mpi = substr($mpi, 1) while length($mpi) > 1 && unpack('C', $mpi) == 0;
  return asn1_pack($INTEGER, unpack('C', $mpi) >= 128 ? pack('C', 0).$mpi : $mpi);
}

sub asn1_enumerated {
  return asn1_pack($ENUMERATED, pack('c', $_[0])) if $_[0] >= -128 && $_[0] <= 127;
  return asn1_pack($ENUMERATED, substr(pack('N', $_[0]), 3 - (length(sprintf('%b', $_[0] >= 0 ? $_[0] : ~$_[0])) >> 3)));
}

sub asn1_obj_id {
  my ($o1, $o2, @o) = @_;
  return asn1_pack($OBJ_ID, pack('w*', $o1 * 40 + $o2, @o));
}

sub asn1_sequence {
  return asn1_pack($CONS | $SEQUENCE, @_);
}

sub asn1_set {
  return asn1_pack($CONS | $SET, @_);
}

sub asn1_utctime {
  return asn1_pack($UTCTIME, utctime(@_));
}

sub asn1_gentime {
  return asn1_pack($GENTIME, gentime(@_));
}

sub asn1_octet_string {
  return asn1_pack($OCTET_STRING, $_[0]);
}

sub asn1_string {
  my ($s, $tag) = @_;
  Encode::_utf8_off($s);	# hope for the best
  return asn1_pack($tag || $UTF8STRING, $s);
}

sub asn1_bytes {
  return asn1_pack($BIT_STRING, pack('C', 0).$_[0]);
}

sub asn1_tagged {
  return asn1_pack(($_[0] < 0x40 ? $CONT : 0) | $CONS | $_[0], $_[1]);
}

sub asn1_tagged_implicit {
  my ($rest, $tag, $body) = asn1_unpack($_[1]);
  return asn1_pack(($_[0] < 0x40 ? $CONT : 0) | ($tag & $CONS) | $_[0], $body).$rest;
}

sub asn1_bits_list {
  my $v = '';
  vec($v, $_ ^ 7, 1) = 1 for @_;
  my $maxbit = $v eq '' ? 7 : (sort {$b <=> $a} @_)[0];
  return asn1_pack($BIT_STRING, pack('C', 7 - ($maxbit % 8)).$v);
}


# little unpack helpers (intag = 0 : any tag allowed)

sub asn1_gettag {
  return (asn1_unpack(@_))[1];
}

sub asn1_unpack_body {
  my ($in, $intag, $default) = @_;
  return (asn1_unpack($in, defined($intag) ? $intag : $default, undef, 1))[2];
}

sub asn1_unpack_integer {
  my $in = asn1_unpack_body($_[0], $_[1], $INTEGER);
  return 0 if $in eq '';
  return unpack('c', $in) if length($in) == 1;
  my $n = pack('C', unpack('C', $in) >= 128 ? 255 : 0) x 4;
  $n = unpack('N', substr("$n$in", -4));
  return unpack('C', $in) >= 128 ? $n - 4294967296 : $n;
}

sub asn1_unpack_integer_mpi {
  my $in = asn1_unpack_body($_[0], $_[1], $INTEGER);
  $in = substr($in, 1) while $in ne '' && unpack('C', $in) == 0;
  return $in;
}

sub asn1_unpack_sequence {
  my ($in, $intag, $allowed) = @_;
  $in = asn1_unpack_body($in, $intag, $CONS | $SEQUENCE);
  my @ret;
  my $tagbody;
  if ($allowed && ref($allowed)) {
    for my $all (@$allowed) {
      return @ret, $in if $all && !ref($all) && $all == -1;	# -1: get rest
      ($in, undef, undef, $tagbody) = asn1_unpack($in, $all);
      push @ret, $tagbody;
    }
    die("tailing data at end of asn1 sequence\n") if $in ne '';
    return @ret;
  }
  while ($in ne '') {
    ($in, undef, undef, $tagbody) = asn1_unpack($in, $allowed);
    push @ret, $tagbody;
  }
  return @ret;
}

sub asn1_unpack_set {
  my ($in, $intag, $allowed) = @_;
  my $in = asn1_unpack_body($in, $intag, $CONS | $SET);
  my @ret;
  my $tagbody;
  while ($in ne '') {
    ($in, undef, undef, $tagbody) = asn1_unpack($in, $allowed);
    push @ret, $tagbody;
  }
  return @ret;
}

sub asn1_unpack_bytes {
  my $in = asn1_unpack_body($_[0], $_[1], $BIT_STRING);
  die("unpack_bytes: bit number not multiple of 8\n") unless unpack('C', $in) == 0;
  return substr($in, 1);
}

sub asn1_unpack_octet_string {
  return asn1_unpack_body($_[0], $_[1], $OCTET_STRING);
}

sub asn1_unpack_string {
  my ($in, $intag) = @_;
  $intag = [ $UTF8STRING, $NUMERICSTRING, $PRINTABLESTRING, $IA5STRING, $BMPSTRING, $UNIVERSALSTRING ] unless defined $intag;
  my (undef, $tag, $in) = asn1_unpack($in, $intag, undef, 1);
  if ($tag == $BMPSTRING) {
    $in = Encode::decode('UCS-2BE', $in);
    Encode::_utf8_off($in);
  } elsif ($tag == $UNIVERSALSTRING) {
    $in = Encode::decode('UCS-4BE', $in);
    Encode::_utf8_off($in);
  }
  return $in;
}

sub asn1_unpack_bits_list {
  my $in = asn1_unpack_body($_[0], $_[1], $BIT_STRING);
  my $empty = unpack('C', $in);
  die("unpack_bits: empty bits not in range 0..7\n") if $empty > 7;
  $in = unpack('B*', substr($in, 1));
  substr($in, -$empty, $empty, '') if $empty;	# just in case
  my @res;
  substr($in, -1, 1, '') ne '0' && unshift(@res, length($in)) while $in ne '';
  return @res;
}

sub asn1_unpack_boolean {
  my $in = asn1_unpack_body($_[0], $_[1], $BOOLEAN);
  return unpack('C', $in) ? 1 : 0;
}

sub asn1_unpack_tagged {
  return asn1_unpack_body($_[0], $_[1], 0);
}

1;

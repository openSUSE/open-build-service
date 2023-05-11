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
  my @gt = gmtime(defined($t) ? $t : time());
  return sprintf "%02d%02d%02d%02d%02d%02dZ", $gt[5] % 100, $gt[4] + 1, @gt[3,2,1,0];
}

sub gentime {
  my ($t) = @_;
  my @gt = gmtime(defined($t) ? $t : time());
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
sub pack_raw {
  my ($tag, @data) = @_;
  my $data = join('', @data);
  my $l = length($data);
  return pack("CC", $tag, $l) . $data if $l < 128;
  my $ll = $l >> 8 ? $l >> 16 ? $l >> 24 ? 4 : 3 : 2 : 1;
  return pack("CCa*", $tag, $ll | 0x80,  substr(pack("N", $l), -$ll)) . $data;
}

sub unpack_raw {
  my ($in, $allowed, $optional, $exact) = @_;
  $allowed = [ $allowed ] if $allowed && !ref($allowed);
  if (length($in) < 2) {
    return ($in, undef, undef, '') if $optional || grep {!defined($_)} @{$allowed || []};
    die("unexpected end of asn1 data\n");
  }
  my ($tag, $l) = unpack("CC", $in);
  if ($allowed) {
    if (!grep {defined($_) && ($tag == $_ || !$_)} @$allowed) {
      return ($in, undef, undef, '') if $optional || grep {!defined($_)} @{$allowed || []};
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
sub pack_null {
  return pack_raw($NULL);
}

sub pack_boolean {
  return pack_raw($BOOLEAN, pack('C', $_[0] ? 255 : 0));
}

sub pack_integer {
  return pack_raw($INTEGER, pack('c', $_[0])) if $_[0] >= -128 && $_[0] <= 127;
  return pack_raw($INTEGER, substr(pack('N', $_[0]), 3 - (length(sprintf('%b', $_[0] >= 0 ? $_[0] : ~$_[0])) >> 3)));
}

sub pack_integer_mpi {
  my $mpi = $_[0];
  $mpi = pack('C', 0) if length($mpi) == 0;
  $mpi = substr($mpi, 1) while length($mpi) > 1 && unpack('C', $mpi) == 0;
  return pack_raw($INTEGER, unpack('C', $mpi) >= 128 ? pack('C', 0).$mpi : $mpi);
}

sub pack_enumerated {
  return pack_raw($ENUMERATED, pack('c', $_[0])) if $_[0] >= -128 && $_[0] <= 127;
  return pack_raw($ENUMERATED, substr(pack('N', $_[0]), 3 - (length(sprintf('%b', $_[0] >= 0 ? $_[0] : ~$_[0])) >> 3)));
}

sub pack_obj_id {
  my ($o1, $o2, @o) = @_;
  my $data = pack('w*', $o1 * 40 + $o2, @o);
  return pack("CC", $OBJ_ID, length($data)).$data if length($data) < 128;
  return pack_raw($OBJ_ID, $data);
}

sub pack_sequence {
  return pack_raw($CONS | $SEQUENCE, map {defined($_) ? $_ : ''} @_);
}

sub pack_set {
  return pack_raw($CONS | $SET, sort {$a cmp $b} @_);
}

sub pack_utctime {
  return pack_raw($UTCTIME, utctime(@_));
}

sub pack_gentime {
  return pack_raw($GENTIME, gentime(@_));
}

sub pack_octet_string {
  return pack_raw($OCTET_STRING, $_[0]);
}

sub pack_string {
  my ($s, $tag) = @_;
  Encode::_utf8_off($s);	# hope for the best
  return pack_raw($tag || $UTF8STRING, $s);
}

sub pack_bytes {
  return pack_raw($BIT_STRING, pack('C', 0).$_[0]);
}

sub pack_tagged {
  return pack_raw(($_[0] < 0x40 ? $CONT : 0) | $CONS | $_[0], $_[1]);
}

sub pack_tagged_implicit {
  my ($rest, $tag, $body) = unpack_raw($_[1]);
  return pack_raw(($_[0] < 0x40 ? $CONT : 0) | ($tag & $CONS) | $_[0], $body).$rest;
}

sub pack_bits_list {
  my $v = '';
  vec($v, $_ ^ 7, 1) = 1 for @_;
  my $maxbit = $v eq '' ? 7 : (sort {$b <=> $a} @_)[0];
  return pack_raw($BIT_STRING, pack('C', 7 - ($maxbit % 8)).$v);
}

sub pack_time {
  my $t = defined($_[0]) ? $_[0] : time();
  return pack_utctime($t) if $t >= -631152000 && $t < 2524608000;
  return pack_gentime($t);
}


# little unpack helpers (tag = 0 : any tag allowed)

sub gettag {
  return (unpack_raw(@_))[1];
}

sub unpack_body {
  my ($in, $tag, $default) = @_;
  return (unpack_raw($in, defined($tag) ? $tag : $default, undef, 1))[2];
}

sub unpack_integer {
  my $in = unpack_body($_[0], $_[1], $INTEGER);
  return 0 if $in eq '';
  return unpack('c', $in) if length($in) == 1;
  my $n = pack('C', unpack('C', $in) >= 128 ? 255 : 0) x 4;
  $n = unpack('N', substr("$n$in", -4));
  return unpack('C', $in) >= 128 ? $n - 4294967296 : $n;
}

sub unpack_integer_mpi {
  my $in = unpack_body($_[0], $_[1], $INTEGER);
  $in = substr($in, 1) while $in ne '' && unpack('C', $in) == 0;
  return $in;
}

sub unpack_sequence {
  my ($in, $tag, $allowed) = @_;
  $in = unpack_body($in, $tag, $CONS | $SEQUENCE);
  my @ret;
  my $tagbody;
  if ($allowed && ref($allowed)) {
    for my $all (@$allowed) {
      return @ret, $in if $all && !ref($all) && $all == -1;	# -1: get rest
      ($in, undef, undef, $tagbody) = unpack_raw($in, $all);
      push @ret, $tagbody;
    }
    die("tailing data at end of asn1 sequence\n") if $in ne '';
    return @ret;
  }
  while ($in ne '') {
    ($in, undef, undef, $tagbody) = unpack_raw($in, $allowed);
    push @ret, $tagbody;
  }
  return @ret;
}

sub unpack_obj_id {
  my @o = unpack('w*', unpack_body($_[0], $_[1], $OBJ_ID));
  if (@o && $o[0] < 80) {
    splice(@o, 0, 1, int($o[0] / 40), $o[0] % 40);
  } elsif (@o) {
    splice(@o, 0, 1, 2, $o[0] - 80);
  }
  return @o;
}

sub gm2t {
  my (@t) = @_;
  my $m = ($t[1] + 9) % 12;
  my $y = $t[0] - int($m / 10);
  my $d = 365 * $y + int ($y / 4) - int($y / 100) + int($y / 400) + int(($m * 306 + 5) / 10) + $t[2] - 719469;
  my $t = $d * 86400 + $t[3] * 3600 + $t[4] * 60 + $t[5];
  $t -= ($t[7] eq '-' ? -1 : 1) * ($t[8] * 3600 + $t[9] * 60) if $t[6] ne 'Z';
  return $t;
}

sub unpack_utctime {
  my $in = unpack_body($_[0], $_[1], $UTCTIME);
  my @t = $in =~ /^(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(Z|([-+])(\d\d)(\d\d))$/;
  die("bad utctime format\n") unless @t;
  $t[0] += $t[0] >= 50 ? 1900 : 2000;
  return gm2t(@t);
}

sub unpack_gentime {
  my $in = unpack_body($_[0], $_[1], $GENTIME);
  my @t = $in =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(Z|([-+])(\d\d)(\d\d))$/;
  die("bad gentime format\n") unless @t;
  return gm2t(@t);
}

sub unpack_set {
  my ($in, $tag, $allowed) = @_;
  $in = unpack_body($in, $tag, $CONS | $SET);
  my @ret;
  my $tagbody;
  while ($in ne '') {
    ($in, undef, undef, $tagbody) = unpack_raw($in, $allowed);
    push @ret, $tagbody;
  }
  return @ret;
}

sub unpack_bytes {
  my $in = unpack_body($_[0], $_[1], $BIT_STRING);
  die("unpack_bytes: bit number not multiple of 8\n") unless unpack('C', $in) == 0;
  return substr($in, 1);
}

sub unpack_octet_string {
  return unpack_body($_[0], $_[1], $OCTET_STRING);
}

sub unpack_string {
  my ($in, $tag) = @_;
  $tag = [ $UTF8STRING, $NUMERICSTRING, $PRINTABLESTRING, $IA5STRING, $BMPSTRING, $UNIVERSALSTRING ] unless defined $tag;
  (undef, $tag, $in) = unpack_raw($in, $tag, undef, 1);
  if ($tag == $BMPSTRING) {
    $in = Encode::decode('UCS-2BE', $in);
    Encode::_utf8_off($in);
  } elsif ($tag == $UNIVERSALSTRING) {
    $in = Encode::decode('UCS-4BE', $in);
    Encode::_utf8_off($in);
  }
  return $in;
}

sub unpack_bits_list {
  my $in = unpack_body($_[0], $_[1], $BIT_STRING);
  my $empty = unpack('C', $in);
  die("unpack_bits: empty bits not in range 0..7\n") if $empty > 7;
  $in = unpack('B*', substr($in, 1));
  substr($in, -$empty, $empty, '') if $empty;	# just in case
  my @res;
  substr($in, -1, 1, '') ne '0' && unshift(@res, length($in)) while $in ne '';
  return @res;
}

sub unpack_boolean {
  return unpack('C', unpack_body($_[0], $_[1], $BOOLEAN)) ? 1 : 0;
}

sub unpack_tagged {
  return unpack_body($_[0], $_[1], 0);
}

sub unpack_tagged_implicit {
  return pack_raw($_[2], unpack_body($_[0], $_[1], 0));
}

sub unpack_time {
  my ($in, $tag) = @_;
  $tag = gettag($in, defined($tag) ? $tag : [ $UTCTIME, $GENTIME ]);
  return unpack_utctime($in) if $tag eq $UTCTIME;
  return unpack_gentime($in) if $tag eq $GENTIME;
  die("unpack_time: unsupported tag $tag\n");
}

1;

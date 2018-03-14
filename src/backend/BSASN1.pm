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

use MIME::Base64 ();

use strict;


# x509 constants
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
our $UTF8STRING	= 0x0c;
our $SEQUENCE	= 0x10;
our $SET	= 0x11;
our $UTCTIME	= 0x17;
our $GENTIME	= 0x18;

our $oid_common_name   = asn1_obj_id(2, 5, 4, 3);
our $oid_country_name  = asn1_obj_id(2, 5, 4, 6);
our $oid_org_name      = asn1_obj_id(2, 5, 4, 10);
our $oid_org_unit_name = asn1_obj_id(2, 5, 4, 11);
our $oid_email_address = asn1_obj_id(1, 2, 840, 113549, 1, 9, 1);
our $oid_sha1   = asn1_obj_id(1, 3, 14, 3, 2, 26);
our $oid_sha256 = asn1_obj_id(2, 16, 840, 1, 101, 3, 4, 2, 1);
our $oid_sha512 = asn1_obj_id(2, 16, 840, 1, 101, 3, 4, 2, 3);
our $oid_id_dsa                  = asn1_obj_id(1, 2, 840, 10040, 4, 1);
our $oid_id_ec_public_key        = asn1_obj_id(1, 2, 840, 10045, 2, 1);
our $oid_prime256v1              = asn1_obj_id(1, 2, 840, 10045, 3, 1, 7);
our $oid_rsaencryption           = asn1_obj_id(1, 2, 840, 113549, 1, 1, 1);
our $oid_sha1withrsaencryption   = asn1_obj_id(1, 2, 840, 113549, 1, 1, 5);
our $oid_sha256withrsaencryption = asn1_obj_id(1, 2, 840, 113549, 1, 1, 11);
our $oid_key_usage         = asn1_obj_id(2, 5, 29, 15);
our $oid_basic_constraints = asn1_obj_id(2, 5, 29, 19);
our $oid_ext_key_usage     = asn1_obj_id(2, 5, 29, 37);
our $oid_code_signing  = asn1_obj_id(1, 3, 6, 1, 5, 5, 7, 3, 3);

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

sub asn1_pack {
  my ($tag, @data) = @_;
  my $ret = pack("C", $tag);
  my $data = join('', @data);
  my $l = length($data);
  return pack("CC", $tag, $l) . $data if $l < 128;
  my $ll = $l >> 8 ? $l >> 16 ? $l >> 24 ? 4 : 3 : 2 : 1;
  return pack("CCa*", $tag, $ll | 0x80,  substr(pack("N", $l), -$ll)) . $data;
}

sub asn1_unpack {
  my ($in, $allowed, $optional) = @_;
  if (length($in) < 2) {
    return (undef, undef, $in) if $optional;
    die("unexpected end of string\n");
  }
  my ($tag, $l) = unpack("CC", $in);
  if ($allowed) {
    $allowed = [ $allowed ] unless ref($allowed);
    if (!grep {$tag == $_}  @$allowed) {
      return (undef, undef, $in) if $optional;
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
  die("unexpected end of string\n") if length($in) < $off + $l;
  return ($tag, substr($in, $off, $l), substr($in, $off + $l));
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

# little helpers
sub asn1_null {
  return asn1_pack($NULL);
}

sub asn1_boolean {
  return asn1_pack($BOOLEAN, pack('C', $_[0] ? 255 : 0));
}

sub asn1_integer {
  return asn1_pack($INTEGER, pack('C', $_[0])) if $_[0] >= -128 && $_[0] <= 127;
  return asn1_pack($INTEGER, substr(pack('N', $_[0]), 3 - (length(sprintf('%b', $_[0] >= 0 ? $_[0] : ~$_[0])) >> 3)));
}

sub asn1_integer_mpi {
  my $mpi = $_[0];
  $mpi = pack('C', 0) if length($mpi) == 0;
  $mpi = substr($mpi, 1) while length($mpi) > 1 && unpack('C', $mpi) == 0;
  return asn1_pack($INTEGER, unpack('C', $mpi) >= 128 ? pack('C', 0).$mpi : $mpi);
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

1;

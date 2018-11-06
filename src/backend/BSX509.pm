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
# certificate/pubkey definitions and helper functions
#

package BSX509;

use BSASN1;

use strict;

our $oid_common_name		= BSASN1::asn1_obj_id(2, 5, 4, 3);
our $oid_country_name		= BSASN1::asn1_obj_id(2, 5, 4, 6);
our $oid_org_name		= BSASN1::asn1_obj_id(2, 5, 4, 10);
our $oid_org_unit_name		= BSASN1::asn1_obj_id(2, 5, 4, 11);
our $oid_email_address		= BSASN1::asn1_obj_id(1, 2, 840, 113549, 1, 9, 1);
our $oid_sha1			= BSASN1::asn1_obj_id(1, 3, 14, 3, 2, 26);
our $oid_sha256			= BSASN1::asn1_obj_id(2, 16, 840, 1, 101, 3, 4, 2, 1);
our $oid_sha512			= BSASN1::asn1_obj_id(2, 16, 840, 1, 101, 3, 4, 2, 3);
our $oid_id_dsa			= BSASN1::asn1_obj_id(1, 2, 840, 10040, 4, 1);
our $oid_id_ec_public_key	= BSASN1::asn1_obj_id(1, 2, 840, 10045, 2, 1);
our $oid_prime256v1		= BSASN1::asn1_obj_id(1, 2, 840, 10045, 3, 1, 7);
our $oid_rsaencryption		= BSASN1::asn1_obj_id(1, 2, 840, 113549, 1, 1, 1);
our $oid_sha1withrsaencryption	= BSASN1::asn1_obj_id(1, 2, 840, 113549, 1, 1, 5);
our $oid_sha256withrsaencryption	= BSASN1::asn1_obj_id(1, 2, 840, 113549, 1, 1, 11);
our $oid_key_usage		= BSASN1::asn1_obj_id(2, 5, 29, 15);
our $oid_basic_constraints	= BSASN1::asn1_obj_id(2, 5, 29, 19);
our $oid_ext_key_usage		= BSASN1::asn1_obj_id(2, 5, 29, 37);
our $oid_code_signing		= BSASN1::asn1_obj_id(1, 3, 6, 1, 5, 5, 7, 3, 3);

sub keydata_getmpi {
  my ($bits) = @_;
  my $p = BSASN1::asn1_unpack_integer_mpi($bits);
  my $nb = length($p) * 8;
  if ($nb) {
    my $first = unpack('C', $p);
    $first < $_ && $nb-- for (128, 64, 32, 16, 8, 4, 2);
  }
  return { 'bits' => $nb, 'data' => $p };
}

sub pubkey2keydata {
  my ($pkder) = @_;
  my ($algoident, $bits) = BSASN1::asn1_unpack_sequence($pkder);
  my ($algooid, $algoparams) = BSASN1::asn1_unpack_sequence($algoident);
  my $algo;
  if ($algooid eq $BSASN1::oid_rsaencryption) {
    $algo = 'rsa';
  } elsif ($algooid eq $BSASN1::oid_id_dsa) {
    $algo = 'dsa';
  } elsif ($algooid eq $BSASN1::oid_id_ec_public_key) {
    $algo = 'ecdsa';
  } else {
    die("unknown pubkey algorithm\n");
  }
  (undef, undef, $bits) = BSASN1::asn1_unpack($bits, $BSASN1::BIT_STRING);
  die("bits does not start with 0\n") unless unpack('C', $bits) == 0;
  $bits = substr($bits, 1);
  my @mpis;
  my $res = { 'algo' => $algo };
  my $nbits;
  if ($algo eq 'dsa') {
    push @mpis, keydata_getmpi($_) for BSASN1::asn1_unpack_sequence($algoparams);
    push @mpis, keydata_getmpi($bits);
    $nbits = $mpis[-1]->{'bits'};
  } elsif ($algo eq 'rsa') {
    push @mpis, keydata_getmpi($_) for BSASN1::asn1_unpack_sequence($bits);
    $nbits = $mpis[0]->{'bits'};
  } elsif ($algo eq 'ecdsa') {
    my $curve;
    (undef, undef, undef, $curve) = BSASN1::asn1_unpack($algoparams, $BSASN1::OBJ_ID, 1);
    if ($curve && $curve eq $BSASN1::oid_prime256v1) {
      $res->{'curve'} = 'prime256v1';
      $nbits = 256;
    } elsif (length($bits) > 1) {
      my $f = unpack('C', $bits);
      if ($f == 2 || $f == 3) {
	$nbits = (length($bits) - 1) * 8;
      } elsif ($f == 4) {
	$nbits = (length($bits) - 1) / 2 * 8;
      }
    }
    $res->{'point'} = $bits;
  }
  $res->{'mpis'} = \@mpis if @mpis;
  $res->{'keysize'} = ($nbits + 31) & ~31 if $nbits;
  return $res;
}

1;

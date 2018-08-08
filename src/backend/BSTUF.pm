#
# Copyright (c) 2018 SUSE Inc.
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
# The Update Framework functions
#

package BSTUF;

use JSON::XS ();
use MIME::Base64 ();
use Digest::SHA;

use BSConfiguration;
use BSUtil;
use BSASN1;

use strict;

sub keydata2asn1 {
  my ($keydata) = @_;
  die("need an rsa pubkey\n") unless ($keydata->{'algo'} || '') eq 'rsa';
  my $pubkey = BSASN1::asn1_sequence(BSASN1::asn1_integer_mpi($keydata->{'mpis'}->[0]->{'data'}), BSASN1::asn1_integer_mpi($keydata->{'mpis'}->[1]->{'data'}));
  $pubkey = BSASN1::asn1_pack($BSASN1::BIT_STRING, pack('C', 0).$pubkey);
  return BSASN1::asn1_sequence(BSASN1::asn1_sequence($BSASN1::oid_rsaencryption, BSASN1::asn1_null()), $pubkey);
}

sub rfc3339time {
  my ($t) = @_;
  my @gt = gmtime($t || time());
  return sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ", $gt[5] + 1900, $gt[4] + 1, @gt[3,2,1,0];
}

sub canonical_json {
  my ($d) = @_;
  return JSON::XS->new->utf8->canonical->encode($d);
}

sub sign {
  my ($data, $signargs) = @_;
  return BSUtil::xsystem($data, $BSConfig::sign, @$signargs, '-O', '-h', 'sha256');
}

sub mktbscert {
  my ($cn, $not_before, $not_after, $subjectkeyinfo) = @_;
  my $serial = pack("CC", 0, 128 + int(rand(128)));
  $serial .= pack("C", int(rand(256))) for (1, 2, 3, 4, 5, 6, 7);
  my $certversion = BSASN1::asn1_pack($BSASN1::CONT | $BSASN1::CONS | 0, BSASN1::asn1_integer(2));
  my $certserial = BSASN1::asn1_pack($BSASN1::INTEGER, $serial);
  my $sigalgo = BSASN1::asn1_sequence($BSASN1::oid_sha256withrsaencryption, BSASN1::asn1_null());
  my $cnattr = BSASN1::asn1_sequence($BSASN1::oid_common_name, BSASN1::asn1_pack($BSASN1::UTF8STRING, $cn));
  my $issuer = BSASN1::asn1_sequence(BSASN1::asn1_set($cnattr));
  my $validity = BSASN1::asn1_sequence(BSASN1::asn1_utctime($not_before), BSASN1::asn1_utctime($not_after));
  my $critical = BSASN1::asn1_boolean(1);
  my $basic_constraints = BSASN1::asn1_sequence($BSASN1::oid_basic_constraints, $critical, BSASN1::asn1_octet_string(BSASN1::asn1_sequence()));
  my $key_usage = BSASN1::asn1_sequence($BSASN1::oid_key_usage, $critical, BSASN1::asn1_octet_string(BSASN1::asn1_pack($BSASN1::BIT_STRING, pack("CC", 5, 160))));
  my $ext_key_usage = BSASN1::asn1_sequence($BSASN1::oid_ext_key_usage, BSASN1::asn1_octet_string(BSASN1::asn1_sequence($BSASN1::oid_code_signing)));
  my $extensions = BSASN1::asn1_pack($BSASN1::CONT | $BSASN1::CONS | 3, BSASN1::asn1_sequence($basic_constraints, $key_usage, $ext_key_usage));
  my $tbscert = BSASN1::asn1_sequence($certversion, $certserial, $sigalgo, $issuer, $validity, $issuer, $subjectkeyinfo, $extensions);
  return $tbscert;
}

sub mkcert {
  my ($tbscert, $signargs) = @_;
  my $sigalgo = BSASN1::asn1_sequence($BSASN1::oid_sha256withrsaencryption, BSASN1::asn1_null());
  my $signature = sign($tbscert, $signargs);
  my $cert = BSASN1::asn1_sequence($tbscert, $sigalgo, BSASN1::asn1_pack($BSASN1::BIT_STRING,  pack("C", 0), $signature));
  return BSASN1::der2pem($cert, 'CERTIFICATE');
}

# return the to-be-signed part of a certificate
sub gettbscert {
  my ($cert) = @_;
  $cert = BSASN1::pem2der($cert, 'CERTIFICATE');
  (undef, $cert, undef) = BSASN1::asn1_unpack($cert, $BSASN1::CONS | $BSASN1::SEQUENCE);
  (undef, $cert, undef) = BSASN1::asn1_unpack($cert, $BSASN1::CONS | $BSASN1::SEQUENCE);
  return BSASN1::asn1_pack($BSASN1::CONS | $BSASN1::SEQUENCE, $cert);
}

# remove the serial number from a tbs certificate. We need to do this because the
# serial is random and we want to compare two certs.
sub removecertserial {
  my ($tbscert) = @_;
  (undef, $tbscert, undef) = BSASN1::asn1_unpack($tbscert, $BSASN1::CONS | $BSASN1::SEQUENCE);
  my $tail = $tbscert;
  (undef, undef, $tail) = BSASN1::asn1_unpack($tail);	# the version
  my $l = length($tail);
  (undef, undef, $tail) = BSASN1::asn1_unpack($tail, $BSASN1::INTEGER);	# the serial
  substr($tbscert, length($tbscert) - $l, $l - length($tail), '');
  return BSASN1::asn1_pack($BSASN1::CONS | $BSASN1::SEQUENCE, $tbscert);
}

# get pubkey
sub getsubjectkeyinfo {
  my ($tbscert) = @_;
  (undef, $tbscert, undef) = BSASN1::asn1_unpack($tbscert, $BSASN1::CONS | $BSASN1::SEQUENCE);
  (undef, undef, $tbscert) = BSASN1::asn1_unpack($tbscert) for 1..6;
  (undef, $tbscert, undef) = BSASN1::asn1_unpack($tbscert, $BSASN1::CONS | $BSASN1::SEQUENCE);
  return BSASN1::asn1_pack($BSASN1::CONS | $BSASN1::SEQUENCE, $tbscert);
}

sub signdata {
  my ($d, $signargs, @keyids) = @_;
  my $sig = MIME::Base64::encode_base64(sign(canonical_json($d), $signargs), '');
  my @sigs = map { { 'keyid' => $_, 'method' => 'rsapkcs1v15', 'sig' => $sig } } @keyids;
  # hack: signed must be first
  $d = { 'AAA_signed' => $d, 'signatures' => \@sigs };
  $d = canonical_json($d);
  $d =~ s/AAA_signed/signed/;
  return $d;
}

sub updatedata {
  my ($d, $oldd, $signargs, @keyids) = @_;
  $d->{'version'} = 1;
  $d->{'version'} = ($oldd->{'signed'}->{'version'} || 0) + 1 if $oldd && $oldd->{'signed'};
  return signdata($d, $signargs, @keyids);
}

# 0: different pubkey
# 1: same pubkey, different cert
# 2: same cert
sub cmprootcert {
  my ($root, $tbscert) = @_;
  my $root_id = $root->{'signed'}->{'roles'}->{'root'}->{'keyids'}->[0];
  my $root_key = $root->{'signed'}->{'keys'}->{$root_id}; 
  return 0 if !$root_key || $root_key->{'keytype'} ne 'rsa-x509';
  my $root_cert = MIME::Base64::decode_base64($root_key->{'keyval'}->{'public'});
  my $root_tbscert = gettbscert($root_cert);
  return 2 if removecertserial($root_tbscert) eq removecertserial($tbscert);
  return 1 if getsubjectkeyinfo($root_tbscert) eq getsubjectkeyinfo($tbscert);
  return 0;
}

sub addmetaentry {
  my ($d, $name, $content) = @_;
  my $entry = {
    'hashes' => {
      'sha256' => MIME::Base64::encode_base64(Digest::SHA::sha256($content), ''),
      'sha512' => MIME::Base64::encode_base64(Digest::SHA::sha512($content), ''),
    },
    'length' => length($content),
  };
  $d->{'meta'}->{$name} = $entry;
}

1;

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

use BSUtil;
use BSASN1;
use BSX509;

use strict;

sub keydata2asn1 {
  my ($keydata) = @_;
  die("need an rsa pubkey\n") unless ($keydata->{'algo'} || '') eq 'rsa';
  my $pubkey = BSASN1::pack_sequence(BSASN1::pack_integer_mpi($keydata->{'mpis'}->[0]->{'data'}), BSASN1::pack_integer_mpi($keydata->{'mpis'}->[1]->{'data'}));
  return BSASN1::pack_sequence(BSASN1::pack_sequence($BSX509::oid_rsaencryption, BSASN1::pack_null()), BSASN1::pack_bytes($pubkey));
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

sub key2keyid {
  return Digest::SHA::sha256_hex(canonical_json($_[0]));
}

sub mktbscert {
  my ($cn, $not_before, $not_after, $subjectkeyinfo) = @_;
  my $certversion = BSASN1::pack_tagged(0, BSASN1::pack_integer(2));
  my $certserial = BSX509::pack_random_serial();
  my $sigalgo = BSASN1::pack_sequence($BSX509::oid_sha256withrsaencryption, BSASN1::pack_null());
  my $issuer = BSX509::pack_distinguished_name([ $BSX509::oid_common_name, $cn ]);
  my $validity = BSX509::pack_validity($not_before, $not_after);
  my $basic_constraints = BSASN1::pack_sequence();
  my $key_usage = BSASN1::pack_bits_list($BSX509::key_usage_digital_signature, $BSX509::key_usage_key_encipherment);
  my $ext_key_usage = BSASN1::pack_sequence($BSX509::oid_code_signing);
  my $extensions = BSX509::pack_cert_extensions(
		    $BSX509::oid_basic_constraints, [ $basic_constraints, 1 ],
		    $BSX509::oid_key_usage, [ $key_usage, 1 ],
		    $BSX509::oid_ext_key_usage, [ $ext_key_usage ]);
  my $tbscert = BSASN1::pack_sequence($certversion, $certserial, $sigalgo, $issuer, $validity, $issuer, $subjectkeyinfo, $extensions);
  return $tbscert;
}

sub mkcert {
  my ($tbscert, $signfunc) = @_;
  my $signature = $signfunc->($tbscert);
  my $sigalgo = BSASN1::pack_sequence($BSX509::oid_sha256withrsaencryption, BSASN1::pack_null());
  my $cert = BSASN1::pack_sequence($tbscert, $sigalgo, BSASN1::pack_bytes($signature));
  return BSASN1::der2pem($cert, 'CERTIFICATE');
}

# return the to-be-signed part of a certificate
sub gettbscert {
  my ($cert) = @_;
  $cert = BSASN1::pem2der($cert, 'CERTIFICATE');
  return (BSASN1::unpack_sequence($cert, undef, [ $BSASN1::CONS | $BSASN1::SEQUENCE, -1]))[0];
}

# remove the serial number from a tbs certificate. We need to do this because the
# serial is random and we want to compare two certs.
sub removecertserial {
  my ($tbscert) = @_;
  my @parts = BSASN1::unpack_sequence($tbscert, undef, [ @$BSX509::tbscertificate_tags[0 .. 1], -1 ]);
  splice(@parts, 1, 1);		# remove serial entry
  return BSASN1::pack_sequence(@parts);
}

# get pubkey
sub getsubjectkeyinfo {
  my ($tbscert) = @_;
  return (BSASN1::unpack_sequence($tbscert, undef, [ @$BSX509::tbscertificate_tags[0 .. 7], -1 ]))[6];
}

sub signdata {
  my ($d, $signfunc, @keyids) = @_;
  my $sig = MIME::Base64::encode_base64($signfunc->(canonical_json($d)), '');
  my @sigs = map { { 'keyid' => $_, 'method' => 'rsapkcs1v15', 'sig' => $sig } } @keyids;
  # hack: signed must come first
  $d = { 'AAA_signed' => $d, 'signatures' => \@sigs };
  $d = canonical_json($d);
  $d =~ s/AAA_signed/signed/;
  return $d;
}

sub updatedata {
  my ($d, $oldd, $signfunc, @keyids) = @_;
  $d->{'version'} = 1;
  $d->{'version'} = ($oldd->{'signed'}->{'version'} || 0) + 1 if $oldd && $oldd->{'signed'};
  return signdata($d, $signfunc, @keyids);
}

sub getrootcert {
  my ($root) = @_;
  return undef unless $root && $root->{'signed'};
  my $root_id = $root->{'signed'}->{'roles'}->{'root'}->{'keyids'}->[0];
  my $root_key = $root->{'signed'}->{'keys'}->{$root_id}; 
  return undef if !$root_key || $root_key->{'keytype'} ne 'rsa-x509';
  return MIME::Base64::decode_base64($root_key->{'keyval'}->{'public'});
}

# 0: different pubkey
# 1: same pubkey, different cert
# 2: same cert
sub cmprootcert {
  my ($root, $tbscert) = @_;
  my $root_cert = getrootcert($root);
  return 0 unless $root_cert;
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

sub update_expires {
  my ($d, $signfunc, $expires) = @_;
  my $keyid = $d->{'signatures'}->[0]->{'keyid'};
  die("update_expires: bad data\n") unless $d->{'signed'} && $keyid;
  $d = { %{$d->{'signed'}} };
  $d->{'expires'} = BSTUF::rfc3339time($expires);
  $d->{'version'} = ($d->{'version'} || 0) + 1;
  return signdata($d, $signfunc, $keyid);
}

1;

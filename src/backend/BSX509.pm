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

use Digest::SHA;

use BSASN1;

use strict;

# useful oids
our $oid_common_name		= BSASN1::pack_obj_id(2, 5, 4, 3);
our $oid_country_name		= BSASN1::pack_obj_id(2, 5, 4, 6);
our $oid_locality_name		= BSASN1::pack_obj_id(2, 5, 4, 7);
our $oid_state_or_province_name	= BSASN1::pack_obj_id(2, 5, 4, 8);
our $oid_street_address		= BSASN1::pack_obj_id(2, 5, 4, 9);
our $oid_org_name		= BSASN1::pack_obj_id(2, 5, 4, 10);
our $oid_org_unit_name		= BSASN1::pack_obj_id(2, 5, 4, 11);
our $oid_email_address		= BSASN1::pack_obj_id(1, 2, 840, 113549, 1, 9, 1);
our $oid_user_id                = BSASN1::pack_obj_id(0, 9, 2342, 19200300, 100, 1, 1);
our $oid_domain_component       = BSASN1::pack_obj_id(0, 9, 2342, 19200300, 100, 1, 25);
our $oid_sha1			= BSASN1::pack_obj_id(1, 3, 14, 3, 2, 26);
our $oid_sha256			= BSASN1::pack_obj_id(2, 16, 840, 1, 101, 3, 4, 2, 1);
our $oid_sha512			= BSASN1::pack_obj_id(2, 16, 840, 1, 101, 3, 4, 2, 3);
our $oid_sha3_256		= BSASN1::pack_obj_id(2, 16, 840, 1, 101, 3, 4, 2, 8);
our $oid_sha3_512		= BSASN1::pack_obj_id(2, 16, 840, 1, 101, 3, 4, 2, 10);
our $oid_id_dsa			= BSASN1::pack_obj_id(1, 2, 840, 10040, 4, 1);
our $oid_id_dsa_with_sha1	= BSASN1::pack_obj_id(1, 2, 840, 10040, 4, 3);
our $oid_id_dsa_with_sha256	= BSASN1::pack_obj_id(2, 16, 840, 1, 101, 3, 4, 3, 2);
our $oid_id_dsa_with_sha512	= BSASN1::pack_obj_id(2, 16, 840, 1, 101, 3, 4, 3, 4);
our $oid_id_ec_public_key	= BSASN1::pack_obj_id(1, 2, 840, 10045, 2, 1);
our $oid_id_ecdsa_with_sha1	= BSASN1::pack_obj_id(1, 2, 840, 10045, 4, 1);
our $oid_id_ecdsa_with_sha256	= BSASN1::pack_obj_id(1, 2, 840, 10045, 4, 3, 2);
our $oid_id_ecdsa_with_sha512	= BSASN1::pack_obj_id(1, 2, 840, 10045, 4, 3, 4);
our $oid_prime256v1		= BSASN1::pack_obj_id(1, 2, 840, 10045, 3, 1, 7);
our $oid_secp384r1		= BSASN1::pack_obj_id(1, 3, 132, 0, 34);
our $oid_rsaencryption		= BSASN1::pack_obj_id(1, 2, 840, 113549, 1, 1, 1);
our $oid_sha1withrsaencryption	= BSASN1::pack_obj_id(1, 2, 840, 113549, 1, 1, 5);
our $oid_sha256withrsaencryption	= BSASN1::pack_obj_id(1, 2, 840, 113549, 1, 1, 11);
our $oid_sha512withrsaencryption	= BSASN1::pack_obj_id(1, 2, 840, 113549, 1, 1, 13);
our $oid_subject_key_identifier	= BSASN1::pack_obj_id(2, 5, 29, 14);
our $oid_key_usage		= BSASN1::pack_obj_id(2, 5, 29, 15);
our $oid_subject_alternative_name	= BSASN1::pack_obj_id(2, 5, 29, 17);
our $oid_basic_constraints	= BSASN1::pack_obj_id(2, 5, 29, 19);
our $oid_authority_key_identifier	= BSASN1::pack_obj_id(2, 5, 29, 35);
our $oid_ext_key_usage		= BSASN1::pack_obj_id(2, 5, 29, 37);
our $oid_server_auth		= BSASN1::pack_obj_id(1 ,3, 6, 1, 5, 5, 7, 3, 1);
our $oid_client_auth		= BSASN1::pack_obj_id(1 ,3, 6, 1, 5, 5, 7, 3, 2);
our $oid_code_signing		= BSASN1::pack_obj_id(1, 3, 6, 1, 5, 5, 7, 3, 3);
our $oid_ed25519		= BSASN1::pack_obj_id(1, 3, 101, 112);
our $oid_ed448			= BSASN1::pack_obj_id(1, 3, 101, 113);
our $oid_mldsa65		= BSASN1::pack_obj_id(2, 16, 840, 1, 101, 3, 4, 3, 18);
our $oid_pkcs9_extension_request	= BSASN1::pack_obj_id(1, 2, 840, 113549, 1, 9, 14);

# certificate keyusage bits
our $key_usage_digital_signature	= 0;
our $key_usage_non_repodiation		= 1;
our $key_usage_key_encipherment		= 2;
our $key_usage_data_encipherment	= 3;
our $key_usage_key_agreement		= 4;
our $key_usage_cert_sign		= 5;
our $key_usage_crl_sign			= 6;
our $key_usage_encipher_only		= 7;
our $key_usage_decipher_only		= 8;

# tbscertificate sequence definition
our $tbscertificate_tags = [
  [ $BSASN1::CONS | $BSASN1::CONT | 0, undef ],		# 0: optional version
  $BSASN1::INTEGER,					# 1: serial number
  $BSASN1::CONS | $BSASN1::SEQUENCE,			# 2: signature algorithm id
  $BSASN1::CONS | $BSASN1::SEQUENCE,			# 3: issuer name
  $BSASN1::CONS | $BSASN1::SEQUENCE,			# 4: validity
  $BSASN1::CONS | $BSASN1::SEQUENCE,			# 5: subject name
  $BSASN1::CONS | $BSASN1::SEQUENCE,			# 6: subject public key info
  [ $BSASN1::CONT | 1, undef ],				# 7: optional issuer unique id
  [ $BSASN1::CONT | 2, undef ],				# 8: optional subject unique id
  [ $BSASN1::CONS | $BSASN1::CONT | 3, undef ],		# 9: optional extensions
];

# pack/unpack helpers for certificates
sub pack_random_serial {
  my $serial = pack("C", 64 + int(rand(32)));
  $serial .= pack("C", int(rand(256))) for 1..19;
  return BSASN1::pack_integer_mpi($serial);
}

sub pack_distinguished_name {
  my (@attrset) = @_;
  my @res;
  for my $attrset (@attrset) {
    my @a;
    my @attr = @$attrset;
    while (@attr) {
      if ($attr[0] eq $oid_country_name && $attr[1] =~ /^[a-zA-Z\'()+\-?:\/= ]*$/s) {
        push @a, BSASN1::pack_sequence($attr[0], BSASN1::pack_string($attr[1], $BSASN1::PRINTABLESTRING));
      } elsif ($attr[0] eq $oid_email_address && $attr[1] =~ /^[\000-\177]*$/s) {
        push @a, BSASN1::pack_sequence($attr[0], BSASN1::pack_string($attr[1], $BSASN1::IA5STRING));
      } else {
        push @a, BSASN1::pack_sequence($attr[0], BSASN1::pack_string($attr[1]));
      }
      splice(@attr, 0, 2);
    }
    push @res, BSASN1::pack_set(@a);
  }
  return BSASN1::pack_sequence(@res);
}

sub unpack_distinguished_name {
  my (@sets) = BSASN1::unpack_sequence($_[0], $_[1]);
  my @res;
  for my $set (@sets) {
    my @a;
    for my $attrseq (BSASN1::unpack_set($set)) {
      my ($oid, $attr) = BSASN1::unpack_sequence($attrseq, undef, [ $BSASN1::OBJ_ID, 0 ]);
      push @a, $oid, BSASN1::unpack_string($attr);
    }
    push @res, \@a;
  }
  return @res;
}

sub pack_cert_extensions {
  my (@ext) = @_;
  return '' unless @ext;
  my @res;
  while (@ext) {
    push @res, BSASN1::pack_sequence($ext[0], $ext[1]->[1] ? BSASN1::pack_boolean(1) : (), BSASN1::pack_octet_string($ext[1]->[0]));
    splice(@ext, 0, 2);
  }
  return BSASN1::pack_tagged(3, BSASN1::pack_sequence(@res));	# tag as explicit [3]
}

sub unpack_cert_extensions {
  my @res;
  return () unless $_[0];
  for my $extseq (BSASN1::unpack_sequence(BSASN1::unpack_tagged($_[0], defined($_[1]) ? $_[1] : $BSASN1::CONT | $BSASN1::CONS | 3))) {
    my ($oid, $critical, $d) = BSASN1::unpack_sequence($extseq, undef, [ $BSASN1::OBJ_ID, [ $BSASN1::BOOLEAN, undef ], $BSASN1::OCTET_STRING ]);
    push @res, $oid, [ BSASN1::unpack_octet_string($d), $critical ? BSASN1::unpack_boolean($critical) : 0 ];
  }
  return @res;
}

sub pack_authority_key_identifier {
  my ($keyid, $dn, $serial) = @_;
  my @res;
  push @res, BSASN1::pack_tagged_implicit(0, BSASN1::pack_octet_string($keyid)) if defined($keyid);
  push @res, BSASN1::pack_tagged_implicit(1, BSASN1::pack_sequence(BSASN1::pack_tagged(4, $dn))) if $dn;
  push @res, BSASN1::pack_tagged_implicit(2, $serial) if $serial;
  return BSASN1::pack_sequence(@res);
}

sub unpack_authority_key_identifier {
  my ($keyid, $generalnames, $serial) = BSASN1::unpack_sequence($_[0], $_[1], [ [ $BSASN1::CONT | 0, undef ], [ $BSASN1::CONT | $BSASN1::CONS | 1, undef ], [ $BSASN1::CONT | 2, undef ] ]);
  my $dn;
  $keyid = $keyid ? BSASN1::unpack_octet_string($keyid, 0) : undef;
  if ($generalnames) {
    for my $gn (BSASN1::unpack_sequence($generalnames, 0)) {
      next unless BSASN1::gettag($gn) == ($BSASN1::CONT | $BSASN1::CONS | 4);
      $dn = BSASN1::unpack_tagged($gn);
      last;
    }
  }
  $serial = $serial ? BSASN1::unpack_tagged_implicit($serial, 0, $BSASN1::INTEGER) : undef;
  return ($keyid, $dn, $serial);
}

sub pack_validity {
  my ($begins, $expires) = @_;
  return BSASN1::pack_sequence(BSASN1::pack_time($begins), BSASN1::pack_time($expires));
}

sub unpack_validity {
  my ($begins, $expires) = BSASN1::unpack_sequence($_[0], $_[1], [ [ $BSASN1::UTCTIME, $BSASN1::GENTIME], [ $BSASN1::UTCTIME, $BSASN1::GENTIME] ]);
  return (BSASN1::unpack_time($begins), BSASN1::unpack_time($expires));
}

sub pack_digalgo {
  my ($algo, $params) = @_;
  my $oid;
  $oid = $BSX509::oid_sha1 if $algo eq 'sha1';
  $oid = $BSX509::oid_sha256 if $algo eq 'sha256';
  $oid = $BSX509::oid_sha512 if $algo eq 'sha512';
  $oid = $BSX509::oid_sha3_256 if $algo eq 'sha3-256';
  $oid = $BSX509::oid_sha3_512 if $algo eq 'sha3-512';
  $oid = BSASN1::pack_obj_id(split(/\./, $algo)) if !$oid && $algo =~ /^\d+\.\d+(?:\.\d+)+$/;
  die("unknown digest algo: $algo\n") unless $oid;
  $params = BSASN1::pack_null() if @_ == 1;	# compat
  return BSASN1::pack_sequence($oid, $params);
}

sub unpack_digalgo {
  my ($oid, $params) = BSASN1::unpack_sequence($_[0], $_[1], [ $BSASN1::OBJ_ID, [0, undef] ]);
  return 'sha1', $params if $oid eq $BSX509::oid_sha1;
  return 'sha256', $params if $oid eq $BSX509::oid_sha256;
  return 'sha512', $params if $oid eq $BSX509::oid_sha512;
  return 'sha3-256', $params if $oid eq $BSX509::oid_sha3_256;
  return 'sha3-512', $params if $oid eq $BSX509::oid_sha3_512;
  return oid2str($oid), $params;
}

sub pack_sigalgo {
  my ($algo, $hash, $params) = @_;
  die("pack_sigalgo: need pubkey algorithm\n") unless $algo;
  my $oid;
  if (defined($hash)) {
    $oid = $oid_sha1withrsaencryption if $algo eq 'rsa' && $hash eq 'sha1';
    $oid = $oid_sha256withrsaencryption if $algo eq 'rsa' && $hash eq 'sha256';
    $oid = $oid_sha512withrsaencryption if $algo eq 'rsa' && $hash eq 'sha512';
    $oid = $oid_id_dsa_with_sha1 if $algo eq 'dsa' && $hash eq 'sha1';
    $oid = $oid_id_dsa_with_sha256 if $algo eq 'dsa' && $hash eq 'sha256';
    $oid = $oid_id_dsa_with_sha512 if $algo eq 'dsa' && $hash eq 'sha512';
    $oid = $oid_id_ecdsa_with_sha1 if $algo eq 'ecdsa' && $hash eq 'sha1';
    $oid = $oid_id_ecdsa_with_sha256 if $algo eq 'ecdsa' && $hash eq 'sha256';
    $oid = $oid_id_ecdsa_with_sha512 if $algo eq 'ecdsa' && $hash eq 'sha512';
    die("unknown algo/hash combination: $algo/$hash\n") unless $oid;
  } else {
    $oid = $oid_rsaencryption if $algo eq 'rsa';
    $oid = $oid_id_dsa if $algo eq 'dsa';
    $oid = $oid_id_ec_public_key if $algo eq 'ecdsa';
    $oid = $oid_ed25519 if $algo eq 'ed25519';
    $oid = $oid_ed448 if $algo eq 'ed448';
    $oid = $oid_mldsa65 if $algo eq 'mldsa65';
    $oid = BSASN1::pack_obj_id(split(/\./, $algo)) if !$oid && $algo =~ /^\d+\.\d+(?:\.\d+)+$/;
    die("unknown algo: $algo\n") unless $oid;
  }
  $params = BSASN1::pack_null() if @_ == 2 && $algo eq 'rsa';
  return BSASN1::pack_sequence($oid, $params);
}

sub unpack_sigalgo {
  my ($oid, $params) = BSASN1::unpack_sequence($_[0], $_[1], [ $BSASN1::OBJ_ID, [0, undef] ]);
  return 'rsa', undef, $params if $oid eq $oid_rsaencryption;
  return 'dsa', undef, $params if $oid eq $oid_id_dsa;
  return 'ecdsa', undef, $params if $oid eq $oid_id_ec_public_key;
  return 'ed25519', undef, $params if $oid eq $oid_ed25519;
  return 'ed448', undef, $params if $oid eq $oid_ed448;
  return 'rsa', 'sha1', $params if $oid eq $oid_sha1withrsaencryption;
  return 'rsa', 'sha256', $params if $oid eq $oid_sha256withrsaencryption;
  return 'rsa', 'sha512', $params if $oid eq $oid_sha512withrsaencryption;
  return 'dsa', 'sha1', $params if $oid eq $oid_id_dsa_with_sha1;
  return 'dsa', 'sha256', $params if $oid eq $oid_id_dsa_with_sha256;
  return 'dsa', 'sha512', $params if $oid eq $oid_id_dsa_with_sha512;
  return 'ecdsa', 'sha1', $params if $oid eq $oid_id_ecdsa_with_sha1;
  return 'ecdsa', 'sha256', $params if $oid eq $oid_id_ecdsa_with_sha256;
  return 'ecdsa', 'sha512', $params if $oid eq $oid_id_ecdsa_with_sha512;
  return 'mldsa65', undef, $params if $oid eq $oid_mldsa65;
  return oid2str($oid), undef, $params;
}

sub generate_key_id {
  my ($subjectpublickeyinfo) = @_;
  my ($algoident, $bits) = BSASN1::unpack_sequence($subjectpublickeyinfo);
  return Digest::SHA::sha1(BSASN1::unpack_bytes($bits));
}

sub generate_cert_fingerprint {
  my ($cert) = @_;
  return Digest::SHA::sha1($cert);
}

my %oid2abbrev = (
  $oid_common_name => 'CN',
  $oid_country_name => 'C',
  $oid_locality_name => 'L',
  $oid_state_or_province_name => 'ST',
  $oid_org_name => 'O',
  $oid_org_unit_name => 'OU',
  $oid_street_address => 'STREET',
  $oid_domain_component => 'DC',
  $oid_user_id => 'UID',
  $oid_email_address => 'emailAddress',
);

sub oid2str {
  return join('.', BSASN1::unpack_obj_id(@_));
}

sub dn2str {
  my @rdns;
  for my $rdn (unpack_distinguished_name(@_)) {
    my %s = @{$rdn || []};
    push @rdns, join('+', map { ($oid2abbrev{$_} || oid2str($_))."=$s{$_}" } sort keys %s);
  }
  return join(', ', @rdns);
}

sub keydata_getmpi {
  my ($bits) = @_;
  my $p = BSASN1::unpack_integer_mpi($bits);
  my $nb = length($p) * 8;
  if ($nb) {
    my $first = unpack('C', $p);
    $first < $_ && $nb-- for (128, 64, 32, 16, 8, 4, 2);
  }
  return { 'bits' => $nb, 'data' => $p };
}

sub oid2curve {
  my ($oid) = @_;
  return undef unless $oid;
  return 'prime256v1' if $oid eq $oid_prime256v1;
  return 'secp384r1' if $oid eq $oid_secp384r1;
  return undef;
}

sub curve2oid {
  my ($curve) = @_;
  return undef unless $curve;
  return $oid_prime256v1 if $curve eq 'prime256v1';
  return $oid_secp384r1 if $curve eq 'secp384r1';
  return undef;
}

# pubkey introspection
sub pubkey2keydata {
  my ($subjectpublickeyinfo) = @_;
  my ($algoident, $bits) = BSASN1::unpack_sequence($subjectpublickeyinfo);
  my ($algo, $hash, $algoparams) = unpack_sigalgo($algoident);
  $bits = BSASN1::unpack_bytes($bits);
  my @mpis;
  my $res = { 'algo' => $algo };
  my $nbits;
  if ($algo eq 'dsa') {
    push @mpis, keydata_getmpi($_) for BSASN1::unpack_sequence($algoparams);
    push @mpis, keydata_getmpi($bits);
    $nbits = $mpis[-1]->{'bits'};
  } elsif ($algo eq 'rsa') {
    push @mpis, keydata_getmpi($_) for BSASN1::unpack_sequence($bits);
    $nbits = $mpis[0]->{'bits'};
  } elsif ($algo eq 'ecdsa') {
    my $curve = oid2curve($algoparams);
    $res->{'curve'} = $curve if $curve;
    my $f = unpack('C', $bits);
    if ($f == 2 || $f == 3) {
      $nbits = (length($bits) - 1) * 8;	# compressed points
    } elsif ($f == 4) {
      $nbits = (length($bits) - 1) / 2 * 8;	# uncompressed points
    }
    $res->{'point'} = $bits;
  } elsif ($algo eq 'ed25519' || $algo eq 'ed448') {
    $res->{'keysize'} = length($bits) * 8;
    $res->{'point'} = $bits;
  } elsif ($algo eq 'mldsa65') {
    $res->{'keysize'} = length($bits) * 8;
    $res->{'keydata'} = $bits;
  }
  $res->{'mpis'} = \@mpis if @mpis;
  $res->{'keysize'} = ($nbits + 31) & ~31 if $nbits;
  return $res;
}

sub keydata2pubkey {
  my ($keydata) = @_;
  my $algo = $keydata->{'algo'} || '?';
  my ($algoparams, $bits);
  if ($algo eq 'rsa') {
    $bits = BSASN1::pack_sequence(BSASN1::pack_integer_mpi($keydata->{'mpis'}->[0]->{'data'}), BSASN1::pack_integer_mpi($keydata->{'mpis'}->[1]->{'data'}));
    $algoparams = BSASN1::pack_null();	# compat
  } elsif ($algo eq 'dsa') {
    my @mpis = @{$keydata->{'mpis'} || []};
    $bits = BSASN1::pack_integer_mpi((pop @mpis)->{'data'});
    $algoparams = BSASN1::pack_sequence(map {BSASN1::pack_integer_mpi($_->{'data'})} @mpis);
  } elsif ($algo eq 'ecdsa') {
    $bits = $keydata->{'point'};
    die("need a curve for ecdsa\n") unless $keydata->{'curve'};
    $algoparams = curve2oid($keydata->{'curve'});
    die("unsupported curve $keydata->{'curve'}\n") unless $algoparams;
  } elsif ($algo eq 'ed25519' || $algo eq 'ed448') {
    $bits = $keydata->{'point'};
  } elsif ($algo eq 'mldsa65') {
    $bits = $keydata->{'keydata'};
  } else {
    die("unsupported pubkey algo $algo\n");
  }
  return BSASN1::pack_sequence(pack_sigalgo($algo, undef, $algoparams), BSASN1::pack_bytes($bits));
}

1;

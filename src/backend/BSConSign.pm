#
# Copyright (c) 2020 SUSE LLC
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
# Create container signatures and handle attestations
#

package BSConSign;

use strict;

use BSPGP;
use JSON::XS ();
use Digest::MD5 ();
use Digest::SHA ();
use MIME::Base64 ();
use IO::Compress::RawDeflate;

our $mt_cosign = 'application/vnd.dev.cosign.simplesigning.v1+json';
our $mt_dsse   = 'application/vnd.dsse.envelope.v1+json';
our $mt_intoto = 'application/vnd.in-toto+json';

our $intoto_predicate_spdx      = 'https://spdx.dev/Document';
our $intoto_predicate_cyclonedx = 'https://cyclonedx.org/bom';
our $intoto_stmt_v01            = 'https://in-toto.io/Statement/v0.1';
our $intoto_stmt_v1             = 'https://in-toto.io/Statement/v1';

sub canonical_json {
  return JSON::XS->new->utf8->canonical->encode($_[0]);
}

sub create_entry {
  my ($data, %extra) = @_;
  my $blobid = 'sha256:'.Digest::SHA::sha256_hex($data);
  my $ent = { %extra, 'size' => length($data), 'data' => $data, 'blobid' => $blobid };
  return $ent;
}

sub create_signature_payload {
  my ($type, $digest, $reference, $creator, $timestamp) = @_;
  my $critical = {
    'type' => $type,
    'image' => { 'docker-manifest-digest' => $digest },
    'identity' => { 'docker-reference' => $reference },
  };
  my $optional = {};
  $optional->{'creator'} = $creator if $creator;
  $optional->{'timestamp'} = $timestamp if $timestamp;
  my $data = { 'critical' => $critical, 'optional' => $optional };
  return canonical_json($data);
}

sub create_atomic_signature {
  my ($signfunc, $digest, $reference, $creator, $timestamp) = @_;
  my $payload = create_signature_payload('atomic container signature', $digest, $reference, $creator, $timestamp);
  my $sig = $signfunc->($payload);
  my $packets = BSPGP::onepass_signed_message($payload, $sig, 'rpmsig-req.bin');
  # compress packets like gpg does
  my $compressed_pkts;
  IO::Compress::RawDeflate::rawdeflate(\$packets, \$compressed_pkts);
  $packets = pack('CC', 0xa3, 1).$compressed_pkts;
  return $packets;
}

sub sig2openshift {
  my ($digest, $sig) = @_;
  my $id = Digest::MD5::md5_hex($sig);
  my $data = {
    'schemaVersion' => 2,
    'type' => 'atomic',
    'name' => "$digest\@$id",
    'content' => MIME::Base64::encode_base64($sig, ''),
  };
  return $data;
}

sub create_cosign_config_ent {
  my ($layer_ents) = @_;
  my @diff_ids = map {$_->{'blobid'}} @{$layer_ents || []};
  my $config = {
    'architecture' => '',
    'config' => {},
    'created' => '0001-01-01T00:00:00Z',
    'history' => [ { 'created' => '0001-01-01T00:00:00Z' } ],
    'os' => '',
    'rootfs' => { 'type' => 'layers', 'diff_ids' => \@diff_ids },
  };
  return create_entry(canonical_json($config));
}

sub create_cosign_layer_ent {
  my ($payloadtype, $payload, $sig, $annotations) = @_;
  my %annotations = %{$annotations || {}};
  $annotations{'dev.cosignproject.cosign/signature'} = MIME::Base64::encode_base64($sig, '') if defined $sig;
  return create_entry($payload, 'mimetype' => $payloadtype, 'annotations' => \%annotations);
}

sub create_cosign_signature_ent {
  my ($signfunc, $digest, $reference, $creator, $timestamp, $annotations) = @_;
  my $payload = create_signature_payload('cosign container image signature', $digest, $reference, $creator, $timestamp);
  # signfunc must return the openssl rsa signature
  my $sig = $signfunc->($payload);
  return (create_cosign_layer_ent($mt_cosign, $payload, $sig, $annotations), $sig);
}

sub create_cosign_attestation_ents {
  my ($attestations, $annotations, $predicatetypes) = @_;
  $attestations = [ $attestations ] if ref($attestations) ne 'ARRAY';
  my @res;
  for my $att (@$attestations) {
    push @res, create_cosign_layer_ent($mt_dsse, $att, '', $annotations);
    $res[-1]->{'annotations'}->{'org.open-build-service.intoto.predicatetype'} = $predicatetypes->{$att} if $predicatetypes->{$att};
  }
  return @res;
}

sub dsse_pae {
  my ($type, $payload) = @_;
  return sprintf("DSSEv1 %d %s %d ", length($type), $type, length($payload)).$payload;
}

sub dsse_sign {
  my ($payload, $payloadtype, $signfunc) = @_;
  my $dsse = dsse_pae($payloadtype, $payload);
  my $sig = $signfunc->($dsse);
  # hack: prepend _ to payloadType so it comes first
  my $envelope = { 
    '_payloadType' => $payloadtype,
    'payload' => MIME::Base64::encode_base64($payload, ''),
    'signatures' => [ { 'sig' => MIME::Base64::encode_base64($sig, '') } ],
  }; 
  my $envelope_json = canonical_json($envelope);
  $envelope_json =~ s/_payloadType/payloadType/;
  return $envelope_json;
}

# change the subject so that it matches the reference/digest and re-sign
sub fixup_intoto_attestation {
  my ($attestation, $signfunc, $digest, $reference, $predicatetypes) = @_;
  $attestation = JSON::XS::decode_json($attestation);
  die("bad attestation\n") unless $attestation && ref($attestation) eq 'HASH';
  if ($attestation->{'payload'}) {
    die("bad attestation\n") unless $attestation->{'payloadType'};
    die("no an in-toto attestation\n") unless $attestation->{'payloadType'} eq $mt_intoto;
    $attestation = JSON::XS::decode_json(MIME::Base64::decode_base64($attestation->{'payload'}));
  }
  if ($attestation && ref($attestation) eq 'HASH' && !$attestation->{'_type'}) {
    my $predicate_type;
    # autodetect predicate type
    $predicate_type = $intoto_predicate_spdx if $attestation->{'spdxVersion'};
    $predicate_type = $intoto_predicate_cyclonedx if ($attestation->{'bomFormat'} || '') eq 'CycloneDX';
    # wrap into an in-toto v0.1 attestation
    $attestation = { '_type' => $intoto_stmt_v01, 'predicateType' => $predicate_type, 'predicate' => $attestation } if $predicate_type;
  }
  die("bad attestation\n") unless $attestation && ref($attestation) eq 'HASH' && $attestation->{'_type'};
  die("not a in-toto v1 or v0.1 attestation\n") unless $attestation->{'_type'} eq $intoto_stmt_v1 || $attestation->{'_type'} eq $intoto_stmt_v01;
  my $predicate_type = $attestation->{'predicateType'};
  my $sha256digest = $digest;
  die("not a sha256 digest\n") unless $sha256digest =~ s/^sha256://;
  $attestation->{'subject'} = [ { 'name' => $reference, 'digest' => { 'sha256' => $sha256digest } } ];
  $attestation = canonical_json($attestation);
  my $att = dsse_sign($attestation, $mt_intoto, $signfunc);
  $predicatetypes->{$att} = $predicate_type if $predicatetypes && $predicate_type && !ref($predicate_type);
  return $att;
}

sub create_cosign_cookie {
  my ($gpgpubkey, $reference, $creator) = @_;
  $creator ||= '';
  my $pubkeyid = BSPGP::pk2fingerprint(BSPGP::unarmor($gpgpubkey));
  return Digest::SHA::sha256_hex("$creator/$pubkeyid/$reference");
}

1;

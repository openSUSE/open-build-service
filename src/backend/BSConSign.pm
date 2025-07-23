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
our $mt_cosign_bundle = 'application/vnd.dev.sigstore.bundle.v0.3+json';

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

sub create_cosign_signature_ent {
  my ($signfunc, $digest, $reference, $creator, $timestamp, $annotations) = @_;
  my $payload = create_signature_payload('cosign container image signature', $digest, $reference, $creator, $timestamp);
  # signfunc must return the openssl rsa signature
  my $sig = $signfunc->($payload);
  die("create_cosign_signature_ent: signature creation failed\n") unless $sig;
  my %annotations = %{$annotations || {}};
  $annotations{'dev.cosignproject.cosign/signature'} = MIME::Base64::encode_base64($sig, '');
  return (create_entry($payload, 'mimetype' => $mt_cosign, 'annotations' => \%annotations), $sig);
}

sub create_cosign_attestation_ent {
  my ($attestation, $annotations, $predicatetype) = @_;
  my %annotations = %{$annotations || {}};
  $annotations{'dev.cosignproject.cosign/signature'} = '';	# why?
  $annotations{'org.open-build-service.intoto.predicatetype'} = $predicatetype if $predicatetype;
  return create_entry($attestation, 'mimetype' => $mt_dsse, 'annotations' => \%annotations);
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
  my ($attestation, $signfunc, $digest, $reference) = @_;
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
  return ($att, !ref($predicate_type) ? $predicate_type : undef);
}

sub create_cosign_cookie {
  my ($gpgpubkey, $reference, $creator) = @_;
  $creator ||= '';
  my $pubkeyid = BSPGP::pk2fingerprint(BSPGP::unarmor($gpgpubkey));
  return Digest::SHA::sha256_hex("$creator/$pubkeyid/$reference");
}

sub create_cosign_attestation_ent_newbundle {
  my ($attestation, $annotations, $predicatetype) = @_;
  my $dsse = JSON::XS::decode_json($attestation);
  my $bundle = { 'mediaType' => $mt_cosign_bundle };
  $bundle->{'dsseEnvelope'} = JSON::XS::decode_json($attestation);
  my $bundle_json = canonical_json($bundle);
  my %annotations = %{$annotations || {}};
  $annotations{'dev.sigstore.bundle.content'} = 'dsse-envelope';
  $annotations{'dev.sigstore.bundle.predicateType'} = $predicatetype if $predicatetype;
  # $annotations{'org.opencontainers.image.created'} = ...;
  return create_entry($bundle_json, 'mimetype' => $mt_cosign_bundle, 'annotations' => \%annotations);
}

sub add_cosign_bundle_annotation {
  my ($ent, $rekorentry, $keyid) = @_;
  return unless $rekorentry->{'verification'};

  if ($ent->{'mimetype'} eq $mt_cosign_bundle) {
    # entry is in new bundle format
    my $pki = defined($keyid) ? {} : undef;
    $pki->{'hint'} = $keyid if $keyid;
    my $bundle = JSON::XS::decode_json($ent->{'data'});
    $bundle->{'verificationMaterial'} = { 'tlogEntries' => [ rekorentry_to_tle($rekorentry) ] };
    $bundle->{'verificationMaterial'}->{'publicKeyIdentifier'} = $pki if $pki;
    my $bundle_json = canonical_json($bundle);
    %$ent = (%$ent, %{ create_entry($bundle_json) });	# patch in new values
    return;
  }

  die("addbundleannotation: rekor entry is incomplete\n") unless $rekorentry->{'body'} && $rekorentry->{'integratedTime'} && $rekorentry->{'logIndex'} && $rekorentry->{'logID'} && $rekorentry->{'verification'}->{'signedEntryTimestamp'};
  # see cosign's EntryToBundle function
  my $bundle = {};
  $bundle->{'Payload'} = {
    'body' => $rekorentry->{'body'},
    'integratedTime' => $rekorentry->{'integratedTime'},
    'logIndex' => $rekorentry->{'logIndex'},
    'logID' => $rekorentry->{'logID'},
  };
  $bundle->{'SignedEntryTimestamp'} = $rekorentry->{'verification'}->{'signedEntryTimestamp'};
  $ent->{'annotations'}->{'dev.sigstore.cosign/bundle'} = canonical_json($bundle);
}

sub rekorentry_to_tle {
  my ($rekorentry) = @_;
  # see rekor's GenerateTransparencyLogEntry function
  die("rekorentry_to_tle: rekor entry is incomplete\n") unless $rekorentry->{'body'} && $rekorentry->{'integratedTime'} && $rekorentry->{'logIndex'} && $rekorentry->{'logID'} && $rekorentry->{'verification'} && $rekorentry->{'verification'}->{'signedEntryTimestamp'} && $rekorentry->{'verification'}->{'inclusionProof'};
  my $body = JSON::XS::decode_json(MIME::Base64::decode_base64($rekorentry->{'body'}));
  die("missing kind or apiVersion in rekor entry body\n") unless $body->{'apiVersion'} && $body->{'kind'};
  my $tle = {};
  # the stringifys below are needed because protojson encodes 64bit numbers as strings
  $tle->{'logIndex'} = "$rekorentry->{'logIndex'}";			# stringify
  $tle->{'logId'} = { 'keyid' => MIME::Base64::encode_base64(pack('H*', $rekorentry->{'logID'}), '') };
  $tle->{'kindVersion'} = { 'kind' => $body->{'kind'}, 'version' => $body->{'apiVersion'} };
  $tle->{'integratedTime'} = "$rekorentry->{'integratedTime'}";		# stringify
  $tle->{'inclusionPromise'} = { 'signedEntryTimestamp' => $rekorentry->{'verification'}->{'signedEntryTimestamp'} };
  my $ip = $rekorentry->{'verification'}->{'inclusionProof'};
  $tle->{'inclusionProof'} = {
    'logIndex' => "$ip->{'logIndex'}",				# stringify
    'rootHash' => MIME::Base64::encode_base64(pack('H*', $ip->{'rootHash'}), ''),
    'treeSize' => "$ip->{'treeSize'}",				# stringify
    'hashes'   => [ map {MIME::Base64::encode_base64(pack('H*', $_), '')} @{$ip->{'hashes'} || []}],
    'checkpoint' => { 'envelope' => $ip->{'checkpoint'} },
  };
  $tle->{'canonicalizedBody'} = $rekorentry->{'body'};
  return $tle;
}

sub dsse_envelope_from_ent {
  my ($ent) = @_;
  if ($ent->{'mimetype'} eq $mt_cosign_bundle) {
    my $bundle = JSON::XS::decode_json($ent->{'data'});
    my $dsse = $bundle->{'dsseEnvelope'};
    die("dsse_envelope_from_ent: not a dsseEnvelope bundle\n") unless $dsse;
    my $envelope = { '_payloadType' => $dsse->{'payloadType'}, 'payload' => $dsse->{'payload'}, 'signatures' => $dsse->{'signatures'} };
    $bundle = $dsse = undef;	# free mem
    my $envelope_json = canonical_json($envelope);
    $envelope_json =~ s/_payloadType/payloadType/;
    return $envelope_json;
  }
  die("dsse_envelope_from_ent: not a dsse type\n") if $ent->{'mimetype'} ne $mt_dsse;
  return $ent->{'data'};
}

1;

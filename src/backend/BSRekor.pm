#
# Copyright (c) 2022 SUSE Inc.
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
# Sigstore rekor support
#

package BSRekor;

use strict;

use JSON::XS ();
use MIME::Base64 ();

use BSRPC ':https';
use BSConfiguration;

our $intoto_slsav_v01 = "https://slsa.dev/provenance/v0.1";
our $intoto_slsav_v02 = "https://slsa.dev/provenance/v0.2";
our $intoto_slsa_v1   = "https://slsa.dev/provenance/v1";
our $intoto_spdx      = "https://spdx.dev/Document";
our $intoto_link_v1   = "https://in-toto.io/Link/v1";
our $intoto_cosign_v1 = "cosign.sigstore.dev/attestation/v1";
our $intoto_vuln_v1   = "cosign.sigstore.dev/attestation/vuln/v1";

sub canonical_json {
  my ($d) = @_;
  return JSON::XS->new->utf8->canonical->encode($d);
}

sub mime_encode {
  my ($d) = @_;
  return MIME::Base64::encode_base64($d, '');
}

sub dsse_pae {
  my ($type, $payload) = @_;
  return sprintf("DSSEv1 %d %s %d ", length($type), $type, length($payload))."$payload";
}

sub upload_entry {
  my ($server, $entry) = @_;
  my $replyheaders;
  my $param = {
    'uri'     => "$server/api/v1/log/entries",
    'request' => 'POST',
    'timeout' => 300,
    'data'    => canonical_json($entry),
    'headers' => [ 'Content-Type: application/json' ],
    'replyheaders' => \$replyheaders,
    'ignorestatus' => 1,
  };
  my $r = BSRPC::rpc($param);
  my $st = $replyheaders->{'status'};
  if ($st !~ /^201|409/) {
    my $msg = eval { (JSON::XS::decode_json($r) || {})->{'message'} };
    die("rekor server: $st ($msg)\n") if $msg;
    die("rekor server: $st\n");
  }
  # entry created or already exists
  my $l = $replyheaders->{'location'};
  die("rekor server did not return a location\n") unless $l;
  $l =~ s/.*\///;
  return $l;
  # new:    {"84f4192f5c38c9eb0973dae7bdd24e0ad6781d9e228b4ee60f411ea0e1050482":{"body":"...","integratedTime":1638195094,"logID":"c0d23d6ad406973f9559f3ba2d1ca01f84147d8ffc5b8445c224f98b9591801d","logIndex":897532,"verification":{"signedEntryTimestamp":"MEQCIDd8LwH1lbeUfCjwRoX5J7fzZ5qIK4PwMsf+sHJHgCCTAiB1h1nD0OjeleiBph8UtlZMTwlpNLq3cSaZ0Oxc8Gom0A=="}}}
}

sub upload_rekord {
  my ($server, $content, $pubkey, $signature, $sigformat) = @_;
  my $sig = {
    'format' => $sigformat,
    'content' => mime_encode($signature),
    'publicKey' => { 'content' => mime_encode($pubkey) },
  };
  my $spec = {
    'data' => { 'content' => mime_encode($content) },
    'signature' => $sig,
  };
  my $entry = {
    'kind' => 'rekord',
    'apiVersion' => '0.0.1',
    'spec' => $spec,
  };
  return upload_entry($server, $entry);
}

sub upload_hashedrekord {
  my ($server, $hash, $pubkey, $signature) = @_;
  die("bad hash $hash\n") unless $hash =~ /^(.+?):([0-9a-f]+)$/;
  my ($hashalgo, $hashvalue) = ($1, $2);
  my $sig = {
    'content' => mime_encode($signature),
    'publicKey' => { 'content' => mime_encode($pubkey) },
  };
  my $spec = {
    'data' => { 'hash' => { 'algorithm' => $hashalgo, 'value' => $hashvalue } },
    'signature' => $sig,
  };
  my $entry = {
    'kind' => 'hashedrekord',
    'apiVersion' => '0.0.1',
    'spec' => $spec,
  };
  return upload_entry($server, $entry);
}

sub upload_intoto {
  my ($server, $envelope, $pubkey) = @_;
  my $spec = {
    'publicKey' => mime_encode($pubkey),
    'content' => { 'envelope' => $envelope },
  };
  my $entry = {
    'kind' => 'intoto',
    'apiVersion' => '0.0.1',
    'spec' => $spec,
  };
  return upload_entry($server, $entry);
}

sub upload_intoto_v2 {
  my ($server, $envelope, $pubkey) = @_;
  my $e = JSON::XS::decode_json($envelope);
  $_->{'publicKey'} ||= $pubkey for @{$e->{'signatures'} || []};
  my $spec = {
    'content' => { 'envelope' => $e },
  };
  my $entry = {
    'kind' => 'intoto',
    'apiVersion' => '0.0.2',
    'spec' => $spec,
  };
  return upload_entry($server, $entry);
}

sub upload_dsse {
  my ($server, $envelope, $pubkey) = @_;
  my $verifier = mime_encode($pubkey);
  my $spec = {
    'proposedContent' => { 'envelope' => $envelope, 'verifiers' => [ $verifier ] },
  };
  my $entry = {
    'kind' => 'dsse',
    'apiVersion' => '0.0.1',
    'spec' => $spec,
  };
  return upload_entry($server, $entry);
}

1;

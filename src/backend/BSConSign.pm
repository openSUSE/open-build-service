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
# Create an "atomic container signature"
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

sub canonical_json {
  return JSON::XS->new->utf8->canonical->encode($_[0]);
}

sub createpayload {
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

sub createsig {
  my ($signfunc, $digest, $reference, $creator, $timestamp) = @_;
  my $payload = createpayload('atomic container signature', $digest, $reference, $creator, $timestamp);
  my $sig = $signfunc->($payload);
  my $sd = BSPGP::pk2sigdata($sig);
  die("no issuer\n") unless $sd->{'issuer'};
  # create onepass_sig packet
  my $onepass_sig_pkt = pack('CCCCH16C', 3, $sd->{'pgptype'}, $sd->{'pgphash'}, $sd->{'pgpalgo'}, $sd->{'issuer'}, 1);
  $onepass_sig_pkt = BSPGP::pkencodepacket(4, $onepass_sig_pkt);
  # create literal data packet
  my $fn = 'rpmsig-req.bin';
  my $t = $sd->{'signtime'} || time();
  my $literal_data_pkt = pack('CCa*N', 0x62, length($fn), $fn, $t).$payload;
  $literal_data_pkt = BSPGP::pkencodepacket(11, $literal_data_pkt);
  # create compressed packet
  my $packets = "$onepass_sig_pkt$literal_data_pkt$sig";
  my $compressed_pkt;
  IO::Compress::RawDeflate::rawdeflate(\$packets, \$compressed_pkt);
  return pack('CC', 0xa3, 1).$compressed_pkt;
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

sub createcosign {
  my ($signfunc, $digest, $reference, $creator, $timestamp, $annotations) = @_;
  my $payload = createpayload('cosign container image signature', $digest, $reference, $creator, $timestamp);
  my $payload_digest = 'sha256:'.Digest::SHA::sha256_hex($payload);
  # signfunc must return the openssl rsa signature
  my $sig = $signfunc->($payload);
  my $config = {
    'architecture' => '',
    'config' => {},
    'created' => '0001-01-01T00:00:00Z',
    'history' => [ { 'created' => '0001-01-01T00:00:00Z' } ],
    'os' => '',
    'rootfs' => { 'type' => 'layers', 'diff_ids' => [ $payload_digest ] },
  };
  my $config_json = canonical_json($config);
  my $payload_layer = {
    'annotations' => { 'dev.cosignproject.cosign/signature' => MIME::Base64::encode_base64($sig, ''), %{$annotations || {}} },
    'digest' => $payload_digest,
    'mediaType' => $mt_cosign,
    'size' => length($payload),
  };
  return ($config_json, $payload_layer, $payload, $sig);
}

1;

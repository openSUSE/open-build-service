use strict;
use warnings;

use Test::More tests => 4;
use FindBin;
use Data::Dumper;

require_ok('BSASN1');
require_ok('BSX509');

sub slurp {
  local $/;
  open(my $fd, '<', $_[0]) || die("$_[0]: $!\n");
  return scalar(<$fd>);
}

no warnings;
sub certinfo {
  my ($der) = @_;
  my $info  = {};
  my $tbscert = (BSASN1::unpack_sequence($der, undef, [ $BSASN1::CONS | $BSASN1::SEQUENCE, -1]))[0];
  my (undef, $serial, $sigalgo, $issuer, $validity, $subject, $subjectkeyinfo) = BSASN1::unpack_sequence($tbscert, undef, $BSX509::tbscertificate_tags);
  $serial = BSASN1::unpack_integer_mpi($serial);
  $info->{'serial'} = length($serial) ? '0x' . unpack('H*', $serial) : '0x0';
  ($info->{'begins'}, $info->{'expires'}) = BSX509::unpack_validity($validity);
  my $pkinfo = BSX509::pubkey2keydata($subjectkeyinfo);
  $info = { %$info, %$pkinfo};
  $info->{'keyid'} = unpack('H*', BSX509::generate_key_id($subjectkeyinfo));
  $info->{'subject'} = BSX509::dn2str($subject);
  $info->{'issuer'} = BSX509::dn2str($issuer) if $issuer ne $subject;
  my $fp = unpack('H*', BSX509::generate_cert_fingerprint($der));
  $info->{'fingerprint'} = $fp;
  return $info;
}
use warnings;

my ($result, $expected);

my $cert1 = "$FindBin::Bin/data/0023/cert.crt";

my $cert1_der = BSASN1::pem2der(slurp($cert1), 'CERTIFICATE');
is(length($cert1_der), 893, "DER cert length is correct");

$expected = { 'mpis' => [ { 'bits' => 2048 }, { 'bits' => 17 } ], 'algo' => 'rsa', 'keysize' => 2048,
          'keyid' => '0336599ae9505d27d090297a6976684e9f85bd3e',
          'fingerprint' => 'ade6e7fff4d5f86593fdf6c8646cceb68f84603c',
          'begins' => 1720688717,
          'expires' => 1789808717,
          'subject' => 'CN=just for testing, emailAddress=signd@localhost',
          'serial' => '0x6d48b301d25dfef3760ce75dd3a85227b5713633'
};
$result = certinfo($cert1_der);
delete $_->{'data'} for @{($result || {})->{'mpis'} || []};
is_deeply($result, $expected, "certinfo result");


use strict;
use warnings;

use Test::More tests => 9;
use FindBin;
use Data::Dumper;

require_ok('BSPGP');

sub slurp {
  local $/;
  open(my $fd, '<', $_[0]) || die("$_[0]: $!\n");
  return scalar(<$fd>);
}

sub get_first_sig {
  my ($pk) = @_;
  while ($pk ne '') {
    my ($tag, $len, $off) = BSPGP::pkdecodetaglenoff($pk);
    return substr($pk, 0, $off + $len) if $tag == 2;
    $pk = substr($pk, $off + $len);
  }
  return undef;
}

my ($result, $expected);

my $key1 = "$FindBin::Bin/data/0022/public-key.asc";

my $key1_noarmor = BSPGP::unarmor(slurp($key1));
is(length($key1_noarmor), 1466, "unarmored key length is correct");

$expected = { 'mpis' => [ { 'bits' => 2048 }, { 'bits' => 17 } ], 'keysize' => 2048, 'algo' => 'rsa' };
$result = BSPGP::pk2keydata($key1_noarmor);
# delete data part of mpis
delete $_->{'data'} for @{($result || {})->{'mpis'} || []};
is_deeply($result, $expected, "pk2keydata result");

$expected = { 'selfsig_create' => 1538979050, 'key_create' => 1538979050 };
$result = BSPGP::pk2times($key1_noarmor);
is_deeply($result, $expected, "pk2times result");

$expected = 'private OBS (key without passphrase) <defaultkey@localobs>';
$result = BSPGP::pk2userid($key1_noarmor);
is($result, $expected, "pk2userid result");

$expected = '2aa0e9f70f186184377807b57581f22be40a9a2f';
$result = BSPGP::pk2fingerprint($key1_noarmor);
is($result, $expected, "pk2fingerprint result");

$expected = [ '2aa0e9f70f186184377807b57581f22be40a9a2f', '7581f22be40a9a2f', 4 ];
$result = [ BSPGP::pk2fingerprint_keyid($key1_noarmor) ];
is_deeply($result, $expected, "pk2fingerprint_keyid result");

my $first_sig = get_first_sig($key1_noarmor);
is(length($first_sig), 316, "self-sig signature length is correct");

$expected = { 'pgpalgo' => 1, 'issuer' => '7581f22be40a9a2f', 'signtime' => 1538979050, 'pgptype' => 19, 'algo' => 'rsa', 'pgphash' => 2, 'hash' => 'sha1' };
$result = BSPGP::pk2sigdata($first_sig);
is_deeply($result, $expected, "pk2sigdata result");


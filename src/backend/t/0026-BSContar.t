use strict;
use warnings;

use Test::More tests => 6;
use FindBin;


require_ok('BSContar');

my ($result, $expected);

$expected = {
  'name' => 'blob',
  'data' => 'hello',
  'size' => 5,
  'blobid' => 'sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
  'foo' => 'bar',
};
($result) = BSContar::make_blob_entry('blob', 'hello', 'foo' => 'bar');
is_deeply($result, $expected, 'make_blob_entry');

is(BSContar::blobid_entry($result), $expected->{'blobid'}, 'blobid_entry matches');

$expected = 'amd64';
$result = BSContar::make_platformstr('amd64', undef, 'linux');
is($result, $expected, 'make_platformstr amd64');

$expected = 'arm64-v8';
$result = BSContar::make_platformstr('arm64', 'v8', 'linux');
is($result, $expected, 'make_platformstr arm64-v8');

$expected = 'any@darwin';
$result = BSContar::make_platformstr(undef, undef, 'darwin');
is($result, $expected, 'make_platformstr any@darwin');

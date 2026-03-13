#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 8;

require_ok('BSVerify');

my @valid_cases = (
  {
    name => 'attribute omitted keeps compatibility',
    data => { flavor => ['default'] },
  },
  {
    name => 'buildemptyflavor true is accepted',
    data => { buildemptyflavor => 'true', flavor => ['default'] },
  },
  {
    name => 'buildemptyflavor false is accepted',
    data => { buildemptyflavor => 'false', flavor => ['default'] },
  },
);

for my $tc (@valid_cases) {
  my $err;
  eval { BSVerify::verify_multibuild($tc->{data}); };
  $err = $@;
  ok(!$err, $tc->{name});
}

my @invalid_cases = (
  {
    name => 'buildemptyflavor invalid value is rejected',
    data => { buildemptyflavor => 'maybe', flavor => ['default'] },
    pattern => qr/buildemptyflavor must be either 'true' or 'false'/,
  },
  {
    name => 'buildemptyflavor must be lowercase true/false',
    data => { buildemptyflavor => 'False', flavor => ['default'] },
    pattern => qr/buildemptyflavor must be either 'true' or 'false'/,
  },
  {
    name => 'package and flavor together are still rejected',
    data => { buildemptyflavor => 'false', package => ['pkg1'], flavor => ['flv1'] },
    pattern => qr/multibuild cannot have both package and flavor elements/,
  },
  {
    name => 'flavor with colon is still rejected',
    data => { buildemptyflavor => 'true', flavor => ['bad:flavor'] },
    pattern => qr/flavor .* is illegal in multibuild/,
  },
);

for my $tc (@invalid_cases) {
  my $err;
  eval { BSVerify::verify_multibuild($tc->{data}); };
  $err = $@;
  like($err, $tc->{pattern}, $tc->{name});
}

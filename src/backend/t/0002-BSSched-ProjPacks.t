use strict;
use warnings;

use Test::More tests => 4;                      # last test to print

use_ok('BSSched::ProjPacks');

my $got       = undef;
my $out       = undef;
my $err       = undef;

### Testing BSSched::ProjPacks::getconfig

eval { $got = BSSched::ProjPacks::getconfig({}, 'project', 'package', 'x86_64') };
ok($@, "Checking getconfig with no path");

$got = BSSched::ProjPacks::getconfig({}, 'project', 'package', 'x86_64', ['openSUSE:test/standard']);
ok(ref($got) eq 'HASH', "Checking getconfig with empty gctx parameters");

my $gctx;
$gctx->{projpacks}->{'openSUSE:test'} = {foo => 'bar'};
$got = BSSched::ProjPacks::getconfig($gctx, 'project', 'package', 'x86_64',['openSUSE:test/standard']);

ok(ref($got) eq 'HASH', "Checking getconfig with projpacks");


exit 0;


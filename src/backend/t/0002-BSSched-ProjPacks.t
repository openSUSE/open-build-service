use strict;
use warnings;

use Test::More tests => 5;                      # last test to print

use_ok('BSSched::ProjPacks');

my $got       = undef;
my $out       = undef;
my $err       = undef;

### Testing BSSched::ProjPacks::getconfig

$got = BSSched::ProjPacks::getconfig({},'x86_64',[]);
ok(!defined($got), "Checking getconfig with invalid parameters");
eval { $got = BSSched::ProjPacks::getconfig() };
ok($@, "Checking getconfig with no parameters");

$got = BSSched::ProjPacks::getconfig({},'x86_64',['openSUSE:test/standard']);
ok(ref($got) eq 'HASH', "Checking getconfig with empty gctx parameters");

my $gctx;
$gctx->{projpacks}->{'openSUSE:test'} = {foo => 'bar'};
$got = BSSched::ProjPacks::getconfig($gctx,'x86_64',['openSUSE:test/standard']);

ok(ref($got) eq 'HASH', "Checking getconfig with projpacks");


exit 0;


use strict;
use warnings;

use Test::More tests => 3;                      # last test to print

no warnings 'once';

use_ok("BSSrcServer::Partition");

my ($got, $expected);

# Test Case 01
my $remotemap = {};
my $projid = "Test::Project";

eval {
    my $result = BSSrcServer::Partition::checkpartition($remotemap,$projid);
};

$got = $@;
$expected = "cannot determine partition for Test::Project\n";

is($got,$expected,"Check die if partition cannot be determined");

$BSConfig::partition = "test";

eval {
  my $result = BSSrcServer::Partition::checkpartition({ %$remotemap, ':partition' => $BSConfig::partition },$projid);
};

$got = $@;

is($got,'',"Check if checkpartition runs without errors");

#print $got;

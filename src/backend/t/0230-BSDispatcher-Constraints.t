use strict;
use warnings;

use Test::More tests => 6;                      # last test to print
use Data::Dumper;
use Build;

use_ok('BSDispatcher::Constraints');
use_ok('BSXML');
use_ok('BSUtil');

# set global return value to zero
my $ret = 0;

# get worker and constraint structs
my $worker1 = readxml("t/data/0230/worker:1", $BSXML::worker, 1);
my $worker2 = readxml("t/data/0230/worker:2", $BSXML::worker, 1);
my $constraints = readxml("t/data/0230/_constraints", $BSXML::constraints);

# test the oracle function
$ret = BSDispatcher::Constraints::oracle($worker1, $constraints);
ok($ret == 0, "Testing non compliant worker");
$ret = BSDispatcher::Constraints::oracle($worker2, $constraints);
ok($ret > 0, "Testing compliant worker");

# get disk constraint for size normalization
my $disk_constraint = readxml("t/data/0230/_disk", $BSXML::constraints); 
 
# check size normalization
my $expected_real_size = 4096; 
my $real_size = BSDispatcher::Constraints::getmbsize($disk_constraint->{'hardware'}->{'disk'});
ok($real_size == $expected_real_size, "Testing real MB size calculation");

exit 0;


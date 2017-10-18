use strict;
use warnings;

use Test::More tests => 1;                      # last test to print
use Data::Dumper;
require_ok('BSSched::BuildResult');
# sub set_suf_and_filter_exports {
# sub calculate_exportfilter {
# sub compile_exportfilter {
#

my $got;

my $fixtures = [
  {
    repo => {
        'test.rpm' => {
          name    => 'test',
          source  => 'test.tar.gz'
        }
    }
  }
];


$got = BSSched::BuildResult::set_suf_and_filter_exports($fixtures->[0]->{repo});

#print Dumper($got);

exit 0;


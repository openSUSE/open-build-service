use strict;
use warnings;

use Test::More tests => 5;                      # last test to print

require_ok('BSSched::BuildJob::Unknown');

my $job = BSSched::BuildJob::Unknown->new();

my @expected = ('broken', 'unknown package type'); 


ok($job,"Checking object generation with new");

my @got;

@got = $job->check();
is_deeply(\@got,\@expected,"Checking result of \$job->check()");

@got = $job->build();
is_deeply(\@got,\@expected,"Checking result of \$job->build()");

@got = $job->expand('a','b','c','d','e');
is_deeply(\@got,[1,'c','d','e'],"Checking result of \$job->expand()");


exit 0;


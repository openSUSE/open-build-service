use strict;
use warnings;


use FindBin;
use lib "$FindBin::Bin/lib/";

use Test::Mock::BSRPC;
use Test::Mock::BSConfig;

use Test::More tests => 2;                      # last test to print

use BSUtil;
use BSXML;
use Data::Dumper;

no warnings 'once';
# preparing data directory for testcase 1
$BSConfig::bsdir = "$FindBin::Bin/data/0360/";
$BSConfig::srcserver = 'srcserver';
$BSConfig::repodownload = 'http://download.opensuse.org/repositories';
use warnings;

use_ok("BSRepServer::BuildInfo");

my ($got,$expected);

### Test Case 01
($got) = BSRepServer::BuildInfo->new(projid=>'openSUSE:13.2', repoid=>'standard', arch=>'i586', packid=>'screen')->getbuildinfo();
$expected = BSUtil::readxml("$BSConfig::bsdir/result/buildinfo_13_2_screen", $BSXML::buildinfo);

$got->{'bdep'}  = [ sort {$a->{'name'} cmp $b->{'name'}} @{$got->{'bdep'} || []} ];
$expected->{'bdep'} = [ sort {$a->{'name'} cmp $b->{'name'}} @{$expected->{'bdep'} || []} ];

is_deeply($got, $expected, 'buildinfo for screen');

exit 0;

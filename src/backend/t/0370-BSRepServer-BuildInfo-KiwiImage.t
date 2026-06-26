use strict;
use warnings;


use FindBin;
use lib "$FindBin::Bin/lib/";

use Test::Mock::BSRPC;
use Test::Mock::BSConfig;
use Test::OBS::Utils;
use Test::OBS;
use Test::Mock::BSRepServer::Checker;

use Test::More tests => 3;                      # last test to print

use BSUtil;
use BSXML;
use Data::Dumper;



no warnings 'once';
# preparing data directory for testcase 1
$BSConfig::bsdir = "$FindBin::Bin/data/0370";


$Test::Mock::BSRPC::fixtures_map = {
  # rpc call to fixture map
  'srcserver/getprojpack?project=home:M0ses:kanku:Images&repository=images&arch=x86_64&package=openSUSE-Leap-42.1-JeOS&withdeps=1&buildinfo=1'
	=> 'srcserver/fixture_002_002',
  'srcserver/getprojpack?project=home:Admin:branches:openSUSE.org:home:M0ses:kanku:Images&repository=images&arch=x86_64&package=openSUSE-Leap-42.1-JeOS&withdeps=1&buildinfo=1',
	=> 'srcserver/fixture_002_003',
};
use warnings;

use_ok("BSRepServer::BuildInfo");

my ($got, $expected);

# Test Case 01
$got = BSRepServer::BuildInfo::buildinfo('home:M0ses:kanku:Images', 'images', 'x86_64', 'openSUSE-Leap-42.1-JeOS');
$expected = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/result/tc01", $BSXML::buildinfo);
cmp_buildinfo($got, $expected, 'buildinfo for Kiwi Image');

# Test Case 02
$got = BSRepServer::BuildInfo::buildinfo('home:Admin:branches:openSUSE.org:home:M0ses:kanku:Images', 'images', 'x86_64', 'openSUSE-Leap-42.1-JeOS');
$expected = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/result/tc02", $BSXML::buildinfo);
cmp_buildinfo($got, $expected, 'buildinfo for Kiwi Image with remotemap');

exit 0;


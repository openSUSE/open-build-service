use strict;
use warnings;


use FindBin;
use lib "$FindBin::Bin/lib/";

use Test::Mock::BSRPC;
use Test::Mock::BSConfig;
use Test::OBS::Utils;
use Test::OBS;
use Test::Mock::BSRepServer::Checker;

use Test::More tests => 2;                      # last test to print

use BSUtil;
use BSXML;
use Data::Dumper;

no warnings 'once';
# preparing data directory for testcase 1
$BSConfig::bsdir = "$FindBin::Bin/data/0380";


$Test::Mock::BSRPC::fixtures_map = {
  # rpc call to fixture map
  'srcserver/getprojpack?project=home:Admin:branches:openSUSE.org:OBS:Server:2.7&repository=images&arch=x86_64&package=_product:OBS-Addon-cd-cd-x86_64&withdeps=1&buildinfo=1'
	=> 'srcserver/fixture_003_002',
};
use warnings;

use_ok("BSRepServer::BuildInfo");

my ($got, $expected);

# Test Case 01
$got = BSRepServer::BuildInfo::buildinfo('home:Admin:branches:openSUSE.org:OBS:Server:2.7', 'images', 'x86_64', '_product:OBS-Addon-cd-cd-x86_64');
$expected = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/result/tc01", $BSXML::buildinfo);
cmp_buildinfo($got, $expected, 'buildinfo for Kiwi Product with remotemap');

exit 0;


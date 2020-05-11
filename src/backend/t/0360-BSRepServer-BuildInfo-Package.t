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
$BSConfig::bsdir = "$FindBin::Bin/data/0360/";
$BSConfig::srcserver = 'srcserver';
$BSConfig::repodownload = 'http://download.opensuse.org/repositories';
use warnings;

use_ok("BSRepServer::BuildInfo");

$Test::Mock::BSRPC::fixtures_map = {
  'srcserver/getprojpack?project=openSUSE:13.2&repository=standard&arch=i586&package=screen&withdeps=1&buildinfo=1'
        => 'srcserver/fixture_003_002',
  'srcserver/getprojpack?project=home:Admin:branches:openSUSE.org:OBS:Server:Unstable&repository=openSUSE_Leap_42.1&arch=x86_64&package=_product:OBS-Addon-release&withdeps=1&buildinfo=1'
        => 'srcserver/fixture_003_003',
};


my ($got, $expected);

### Test Case 01
$got = BSRepServer::BuildInfo::buildinfo('openSUSE:13.2', 'standard', 'i586', 'screen');
$expected = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/result/tc01", $BSXML::buildinfo);
cmp_buildinfo($got, $expected, 'buildinfo for screen');

# Test Case 02
$got = BSRepServer::BuildInfo::buildinfo('home:Admin:branches:openSUSE.org:OBS:Server:Unstable', 'openSUSE_Leap_42.1', 'x86_64', '_product:OBS-Addon-release');
$expected = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/result/tc02", $BSXML::buildinfo);
cmp_buildinfo($got, $expected, 'buildinfo for regular Package with remotemap');

exit 0;

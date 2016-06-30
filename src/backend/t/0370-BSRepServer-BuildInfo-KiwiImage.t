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
use XML::Structured;



no warnings 'once';
# preparing data directory for testcase 1
$BSConfig::bsdir = "$FindBin::Bin/data/0370";


$Test::Mock::BSRPC::fixtures_map = {
  # rpc call to fixture map
  'srcserver/getconfig?project=home:Admin:branches:openSUSE.org:home:M0ses:kanku:Images&repository=images&path=home:Admin:branches:openSUSE.org:home:M0ses:kanku:Images/images&path=openSUSE.org:openSUSE:Leap:42.1:Update/standard&path=openSUSE.org:openSUSE:Leap:42.1/standard'
	=> 'srcserver/fixture_002_000',
  'srcserver/getprojpack?withsrcmd5&withdeps&withrepos&expandedrepos&withremotemap&ignoredisable&project=home:Admin:branches:openSUSE.org:OBS:Server:Unstable&repository=openSUSE_Leap_42.1&arch=x86_64&parseremote=1&package=_product:OBS-Addon-release'
	=> 'srcserver/fixture_003_000',
  'srcserver/getconfig?project=home:Admin:branches:openSUSE.org:OBS:Server:Unstable&repository=openSUSE_Leap_42.1'
	=> 'srcserver/fixture_003_001',
  "srcserver/getprojpack?withsrcmd5&withdeps&withrepos&expandedrepos&withremotemap&ignoredisable&project=home:Admin:branches:openSUSE.org:home:M0ses:kanku:Images&repository=images&arch=x86_64&parseremote=1&package=openSUSE-Leap-42.1-JeOS" => 'srcserver/fixture_00002.xz',
  "srcserver/getprojpack?withsrcmd5&withdeps&withrepos&expandedrepos&withremotemap&ignoredisable&project=home:M0ses:kanku:Images&repository=images&arch=x86_64&parseremote=1&package=openSUSE-Leap-42.1-JeOS" => 'srcserver/fixture_00003.xz',
  "srcserver/getconfig?project=home:M0ses:kanku:Images&repository=images&path=home:M0ses:kanku:Images/images&path=openSUSE:Leap:42.1/standard&path=openSUSE:Leap:42.1:Update/standard" => "srcserver/fixture_00004.xz",
};
use warnings;

use_ok("BSRepServer::BuildInfo");

my ($got,$expected);

# Test Case 01
{ 
  ($got) = BSRepServer::BuildInfo->new(projid=>'home:M0ses:kanku:Images', repoid=>'images', arch=>'x86_64', packid=>'openSUSE-Leap-42.1-JeOS')->getbuildinfo();

  $expected = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/result/tc01", $BSXML::buildinfo);
}
cmp_buildinfo($got, $expected, 'buildinfo for Kiwi Image');

# Test Case 02
{
  ($got) = BSRepServer::BuildInfo->new(projid=>'home:Admin:branches:openSUSE.org:home:M0ses:kanku:Images', repoid=>'images', arch=>'x86_64', packid=>'openSUSE-Leap-42.1-JeOS')->getbuildinfo();

  $expected = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/result/tc02", $BSXML::buildinfo);
}
cmp_buildinfo($got, $expected, 'buildinfo for Kiwi Image with remotemap');

exit 0;


use strict;
use warnings;


use FindBin;
use lib "$FindBin::Bin/lib/";

use Test::Mock::BSRPC;
use Test::Mock::BSConfig;
use Test::OBS::Utils;

use Test::More tests => 3;                      # last test to print

use BSUtil;
use BSXML;
use Data::Dumper;
use XML::Structured;


no warnings 'once';
# preparing data directory for testcase 1
$BSConfig::bsdir = "$FindBin::Bin/data/0370";
$BSConfig::srcserver = 'srcserver';
$BSConfig::repodownload = 'http://download.opensuse.org/repositories';


$Test::Mock::BSRPC::fixtures_map = {
  # rpc call to fixture map
   'srcserver/getconfig?project=home:Admin:branches:openSUSE.org:home:M0ses:kanku:Images&repository=images&path=home:Admin:branches:openSUSE.org:home:M0ses:kanku:Images/images&path=openSUSE.org:openSUSE:Leap:42.1:Update/standard&path=openSUSE.org:openSUSE:Leap:42.1/standard'
	=> 'srcserver/fixture_002_000',
};
use warnings;

use_ok("BSRepServer::BuildInfo");

my ($got,$expected);

# decompress fixtures and keep track of them
my @files2delete = Test::OBS::Utils::prepare_compressed_files("$BSConfig::bsdir/build");

# Test Case 01
{ 
	($got) = BSRepServer::BuildInfo->new(projid=>'home:M0ses:kanku:Images', repoid=>'images', arch=>'x86_64', packid=>'openSUSE-Leap-42.1-JeOS')->getbuildinfo();

	$expected = Test::OBS::Utils::transparent_read_xz("$BSConfig::bsdir/result/tc01",\&BSUtil::readxml,$BSXML::buildinfo);

	$got->{'bdep'}  = [ sort {$a->{'name'} cmp $b->{'name'}} @{$got->{'bdep'} || []} ];
	$expected->{'bdep'} = [ sort {$a->{'name'} cmp $b->{'name'}} @{$expected->{'bdep'} || []} ];
}
is_deeply($got, $expected, 'buildinfo for Kiwi Image');


# Test Case 02
{

	local *STDOUT;
	my $out;
	open(STDOUT,">",\$out);

	($got) = BSRepServer::BuildInfo->new(projid=>'home:Admin:branches:openSUSE.org:home:M0ses:kanku:Images', repoid=>'images', arch=>'x86_64', packid=>'openSUSE-Leap-42.1-JeOS')->getbuildinfo();

	#my $data = BSUtil::readstr("$BSConfig::bsdir/result/tc02");
	#eval "$data";

	$expected = Test::OBS::Utils::transparent_read_xz("$BSConfig::bsdir/result/tc02",\&BSUtil::readxml,$BSXML::buildinfo);

	$got->{'bdep'}  = [ sort {$a->{'name'} cmp $b->{'name'}} @{$got->{'bdep'} || []} ];
	$expected->{'bdep'} = [ sort {$a->{'name'} cmp $b->{'name'}} @{$expected->{'bdep'} || []} ];
}
is_deeply($got, $expected, 'buildinfo for Kiwi Image with remotemap');


# cleanup decompressed files
for my $f (@files2delete) {
  unlink $f;
};

exit 0;

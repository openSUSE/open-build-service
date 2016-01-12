use strict;
use warnings;

use Test::More tests => 5;                      # last test to print

require_ok('BSSched::BuildRepo');
use FindBin;
use Data::Dumper;

### fctx_set_metaidmd5
my $got = undef;

$got = BSSched::BuildRepo::fctx_set_metaidmd5();
is($got,'d41d8cd98f00b204e9800998ecf8427e',"Checking without fctx");

$got = BSSched::BuildRepo::fctx_set_metaidmd5({lastmeta=> $FindBin::Bin.'/data/0010/lastmeta.empty'});
is($got,'d41d8cd98f00b204e9800998ecf8427e',"Checking empty lastmeta");

$got = BSSched::BuildRepo::fctx_set_metaidmd5({lastmeta=> $FindBin::Bin.'/data/0010/lastmeta.nonexistent'});
is($got,'00000000000000000000000000000000',"Checking non existent");

$got = BSSched::BuildRepo::fctx_set_metaidmd5({lastmeta=> $FindBin::Bin.'/data/0010/lastmeta'});
is($got,'d8e8fca2dc0f896fd7cb4cb0031ba249',"Checking lastmeta with content");


exit 0;

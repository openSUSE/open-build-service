#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;


use FindBin;
use lib "$FindBin::Bin/lib/";

use BSUtil;
use Test::Mock::BSConfig;
use Test::Mock::BSRPC;


@::ARGV = ('--testcase');
require_ok('./bs_worker');

$BSConfig::bsdir = $FindBin::Bin;
my $tmpdir = "$FindBin::Bin/tmp/1000";
mkdir($tmpdir);

my $buildinfo = {
  srcserver  => $BSConfig::srcserver,
  project    => 'project1',
  package    => 'package1',
  srcmd5     => 'f157738ddea737a2b7479996175a6cec',
  verifymd5  => 'f157738ddea737a2b7479996175a6cec',
};

$Test::Mock::BSRPC::fixtures_map = {
  "srcserver/getsources?project=project1&package=package1&srcmd5=$buildinfo->{srcmd5}"
    => 'data/1000/srcserver/getsources',
};

my (@got, @expected);


# getsources

@got = getsources($buildinfo, $tmpdir);
@expected = ('f157738ddea737a2b7479996175a6cec  package1');
is_deeply(\@got, \@expected, 'getsources - Return value');

my $expected = [
                 {
                   'digest' => {
                     'sha256' => 'e237d5c5ea2b4dd327d2e103afd09572286609fbc9bf43cc9609f1371b4c8dd2'
                   },
                   'uri' => 'srcserver/source/project1/package1/hello_world.spec?rev=f157738ddea737a2b7479996175a6cec'
                 }
               ];
is_deeply($buildinfo->{'materials'}, $expected, "getsources - Add 'materials' key to \$buildinfo");

BSUtil::cleandir($tmpdir);
rmdir($tmpdir);

#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

use_ok("BSRepServer");

$BSConfig::repodownload = "http://a.b.c.de";
my ($got,$expected);
$expected = "http://a.b.c.de/prp_ext/";
eval {
	$got = BSRepServer::get_downloadurl("prp","prp_ext");
};
is($got,$expected,"Checking download url");

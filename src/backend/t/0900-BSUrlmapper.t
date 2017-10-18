#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

use_ok("BSUrlmapper");

$BSConfig::repodownload = undef;	# get rid of warning
$BSConfig::repodownload = "http://a.b.c.de";

my ($got,$expected);
$expected = "http://a.b.c.de/p1:/p2/r1/";
eval {
	$got = BSUrlmapper::get_downloadurl("p1:p2/r1");
};
is($got,$expected,"Checking download url");

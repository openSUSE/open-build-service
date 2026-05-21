#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 1;
use FindBin;

system("osc meta prj home:Admin:scmbridge -F $FindBin::Bin/fixtures/home:Admin:scmbridge.xml");

ok(!$?,"Checking creation of home:Admin:scmbridge project");

exit 0

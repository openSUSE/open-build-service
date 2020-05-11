#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 1;
use FindBin;

system("osc meta prj home:Admin -F $FindBin::Bin/fixtures/home:Admin.xml");

ok(!$?,"Checking creation of home:Admin project");

exit 0

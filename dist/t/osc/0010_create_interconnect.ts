#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 1;
use FindBin;

system("osc meta prj openSUSE.org -F $FindBin::Bin/fixtures/openSUSE.org.xml");

ok(!$?,"Configuring interconnect");

exit 0;

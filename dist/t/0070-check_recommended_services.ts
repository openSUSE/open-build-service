#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;

BEGIN {
  unshift @::INC,
    "$FindBin::Bin/lib",
    "$FindBin::Bin/../../src/backend/build",
    "/usr/lib/build"
  ;
}

use OBS::Test::Utils;
use Build::Rpm;

my $test_count = 6;
my $max_wait = 300;

my @daemons = qw/obsdodup obssigner obsdeltastore/;
my $pkg_ver = OBS::Test::Utils::get_package_version('obs-server', 2);
if ( Build::Rpm::verscmp($pkg_ver, "2.8.99") > 0) {
  $test_count = 8;
  push (@daemons, 'obsservicedispatch');
}

plan tests => $test_count;

foreach my $srv (@daemons) {
	my @state=`systemctl is-enabled $srv\.service 2>/dev/null`;
	chomp($state[-1]);
	is($state[-1],"enabled","Checking if recommended service $srv is enabled");
}

my %srv_state=();

while ($max_wait > 0) {
	
	foreach my $srv (@daemons) {
		my @state=`systemctl is-active $srv\.service 2>/dev/null`;
		chomp($state[0]);
		if ( $state[0] eq 'active') {
			$srv_state{$srv} = 'active';
		}
	}
	if ( keys(%srv_state) == scalar(@daemons) ) {
		last;
	}
	$max_wait--;
	sleep 1;
}

foreach my $srv ( @daemons ) {
	is($srv_state{$srv} || 'timeout','active',"Checking recommended service '$srv' status");
}


exit 0;

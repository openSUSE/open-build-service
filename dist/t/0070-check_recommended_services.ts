#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use OBS::Test::Utils;
use Test::More 'tests' => 6;

my $max_wait = 300;

my @daemons = qw/obsdodup obssigner obsdeltastore/;
my $pkg_ver = OBS::Test::Utils::get_package_version('obs-server', 2);

if ( $pkg_ver > 2.8) {
  plan tests => 8;
  push (@daemons, 'obsservicedispatcher');
}

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

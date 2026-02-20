#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 20;

use Test::Mock::BSConfig;

require_ok('BSSrcServer::Multibuild');

{
	no warnings 'redefine';

	local *BSSrcServer::Multibuild::getcache = sub {
		return {
			'mypackage' => {
				'flavor' => [ 'flavor1', 'flavor2' ],
			},
		};
	};

	my @got = BSSrcServer::Multibuild::addmultibuildpackages('home:Admin', undef, 'mypackage');
	is_deeply(
		\@got,
		[ 'mypackage', 'mypackage:flavor1', 'mypackage:flavor2' ],
		'default behavior keeps base package and adds flavored packages'
	);
}

{
	no warnings 'redefine';

	local *BSSrcServer::Multibuild::getcache = sub {
		return {
			'mypackage' => {
				'buildemptyflavor' => 'true',
				'flavor' => [ 'flavor1' ],
			},
		};
	};

	my @got = BSSrcServer::Multibuild::addmultibuildpackages('home:Admin', undef, 'mypackage');
	is_deeply(
		\@got,
		[ 'mypackage', 'mypackage:flavor1' ],
		'buildemptyflavor=true keeps the base package'
	);
}

{
	no warnings 'redefine';

	local *BSSrcServer::Multibuild::getcache = sub {
		return {
			'mypackage' => {
				'buildemptyflavor' => 'false',
				'flavor' => [ 'flavor1', 'flavor2' ],
			},
		};
	};

	my %origins = ( 'mypackage' => 'origin:Project' );
	my @got = BSSrcServer::Multibuild::addmultibuildpackages('home:Admin', \%origins, 'mypackage');

	is_deeply(
		\@got,
		[ 'mypackage:flavor1', 'mypackage:flavor2' ],
		'buildemptyflavor=false excludes the base package'
	);
	is(
		$origins{'mypackage:flavor1'},
		'origin:Project',
		'origin copied to first flavored package'
	);
	is(
		$origins{'mypackage:flavor2'},
		'origin:Project',
		'origin copied to second flavored package'
	);
	ok(!exists $origins{'mypackage:unknown'}, 'no extra origin entries are created');
}

# packids_match_packages: flavor packages should match against base name
{
	ok(
		BSSrcServer::Multibuild::packids_match_packages(
			{'mypackage' => 1},
			'mypackage:flavor1', 'mypackage:flavor2'
		),
		'packids_match_packages matches flavor against base name in packids'
	);
}

# packids_match_packages: exact match still works
{
	ok(
		BSSrcServer::Multibuild::packids_match_packages(
			{'mypackage' => 1},
			'mypackage'
		),
		'packids_match_packages matches exact package name'
	);
}

# packids_match_packages: no match when base differs
{
	ok(
		!BSSrcServer::Multibuild::packids_match_packages(
			{'mypackage' => 1},
			'otherpkg:flavor1', 'otherpkg:flavor2'
		),
		'packids_match_packages does not match unrelated flavors'
	);
}

# packids_match_packages: _product: and _patchinfo: are not multibuild flavors
{
	ok(
		!BSSrcServer::Multibuild::packids_match_packages(
			{'_product' => 1, '_patchinfo' => 1},
			'_product:openSUSE', '_patchinfo:12345'
		),
		'packids_match_packages excludes _product: and _patchinfo: packages'
	);
}

# packids_match_packages: mixed list with regular and flavor packages
{
	ok(
		BSSrcServer::Multibuild::packids_match_packages(
			{'otherpkg' => 1},
			'mypackage:flavor1', 'otherpkg', 'mypackage:flavor2'
		),
		'packids_match_packages matches regular package in mixed list'
	);
}

# check_flavor_update: base package returns (mb, undef)
{
	no warnings 'redefine';

	my $expected_mb = { 'flavor' => ['flavor1'] };
	local *BSSrcServer::Multibuild::updatemultibuild = sub { return $expected_mb };

	my ($mb, $stale) = BSSrcServer::Multibuild::check_flavor_update('home:Admin', 'mypackage', {}, 1);
	is($mb, $expected_mb, 'check_flavor_update returns mb data for base packages');
	ok(!defined $stale, 'check_flavor_update returns no stale packages for base packages');
}

# check_flavor_update: valid flavor returns (undef, undef)
{
	no warnings 'redefine';

	local *BSSrcServer::Multibuild::updatemultibuild = sub { return {'flavor' => ['flavor1']} };
	local *BSSrcServer::Multibuild::getcache = sub {
		return {
			'mypackage' => {
				'buildemptyflavor' => 'false',
				'flavor' => [ 'flavor1' ],
			},
		};
	};

	my ($mb, $stale) = BSSrcServer::Multibuild::check_flavor_update('home:Admin', 'mypackage:flavor1', {}, 1);
	ok(!defined $mb, 'check_flavor_update returns no mb for valid flavor');
	ok(!defined $stale, 'check_flavor_update returns no stale packages for valid flavor');
}

# check_flavor_update: stale flavor returns (undef, \@newpackages)
{
	no warnings 'redefine';

	local *BSSrcServer::Multibuild::updatemultibuild = sub { return {'flavor' => ['new_flavor']} };
	local *BSSrcServer::Multibuild::getcache = sub {
		return {
			'mypackage' => {
				'buildemptyflavor' => 'false',
				'flavor' => [ 'new_flavor' ],
			},
		};
	};

	my ($mb, $stale) = BSSrcServer::Multibuild::check_flavor_update('home:Admin', 'mypackage:old_flavor', {}, 1);
	ok(!defined $mb, 'check_flavor_update returns no mb for stale flavor');
	is_deeply(
		$stale,
		[ 'mypackage:new_flavor' ],
		'check_flavor_update returns new package list when flavor is stale'
	);
}

# Multiple base packages: buildemptyflavor only affects the package that sets it
{
	no warnings 'redefine';

	local *BSSrcServer::Multibuild::getcache = sub {
		return {
			'pkg_a' => {
				'buildemptyflavor' => 'false',
				'flavor' => [ 'flavor1' ],
			},
			'pkg_b' => {
				'flavor' => [ 'flavor2' ],
			},
		};
	};

	my @got = BSSrcServer::Multibuild::addmultibuildpackages('home:Admin', undef, 'pkg_a', 'pkg_b');

	is_deeply(
		\@got,
		[ 'pkg_a:flavor1', 'pkg_b', 'pkg_b:flavor2' ],
		'buildemptyflavor only excludes the base of the package that sets it'
	);

	ok(
		BSSrcServer::Multibuild::packids_match_packages({'pkg_a' => 1}, @got),
		'packids_match_packages works with mixed buildemptyflavor packages'
	);
}

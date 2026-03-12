#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 8;

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
		[ 'mypackage', 'mypackage:flavor1', 'mypackage:flavor2' ],
		'buildemptyflavor=false keeps the base package in the list (excluded via pinfo in src server)'
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

# Multiple base packages: buildemptyflavor setting is per-package
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
		[ 'pkg_a', 'pkg_a:flavor1', 'pkg_b', 'pkg_b:flavor2' ],
		'both base packages are kept regardless of buildemptyflavor'
	);
}

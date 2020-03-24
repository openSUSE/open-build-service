#!/usr/bin/perl -w

use strict;
use Test::More tests => 5;
use Data::Dumper;

use BSXPathKeys;
use BSXPath;
use BSDB;
use Carp;

my @fruits = (
  { name => 'apple', color => [ 'red' ] },
  { name => 'grape', color => [ 'green', 'blue' ] },
  { name => 'ananas', color => [ 'yellow' ] },
);

my $fruit = { 'fruit' => \@fruits };
my $fruits = { 'fruits' => $fruit };

# create index
my %index;

for my $key (1..@fruits) {
  my @rel;
  BSDB::torel('', $key, $fruits[$key - 1], \@rel);
  $index{"fruits/fruit/$_->[0]"}->{$_->[1]}->{$_->[2]} = 1 for @rel;
}

package BSXPathKeysTest;

sub rawfetch {
  my ($db, $key) = @_; 
  return { 'fruits' => { 'fruit' => $fruits[$key - 1] } };
}

sub rawvalues {
  my ($db, $path) = @_;
  return sort keys(%{$index{$path} || {}});
}

sub rawkeys {
  my ($db, $path, $value) = @_;
  return map {$_} 1..@fruits unless defined $path;
  return sort keys(%{($index{$path} || {})->{$value} || {}});
}

sub fetch;
sub keys;
sub values;
*fetch = \&BSDB::fetch;
*keys = \&BSDB::keys;
*values = \&BSDB::values;


package main;


my @select_tests = (
  'fruits/fruit[name="grape"]/color="green"' => 'true',
  'fruits/fruit[name="grape"]/color!="green"' => 'true',

  'fruits/fruit[starts-with(name,"a")]/name' => [ 'apple', 'ananas' ],
  'fruits/fruit[not(xxx)]/name' => [ 'apple', 'grape', 'ananas' ],
  'fruits/fruit[starts-with(name,"a") and not(contains(name,"as"))]/name' => [ 'apple' ],
);

my $db = bless {}, 'BSXPathKeysTest';
my $rootnode = BSXPathKeys::node($db, '');

while (@select_tests) {
  my ($path, $expected) = splice(@select_tests, 0, 2);
  my $actual = BSXPath::select($rootnode, $path);
  $actual = [ sort @$actual ] if ref($actual);
  $expected = [ sort @$expected ] if ref($expected);
  is_deeply($actual, $expected, $path);
}


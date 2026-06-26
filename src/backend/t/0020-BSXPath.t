#!/usr/bin/perl -w

use strict;
use Test::More tests => 34;
use Data::Dumper;

use BSXPath;

my $fruit = {
  'fruit' => [
    { name => 'apple', color => [ 'red' ] },
    { name => 'grape', color => [ 'green', 'blue' ] },
    { name => 'ananas', color => [ 'yellow' ] },
  ],
};
my $fruits = { 'fruits' => $fruit };

my @select_tests = (
  '4*1024'                      => '4096',
  '5 < 1'                       => '',
  '(4 + 5) * 2 = 18'            => 'true',
  '5 or 0'                      => 'true',
  '5 and 0'                     => '',
  'not("")'                     => 'true',
  'not("foo")'                  => '',
  '0 or 3'                      => 'true',
  '2 or 3'                      => 'true',
  '0 or 0'                      => '',
  '2 or 0'                      => 'true',
  '"" or "foo"'                 => 'true',
  '"bar" or "foo"'              => 'true',
  '0 and 3'                     => '',
  '2 and 3'                     => 'true',
  '0 and 0'                     => '',
  '2 and 0'                     => '',
  '"" and "foo"'                => '',
  '"bar" and "foo"'             => 'true',
  '1 or 2 and 0'                => 'true',
  '1 - 1 - 1'                   => '-1',
  '1 + 2 * 3'                   => '7',
  '2 * -2'                      => '-4',
  '7 = 1 + 2 * 3'               => 'true',
  '5 mod 2'                     => '1',
  'string(1 and 0)'             => 'false',
  'number(1 and 0)'             => '0',
  'concat("foo", "bar", "baz")' => 'foobarbaz',

  'fruits/fruit[name="grape"]/color="green"' => 'true',
  'fruits/fruit[name="grape"]/color!="green"' => 'true',

  'fruits/fruit[starts-with(name,"a")]/name' => [ 'apple', 'ananas' ],
  'fruits/fruit[not(xxx)]/name' => [ 'apple', 'grape', 'ananas' ],
  'fruits/fruit[starts-with(name,"a") and not(contains(name,"as"))]/name' => [ 'apple' ],
  'string(fruits/fruit[name="grape"]/color)' => 'green',
);

while (@select_tests) {
  my ($path, $expected) = splice(@select_tests, 0, 2);
  my $actual = BSXPath::select($fruits, $path);
  is_deeply($actual, $expected, $path);
}


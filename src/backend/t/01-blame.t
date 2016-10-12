#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 31;

use BSBlame::Diff3;

our $fixtures_dir = 'fixtures';

sub test_sub {
  my ($test_name, $code_ref, $args, $expected) = @_;
  die("code ref required\n") unless $code_ref;
  is_deeply($code_ref->(@$args), $expected, $test_name);
}

sub fixture {
  my ($filename) = @_;
  my $dir = __FILE__;
  $dir =~ s/\/[^\/]*$//;
  return "$dir/$fixtures_dir/$filename";
}

sub test_diff3 {
  my ($test_name, $args, @expected) = @_;
  test_sub("diff3: " . $test_name,
    sub { return [BSBlame::Diff3::diff3(@_)]; },
    $args, \@expected);
}

sub test_merge {
  my ($test_name, $args, @expected) = @_;
  test_sub("merge: " . $test_name,
    sub { return [BSBlame::Diff3::merge(@_)]; },
    $args, \@expected);
}

# test cases for BSBlame::Diff3::diff3

test_diff3("two-way diff of my and /dev/null",
  ['/dev/null', fixture('my'), '/dev/null'],
  (
    {
      'odd' => 1,
      'data' => [
        [-1, -1, 'a'],
        [0, 11, 'c'],
        [-1, -1, 'a']
      ]
    }
  ));

test_diff3("two-way diff of your and common",
  [fixture('common'), fixture('your'), fixture('common')],
  (
    {
      'odd' => 1,
      'data' => [
        [4, 5, 'c'],
        [4, 5, 'c'],
        [4, 5, 'c']
      ]
    },
    {
      'odd' => 1,
      'data' => [
        [9, 9, 'a'],
        [10, 12, 'c'],
        [9, 9, 'a']
      ]
    }
  ));

test_diff3("three-way diff of my, your and common",
  [fixture('my'), fixture('your'), fixture('common')],
  (
    {
      'odd' => 0,
      'data' => [
        [1, 2, 'c'],
        [1, 1, 'c'],
        [1, 1, 'c']
      ]
    },
    {
      'odd' => 1,
      'data' => [
        [5, 6, 'c'],
        [4, 5, 'c'],
        [4, 5, 'c']
      ]
    },
    {
      'odd' => 0,
      'data' => [
        [8, 10, 'c'],
        [7, 8, 'c'],
        [7, 8, 'c']
      ]
    },
    {
      'odd' => 1,
      'data' => [
        [11, 11, 'a'],
        [10, 12, 'c'],
        [9, 9, 'a']
      ]
    }
  ));

test_diff3("three-way diff of my, your.noeol and common (your.noeol has no EOL)",
  [fixture('my'), fixture('your.noeol'), fixture('common')],
  (
    {
      'odd' => 0,
      'data' => [
        [1, 2, 'c'],
        [1, 1, 'c'],
        [1, 1, 'c']
      ]
    },
    {
      'odd' => 1,
      'data' => [
        [5, 6, 'c'],
        [4, 5, 'c'],
        [4, 5, 'c']
      ]
    },
    {
      'odd' => 0,
      'data' => [
        [8, 10, 'c'],
        [7, 8, 'c'],
        [7, 8, 'c']
      ]
    },
    {
      'odd' => 1,
      'data' => [
        [11, 11, 'a'],
        [10, 12, 'c'],
        [9, 9, 'a']
      ]
    }
  ));

test_diff3("empty three-way diff",
  [fixture('my'), fixture('my'), fixture('my')],
  ());

test_diff3("conflict in a three-way diff",
  [fixture('common'), fixture('your'), fixture('my')],
  (
    {
      'odd' => 2,
      'data' => [
        [1, 1, 'c'],
        [1, 1, 'c'],
        [1, 2, 'c']
      ]
    },
    {
      'odd' => 1,
      'data' => [
        [4, 5, 'c'],
        [4, 5, 'c'],
        [5, 6, 'c']
      ]
    },
    {
      'odd' => undef,
      'data' => [
        [7, 9, 'c'],
        [7, 12, 'c'],
        [8, 11, 'c']
      ]
    }
  ));

# test cases for BSBlame::Diff3::merge

test_merge("my and /dev/null",
  [fixture('my'), '/dev/null', '/dev/null'],
  (
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 3],
    [0, 4],
    [0, 5],
    [0, 6],
    [0, 7],
    [0, 8],
    [0, 9],
    [0, 10],
    [0, 11]
  ));

test_merge("/dev/null and common",
  ['/dev/null', fixture('common'), fixture('common')],
  ());

test_merge("my, your and common",
  [fixture('my'), fixture('your'), fixture('common')],
  (
    [2, 0],
    [0, 1],
    [0, 2],
    [2, 2],
    [2, 3],
    [1, 4],
    [1, 5],
    [2, 6],
    [0, 8],
    [0, 9],
    [0, 10],
    [2, 9],
    [1, 10],
    [1, 11],
    [1, 12]
  ));

# same result as above
test_merge("my, your.noeol and common (your.noeol has no EOL)",
  [fixture('my'), fixture('your.noeol'), fixture('common')],
  (
    [2, 0],
    [0, 1],
    [0, 2],
    [2, 2],
    [2, 3],
    [1, 4],
    [1, 5],
    [2, 6],
    [0, 8],
    [0, 9],
    [0, 10],
    [2, 9],
    [1, 10],
    [1, 11],
    [1, 12]
  ));

test_merge("only changes in the middle of the files (take rest from common)",
  [fixture('my'), fixture('common'), fixture('common')],
  (
    [2, 0],
    [0, 1],
    [0, 2],
    [2, 2],
    [2, 3],
    [2, 4],
    [2, 5],
    [2, 6],
    [0, 8],
    [0, 9],
    [0, 10],
    [2, 9]
  ));

test_merge("/dev/null /dev/null common",
  ['/dev/null', '/dev/null', fixture('common')],
  ());

test_merge("no changes (real file)",
  [fixture('my'), fixture('my'), fixture('my')],
  (
    [2, 0],
    [2, 1],
    [2, 2],
    [2, 3],
    [2, 4],
    [2, 5],
    [2, 6],
    [2, 7],
    [2, 8],
    [2, 9],
    [2, 10],
    [2, 11]
  ));

test_merge("no changes (/dev/null)",
  ['/dev/null', '/dev/null', '/dev/null'],
  ());

test_merge("numlines for the common file",
  [fixture('my'), fixture('common'), fixture('common'), 9],
  (
    [2, 0],
    [0, 1],
    [0, 2],
    [2, 2],
    [2, 3],
    [2, 4],
    [2, 5],
    [2, 6],
    [0, 8],
    [0, 9],
    [0, 10],
    [2, 9]
  ));

test_merge("numlines for the common file (one line less)",
  [fixture('my'), fixture('common'), fixture('common'), 8],
  (
    [2, 0],
    [0, 1],
    [0, 2],
    [2, 2],
    [2, 3],
    [2, 4],
    [2, 5],
    [2, 6],
    [0, 8],
    [0, 9],
    [0, 10]
  ));

test_merge("pretend that the common file comprises one line (numlines 0)",
  [fixture('my'), fixture('my'), fixture('my'), 0],
  (
    [2, 0]
  ));

test_merge("pretend that the common file is empty (numlines -1)",
  [fixture('my'), fixture('my'), fixture('my'), -1],
  ());

test_merge("conflict",
  [fixture('common'), fixture('your'), fixture('my')],
  undef);

test_merge("my2.sdel my2.sdel common2 (deletes a single line from common2)",
  [fixture('my2.sdel'), fixture('my2.sdel'), fixture('common2')],
  (
    [2, 0],
    [2, 1],
    [2, 3],
    [2, 4]
  ));

test_merge("my2.mdel my2.mdel common2 (deletes multiple lines from common2)",
  [fixture('my2.mdel'), fixture('my2.mdel'), fixture('common2')],
  (
    [2, 0],
    [2, 1],
    [2, 4]
  ));

test_merge("my2.sadd my2.sadd common2 (adds a single line from the my file)",
  [fixture('my2.sadd'), fixture('my2.sadd'), fixture('common2'), undef, $BSBlame::Diff3::FM],
  (
    [2, 0],
    [2, 1],
    [2, 2],
    [0, 3],
    [2, 3],
    [2, 4]
  ));

test_merge("my2.sadd my2.sadd common2 (adds a single line from the your file)",
  [fixture('my2.sadd'), fixture('my2.sadd'), fixture('common2'), undef, $BSBlame::Diff3::FY],
  (
    [2, 0],
    [2, 1],
    [2, 2],
    [1, 3],
    [2, 3],
    [2, 4]
  ));

# same as above, but the ctie is omitted
test_merge("my2.sadd my2.sadd common2 (adds a single line from the your file)",
  [fixture('my2.sadd'), fixture('my2.sadd'), fixture('common2')],
  (
    [2, 0],
    [2, 1],
    [2, 2],
    [1, 3],
    [2, 3],
    [2, 4]
  ));

test_merge("my2.madd my2.madd common2 (adds multiple lines from the my file)",
  [fixture('my2.madd'), fixture('my2.madd'), fixture('common2'), undef, $BSBlame::Diff3::FM],
  (
    [2, 0],
    [2, 1],
    [2, 2],
    [0, 3],
    [0, 4],
    [0, 5],
    [2, 3],
    [2, 4]
  ));

test_merge("my2.madd my2.madd common2 (adds multiple lines from the your file)",
  [fixture('my2.madd'), fixture('my2.madd'), fixture('common2')],
  (
    [2, 0],
    [2, 1],
    [2, 2],
    [1, 3],
    [1, 4],
    [1, 5],
    [2, 3],
    [2, 4]
  ));

test_merge("my2.change my2.change common2 (adds + deletes from the my file)",
  [fixture('my2.change'), fixture('my2.change'), fixture('common2'), undef, $BSBlame::Diff3::FM],
  (
    [2, 0],
    [2, 1],
    [0, 2],
    [0, 3],
    [0, 4],
    [2, 4]
  ));

test_merge("my2.change my2.change common2 (adds + deletes from the your file)",
  [fixture('my2.change'), fixture('my2.change'), fixture('common2')],
  (
    [2, 0],
    [2, 1],
    [1, 2],
    [1, 3],
    [1, 4],
    [2, 4]
  ));

test_merge("my3 your3 common3 (adds + deletes + changes)",
  [fixture('my3'), fixture('your3'), fixture('common3')],
  (
    [0, 0],
    [2, 1],
    [1, 2],
    [2, 3],
    [2, 6],
    [2, 7],
    [0, 6],
    [0, 7],
    [2, 8],
    [1, 7],
    [1, 8],
    [2, 9],
    [0, 10],
    [0, 11],
    [2, 10]
  ));

test_merge("common2 my2.mdel common2 (basically a two-way diff)",
  [fixture('common2'), fixture('my2.mdel'), fixture('common2')],
  (
    [2, 0],
    [2, 1],
    [2, 4]
  ));

test_merge("my2.sdel common2 common2 (my2.sdel just removes a single line)",
  [fixture('my2.sdel'), fixture('common2'), fixture('common2')],
  (
    [2, 0],
    [2, 1],
    [2, 3],
    [2, 4]
  ));

#test_merge("my2, your2 and common (my2 and your2 share a new line)",
#  [fixture('my2'), fixture('common'), fixture('your2')],
#  (
#    [2, 0],
#    [2, 1],
#    [2, 2],
#    [1, 3],
#    [2, 3],
#    [2, 0],
#    [0, 6],
#    [0, 7],
#    [0, 8],
#    [2, 9],
#    [1, 9],
#    [1, 10],
#    [1, 11]
#  ));

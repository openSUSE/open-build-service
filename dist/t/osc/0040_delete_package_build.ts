#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use File::Path qw(make_path remove_tree);

my $TMP_DIR="$FindBin::Bin/tmp/";
if ( -f "$TMP_DIR/.SKIP" ) {
  plan skip_all => "Previous tests failed - keeping results";
} else {
  plan tests => 2;

  chdir("$TMP_DIR/home:Admin");

  system("osc delete obs-testpackage");

  ok(!$?,"Deleting package obs-testpackage");

  system("osc ci -m \"removed package obs-testpackage\"");
 ok(!$?,"Commiting deleted package obs-testpackage");

  # cleanup TMP_DIR
  chdir($FindBin::Bin);
  remove_tree($TMP_DIR);
}

exit 0;

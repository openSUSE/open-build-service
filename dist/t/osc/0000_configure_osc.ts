#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 1;

eval {
  my $oscrc="$::ENV{HOME}/.oscrc";
  open(OSCRC,'>',$oscrc) || die "Could not open $oscrc: $!";
  print OSCRC "[general]
apiurl = https://localhost

[https://localhost]
user=Admin
pass=opensuse
";
  close OSCRC;
};

ok(!$@,"Configuring oscrc");

exit 0

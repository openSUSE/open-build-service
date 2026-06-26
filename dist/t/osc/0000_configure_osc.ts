#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 2;

use Net::Domain qw(hostfqdn);
my $fqhn = hostfqdn();

ok($fqhn,"Checking for fully qualified hostname");

eval {
  my $oscrc="$::ENV{HOME}/.oscrc";
  open(OSCRC,'>',$oscrc) || die "Could not open $oscrc: $!";
  print OSCRC "[general]
apiurl = https://$fqhn

[https://$fqhn]
user=Admin
pass=opensuse
";
  close OSCRC;
};

ok(!$@,"Configuring oscrc");

exit 0

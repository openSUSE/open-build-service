#!/usr/bin/perl

use strict;
use warnings;

my $tests = 2;
use Test::More;
plan tests => $tests;

BEGIN {
  unshift @INC, "/usr/lib/obs/server";
};

use BSRPC;
use JSON::XS;

# These test need a lot of resources, so they should be
# skipable

SKIP: {
  skip "tests disabled by default. To enable set ENABLE_DOCKER_REGISTRY_TESTS=1", $tests unless $ENV{ENABLE_DOCKER_REGISTRY_TESTS};
  `osc rdelete -m "testing deleted it" -rf BaseContainer 2>&1`;
  `rm -rf /tmp/BaseContainer`;
  `osc branch openSUSE.org:openSUSE:Templates:Images:42.3:Base  openSUSE-Leap-Container-Base BaseContainer`;

  chdir("/tmp");

  `osc co BaseContainer/openSUSE-Leap-Container-Base`;
  chdir("/tmp/BaseContainer/openSUSE-Leap-Container-Base");

  `osc meta prjconf openSUSE.org:openSUSE:Templates:Images:42.3:Base |osc meta prjconf -F -`;
  my $fh;
  open($fh, "<", "/tmp/BaseContainer/openSUSE-Leap-Container-Base/config.kiwi")||die $!;
  my $result;
  while (<$fh>) {
    s#obs://#obs://openSUSE.org:#;
    $result .= $_;
  }
  close($fh);
  open(my $of, ">", "/tmp/BaseContainer/openSUSE-Leap-Container-Base/config.kiwi")||die $!;
  print $of $result;
  close($of);

  `osc ci -m "reconfigured 'source path' elements to use 'openSUSE.org:' as prefix in config.kiwi"`;

  `osc r -w`;

  ok($? == 0,"Checking result code");

  # wait for publishing in registry
  my $timeout=1800;
  sleep 10;
  my $repo;
  while (1) {
    $timeout--;
    my $response = BSRPC::rpc("http://localhost:5000/v2/_catalog");
    my $json = decode_json($response);
    if ( $json->{repositories}->[0]) {
      $repo = $json->{repositories}->[0];
      last;
    }
    last if $timeout < 1;
    sleep 1;
  }

  is($repo, "basecontainer/images/opensuse", "Found repository 'basecontainer/images/opensuse' in registry");
}

exit 0;

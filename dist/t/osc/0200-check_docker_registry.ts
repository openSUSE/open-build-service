#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

BEGIN {
  unshift @INC, "/usr/lib/obs/server";
};

use BSRPC;
use JSON::XS;

# These test need a lot of resources, so they should be
# skipable

SKIP: {
  skip "tests disabled by default. To enable set ENABLE_DOCKER_REGISTRY_TESTS=1", 4 unless $ENV{ENABLE_DOCKER_REGISTRY_TESTS};
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

  my $timeout=1800;
  # waiting for publishing to start
  sleep 10;
  my $tmp_file;

  # Waiting for publishing
  while (1) {
    $timeout--;
    open($fh, "<", "/srv/obs/log/publisher.log");
    while (<$fh>) {
      if ( $_ =~ /Decompressing.*(\/tmp\/\w*)/ ) {
        $tmp_file = $1;
        $timeout  = 0;
      }
    }
    close($fh);
    last if $timeout < 1;
    sleep 1;
  }

  ok($tmp_file,"Found temp file '$tmp_file' in log");

  # wait for publishing in registry
  $timeout=600;
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

  my $deleted=0;
  $timeout=10;
  while (1) {
    $timeout--;
    if (! -f $tmp_file) {
      $deleted=1;
      last;
    }
    last if $timeout < 1;
    sleep 1;
  }
  ok($deleted, "temp file removed successfully"); 
}

exit 0;

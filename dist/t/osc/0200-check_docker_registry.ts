#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

# These test need a lot of resources, so they should be
# skipable

SKIP: {
  skip "tests disabled by default. To enable set ENABLE_DOCKER_REGISTRY_TESTS=1", 1 unless $ENV{ENABLE_DOCKER_REGISTRY_TESTS};
  `osc rdelete -m "testing deleted it" -rf BaseContainer 2>&1`;
  `rm -rf /tmp/BaseContainer`;
  `osc branch openSUSE.org:openSUSE:Templates:Images:42.3:Base  openSUSE-Leap-Container-Base BaseContainer`;

  chdir("/tmp");

  `osc co BaseContainer/openSUSE-Leap-Container-Base`;
  chdir("/tmp/BaseContainer/openSUSE-Leap-Container-Base");

  `osc meta prjconf openSUSE.org:openSUSE:Templates:Images:42.3:Base |osc meta prjconf -F -`;
  open(my $fh, "<", "/tmp/BaseContainer/openSUSE-Leap-Container-Base/config.kiwi")||die $!;
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

  my $last_upload="";
  my $timeout=600;
  # waiting for publishing to start
  sleep 10;
  # Waiting for publishing
  while (1) {
    my $found="";
    $timeout--;
    open(my $fh, "<", "/srv/obs/log/publisher.log");
    while (<$fh>) {
      $last_upload = $1 if ( $_ =~ /Decompressing.*(\/tmp\/\w*)/ );
    }
    close($fh);
    open($fh, "<", "/srv/obs/log/publisher.log");
    while (<$fh>) {
      $found = $1 if ( $_ =~ /Deleting ($last_upload)/);
    }
    close($fh);

    if ( $found ) {
      ok(1,"Checking for upload");
      
      last;
    } else {
      if ($timeout < 0 ) {
        ok(0,"Checking for upload");
        last;
      }
    }
    sleep 1;
  }
}

exit 0;

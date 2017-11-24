#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;

# These test need a lot of resources, so they should be
# skipable

SKIP: {
  skip 1, "tests disabled by default. To enable set ENABLE_DOCKER_REGISTRY_TESTS=1" unless $ENV{ENABLE_DOCKER_REGISTRY_TESTS};
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
}

exit 0;

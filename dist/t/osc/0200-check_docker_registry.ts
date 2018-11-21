#!/usr/bin/perl

use strict;
use warnings;

my $tests = 2;
use Test::More;
use FindBin;
use JSON::XS;

plan tests => $tests;

BEGIN {
  unshift @::INC,
    "/usr/lib/obs/server",
    "$FindBin::Bin/../lib",
    "$FindBin::Bin/../../../src/backend/build",
    "/usr/lib/build"
  ;
};

use OBS::Test::Utils;
use Build::Rpm;

my $obs_version = OBS::Test::Utils::get_package_version('obs-server', 2);
my $vcmp = Build::Rpm::verscmp($obs_version, "2.9");

# These test need a lot of resources, so they should be
# skipable

SKIP: {

  skip "tests disabled by default. To enable set ENABLE_DOCKER_REGISTRY_TESTS=1", $tests unless $ENV{ENABLE_DOCKER_REGISTRY_TESTS};

  BAIL_OUT("Container registry not supported in OBS prior 2.9") if ($vcmp < 0);

  my $registry_url = ($vcmp)
    ? 'https://localhost/v2'
    : 'https://localhost:444/v2' # url for separate registry in obs 2.9.x
  ;

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
    my $response = `curl $registry_url/_catalog 2>/dev/null`;
    my $json = decode_json($response);
    if ( $json->{repositories}->[0]) {
      $repo = $json->{repositories}->[0];
      last;
    }
    last if $timeout < 1;
    sleep 1;
  }
  my $expected = qr{basecontainer/images/(?:x86_64/)?opensuse};

  like($repo, $expected, "Checking upload to registry");
}

exit 0;

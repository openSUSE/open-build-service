#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use File::Path qw(make_path remove_tree);
use Net::Domain qw(hostfqdn);

BEGIN {
  unshift @::INC, "/usr/lib/obs/server";
}

use BSRPC ':https';

my $fqhn = hostfqdn();
my $gitea_user = "obsadmin";
my $gitea_pass = "opensuse";
my $gitea_repo = "obs-gitworkflow-testpackage";

my $TMP_DIR="$FindBin::Bin/tmp/";

if ( -f "$TMP_DIR/.SKIP" ) {
  plan skip_all => "Previous tests failed - keeping results";
} else {
  plan tests => 3;

  chdir("$TMP_DIR/home:Admin");

  system('osc rdelete -m "rdelete test 1" home:Admin obs-testpackage');
  ok(!$?, 'Deleting package obs-testpackage');

  system('osc rdelete -m "rdelete test 2" home:Admin:scmbridge obs-gitworkflow-testpackage');
  ok(!$?, 'Deleting package obs-gitworkflow-testpackage');

  my $param = {
    'headers' => [ 'Content-Type: application/json' ],
    'uri'     => "https://$gitea_user:$gitea_pass\@$fqhn/gitea/api/v1/repos/$gitea_user/$gitea_repo",
    'request' => 'DELETE',
  };
  my $ans = BSRPC::rpc($param);
  ok(!$ans, 'Deleting package obs-gitworkflow-testpackage');

  # cleanup TMP_DIR
  chdir($FindBin::Bin);
  remove_tree($TMP_DIR);
}

exit 0;

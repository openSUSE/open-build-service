#!/usr/bin/env perl

use strict;
use warnings;
use Test::Most;
use FindBin;
use File::Path qw(make_path remove_tree);
use File::Copy;
use Cwd;
use Carp;

BEGIN {
  -d '/usr/lib/obs/server' && unshift @::INC, '/usr/lib/obs/server';
  -d "$FindBin::Bin/../../../src/backend" && unshift @::INC, "$FindBin::Bin/../../../src/backend";
  unshift @::INC, "$FindBin::Bin/../lib";
}

use OBS::Test::Utils;

use Net::Domain qw(hostfqdn);
use BSRPC ':https';

my $fqhn = hostfqdn();

my $RCODE = 0;

my $TMP_DIR = "$FindBin::Bin/tmp";
my $PRJ     = "home:Admin:scmbridge";
my $PKG     = "obs-gitworkflow-testpackage";

bail_on_fail;

my $TMP_DIR="$FindBin::Bin/tmp/";

if ( -f "$TMP_DIR/.SKIP" ) {
  plan skip_all => "Previous tests failed - keeping results";
  exit 0;
}

plan tests => 6;

ok(prepare_tmp_dir(), 'Checking preparation of temp directory');

ok(checkout_home_project(), 'Checking preparation of project');

ok(create_gitea_migration(), "Checking creation of gitea migration");

ok(configure_gitworkflow_package(), "Checking creation of a git workflow package");

ok(update_obs_working_copy(), "Checking update of OBS working copy");

ok(wait_for_buildresults(), 'Checking if build succeeded');

exit 0;

################################################################################
# SUBROUTINES
################################################################################

sub prepare_tmp_dir {
  eval {    ## no critic (ErrorHandling::RequireCheckingReturnValueOfEval)
    remove_tree($TMP_DIR);
    make_path($TMP_DIR);
    chdir $TMP_DIR || croak "Could not change to directory '$TMP_DIR': $!";
  };
  print STDERR $@ if $@;
  return !$@;
}

sub create_gitea_migration {
  my $param = {
    'headers' => [ 'Content-Type: application/json' ],
    'uri'     => "https://obsadmin:opensuse\@$fqhn/gitea/api/v1/repos/migrate",
    'request' => 'POST',
    'data'    => '{"clone_addr": "https://github.com/openSUSE/'.$PKG.'", "repo_name": "'.$PKG.'", "default_branch": "master", "private": false, "mirror": true}',
  };
  BSRPC::rpc($param);
}

sub configure_gitworkflow_package {
   
  my $pkg_meta = <<EOF;
<package name="$PKG" project="$PRJ">
 <title>OBS GitWorkFlow TestPackage</title>
 <description>An example for native OBS git support.
This is one has our packaging specific files in git and is downloading the upstream files, like the tar ball via the asset mechanism.
 </description>
 <scmsync>https://$fqhn/gitea/obsadmin/$PKG</scmsync>
</package>
EOF

  my @cmd = (qw/osc meta pkg -F - /, $PRJ, $PKG);
  my $rc = 0;
  if (open(my $pipe, '|-', @cmd)) {
    print $pipe $pkg_meta;
    close $pipe;
    $rc = !$?;
  } else {
    warn "Could not create pipe for command '@cmd'\n";
  }
  return $rc;
}

sub checkout_home_project {
  my @output = `osc co $PRJ`;
  print STDERR @output if $?;
  chdir $PRJ || croak "Could not change to directory '$PRJ': $!";
  return !$?;
}


sub update_obs_working_copy {
  my @output = `osc update`;
  print STDERR @output if $?;
  return !$?;
}

sub wait_for_buildresults {

  # wait for at least an hour by default or take timeout from ENV
  my $time_out = $::ENV{OBS_TEST_TIMEOUT} || 60 * 60;
  my $start_time = time;
  my $retry_timeout = 5;    # retry after X seconds
  my $succeed;

  my @states_list = qw/broken scheduled succeeded building failed signing
                       finished unresolvable published blocked/;
  my $re = join q{|}, @states_list;
  my $regex = qr{\s($re)([*])?}xsm;    ## no critic
  while (1) {
    my $states = {};

    # initialize to avoid warnings
    $states->{$_} = 0 for @states_list;
    my $recalculation = 0;
    my @result        = `osc r -v $PRJ $PKG`;
    for my $line (@result) {
      $recalculation = 1 if ($line =~ /outdated/);
      if ($line =~ $regex) {
	if (($2 || q{}) eq q{*}) {
	  $recalculation = 1;
	} else {
	  $states->{$1}++;
	}
      }
    }

    my $last_result = join q{}, @result;

    # test reached timeout (e.g. stuck while signing)
    if (($start_time + $time_out) < time) {
      print STDERR <<"EOF"
TEST TIMEOUT REACHED ($time_out sec)!
Last result:
$last_result

EOF
	;
      last;
    }

    if ($states->{blocked}) {
      sleep $retry_timeout;
      next;
    } 

    if (!$recalculation) {

      # if all have succeeded and no recalculation is needed the test succeed
      $succeed = 1 if ($states->{succeeded} + $states->{published} == @result);

      # if any of the results is failed/broken the whole test is failed
      my $bad_results = $states->{broken} + $states->{unresolvable} + $states->{failed};
      if ($bad_results > 0) {
	$succeed = 0;
	print STDERR <<"EOF"
AN ERROR OCCOURED WHILE BUILDING:
Last result:
$last_result

EOF
	  ;
      }
    }

    last if (defined $succeed);

    sleep $retry_timeout;
  }

  # create a skip file for the next test script
  # to keep home:Admin project if build fails for better debugging
  # wait for building results
  if (!$succeed) {
    open(my $skipfile, '>', "$TMP_DIR/.SKIP")
      || croak "Error while touching $TMP_DIR/.SKIP: $!";
    close($skipfile) || croak "Error while touching $TMP_DIR/.SKIP: $!";
  }

  return $succeed;
}

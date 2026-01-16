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

if ( -f "$TMP_DIR/.SKIP" ) {
  plan skip_all => "Previous tests failed - keeping results";
  exit 0;
}

plan tests => 5;

ok(prepare_tmp_dir(), 'Checking preparation of temp directory');

ok(prepare_ssh(), "Checking preparation of ssh keys");

ok(clone_git_repository(), 'Checking git clone of package');

ok(update_package_repository(), 'Checking update and commit of package');

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

sub prepare_ssh {
  my $id_file = "$::ENV{HOME}/.ssh/id_rsa";
  `[ -f $id_file ] || ssh-keygen -t rsa -f $id_file -N ""`;
  `ssh-keyscan $fqhn >> ~/.ssh/known_hosts`;
  my $key;
  if(!open(my $fh, '<', "$id_file.pub")) {
    return 0;
  } else {
    local $/ = undef;
    $key = <$fh>;
    close $fh;
  }

  my $keys_param = {
    'headers' => [ 'Content-Type: application/json' ],
    'uri'     => "https://obsadmin:opensuse\@$fqhn/gitea/api/v1/user/keys",
    'request' => 'POST',
    'data'    => '{"key": "'.$key.'", "title": "root on localhost", "read_only": false}',
  };
  BSRPC::rpc($keys_param);

  return 1;
}

sub clone_git_repository {
  my $url    = "gitea\@$fqhn:obsadmin/obs-gitworkflow-testpackage.git";
  my @output = `git clone $url`;
  `git -C $TMP_DIR/obs-gitworkflow-testpackage/ config user.email root\@$fqhn`;
  `git -C $TMP_DIR/obs-gitworkflow-testpackage/ config user.name "OBS Admin"`;
  print STDERR @output if $?;
  return !$?;
}

sub update_package_repository {
  my $spec_file = "$TMP_DIR/obs-gitworkflow-testpackage/obs-gitworkflow-testpackage.spec";
  my @fc;
  if(!open(my $fh, '<', $spec_file)) {
    return 0;
  } else {
    @fc = <$fh>;
    close $fh;
  }
  map { s/^Version:.*/Version: 0.99.0/ } @fc;
  
  if(!open(my $fh, '>', $spec_file)) {
    return 0;
  } else {
    print $fh @fc;
    close $fh;
  }
  `git -C $TMP_DIR/obs-gitworkflow-testpackage/ add obs-gitworkflow-testpackage.spec`;
  `git -C $TMP_DIR/obs-gitworkflow-testpackage/ commit -m "update spec to Version: 0.99.0"`;
  `git -C $TMP_DIR/obs-gitworkflow-testpackage/ push`;
  return 1;
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

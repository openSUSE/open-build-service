#!/usr/bin/env perl

use strict;
use warnings;
use Test::Most tests => 5;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Path qw(make_path remove_tree);
use File::Copy;
use Cwd;
use Carp;

use OBS::Test::Utils;

my $RCODE = 0;

my $TMP_DIR = "$FindBin::Bin/tmp";

bail_on_fail;

ok(prepare_tmp_dir(), 'Checking preparation of temp directory');

ok(checkout_home_project(), 'Checking preparation of project');

ok(prepare_package(), 'Checking preparation of package');

ok(commit_package(), 'Checking initial commit of package obs-testpackage');

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

sub checkout_home_project {
  my @output = `osc co home:Admin`;
  print STDERR @output if $?;
  return !$?;
}

sub prepare_package {
  eval {    ## no critic
    chdir 'home:Admin'
      || croak "Could not change to directory 'home:Admin': $!";
    mkdir 'obs-testpackage'
      || croak "Could not create directory 'obs-testpackage':$!";
    my @output = `osc add obs-testpackage`;
    if ($?) {
      croak "Could not add package 'obs-testpackage' via osc:\n" .
	join q{}, @output;
    }
    chdir 'obs-testpackage'
      || croak 'Could not change to directory \''.cwd()."/obs-testpackage': $!";

    my $src = "$FindBin::Bin/fixtures/obs-testpackage._service";
    my $pkg_ver = OBS::Test::Utils::get_package_version('obs-server', 2);
    if ($pkg_ver eq '2.8') {
      $src = "$FindBin::Bin/fixtures/obs-testpackage-2.8._service";
    }

    my $dst = './_service';
    copy($src, $dst) or croak "Copy '$src' -> '$dst' failed: $!";
    @output = `osc ar`;
    if ($?) {
      croak "Could not add files to package via osc!\n" . join q{}, @output;
    }
  };
  print STDERR $@ if $@;
  return !$@;
}

sub commit_package {
  my @output = `osc ci -m "initial version"`;
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
                       finished unresolvable/;
  my $re = join q{|}, @states_list;
  my $regex = qr{($re)([*])?$}xsm;    ## no critic
  while (1) {
    my $states = {};

    # initialize to avoid warnings
    $states->{$_} = 0 for @states_list;
    my $recalculation = 0;
    my @result        = `osc r`;
    for my $line (@result) {
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

    if (!$recalculation) {

      # if all have succeeded and no recalculation is needed the test succeed
      $succeed = 1 if ($states->{succeeded} + $states->{failed} == @result);

      # if any of the results is failed/broken the whole test is failed
      my $bad_results = $states->{broken} + $states->{unresolvable};
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

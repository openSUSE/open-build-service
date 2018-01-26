#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 4;
use FindBin;
use File::Path qw(make_path remove_tree);
use File::Copy;
use Cwd;

my $RCODE=0;

my $TMP_DIR="$FindBin::Bin/tmp";

# prepare TMP_DIR
remove_tree($TMP_DIR);
make_path($TMP_DIR);
chdir($TMP_DIR);

# checkout home:Admin
system("osc co home:Admin");

ok(!$?,"Checking preparation of project");

# prepare package
eval {
  chdir("home:Admin") || die "Could not change to directory 'home:Admin': $!";
  mkdir("obs-testpackage") || die "Could not create directory 'obs-testpackage':$!";
  system("osc add obs-testpackage");
  die "Could not add package 'obs-testpackage' via osc" if ($?);
  chdir("obs-testpackage") || die "Could not change to directory '".cwd()."/obs-testpackage': $!";

  my @pkg_ver = `rpm -q --qf '%{version}' obs-server`;
  my $src="$FindBin::Bin/fixtures/obs-testpackage._service";
  if ( $pkg_ver[0] =~ /^2\.8\./ ) {
    $src = "$FindBin::Bin/fixtures/obs-testpackage-2.8._service";
  }

  my $dst="./_service";
  copy($src,$dst) or die "Copy '$src' -> '$dst' failed: $!";
  system("osc ar");
  die "Could not add files to package via osc!" if ($?);
};

ok(!$@,"Checking preparation of package");

# commit package
system('osc ci -m "initial version"');
ok(!$?,"Checking initial commit of package obs-testpackage");

# wait for building results
my $time_out = 60 * 60; # wait for at least an hour
my $start_time = time();
my $retry_timeout = 5; # retry after X seconds
my $succeed;

while (1) {
  my $states = {
    broken       => 0,
    scheduled    => 0,
    succeeded    => 0,
    building     => 0,
    failed       => 0,
    signing      => 0,
    finished     => 0,
    unresolvable => 0
  };
  my $re = join('|',keys(%$states));
  my $recalculation = 0;
  my @result = `osc r`;
  for my $line (@result) {
    if ( $line =~ /($re)(\*)?$/) {
      if (($2 ||'') eq '*'){
        $recalculation = 1;
      } else {
        $states->{$1}++;
      }
    }
  }

  # test reached timeout (e.g. stuck while signing)
  last if (($start_time + $time_out) < time());

  if (! $recalculation) {
    # if all have succeeded and no recalculation is needed the test succeed
    $succeed = 1 if (($states->{succeeded} + $states->{failed}) == @result);
    # if any of the results is failed/broken the whole test is failed
    my $bad_results = $states->{broken} + $states->{unresolvable};
    if ($bad_results > 0) {
      $succeed = 0;
      print STDERR "@result";
    }
  }

  last if (defined($succeed));

  sleep($retry_timeout);
}

my $r = ok($succeed,"Checking if build succeeded");

if (! $r) {
  open(F,">","$TMP_DIR/.SKIP") || die "Error while touching $TMP_DIR/.SKIP: $!";
  close(F);
}

exit 0

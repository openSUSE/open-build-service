#!/usr/bin/env perl

use strict;
use warnings;
use SourceServiceTests;
use FindBin;
use Data::Dumper;
use Test::More;

my $datadir   = "$FindBin::Bin/data";
my ($hostname, $port) = split(/:/, shift @ARGV);
$port |= 5152;
my @testcases;
if ($ARGV[0]) {
  @testcases = @ARGV;
} else {
  opendir(TC, $datadir) || die "Could not open $datadir: $!\n";
  @testcases = sort grep { /^[^\.]/ } readdir(TC);
  closedir(TC);
}

plan tests => scalar @testcases;

for my $tc (@testcases) {
  SKIP: {
    BAIL_OUT("No testcase named $tc") unless -d "$datadir/$tc";
    if (-e "$datadir/$tc/.disabled") {
      skip "Test $tc is manually disabled", 1;
    }
    my $sst = SourceServiceTests->new(
      testcase =>$tc ,
      hostname => $hostname,
      port => $port,
      pkg_name => $tc,
      workingdir => "$datadir/$tc",
    );
    #my @fl  = $sst->get_filelist();
    #my $exp = $sst->get_expected_files();
    #print Dumper($exp);
    $sst->send_cpio();
    ok($sst->check_result, "Checking $tc");
    $sst->cleanup;
  }
}

exit 0;

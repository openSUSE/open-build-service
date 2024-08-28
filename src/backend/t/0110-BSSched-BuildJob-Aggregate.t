use strict;
use warnings;

use Test::More tests => 5;                      # last test to print
use Data::Dumper;
use FindBin;

use lib "$FindBin::Bin/lib/";

use Test::Mock::BSConfig;
use Test::Mock::BSSched::Checker;
use Test::Mock::BSSched::BuildJob;

use_ok("BSSched::BuildJob::Aggregate");

my $tmpdir = "$FindBin::Bin/tmp/0110";
BSUtil::mkdir_p($tmpdir);
BSUtil::cleandir($tmpdir);

sub cp_dir {
  my ($from, $to) = @_;
  BSUtil::mkdir_p($to);
  BSUtil::cp("$from/$_", "$to/$_") for sort(BSUtil::ls($from));
}

my $myarch = 'x86_64';

my $gctx = {
  'arch' => $myarch,
  'reporoot' => "$tmpdir/build",
  'myjobsdir' => "$tmpdir/jobs",
  'obsname' => 'testobs',
};
BSUtil::mkdir_p($gctx->{'myjobsdir'});
BSUtil::mkdir_p($gctx->{'reporoot'});

# setup target project
$gctx->{'projpacks'}->{'Test'} = {
  'package' => { 'test' => {} },
  'repository' => [
     { 'name' => 'standard', 'arch' => [ $myarch ] },
  ],
};

# setup project we're aggregating from
$gctx->{'projpacks'}->{'TestFrom'} = {
  'package' => { 'testrpm' => {}, 'testcontainer' => {} },
  'repository' => [
     { 'name' => 'standard', 'arch' => [ $myarch ] },
  ],
};
cp_dir("$FindBin::Bin/data/shared/buildresult/rpm", "$gctx->{'reporoot'}/TestFrom/standard/$myarch/testrpm");
cp_dir("$FindBin::Bin/data/shared/buildresult/container", "$gctx->{'reporoot'}/TestFrom/standard/$myarch/testcontainer");



my $projid = 'Test';
my $repoid = 'standard';
my $packid = 'test';

my $ctx = Test::Mock::BSSched::Checker->new($gctx, "$projid/$repoid");

my $pdata = {
  'aggregatelist' => {
    'aggregate' => [
      { 'project' => 'TestFrom', 'package' => [ 'testrpm', 'testcontainer' ] },
    ],
  },
  'srcmd5' => 'd41d8cd98f00b204e9800998ecf8427e',
};
my $info = {};

my $h = BSSched::BuildJob::Aggregate->new();

my ($status, $diag);
($status, $diag) = $h->check($ctx, $packid, $pdata, $info, 'aggregate', []);
is($status, 'scheduled', 'check call');

($status, $diag) = $h->build($ctx, $packid, $pdata, $info, $diag);
is($status, 'scheduled', 'build call');

my $fakejob = $ctx->{'fakejob'} || [];
is($fakejob->[1], 'succeeded', 'build result');

my $job = $fakejob->[0];
my @jobdir = sort(BSUtil::ls("$gctx->{'myjobsdir'}/$job:dir"));

my $expected = [ qw{
_blob.sha256:334d7a5b49823b1cb969fd31a3a7eaa26d643eb72b79f966513b4b4d870ac902
_blob.sha256:f24bdc8441e003f6b292b47b0244d181a5a82590099f3448360b613e8cf81939
foo-1.2.x86_64-5.1.containerinfo
foo-1.2.x86_64-5.1.obsbinlnk
hello_world-1-4.1.src.rpm
hello_world-1-4.1.x86_64.rpm
logfile
meta
}];

is_deeply(\@jobdir, $expected, "build files");

BSUtil::cleandir($tmpdir);
rmdir($tmpdir);

exit 0;

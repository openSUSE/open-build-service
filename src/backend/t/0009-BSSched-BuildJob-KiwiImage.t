use strict;
use warnings;

use Test::More tests => 5;
use Data::Dumper;
use feature qw/say/;

use_ok('BSSched::BuildJob::KiwiImage');


my ($got,$expected,$fixture);

$fixture = {
  path => [
    { path => 'abc' , project => 'openSUSE:Factory' , repository => 'standard' },
  ],
};

@$got = BSSched::BuildJob::KiwiImage::expandkiwipath($fixture);
$expected = [ 'openSUSE:Factory/standard' ];
is_deeply($got,$expected,'Checking testcase 1 TODO: better description');
################################################################################
$fixture = [
    {
      path => [
        { path => 'abc' , project => '_obsrepositories' },
      ],
    },
  ['prpsearchpath1','prpsearchpath2']
];
$expected = [ 'prpsearchpath1', 'prpsearchpath2' ];
@$got = BSSched::BuildJob::KiwiImage::expandkiwipath(@$fixture);
is_deeply($got,$expected,'Checking with _obsrepositories and prpsearchpath');

################################################################################
$fixture = [
    {
      path => [
        { path => 'abc' , project => '_obsrepositories' },
      ],
    },
];
$expected = [ ];
@$got = BSSched::BuildJob::KiwiImage::expandkiwipath(@$fixture);
is_deeply($got,$expected,'Checking with _obsrepositories w/o prpsearchpath');

################################################################################
@$got = BSSched::BuildJob::KiwiImage::expandkiwipath();
$expected = [ 'openSUSE:Factory/standard' ];
is_deeply($got,[],'Checking empty $info->{path} element');


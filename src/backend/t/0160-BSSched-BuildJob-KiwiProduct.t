use strict;
use warnings;

use Test::More tests => 7;                      # last test to print
use Data::Dumper;
use FindBin;
use BSUtil;
use BSXML;
use BSSched::ProjPacks;

use lib "$FindBin::Bin/lib/";

use Test::Mock::BSConfig;
use Test::Mock::BSSched::Checker;
use Test::OBS;
use Test::OBS::Utils;

use_ok('BSSched::BuildJob::KiwiProduct');

$BSConfig::bsdir = "$FindBin::Bin/data/0160";

my $gctx = {
  'arch' => 'x86_64',
  'reporoot' => "$BSConfig::bsdir/build",
  'obsname' => 'testobs',
  'genmetaalgo' => 0,
  'maxgenmetaalgo' => 0,
};

my $projid = 'OBS:Server:Unstable';
my $repoid = 'images';
my $packid = '_product:OBS-Addon-cd-cd-x86_64_i586';

my $projpacksin = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/projpacks/projects", $BSXML::projpack);
BSSched::ProjPacks::update_projpacks($gctx, $projpacksin);
$projpacksin = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/projpacks/package", $BSXML::projpack);
BSSched::ProjPacks::update_projpacks($gctx, $projpacksin, $projid, [ $packid ]);
BSSched::ProjPacks::get_projpacks_postprocess($gctx);


my $pdatas = $gctx->{'projpacks'}->{$projid}->{'package'} || {};
my $pdata = $pdatas->{$packid};
my $info = (grep {$_->{'repository'} eq $repoid} @{$pdata->{'info'} || []})[0];

my ($status, $diag);

my $ctx = Test::Mock::BSSched::Checker->new($gctx, "$projid/$repoid");

($status, $diag) = $ctx->setup();
is($status, 'scheduling', 'checker setup call');

($status, $diag) = $ctx->preparepool();
is($status, 'scheduling', 'checker preparepool call');

my $xp = BSSolv::expander->new($ctx->{'pool'}, $ctx->{'conf'});
no warnings 'redefine';
*Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
use warnings 'redefine';

my $h = BSSched::BuildJob::KiwiProduct->new();

my ($eok, @edeps) = $h->expand($ctx->{'conf'}, [], @{$info->{'dep'}});
ok($eok, 'expander');

($status, $diag) = $h->check($ctx, $packid, $pdata, $info, 'kiwi-product', \@edeps);
is($status, 'scheduled', 'check call');

($status, $diag) = $h->build($ctx, $packid, $pdata, $info, $diag);
is($status, 'scheduled', 'build call');

my $expected = Test::OBS::Utils::readxmlxz("$BSConfig::bsdir/result/tc01", $BSXML::buildinfo);
my $got = $ctx->{'buildinfo'};
# compat...
delete $got->{$_} for qw{needed release debuginfo};

cmp_buildinfo($got, $expected, 'kiwi product build job');

exit 0;

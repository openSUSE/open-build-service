use strict;
use warnings;

use Test::More tests => 9;			# last test to print
use Data::Dumper;
use FindBin;
use BSUtil;
use BSXML;
use Build;

use lib "$FindBin::Bin/lib/";

use Test::Mock::BSConfig;
use Test::Mock::BSSched::Checker;
use Test::OBS;

use warnings;

use_ok("BSSched::BuildJob::Package");
use_ok("BSSched::ProjPacks");

my $gctx = {
  'arch' => 'i586',
  'reporoot' => "$BSConfig::bsdir/build",
  'obsname' => 'testobs',
  'genmetaalgo' => 0,
  'maxgenmetaalgo' => 0,
};

my $projpacksin = readxml("$FindBin::Bin/data/0170/srcserver/fixtures_0001", $BSXML::projpack);
BSSched::ProjPacks::update_projpacks($gctx, $projpacksin);
BSSched::ProjPacks::get_projpacks_postprocess($gctx);

my $projid = 'openSUSE:13.2';
my $repoid = 'standard';
my $packid = 'screen';

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

my $h = BSSched::BuildJob::Package->new();

my ($eok, @edeps) = $h->expand($ctx->{'conf'}, $ctx->{'subpacks'}->{'screen'}, @{$info->{'dep'}});
ok($eok, 'expander');

($status, $diag) = $h->check($ctx, $packid, $pdata, $info, 'spec', \@edeps);
is($status, 'scheduled', 'check call');

($status, $diag) = $h->build($ctx, $packid, $pdata, $info, $diag);
is($status, 'scheduled', 'build call');

my $xbi = BSUtil::readxml("$FindBin::Bin/data/0170/buildjob/result/buildjob_13_2_screen", $BSXML::buildinfo);
my $bi = $ctx->{'buildinfo'};
delete $bi->{'readytime'};
delete $xbi->{'readytime'};

cmp_buildinfo($bi, $xbi, 'buildinfo for screen');
is($ctx->{'reason'}->{'explain'}, 'new build', 'reason for build');

exit 0;

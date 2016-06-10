use strict;
use warnings;

use Test::More tests => 10;                      # last test to print
use Data::Dumper;

use BSUtil;
use BSXML;
use Build;

no warnings;

$INC{'BSConfig.pm'} = 'BSConfig.pm';
$BSConfig::bsdir = 'testdata/buildinfo';
$BSConfig::srcserver = 'srcserver';
$BSConfig::reposerver = 'reposerver';
$BSConfig::repodownload = 'http://download.opensuse.org/repositories';

use warnings;

use_ok("BSSched::BuildJob::Package");
use_ok("BSSched::Checker");
use_ok("BSSched::ProjPacks");

no warnings;

*BSSched::Checker::addrepo = sub {
  my ($ctx, $pool, $prp, $arch) = @_;
  my $gctx = $ctx->{'gctx'};
  $arch ||= $gctx->{'arch'};
  return $pool->repofromfile($prp, "$gctx->{'reporoot'}/$prp/$arch/:full.solv");
};

*BSSched::Checker::writejob = sub {
  my ($ctx, $job, $binfo, $reason) = @_;
  $ctx->{'buildinfo'} = $binfo;
  $ctx->{'reason'} = $reason;
};

use warnings;

my $gctx = {
  'arch' => 'i586',
  'reporoot' => 'testdata/buildinfo/build',
  'obsname' => 'testobs',
  'myjobsdir' => 'testdata/jobsdir_does_not_exist',
};

my $projpacksin = readxml('testdata/buildinfo/srcserver/getprojpack?withsrcmd5&withdeps&withrepos&withconfig&withremotemap&ignoredisable&project=openSUSE:13.2&repository=standard&arch=i586&package=screen', $BSXML::projpack);
BSSched::ProjPacks::update_projpacks($gctx, $projpacksin);
BSSched::ProjPacks::get_projpacks_postprocess($gctx);

my $projid = 'openSUSE:13.2';
my $repoid = 'standard';
my $packid = 'screen';

my $pdatas = $gctx->{'projpacks'}->{$projid}->{'package'} || {};
my $pdata = $pdatas->{$packid};
my $info = (grep {$_->{'repository'} eq $repoid} @{$pdata->{'info'} || []})[0];

my ($status, $diag);

my $ctx = BSSched::Checker->new($gctx, "$projid/$repoid");

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

($status, $diag) = $h->check($ctx, $packid, $pdata, $info, 'spec');
is($status, 'scheduled', 'check call');

($status, $diag) = $h->build($ctx, $packid, $pdata, $info, $diag);
is($status, 'scheduled', 'build call');

my $xbi = BSUtil::readxml("testdata/buildjob/result/buildjob_13_2_screen", $BSXML::buildinfo);
my $bi = $ctx->{'buildinfo'};
delete $bi->{'readytime'};
delete $xbi->{'readytime'};

is_deeply($ctx->{'buildinfo'}, $xbi, 'buildinfo for screen');
is($ctx->{'reason'}->{'explain'}, 'new build', 'reason for build');

exit 0;

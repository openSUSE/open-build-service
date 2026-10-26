use strict;
use warnings;

use Test::More tests => 6;                      # last test to print

use_ok('BSSched::Checker');
use FindBin;
use Data::Dumper;

use BSUtil;
use BSSched::EventSource::Retry;

my $tmpdir = "$FindBin::Bin/tmp/0013";

# Returns the packages that wipeobsolete wipes, with the reason, for a
# repository that has build results for pack1 and remotepack.
sub wiped_packages {
  my ($proj) = @_;
  BSUtil::mkdir_p($tmpdir);
  BSUtil::cleandir($tmpdir);
  my $gdst = "$tmpdir/home:user/standard/x86_64";
  BSUtil::mkdir_p("$gdst/$_") for qw(pack1 remotepack);

  my @wiped;
  no warnings qw(once redefine);
  local *BSSched::BuildResult::wipeobsolete = sub {
    my ($gctx, $prp, $packid, $dstcache, $reason) = @_;
    push @wiped, [ $packid, $reason ];
    return 1;
  };
  local *BSSched::BuildJob::killbuilding = sub {};
  local *BSSched::EventSource::Directory::sendrepochangeevent = sub {};

  my $ctx = {
    'gctx' => { 'arch' => 'x86_64' },
    'gdst' => $gdst,
    'prp' => 'home:user/standard',
    'project' => 'home:user',
    'repository' => 'standard',
    'proj' => $proj,
    'repo' => {},
  };
  BSSched::Checker::wipeobsolete($ctx);
  return \@wiped;
}

is_deeply(wiped_packages({ 'package' => { 'pack1' => {} } }), [ [ 'remotepack', 'obsolete' ] ],
  'wipeobsolete wipes the build results of a package missing from the package list');
is_deeply(wiped_packages({ 'package' => { 'pack1' => {} }, 'missingpackages' => 1 }), [],
  'wipeobsolete keeps them when the package list is incomplete (missingpackages)');
is_deeply(wiped_packages({ 'package' => { 'pack1' => {} }, 'missingpackages' => 1, 'remoteaccessdenied' => 1 }), [],
  'wipeobsolete keeps them when a remote denies access (remoteaccessdenied)');

# Returns the seconds until the retry that addretryevent_missingpackages queues.
sub retry_delay {
  my ($proj) = @_;
  my $gctx = { 'retryevents' => BSSched::EventSource::Retry->new() };
  my $now = time();
  BSSched::Checker::addretryevent_missingpackages($gctx, 'home:user', $proj);
  my @events = $gctx->{'retryevents'}->events();
  return $events[0]->{'retry'} - $now;
}

ok(abs(retry_delay({ 'missingpackages' => 1 }) - 60) <= 1,
  'missingpackages: the project is fetched again after a minute');
ok(abs(retry_delay({ 'missingpackages' => 1, 'remoteaccessdenied' => 1 }) - 600) <= 1,
  'remoteaccessdenied: the project is fetched again after ten minutes');

exit 0;

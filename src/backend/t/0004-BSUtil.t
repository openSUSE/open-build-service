use strict;
use warnings;

use Test::More tests => 25; 

require_ok('BSUtil');

#sub enabled {
#  my ($repoid, $disen, $default, $arch) = @_;

my $result = {};
$result->{'repo:disabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:disabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:enabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:enabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:disabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:disabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:enabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:enabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:disabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:disabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:enabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:enabled'}->{'i586'} = [qw/0 1/];

my @default_repoids = qw/repo:disabled repo:enabled/;
my @default_archs   = qw/x86_64 i586/;

sub run_all_test_with_disen {
  my %opts      = @_;
  my $disen     = $opts{disen};
  my @repoids   = @{$opts{repos}};
  my @archs     = @{$opts{archs}};
  my @defaults  = qw/0 1/;
  my $tres = {};
  for my $repo (@repoids) {
    for my $arch (@archs) {
      my @tres = ();
      my $c1 = 0;
      for my $default (@defaults) {
        my $got = BSUtil::enabled($repo,$disen,$default,$arch);
        is($got,$result->{$repo}->{$arch}->[$c1],"Checking combination ( $repo / $arch / $default )");
        $c1++;
        #if ($ENV{PERL_TEST_RECORD_RESULTS}) {
        #  $result->{$repo}->{$arch} = [];
        #  push(@tres,$got);
      }
      #print '$result->{\''.$repo.'\'}->{\''.$arch."'} = [ qw/@tres/ ];\n";
    } 
  }
}


my $disen  = {
  disabled => [
    { repository => 'openSUSE:Disabled' , arch => 'x86_64'  }
  ]
};

run_all_test_with_disen(disen=>$disen,repos=>\@default_repoids,archs=>\@default_archs);

$disen  = {
  disabled => [
    { repository => 'openSUSE:Disabled' , arch => 'x86_64'  },
    { arch => 'i586' }
  ]
};
run_all_test_with_disen(disen=>$disen,repos=>\@default_repoids,archs=>\@default_archs);

$disen  = {
  disabled => [
    { repository => 'openSUSE:Disabled' },
  ]
};
run_all_test_with_disen(disen=>$disen,repos=>\@default_repoids,archs=>\@default_archs);

exit 0;


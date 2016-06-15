use strict;
use warnings;

use Test::More tests => 21;                      # last test to print
use Storable qw/dclone/;
use_ok('BSSched::EventSource::Retry');

use FindBin;
use Data::Dumper;

my $ev        = undef;
my $expected  = undef;
my $txt       = undef;
my @got       = ();
my $retry = BSSched::EventSource::Retry->new();
$retry->addretryevent(
    {
      project     => 'home:M0ses',
      repository  => 'openSUSE_13.2',
      type        => 'repository',
    }
);
$retry->addretryevent(
    {
      project     => 'home:M0ses',
      repository  => 'openSUSE_13.2',
      type        => 'recheck',
    },
);
# hack: fixup time entry
$_->{'retry'} = time() for $retry->events();
ok($retry->count() == 2, "Checking queue initialization");

#
# NON CHANGING OPERATIONS
#
###
my $retryevents = dclone([ $retry->events() ]);
ok(@{$retryevents || []} == 2, "Checking events method");

$expected = $retryevents;
$ev = {
      project => 'home:M0ses',
      repository => 'openSUSE_13.2',
      type  => 'repository'
};

$retry->addretryevent($ev);
$txt = sprintf("Checking with event type %s (%s/%s)",$ev->{type},$ev->{project},$ev->{repository});
is_deeply([$retry->events()],$expected,$txt);

###
$ev = {
      project => 'home:M0ses',
      repository => 'openSUSE_13.2',
      type  => 'recheck'
};

$retry->addretryevent($ev);
$txt = sprintf("Checking with event type %s (%s/%s)",$ev->{type},$ev->{project},$ev->{repository});
is_deeply([$retry->events()],$expected,$txt);

#
# CHANGING OPERATIONS
#
###

my $with_retry = [
  # tests 
  {
    ev => {
      project => 'home:M0ses:new',
      repository => 'openSUSE_13.2',
      type  => 'recheck',
    },
  },
  {
  ###
    ev => {
      project => 'home:M0ses:perl',
      repository => 'openSUSE_13.2',
      type  => 'repository'
    },
  },
  {
    ev => {
      project => 'home:M0ses:perl',
      repository => 'openSUSE_13.2',
      'package'     => 'perl-CPANMINUS',
      type  => 'package'
    },
  },
  {
    ###
    ev => {
          project => 'home:M0ses:perl',
          repository => 'openSUSE_13.2',
          'package'     => 'perl-CPANMINUS',
          type  => 'foo'
    },
  },
  {
    ###
    ev => {
          project => 'home:M0ses:perl',
          repository => 'openSUSE_Leap_42.1',
          'package'     => 'perl-CPANMINUS',
          type  => 'repository'
    },
  },
  {
    ###
    ev => {
          project => 'home:M0ses:perl',
          repository => 'openSUSE_Leap_42.1',
          'package'     => 'perl-CPANMINUS-New',
          type  => 'package'
    },
  },
  {
    ###
    ev => {
          project => 'home:M0ses:perl',
          repository => 'openSUSE_Leap_42.1',
          type  => 'package'
    },
  },
];

for my $test (@$with_retry) {
    my $expected = [
    $retry->events(),
    {
      %{$test->{ev}},
      'retry' => time + 60
    }
  ];
  check_with_retry($test->{ev},$expected);
# print Dumper([$retry->events()]);
}


@got = $retry->due();
$expected = [
      {
        'project' => 'home:M0ses',
        'type' => 'repository',
        'repository' => 'openSUSE_13.2'
      },
      {
        'repository' => 'openSUSE_13.2',
        'type' => 'recheck',
        'project' => 'home:M0ses'
      }
    ];
is_deeply(\@got,$expected,"Checking due method");

$expected = [];
@got = $retry->due();
is_deeply(\@got,$expected,"Checking that due method removed entries from the queue");

exit 0;

sub check_with_retry {

  my ($ev,$expected) = @_;

  $retry->addretryevent($ev);
  $txt = sprintf("Checking with event type %s (%s/%s)",$ev->{type},$ev->{project},$ev->{repository});
  is_deeply([$retry->events()],$expected,$txt);

  $retry->addretryevent($ev);
  $txt = sprintf("Retrying with event type %s (%s/%s)",$ev->{type},$ev->{project},$ev->{repository});
  is_deeply([$retry->events()],$expected,$txt);

}

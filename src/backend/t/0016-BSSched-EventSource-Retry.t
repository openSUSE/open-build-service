use strict;
use warnings;

use Test::More tests => 19;                      # last test to print
use Storable qw/dclone/;
use_ok('BSSched::EventSource::Retry');

use FindBin;
use Data::Dumper;

my $ev        = undef;
my $expected  = undef;
my $txt       = undef;
my @got       = ();
my $gctx = {
  retryevents => [
    {
      project     => 'home:M0ses',
      repository  => 'openSUSE_13.2',
      type        => 'repository',
      'retry'     => time()
    },
    {
      project     => 'home:M0ses',
      repository  => 'openSUSE_13.2',
      type        => 'recheck',
      'retry'     => time()
    },
  ]
};


#
# NON CHANGING OPERATIONS
#
###
my $retryevents = dclone($gctx->{retryevents});
$expected = $retryevents;
$ev = {
      project => 'home:M0ses',
      repository => 'openSUSE_13.2',
      type  => 'repository'
};

BSSched::EventSource::Retry::addretryevent($gctx,$ev);
$txt = sprintf("Checking with event type %s (%s/%s)",$ev->{type},$ev->{project},$ev->{repository});
is_deeply($gctx->{retryevents},$expected,$txt);

###
$ev = {
      project => 'home:M0ses',
      repository => 'openSUSE_13.2',
      type  => 'recheck'
};

BSSched::EventSource::Retry::addretryevent($gctx,$ev);
$txt = sprintf("Checking with event type %s (%s/%s)",$ev->{type},$ev->{project},$ev->{repository});
is_deeply($gctx->{retryevents},$expected,$txt);

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
    @{$gctx->{retryevents}},
    {
      %{$test->{ev}},
      'retry' => time + 60
    }
  ];
  check_with_retry($gctx,$test->{ev},$expected);
# print Dumper($gctx->{retryevents});
}


@got = BSSched::EventSource::Retry::getretryevents($gctx);
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
is_deeply(\@got,$expected,"Checking getretryevents");

@got = BSSched::EventSource::Retry::getretryevents($gctx);
$expected = [];
is_deeply(\@got,$expected,"Checking getretryevents when queue empty");

exit 0;

sub check_with_retry {

  my ($gctx,$ev,$expected) = @_;

  BSSched::EventSource::Retry::addretryevent($gctx,$ev);
  $txt = sprintf("Checking with event type %s (%s/%s)",$ev->{type},$ev->{project},$ev->{repository});
  is_deeply($gctx->{retryevents},$expected,$txt);

  BSSched::EventSource::Retry::addretryevent($gctx,$ev);
  $txt = sprintf("Retrying with event type %s (%s/%s)",$ev->{type},$ev->{project},$ev->{repository});
  is_deeply($gctx->{retryevents},$expected,$txt);

}

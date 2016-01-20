use strict;
use warnings;

use Test::More tests => 7;                      # last test to print
use Data::Dumper;
use FindBin;

use BSSched::EventSource::Directory;
use_ok("BSSched::EventQueue");

my $got = undef;

my $eq = BSSched::EventQueue->new();

# only for coverage
$eq->process_events();

# do no execute any handler ATM
map { $BSSched::EventHandler::event_handlers{$_} = \&main::event_noop } keys( %BSSched::EventHandler::event_handlers );

is(ref($eq),"BSSched::EventQueue","Creating EventQueue");

$got = $eq->add_events(
            {
              project => "B",
              job => "B"
            },
            {
              project => "B",
              job => "A"
            },
            {
              job => "C"
            },
            {
              type => "unknown"
            },
            {
              type => "exit"
            },
            {
              type => "restart"
            },
            {
              type => "uploadbuild"
            },
            {
              type => "import"
            },
            {
              project => "A",
              job => "B"
            },
            {
              project => "A",
              job => "A"
            },
);

is($got,10,"Testing return value of add_events");

$eq->order();

is($eq->order,0,"Testing return value of method order");

$got = $eq->get_events();

my $sorted = [
          {
            'type' => 'exit'
          },
          {
            'type' => 'restart'
          },
          {
            'job' => 'C'
          },
          {
            'project' => 'A',
            'job' => 'A'
          },
          {
            'project' => 'A',
            'job' => 'B'
          },
          {
            'project' => 'B',
            'job' => 'A'
          },
          {
            'job' => 'B',
            'project' => 'B'
          },
          {
            'type' => 'unknown'
          },
          {
            'type' => 'import'
          },
          {
            'type' => 'uploadbuild'
          }
        ];

#print Dumper($got);
is_deeply($got,$sorted,"Checking sorted events");

is($eq->events_in_queue,10,"Checking counter of events in queue");
{
	local *STDOUT;
	my $out=undef;
	open STDOUT, '>', \$out or die "Can't open STDOUT: $!";
	$eq->process_events();

}

is($eq->events_in_queue,0,"Checking if queue is empty after processing");

exit 0;

sub event_noop {
	# just a stub
	#print Dumper(@_) 
}

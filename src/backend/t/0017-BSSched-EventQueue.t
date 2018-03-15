use strict;
use warnings;

use Test::More tests => 13;                      # last test to print
use Data::Dumper;
use FindBin;

use BSSched::EventSource::Directory;
use_ok("BSSched::EventQueue");

my $got = undef;
my $out = undef;
my $eq = BSSched::EventQueue->new();

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
	open STDOUT, '>', \$out or die "Can't open STDOUT: $!";
	$eq->process_events();

}

is($eq->events_in_queue,0,"Checking if queue is empty after processing");

####
# only for coverage

# check for deactivated ordering, because only 1 event given
my $expected = undef;
$eq->add_events({});

{
	local *STDOUT;
	open STDOUT, '>', \$out or die "Can't open STDOUT: $!";
	$eq->process_events();
}

$out =~ s/.*?\] +//;
$expected = "remote event unknown
unknown event type 'unknown'
";
is($out,$expected,"Checking output one unknown event");

# check for empty event queue
{
	local *STDOUT;
	open STDOUT, '>', \$out or die "Can't open STDOUT: $!";
	$eq->process_events();
}

$expected = "";
is($out,$expected,"Checking empty event queue");

{
	local *STDOUT;
	open STDOUT, '>', \$out or die "Can't open STDOUT: $!";
        $eq->process_one({});
}
$expected = "";$expected = "unknown event type 'unknown'
";
is($out,$expected,"Checking output of process_one with empty event");



### initialstartup
$eq->{initialstartup} = 1;

# ...
{
	local *STDOUT;
	open STDOUT, '>', \$out or die "Can't open STDOUT: $!";
        $eq->process_one({});
}
$expected = "unknown event type 'unknown'
";
is($out, $expected, "Checking output of one unknown event on initialstartup");


# ...
{
	local *STDOUT;
	open STDOUT, '>', \$out or die "Can't open STDOUT: $!";
	$eq->process_one({type=>'exit'});
}
#  print '$expected = "'.$out.'";';
$expected = "WARNING: there was an exit event, but we ignore it directly after starting the scheduler.
";

is($out, $expected, "Checking output of exit event on initialstartup");


# ...
{
	local *STDOUT;
	open STDOUT, '>', \$out or die "Can't open STDOUT: $!";
	$eq->process_one({type=>'exitcomplete'});
}
$expected = "WARNING: there was an exit event, but we ignore it directly after starting the scheduler.
";

is($out, $expected, "Checking output of exitcomplete event on initialstartup");



#
####



exit 0;

sub event_noop {
	# just a stub
	print Dumper(@_)
}

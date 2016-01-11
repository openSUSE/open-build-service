use strict;
use warnings;

use Test::More;                      # last test to print

require_ok('BSSched::BuildJob');
require_ok('BSSched::BuildJob::DeltaRpm');
require_ok('BSSched::EventHandler');
require_ok('BSSched::EventSource::Directory');
require_ok('BSSched::EventSource::Retry');
require_ok('BSSched::BuildRepo');
require_ok('BSSched::PublishRepo');
require_ok('BSSched::BuildResult');
require_ok('BSSched::RPC');
require_ok('BSSched::Remote');


my $obj;
my @all_object = ();
my %BSSched_handlers;
{ 
  no warnings 'once';
  %BSSched_handlers = %BSSched::handlers;
}
 
while ( my ($key,$class) = each(%BSSched_handlers)) {
    use_ok($class);
    $obj = $class->new();
    print $@;
    ok(ref($obj) eq $class,"Checking object $class creation");
}

done_testing();
exit 0;

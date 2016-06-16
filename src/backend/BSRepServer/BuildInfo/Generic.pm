package BSRepServer::BuildInfo::Generic;

use strict;
use warnings;

sub new { my $class = shift; bless {@_} }
sub buildtype { $_[0]->{buildtype} || '' }
sub kiwitype { '' }

1;

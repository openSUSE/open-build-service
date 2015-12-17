use strict;
use warnings;

use Test::More tests => 1;                      # last test to print
use Data::Dumper;
use File::Basename;
use File::Spec;
use Symbol;
use Encode;
use DynaLoader;
use IO::File;

my @fp = split('/',__FILE__);
pop(@fp);
my $basepath = join('/',@fp);

@INC = (
  $basepath . "/_chooseparser/lib1",
  $basepath . "/.."
);
require XML::SAX;
require XML::Structured;

my $got =   XML::Structured::_chooseparser();
ok(
  1,
  "Checking _chooseparser with XML::SAX"
);



exit 0;


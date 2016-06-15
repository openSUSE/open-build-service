use strict;
use warnings;

use Test::More tests => 1;
use Data::Dumper;
use DynaLoader;
use Encode;
my @fp = split('/',__FILE__);
pop(@fp);
my $basepath = join('/',@fp);

@INC = (
  $basepath . "/_chooseparser/lib2",
  $basepath . "/.."
);

require XML::Structured;
eval {
  XML::Structured::_chooseparser();
};

is($@,"XML::Structured needs either XML::SAX or XML::Parser\n","Checking without parser module");


exit 0;


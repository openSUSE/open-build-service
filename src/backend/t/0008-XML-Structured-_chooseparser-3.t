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
  $basepath . "/_chooseparser/lib3" ,
  $basepath . "/.." ,
);

require XML::Structured;

eval {
  XML::Structured::_chooseparser();
};

ok(! $@,"Checking _chooseparser with XML::Parser");

exit 0;


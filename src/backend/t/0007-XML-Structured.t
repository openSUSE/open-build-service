use strict;
use warnings;

use Test::More;                      # last test to print
use Data::Dumper;

$ENV{LANG} = "C";

my $dtd       = undef;
my $got       = undef;
my $expected  = undef;
my $xml       = undef;
my $tcounter  = 0;

my @tcS = ();

$tcS[0] = {
    xml => '<user login="foo" password="bar" />',
    dtd => [ 'user' => 'login', 'password'],
    expected_in  => { 'login' => 'foo', 'password' => 'bar' },
    expected_out => '<user login="foo" password="bar" />'
};

$tcS[1] = {
    xml => '<user><login>foo</login><password>bar</password></user>',
    dtd => [ 'user' => 'login', 'password' ],
    expected_in => { 'login' => 'foo', 'password' => 'bar' },
    expected_out => '<user login="foo" password="bar" />'

};


$tcS[2] = {
    dtd => [ 'user' =>
                 'login',
                 [ 'favorite_fruits' ],
           ]
    ,
    xml=> '
    <user login="foo">
      <favorite_fruits>apple</favorite_fruits>
      <favorite_fruits>peach</favorite_fruits>
    </user>
',
    expected_in =>{
          'login' => 'foo',
          'favorite_fruits' => [
                               'apple',
                               'peach'
                             ]
        } 
    ,
    expected_out => '<user login="foo">
  <favorite_fruits>apple</favorite_fruits>
  <favorite_fruits>peach</favorite_fruits>
</user>'
    ,
};

$tcS[3] = { 
        dtd => [ 'user' =>
                     'login',
                     [ 'favorite_fruits' ],
                     'password',
               ]
        ,xml =>'<user login="foo">
          <favorite_fruits>apple</favorite_fruits>
          <favorite_fruits>peach</favorite_fruits>
          <password>bar</password>
        </user>'
    ,expected_in => {
          'favorite_fruits' => [
                               'apple',
                               'peach'
                             ],
          'password' => 'bar',
          'login' => 'foo'
        }
    ,expected_out => 
'<user login="foo">
  <favorite_fruits>apple</favorite_fruits>
  <favorite_fruits>peach</favorite_fruits>
  <password>bar</password>
</user>'

};


$tcS[4] = {
        dtd => [ 'user' =>
                     [],
                     'login',
                     'password',
               ],
        xml =>
        '<user>
          <login>foo</login>
          <password>bar</password>
        </user>'
    ,expected_in => {
          'password' => 'bar',
          'login' => 'foo'
        }
    ,expected_out => '<user>
  <login>foo</login>
  <password>bar</password>
</user>'

};

$tcS[5] = {
    dtd => 
         [ 'user' =>
                     'login',
                     [ 'address' =>
                         'street',
                         'city',
                     ],
               ],
,xml => '
        <user login="foo">
          <address street="broadway 7" city="new york" />
        </user>
'
    ,expected_in => 
{
          'address' => {
                       'street' => 'broadway 7',
                       'city' => 'new york'
                     },
          'login' => 'foo'
        }
    ,expected_out => '<user login="foo">
  <address street="broadway 7" city="new york" />
</user>'
};
$tcS[6] = {
        dtd => [ 'user' =>
                     'login',
                     [[ 'address' =>
                         'street',
                         'city',
                     ]],
               ],
        xml =>
        '<user login="foo">
  <address street="broadway 7" city="new york" />
  <address street="rural road 12" city="tempe" />
</user>'
    ,expected_in => 
{
          'address' => [
                       {
                         'street' => 'broadway 7',
                         'city' => 'new york'
                       },
                       {
                         'street' => 'rural road 12',
                         'city' => 'tempe'
                       }
                     ],
          'login' => 'foo'
        }
    ,expected_out => '<user login="foo">
  <address street="broadway 7" city="new york" />
  <address street="rural road 12" city="tempe" />
</user>'
};

my $addressdtd = [ 'address' =>
             'street',
             'city',
      ];

$tcS[7] = {
xml=>'
        <user login="foo">
          <address street="broadway 7" city="new york"/>hello
          <address street="rural road 12" city="tempe"/>world
        </user>
',
        dtd => [ 'user' =>
                     'login',
                     [ $addressdtd ],
                     '_content',
               ],
        expected_in => {
          'login' => 'foo',
          'address' => [
                       {
                         'street' => 'broadway 7',
                         'city' => 'new york'
                       },
                       {
                         'street' => 'rural road 12',
                         'city' => 'tempe'
                       }
                     ],
          '_content' => 'hello world'
        },
        expected_out=>
        '<user login="foo">
  <address street="broadway 7" city="new york" />
  <address street="rural road 12" city="tempe" />
  hello world
</user>'
};


plan tests => ( @tcS * 2 + 7 ) * 2 + 4;

use_ok('XML::Structured');

all_my_tests();

XML::Structured->import(":bytes");

all_my_tests();


sub all_my_tests {

    for my $tc (@tcS)  {

      $got = XMLin($tc->{dtd},$tc->{xml});
      is_deeply(
        $got,
        $tc->{expected_in},
        "Checking XMLin on test case (tc) ".$tcounter
      )
      || print Dumper($got);

      $got = XMLout($tc->{dtd},$got);
      is(
        $got,
        $tc->{expected_out}."\n",
        "Checking XMLout on test case (tc) ".$tcounter
      ) 
      || print "\n'$got'\n";

      $tcounter++;
    }

    # checking error handling
    #

    my $tc_e1 = {
        xml => '<user login="foo" password="bar" bar="foo" />',
        dtd => [ 'user' => 'login', 'password'],
    };

    eval {
      $got = XMLin($tc_e1->{dtd},$tc_e1->{xml});
    };
    is($@,"unknown attribute: bar\n","Checking unknown attribute");

    $tc_e1 = {
        xml => '<user login="foo" password="bar" password="foo" />',
        dtd => [ 'user' => 'login', 'password'],
    };

    eval {
      $got = XMLin($tc_e1->{dtd},$tc_e1->{xml});
    };
    like($@,qr/(duplicate attribute|Attribute.*redefined)/,"Checking duplicate attribute");

    ####
    $tc_e1 = {
        xml => '<user login="foo" password="bar"><foo bar=""></user>',
        dtd => [ 'user' => 'login', 'password'],
    };

    eval {
      $got = XMLin($tc_e1->{dtd},$tc_e1->{xml});
    };
    like($@,qr/(mismatched tag|tag mismatch)/,"Checking mismatched tag");

    ####
    $tc_e1 = {
        xml => '<user login="foo" password="bar"><foo bar="" /></user>',
        dtd => [ 'user' => 'login', 'password','foo'],
    };

    eval {
      $got = XMLin($tc_e1->{dtd},$tc_e1->{xml});
    };
    is($@,"element 'foo' contains attributes bar\n","Checking missing attribute in dtd");

    ####
    $tc_e1 = {
        xml => '<user login="foo" password="bar"><foo/>hello world</user>',
        dtd => [ 'user' => 'login', 'password','foo'],
    };

    eval {
      $got = XMLin($tc_e1->{dtd},$tc_e1->{xml});
    };
    is($@,"element 'user' contains content\n","Checking missing _content in dtd");

    ####
    $tc_e1 = {
        dtd => [ 'user' => 'login', 'password','foo'],
    };

    eval {
      $got = XMLinfile($tc_e1->{dtd},"t/data/0007-XML-Structured/in.xml");
    };
    is($@,"","Checking using infile");

    ####
    eval {
      $got = XMLinfile($tc_e1->{dtd},"t/data/0007-XML-Structured/noin.xml");
    };
    is($@,"t/data/0007-XML-Structured/noin.xml: No such file or directory\n","Checking missing infile");
 

}

eval { XMLout({},'') };
is($@,"parameter is not a hash\n","Checking XMLout without data hash");

eval { XMLout([],{}) };
is($@,"no match for alternative\n","Checking XMLout with empty data and dtd");

eval { XMLout([],{foo=>1,bar=>0}) };
is($@,"excess hash elements\n","Checking XMLout with empty dtd and to much data keys");

exit 0;


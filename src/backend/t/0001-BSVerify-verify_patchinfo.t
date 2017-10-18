#
#===============================================================================
#
#         FILE: 0001-BSVerify.t
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Frank Schreiner (M0ses), m0ses@samaxi.de
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 02.10.2015 14:02:09
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use Test::More;
use Data::Dumper;


my %pi_valid_part = (
              'releasetarget'   => 
                                [
                                   {
                                     'project' => 'foo',
                                     'repository' => 'foo'
                                   },
                                   {
                                     'project' => 'foo',
                                     'repository' => 'bar'
                                   }
                                ],
              'name'            => 'foobar',
              'summary'         => 'abc',
              'description'     => 'cde'
);

my $tc_patchinfo = {
    test_class_name     => 'patchinfo',
    code_ref            => \&BSVerify::verify_patchinfo,
    valid => [
        {
            'category'        => 'feature',
            %pi_valid_part
        },
        {
            'category'        => 'optional',
            %pi_valid_part
        },
        {
            'category' => 'recommended',
            %pi_valid_part
        },
        {
          'category' => 'security',
            %pi_valid_part
        },
        {
          'category' => 'security',
          'releasetarget' => $pi_valid_part{releasetarget},
          'summary'       => 'abc',
          'description'   => 'cde',
          'name'          => undef
        },
        {
            'category'        => undef,
            %pi_valid_part
        },
        {
          'category' => 'security',
          'releasetarget' => undef,
          'summary'       => 'abc',
          'description'   => 'cde',
          'name'          => 'validname', 
        },
        {
              'releasetarget'   => 
                                [
                                   {
                                     'project' => 'foo',
                                     'repository' => 'foo'
                                   },
                                   {
                                     'project' => 'foo',
                                     'repository' => undef
                                   }
                                ],
              'name'            => 'foobar',
              'summary'         => 'abc',
              'description'     => 'cde'
        }
    ],
    invalid => [
        {
          'category' => 'foo',
          'releasetarget' => [
                               {
                                     'project' => 'foo',
                                     'repository' => 'foo'
                                   }
                                 ],
              'name' => 'foobar'
        },
        {
              'category' => 'feature',
              'releasetarget' => [
                                   {
                                     'project' => '',
                                     'repository' => 'foo'
                                   }
                                 ],
              'name' => 'foobar'
        },
        {
              'category' => 'feature',
              'releasetarget' => [
                                   {
                                     'project' => 'foo',
                                     'repository' => 'foo'
                                   }
                                 ],
              'name' => '.foobar'
        },
        {
              'category' => 'feature',
              'releasetarget' => [
                                   {
                                     'project' => 'foo',
                                     'repository' => 'foo'
                                   },
                                   {
                                     'project' => 'foo',
                                     'repository' => ''
                                   }
                                 ],
              'name' => 'foobar'
        },
    ]
};

my $test_cases = [
    $tc_patchinfo,
];

my $test_handler = {
    valid => sub { ok(! $_[0],"Checking legal $_[1] '$_[2]'") },
    invalid => sub { ok($_[0],"Checking illegal $_[1] '$_[2]'") },
};
# Calculate number of tests^
#
my $tests = 1;
foreach my $class (@{$test_cases}) {
    $tests = $tests + scalar(@{$class->{invalid}}) + scalar(@{$class->{valid}});
}

plan tests => $tests;

require_ok( 'BSVerify' );

# execute tests
foreach my $class (@{$test_cases}) {
    foreach my $res ('valid','invalid') {
        foreach my $tc ( @{$class->{$res}} ) {
            eval { $class->{code_ref}->($tc); };
            my $got = $@;
            my $str = format_tc($tc);
            my $res = $test_handler->{$res}->($got,$class->{test_class_name},$str);
            if (! $res ) { 
                print "got: '$got'\n";
                ref($tc) && print Dumper($tc) 
            };
        }
    }
}

exit 0;

sub format_tc {
        my $str = shift;
        return "undef" unless defined($str);
        $str =~ s/\n/\\n/g;
        if (length $str > 30 ) {
            $str = substr($str,0,27) . '...';
        }
        return $str;
}



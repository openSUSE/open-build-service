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



my $tc_dod = {
    test_class_name     => "download",
    code_ref            => \&BSVerify::verify_dod,
    valid               => [
        {
            arch => "x86_64",
            repotype => "foo-bar",
            url => "https://sf.net/mysource.tgz",
            master => { 
                url => "https://src.suse.de/mysource.tgz" ,
                sslfingerprint => 'D1:31:1A:7E:8C:2A:04:DD:81:C9:23:F3:41:0F:2D:75:2F:0B:76:81'
            }
        }
    ],
    invalid             => [
        # illegal character in repotype
        {
            arch => "x86_64",
            repotype => "foo/bar",
            url => "https://sf.net/mysource.tgz",
        },
        # empty arch
        {
            url => "https://sf.net/mysource.tgz",
        },
        # empty url
        {
            arch => "x86_64",
        },
        # master without url
        {
            arch => "x86_64",
            url => "https://sf.net/mysource.tgz",
            master => {
                url => ''
            }
        },
    ],
};

my $test_cases = [
    $tc_dod,
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



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



my $tc_repo = {
    test_class_name     => "repository",
    code_ref            => \&BSVerify::verify_repo,
    valid               => [
        {
            name    => 'openSUSE_13.2',
            path    => [
                { project => 'openSUSE:13.2'  , repository => 'standard' },
                { project => 'devel:languages:perl'  , repository => 'openSUSE_13.2' },
            ],
            arch => ['i586','x86_64'],
            releasetarget => [
                { project => 'openSUSE:13.2'  , repository => 'standard' },
                { project => 'devel:languages:perl'  , repository => 'openSUSE_13.2' },
            ],
            download => [
                { arch => 'x86_64' , url => "http://www.suse.de?view=mysource.tgz" }
            ],
            hostsystem => { project => 'openSUSE:13.2' , repository => 'standard' }
        }
    ],
    invalid             => [
        # empty url
        {
            name    => 'openSUSE_13.2',
            path    => [
                { project => 'openSUSE:13.2'  , repository => 'standard' },
                { project => 'devel:languages:perl'  , repository => 'openSUSE_13.2' },
            ],
            arch => ['i586','x86_64'],
            releasetarget => [
                { project => 'openSUSE:13.2'  , repository => 'standard' },
                { project => 'devel:languages:perl'  , repository => 'openSUSE_13.2' },
            ],
            download => [
                { arch => 'x86_64' }
            ],
        },
        # duplicate arch in download
        {
            name    => 'openSUSE_13.2',
            arch => ['i586','x86_64'],
            download => [
                { arch => 'x86_64', url => "http://src.server.org/mysource1.tgz" },
                { arch => 'x86_64', url => "http://src.server.org/mysource2.tgz" }
            ],
        },
        # arch of dod not found
        {
            name    => 'openSUSE_13.2',
            arch => ['i586','x86_64'],
            download => [
                { arch => 'foo', url => "http://src.server.org/mysource1.tgz" },
            ],
        },
        # base entry illegal in repo
        {
            name    => 'openSUSE_13.2',
            arch => ['i586','x86_64'],
            download => [
                { arch => 'foo', url => "http://src.server.org/mysource1.tgz" },
            ],
            base => 'foo'
        },
    ],
};


my $test_cases = [
    $tc_repo,
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



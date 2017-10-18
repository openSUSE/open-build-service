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


my $tc_projid = {
    test_class_name     => 'project id',
    code_ref            => \&BSVerify::verify_projid,
    valid               => [
        'openSUSE:test',
        'open SUSE:test',
        'open.SUSE:test',
    ],
    invalid             => [
        "openSUSE:.test",
        ".test:openSUSE",
        "_test:openSUSE",
        "openSUSE::Test",
        'opensuse/test',
        "\n",
#        ' ',
        '',
        'x' x 201,
        undef
    ],
};

my $tc_projkind = {
    test_class_name     => 'project kind',
    code_ref            => \&BSVerify::verify_projkind,
    valid               => [qw/standard maintenance maintenance_incident maintenance_release/],
    invalid             => ['foo',undef]
};

my $tc_packid = {
    test_class_name     => 'package id',
    code_ref            => \&BSVerify::verify_packid,
    valid               => [qw/_product _pattern _project _patchinfo _product:foo _patchinfo:bar foo.bar/],
    invalid             => [
        '',
#        ' ',
        "\n",
        # TBC
#        'package name',
        '_pattern:foo',
        '_project:foo',
        'foo:_foo',
        '_foo',
        '.test',
        '_product:.test',
        "foo\nfoo",
        "foo\n",
#        'foo;bar',
        'x' x 201,
        '0',
        undef
    ]
};

my $tc_repoid = {
    test_class_name     => 'repository id',
    code_ref            => \&BSVerify::verify_repoid,
    valid               => [qw/foo bar foo_bar/],
    invalid             => [
        '',
#        ' ',
        "\n",
#        'repo name',
        "_repo",
        '.repo', 
        'x' x 201,
        undef
    ]
};

my $tc_jobid = {
    test_class_name     => 'job id',
    code_ref            => \&BSVerify::verify_jobid,
    valid               => [qw/foo foo:bar foo_bar/],
    invalid             => [
        '',
#        ' ',
        "\n",
        '.job_fails',
        undef
        # TBC
        #'x' x 201
    ]
};

my $tc_arch = {
    test_class_name     => 'arch',
    code_ref            => \&BSVerify::verify_arch,
    valid               => [qw/%foo foo_bar/,'foo,bar'],
    invalid             => [
        '',
#        ' ',
        "\n",
        'foo:bar',
        'foo.bar',
        'foo;bar',
        'x' x 201,
        undef
    ]
};

my $tc_packid_repository = {
    test_class_name     => 'package id and repository',
    code_ref            => \&BSVerify::verify_packid_repository,
    valid               => [qw/_repository/,@{$tc_packid->{valid}}],
    invalid             => [ @{$tc_packid->{invalid}} ]
};

my $tc_filename = {
    test_class_name     => 'filename',
    code_ref            => \&BSVerify::verify_filename,
    valid               => [qw/ foo foo.bar/,'foo,bar'],
    invalid             => [
        '',
        "\n",
        '.foobar',
        # TBC
        undef,
#        ' ',
#        'foo;bar',
#        'foo bar',
#        ' .sh'
    ]
};

# service test basics
my $tc_service = {
    test_class_name     => 'filename in service',
    code_ref            => \&BSVerify::verify_service,
    valid=>[],
    invalid=>[],
};

# generate all combinations of filenames and add it to tc_service
foreach my $state (qw/valid invalid/) {
    foreach my $val ( @{$tc_filename->{$state}} ) {
       push(@{$tc_service->{$state}},{name=>$val}); 
    }
    my $param = [];
    map { push(@{$param},{ name => $_}) } @{$tc_filename->{$state}};
    push(@{$tc_service->{$state}},{ param => $param }); 
}
 
@{$tc_service->{invalid}} = grep { defined $_->{name} } @{$tc_service->{invalid}};

my $tc_url = {
    test_class_name     => "url",
    code_ref            => \&BSVerify::verify_url,
    valid               => [qw|http://www.suse.de https://suse.de?nana=lalal&foo=bar|],
    invalid             => [
        '',
        'foog_llaal_anana',
        "http://nana\nlala",
    ]
};

my $tc_md5 = {
    test_class_name     => "md5",
    code_ref            => \&BSVerify::verify_md5,
    valid               => [qw|dabfc3276eceae1e09f46bbfe41b6bfc|],
    invalid             => [
        'dabfc3276eceae1e09f46bbfe41b6bf',
        'dabfc3276eceae1e09f46bbfe41b6bfC',
        ''
    ]
};

my $tc_srcmd5 = {
    test_class_name     => "srcmd5",
    code_ref            => \&BSVerify::verify_srcmd5,
    valid               => [qw|dabfc3276eceae1e09f46bbfe41b6bfc 240f1cee336fc58642ecf36a717bfcb7fdc35da4|],
    invalid             => [
        'dabfc3276eceae1e09f46bbfe41b6bf',
        'dabfc3276eceae1e09f46bbfe41b6bfC',
        '240f1cee336fc58642ecf36a717bfcb7fdc35dA4',
        '',
        'dabfc3276eceae1e09f46bbfe41b6bfcavc',
        '240f1cee336fc58642ecf36a717bfcb7fdc35Da4',
        undef
    ]
};

my $tc_rev = {
    test_class_name     => "rev",
    code_ref            => \&BSVerify::verify_rev,
    valid               => [qw|
        dabfc3276eceae1e09f46bbfe41b6bfc 
        240f1cee336fc58642ecf36a717bfcb7fdc35da4
        upload
        build
        latest
        repository
        12345
    |],
    invalid             => [
        '',
        'dabfc3276eceae1e09f46bbfe41b6bf',
        'dabfc3276eceae1e09f46bbfe41b6bfC',
        '240f1cee336fc58642ecf36a717bfcb7fdc35dA4',
        'foo',
        'bar',
        '',
        undef
    ]
};

my $tc_linkrev = {
    test_class_name     => "linkrev",
    code_ref            => \&BSVerify::verify_linkrev,
    valid               => [ @{$tc_rev->{valid}} , 'base' ],
    invalid             => $tc_rev->{invalid},
};

my $tc_port = {
    test_class_name     => "port",
    code_ref            => \&BSVerify::verify_port,
    valid               => [qw/1025 65535 65536/],
    invalid             => [qw/abc 1023/,'',undef],
};

my $tc_num = {
    test_class_name     => "number",
    code_ref            => \&BSVerify::verify_num,
    valid               => [qw/1234 12345678901234567890/],
    invalid             => [qw/a 1a1 -1/,'',undef],
};

my $tc_intnum = {
    test_class_name     => "integer number",
    code_ref            => \&BSVerify::verify_intnum,
    valid               => [qw/-1 1234 12345678901234567890/],
    invalid             => [qw/a 1a1/,'',undef],
};

my $tc_bool= {
    test_class_name     => "boolean",
    code_ref            => \&BSVerify::verify_bool,
    valid               => [qw/0 1/],
    invalid             => [qw/a -1 true false n y j/,'',undef],
};

my $tc_prp= {
    test_class_name     => "project and repository",
    code_ref            => \&BSVerify::verify_prp,
    valid               => [qw|openSUSE:Test/foo foo/bar|],
    invalid             => [qw|openSUSE:.Test/foo foo/.bar foo_bar|,''],
};

my $tc_prpa= {
    test_class_name     => "project, repository and arch",
    code_ref            => \&BSVerify::verify_prpa,
    valid               => [qw|openSUSE:Test/foo/x86_64 foo/bar/i586|],
    invalid             => [qw|openSUSE:.Test/foo/x86_64 foo/.bar/x86_64  foo_bar/x86_64 openSUSE:Test/foo/foo:bar openSUSE:Test/foo/foo;bar|,''],
};

my $tc_resultview = {
    test_class_name     => "resultview",
    code_ref            => \&BSVerify::verify_resultview,
    valid               => [qw|status binarylist stats versrel|],
    invalid             => [qw|foo bar|,'',undef],
};

my $tc_disableenable = {
    test_class_name     => "disableenable",
    code_ref            => \&BSVerify::verify_disableenable,
    valid               => [
        {
            disable => [{repository=>"standard",arch=>"i586"}],
            enable  => [{repository=>"standard",arch=>"x86_64"}]
        }
    ],
    invalid             => [
        {
            disable => [{repository=>"standard",arch=>"i586:99"}],
            enable  => [{repository=>".standard",arch=>"x86_64"}]
        },
        {
            disable => [{repository=>"foo|standard",arch=>"i586"}],
            enable  => [{repository=>"standard",arch=>"x86_64;foo"}]
        }
    ],
};


my $test_cases = [
    $tc_projid,
    $tc_projkind,
    $tc_packid,
    $tc_repoid,
    $tc_jobid,
    $tc_arch,
    $tc_packid_repository,
    $tc_filename,
    $tc_service,
    $tc_url,
    $tc_md5,
    $tc_srcmd5,
    $tc_rev,
    $tc_linkrev,
    $tc_port,
    $tc_num,
    $tc_intnum,
    $tc_bool,
    $tc_prp,
    $tc_prpa,
    $tc_resultview,
    $tc_disableenable,
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



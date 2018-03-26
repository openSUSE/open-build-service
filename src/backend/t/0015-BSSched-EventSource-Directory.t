use strict;
use warnings;

use Test::More tests => 16;                      # last test to print

use_ok('BSSched::EventSource::Directory');
use FindBin;
use BSUtil;
use BSXML;
use Data::Dumper;

my $base_path = __FILE__;
$base_path =~ s/(.*)\/[^\/]*$/$1/;

my $eventdir_base   = "$base_path/data/0015/events";
my $eventdir = {
	x86_64 => "$eventdir_base/x86_64",
	i586   => "$eventdir_base/i586",
};

my $broken_file = "$eventdir->{x86_64}/package:broken:event::test";
my $gctx = {eventdir=> $eventdir_base};
my $ev = undef;
my $arch = undef;
my @ev = ();
my $prp = undef;
my $type = undef;
my @files_to_remove = ();
my $got = undef;
my $ev_dir = undef;
my $file_name = undef;
my $expected = undef;

open(FH,">",$broken_file);
print FH "
<broken>
  <event>
    <test> 
    </test> 
  </event>
</broken>
";

close FH;

$ev = { type =>'package',package=>'test-package-name'};
my $ev_string='<event type="package">
  <package>test-package-name</package>
</event>
';

my $evname = "package:project-name::test-package-name";
$arch   = "x86_64";
open(FH,"> $eventdir->{$arch}/.ping");
close("$eventdir->{$arch}/.ping");
push(@files_to_remove,"$eventdir->{$arch}/.ping");

BSSched::EventSource::Directory::sendevent($gctx,$ev,$arch,$evname);

ok(( -f "$eventdir->{$arch}/$evname" ),"Checking sendevent for $arch");

$arch   = "i586";
mkdir $eventdir->{$arch};
push(@files_to_remove,"$eventdir->{$arch}/.ping","$eventdir->{$arch}/$evname",$eventdir->{$arch});
open(FH,"> $eventdir->{$arch}/.ping");
close("$eventdir->{$arch}/.ping");
BSSched::EventSource::Directory::sendevent($gctx,$ev,$arch,$evname);

ok(( -f "$eventdir->{$arch}/$evname" ),"Checking sendevent for $arch");

###
$arch   = "x86_64";
my $stdout_content;
{ 
  local *STDOUT;
  open(STDOUT,">>",\$stdout_content);

  @ev = BSSched::EventSource::Directory::readevents($gctx,$eventdir->{$arch});
  $expected = [
	    {
	      'evfilename' => 't/data/0015/events/x86_64/finished:devel:languages:perl:CPAN-P::openSUSE_Tumbleweed::perl-perlbench-1c7e973409998f482ce9dba10304e653',
	      'type' => 'built',
	      'job' => 'devel:languages:perl:CPAN-P::openSUSE_Tumbleweed::perl-perlbench-1c7e973409998f482ce9dba10304e653'
	    },
	    {
	      'project' => 'devel:languages:perl:CPAN-S',
	      'evfilename' => 't/data/0015/events/x86_64/package:devel:languages:perl::perl-Unknown-Type',
	      'type' => 'unknown',
	      'package' => 'perl-SWISH'
	    },
	    {
	      'project' => 'devel:languages:perl:CPAN-S',
	      'evfilename' => 't/data/0015/events/x86_64/package:devel:languages:perl:CPAN-S::perl-SWISH',
	      'type' => 'package',
	      'package' => 'perl-SWISH'
	    },
	    {
	      'evfilename' => 't/data/0015/events/x86_64/package:devel:languages:perl:CPAN-S::perl-Scalar-Boolean',
	      'project' => 'devel:languages:perl:CPAN-S',
	      'package' => 'perl-Scalar-Boolean',
	      'type' => 'package'
	    },
	    {
	      'type' => 'package',
	      'package' => 'perl-ScatterPlot',
	      'project' => 'devel:languages:perl:CPAN-S',
	      'evfilename' => 't/data/0015/events/x86_64/package:devel:languages:perl:CPAN-S::perl-ScatterPlot'
	    },
	    {
	      'evfilename' => 't/data/0015/events/x86_64/package:project-name::test-package-name',
	      'package' => 'test-package-name',
	      'type' => 'package'
	    }
	  ];

}
is($stdout_content,"package:broken:event::test: bad event xml\n","Checking error message for broken xml");
is_deeply(\@ev,$expected,"Checking readevents (arch: $arch)");
ok((! -f $broken_file),"Checking if broken file was delete");

$arch = "i586";
@ev = BSSched::EventSource::Directory::readevents($gctx,$eventdir->{$arch});

$expected = [
          {
            'package' => 'test-package-name',
            'type' => 'package',
            'evfilename' => 't/data/0015/events/i586/package:project-name::test-package-name'
          }
        ];

is_deeply(\@ev,$expected,"Checking readevents (arch: $arch)");

my $ping_string = undef;

$ping_string = read_ping($eventdir->{x86_64});
is_deeply($ping_string,["x"],"Checking ping for x86_64");
$ping_string = read_ping($eventdir->{i586});
is_deeply($ping_string,["x"],"Checking ping for i586");

$arch   = "broken_ping_arch";
BSSched::EventSource::Directory::sendevent($gctx,$ev,$arch,$evname);
my $f2check = "$eventdir_base/$arch/$evname";
ok(( -f $f2check ),"Checking sendevent for $arch");
push(@files_to_remove,$f2check);

# Checking evname with overlength
my $ol_checksum = "package:::51d06305b4425161b3fd3f631f3a38b6";
my $overlength_evname = $evname . "x" x 200;
BSSched::EventSource::Directory::sendevent($gctx,$ev,$arch,$overlength_evname);
$f2check = "$eventdir_base/$arch/$ol_checksum";
push(@files_to_remove,$f2check);

ok(( -f "$eventdir_base/$arch/$ol_checksum" ),"Checking sendevent for $arch with overlength event name");

push(@files_to_remove,"$eventdir_base/$arch/");

#
# BSSched::EventSource::Directory::sendrepochangeevent
#
$gctx->{arch} = 'x86_64';
$prp = "devel:languages:perl/openSUSE_Leap_42.1";
$expected = {
          'type' => 'repository',
          'arch' => 'x86_64',
          'repository' => 'openSUSE_Leap_42.1',
          'project' => 'devel:languages:perl'
        };

BSSched::EventSource::Directory::sendrepochangeevent($gctx, $prp, $type);

$file_name = $prp;
$file_name =~ s/\//::/;
$file_name = "repository::${file_name}::$gctx->{arch}";
$ev_dir = "$eventdir_base/repository/";
$got = readxml("$ev_dir/$file_name",$BSXML::event);

is_deeply($got,$expected,"Checking sendrepochangeevent without type");
push(@files_to_remove,"$ev_dir/$file_name",$ev_dir);

$type = "repoinfo";
$expected->{type}=$type;
BSSched::EventSource::Directory::sendrepochangeevent($gctx, $prp, $type);

$file_name = $prp;
$file_name =~ s/\//::/;
$file_name = "repoinfo::${file_name}::$gctx->{arch}";
$ev_dir = "$eventdir_base/repository/";
$got = readxml("$ev_dir/$file_name",$BSXML::event);

is_deeply($got,$expected,"Checking sendrepochangeevent");
push(@files_to_remove,"$ev_dir/$file_name",$ev_dir);

#
# BSSched::EventSource::Directory::sendrepochangeevent
#
$arch = 'x86_64';
BSSched::EventSource::Directory::sendunblockedevent($gctx, $prp, $arch);

$file_name = $prp;
$file_name =~ s/\//::/;
$file_name = "unblocked::" . $file_name;

$ev_dir = "$eventdir_base/$arch";
$got = readxml("$ev_dir/$file_name",$BSXML::event);
$expected = {
          'repository' => 'openSUSE_Leap_42.1',
          'project' => 'devel:languages:perl',
          'type' => 'unblocked'
        };

is_deeply($got,$expected,"Checking sendunblockedevent");
push(@files_to_remove,"$ev_dir/$file_name");

#
# BSSched::EventSource::Directory::sendpublishevent
#

BSSched::EventSource::Directory::sendpublishevent($gctx, $prp);

$file_name = $prp;
$file_name =~ s/\//::/;

$ev_dir = "$eventdir_base/publish/";
$got = readxml("$ev_dir/$file_name",$BSXML::event);
$expected = {
          'repository' => 'openSUSE_Leap_42.1',
          'project' => 'devel:languages:perl',
          'type' => 'publish'
        };

is_deeply($got,$expected,"Checking sendpublishevent");
push(@files_to_remove,"$ev_dir/$file_name",$ev_dir);

#
# BSSched::EventSource::Directory::sendimportevent
#

my $job = "my_great_jobname";
BSSched::EventSource::Directory::sendimportevent($gctx, $job, $arch);

$file_name = $prp;
$file_name =~ s/\//::/;
$file_name = "import.$job";
$ev_dir = "$eventdir_base/$arch/";
$got = readxml("$ev_dir/$file_name",$BSXML::event);
$expected = {
	  'job'  => $job,
          'type' => 'import'
        };

is_deeply($got,$expected,"Checking sendimportevent");
push(@files_to_remove,"$ev_dir/$file_name");


####################
# CLEANUP
unshift(@files_to_remove,"$eventdir_base/$arch/$evname");

for (BSUtil::unify(sort {$b cmp $a} @files_to_remove)) {
  ( -d $_ ) ? rmdir $_ : unlink $_;
  warn "$_: $!" if $!;
}

exit 0;

sub read_ping { 
	my ($ev_dir) = @_;
	open(FH,"< $ev_dir/.ping");
	my @lines = <FH>;
	close(FH);
	return \@lines;
}

sub read_file {
	my $file = shift;
	my $rv   = undef;
print "$file\n";
	open(FH,$file);
	while (<FH>) { $rv .= $_ }
	return $rv
}


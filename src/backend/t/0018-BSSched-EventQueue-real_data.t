use strict;
use warnings;

use Test::More tests => 2;                      # last test to print
use Data::Dumper;
use FindBin;

use File::Copy;
use BSSched::RPC;
use BSSched::EventSource::Directory;
use_ok("BSSched::EventQueue");

my $DEBUG=0;
my $gctx = {
  myjobsdir => "$FindBin::Bin/tmp/0018/jobs/",
  reporoot  => "$FindBin::Bin/tmp/0018/repo",
  arch      => "x86_64",
  projpacks => {
    "devel:languages:perl" => {
      package => {
	"perl-Devel-Cover"     => {},
	"perl-Test-Finished-Package"   => {},
      }
    }
  },
  rctx => BSSched::RPC->new(),
};

my $datadir = "$FindBin::Bin/data/0018";
my $backenddir = "$FindBin::Bin/tmp/0018";
my $eventsdir = "$backenddir/events";

( -d "$FindBin::Bin/tmp/" ) || mkdir "$FindBin::Bin/tmp/";

rm_rf($backenddir);
cp_r($datadir,$backenddir);

my $got = undef;

my $eq = BSSched::EventQueue->new($gctx);

# just for coverage
$eq->process_events();

my @ev = BSSched::EventSource::Directory::readevents($gctx,$eventsdir);


$eq->add_events(@ev);

is($eq->events_in_queue,2,"Checking number of events in queue");

#is_deeply($got,$sorted,"Checking sorted events");

#{
#	local *STDOUT;
#	my $out=undef;
#	open STDOUT, '>', \$out or die "Can't open STDOUT: $!";
#	$eq->process_events();
#
#}

my $gotevent;
eval {
  local *STDOUT;
  my $out = undef;
  open(STDOUT,">",\$out);
  $gotevent = $eq->process_events();
};
#print "$@\n";



exit 0;

sub cp_r {
	my ($src,$dst) = @_;
	die "no destination given" if (  ! $dst );
	if ( -d $src ) {
		( -d $dst ) || mkdir $dst;
		opendir(my $dh,$src) || die "Could not open $src: $!";
		while (my $f = readdir($dh) ) {
			next if ( $f eq '.' or $f eq '..' );
			cp_r($src."/$f",$dst."/$f");
		}
		closedir($dh);
	} elsif ( -e $src ) {
		print "copy $src -> $dst\n" if $DEBUG;
		copy($src,$dst);
	} else {
		die "Source $src does not exist";
	}
}

sub rm_rf {
	my ($src) = @_;
	die "no file or directory given" if (  ! $src );
	if ( -d $src ) {
		opendir(my $dh,$src) || die "Could not open $src: $!";
		while (my $f = readdir($dh) ) {
			next if ( $f eq '.' or $f eq '..' );
			rm_rf($src."/$f");
		}
		closedir($dh);
		rmdir $src || die "Error while removing directory '$src': $!\n";
	} elsif ( -e $src ) {
		print "removing file $src\n" if $DEBUG;
		unlink $src || die "Error while removing file '$src': $!\n";
	}
}

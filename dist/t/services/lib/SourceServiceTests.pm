package SourceServiceTests;

use strict;
use warnings;
use File::Temp qw/tempdir/;
use File::Path qw(make_path remove_tree);
use Cwd;
use Data::Dumper;

# CONSTRUCTOR
sub new { my $class = shift; bless {@_}, $class }

# ATTRIBUTES
sub testcase   { return $_[0]->{testcase} }
sub hostname   { return $_[0]->{hostname} }
sub pkg_name   { return $_[0]->{pkg_name} }
sub workingdir { return $_[0]->{workingdir} }
sub port       { return $_[0]->{port} }

sub cpiofile {
  my ($self, $fn) = @_;
  $self->{cpiofile} = $fn if $fn;
  if (! $self->{cpiofile}) {
    $self->{cpiofile} = $self->temp_dir() . "/" . $self->testcase() . ".cpio";
  }
  return $self->{cpiofile};
}

sub temp_dir {
  return $_[0]->{temp_dir} if $_[0]->{temp_dir};
  $_[0]->{temp_dir} = "$FindBin::Bin/tmp/".$_[0]->testcase;;
  if (-d $_[0]->{temp_dir} ) {
    remove_tree($_[0]->{temp_dir});
  }
  make_path($_[0]->{temp_dir});
  return $_[0]->{temp_dir};
};

# METHODS
sub get_expected_files {
  my ($self) = @_;
  my $tc     = $self->testcase;
  my $fn     = "$FindBin::Bin/data/$tc/expected.list";
  my $res    = [];
  return $res unless -f $fn;
  open(my $fh, '<', $fn) || die "Could not open $fn: $!\n";
  while (<$fh>) {chomp; push @{$res}, $_};
  close $fh;
  return $res;
}

sub create_cpio {
  my ($self, @files) = @_;
  my $cpio = $self->cpiofile;
  my $cwd  = getcwd();
  chdir($self->workingdir);
  open(PIPE, "|cpio -o -H newc > $cpio 2>/dev/null")|| die "Could not open $cpio: $!";
  print PIPE join("\n", @files);
  close PIPE;
  die "!!! ERROR WHILE GENERATING CPIO !!!\nFILES:\n".Dumper(\@files)."\nWORKINGDIR: ".$self->workingdir."\n" if $?;
  chdir($cwd);
}

sub get_filelist {
  my ($self) = @_;
  my $tc     = $self->testcase;
  die "No testname given\n" unless $tc;
  my $fn = "$FindBin::Bin/data/$tc/file.list";
  my @list;

  if (-e $fn) {
    open(FL, "<", $fn) || die("Could not open $fn: $!\n");
    while (<FL>) {
      chomp;
      push @list, $_;
    }
  } else {
    @list = ('_service');
  }

  return @list;
}

sub send_cpio {
  my ($self) = shift;
  my $tc     = $self->testcase;
  my $hn     = $self->hostname;
  my $pkg    = $self->pkg_name;
  my $port   = $self->port;
  $self->create_cpio(
    $self->get_filelist
  );
  my $cpio = $self->cpiofile;
  my $cwd  = getcwd();
  chdir($self->temp_dir);
  my $cmd = "curl -s -X POST --data-binary \@$cpio http://$hn:$port/sourceupdate/home:M0ses/$pkg --header \"Content-Type:application/x-cpio\" | cpio -i 2>/dev/null";
  `$cmd`;
  chdir($cwd);
}

sub check_result {
  my ($self) = shift;
  my $cwd  = getcwd();
  my $rc   = 0;
  chdir($self->temp_dir);

  if (! -f "./_service_error" ) {
    my $not_found=0;
    my $exp = $self->get_expected_files;
    for my $f (@$exp) {
      my @files = glob($f);
      if (! @files) {
        $not_found = 1;
	print STDERR "File not found: ".$self->temp_dir."/$f\n";
      }
      for my $cf (@files) {
	unless (-e $cf) {
	  $not_found = 1;
	  print STDERR "File not found: ".$self->temp_dir."/$f\n";
	}
      }
    }
    $rc = 1 unless $not_found;
    my $check_result = $self->workingdir."/check_result";
    if (-x $check_result) {
      system($check_result);
      $rc = 1 unless $?;
    }
  } else {
    open(SE, "<", "./_service_error") || die "Could not open ".$self->temp_dir."/_service_error: $!\n";
    while (<SE>) { print STDERR $_; }
    close SE;
  }
  chdir($cwd);

  return $rc;
}

sub cleanup {
  my ($self) = @_;
  return if $ENV{KEEP_RESULTS};
  remove_tree($self->temp_dir);
}

1;

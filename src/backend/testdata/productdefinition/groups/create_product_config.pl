#!/usr/bin/perl -w
# $Id: create_product_config.pl,v 1.1 2008/09/02 12:54:59 lrupp Exp $
#

BEGIN {
  $abuild_base_dir = "/work/abuild/lib/abuild";
  unshift @INC, "$abuild_base_dir/modules";
}

use strict;
use RPMQ;
use XML::Simple qw(:strict);
use Data::Dumper;
use FileHandle;

my %xml;
my $debug=0;
our $verbose=0;
my $outputdir="/tmp/xml";
my $packagedir="";
our $descr_dir="";
our %rpmtags=( Prq => 'requires',
		       Prc => 'recommends',
			   Psg => 'suggests');
our %patterntags=( Obs => 'obsoletes',
				   Fre => 'freshens',
				   Req => 'requires',
				   Rec => 'recommends',
				   Prv => 'provides',
				   Sug => 'suggests');
my %unknown_groups=( baselibs_x86_64 => '32bit',
                     baselibs_ia64   => 'x86',
                     baselibs_s390x  => '32bit',
					 baselibs_ppc64  => '64bit');
my %patterns=();
our $pattern_files;
our $used_pattern_files;

sub usage {
	my $exit_code=shift || 1;
	print <<EOF
    Usage: $0 [OPTIONS]
           --patternsdir <directory> : directory containing pattern files
           --outputdir <directory>   : output directory
           --packagedir <directory>  : directory containing packages which 
                                       should end on the media
           --verbose                 : verbose output
EOF
;

exit $exit_code;
}

sub OpenFileWrite {
  my $filename = shift;
  my ($FH) = new FileHandle;
  open ($FH, ">$filename") || die "ERROR: can't write output file $filename";
  return $FH;
}

sub ParsePatternFile {
    my $file=shift;
    my %data;
    if ($file =~ /\.gz$/) {
        open (FILE,"zcat $file |") || die ("Can not open $file: $! $?!\n");
    } else {
        open (FILE,"$file") || die ("Can not open $file: $! $?!\n");
    }
    while (<FILE>) {
      chomp;
      next unless /^[=+]/;
      my ($tag, $data);
      if (/^\+(.*)$/) {
        $tag = $1;
        $data = '';
        while (<FILE>) {
          chomp;
          last if $_ eq "-$tag";
          $_ =~ s/[\ \<\>=].*// if ( "$tag" ne "Des:" ); 
          $data .= "$_\n";
        }
        chop $data;
      } else {
        ($tag,$data) = split(/ /, $_, 2);
        $tag = substr($tag, 1);
      }
     chop $tag;
     $data{$tag}=$data;
     }
    close (FILE);
  print Dumper(\%data) if ($debug);
 return \%data;
}

sub getFiles {
    my $path=shift;
    my $ending=shift;
    opendir(DESCDIR,"$path") || die ("Could not open $path: $! $?!\n");
    my @Files= grep {/.*\Q$ending\E/} readdir(DESCDIR);
    closedir (DESCDIR);
    my $number = @Files;
    if ( $number gt 0 ){
      my @return;
      foreach (@Files){
        next if ( $_ eq "." );
        next if ( $_ eq ".." );
        push @return,$_;
      }
     return \@return;
    }
 return 0;
}


sub writeData {
	my $fh=shift;
	my $key=shift || 'package';
	my $value=shift;
	if ($key eq "package"){
		print $fh "            <package name=\"$value\" />\n";
	}
}

sub print_pattern_tags {
	my $fh=shift;
	my $tags=shift;
    my $patterntags=shift;
	my %wantedtags=( 	Vis => 'visible',
						Ico => 'icon',
						Sum => 'summary',
						Cat => 'category',
						Des => 'description' 
					);

	if (defined($tags->{'Ord'})){
		print $fh "    <pattern ordernumber=\"".$tags->{'Ord'}."\">\n";
	} else {
		print $fh "    <pattern>\n";
	}

	foreach my $key (sort(keys %$tags)){
		# TODO: for now only a short list is allowed
		foreach my $wanted (keys %wantedtags){
			if ( "$key" eq "$wanted" ){
				print $fh "        <".$wantedtags{"$wanted"}.">".$tags->{"$key"}."</".$wantedtags{"$wanted"}.">\n";
			}
		}
	}
    print $fh "        <relationships>\n";
    for my $patkey (keys %$patterntags){
        if (defined($tags->{$patkey})){
            foreach my $patname (split(/\n/,$tags->{$patkey})){
                print $fh "           <pattern name=\"$patname\" relationship=\"$patterntags{$patkey}\" />\n";
            }
        }
    }
    print $fh "        </relationships>\n";
    print $fh "    </pattern>\n";
}

while (my $param=shift (@ARGV)){
  if (($param eq '--help') || ($param eq '-h')) {
    usage('0');
  }
  if ($param eq '--packagedir'){
	$packagedir=shift @ARGV;
  }
  if ($param eq '--patternsdir'){
	$descr_dir=shift @ARGV;
  }
  if ($param eq '--outputdir'){
    $outputdir=shift @ARGV;	
  }
  if ($param eq '--verbose'){
    $verbose=1;
  }
#  die (usage(1));
}

# get the current packages on the media
opendir(P,$packagedir) || die "Could not open $packagedir : $!\n";
my %packages=grep { ! /^\./  } readdir(P);
closedir(P);

if (-d "$outputdir"){
	print "Removing $outputdir/* [Y/n]? ";
    my $ans=<STDIN>;
	chomp($ans);
    if (("$ans" eq "n") || ("$ans" eq "N")){
         print "WARNING:  The script will overwrite existing files in $outputdir\n";
    } else {
         system("rm -rf $outputdir/*");
    }
} else {
	system("mkdir -p $outputdir");
}

# get the current pattern files
$pattern_files=getFiles($descr_dir,'.pat');
$pattern_files=getFiles($descr_dir,'.pat.gz') unless ( $pattern_files ne "0" );

if ( $verbose ){
    print "INFO:    output_dir        = ".$outputdir."\n";
    print "INFO:    packagedir        = ".$packagedir."\n";
    print "INFO:    descr directory   = ".$descr_dir."\n";
    print "INFO:    pattern files     = ";
    foreach (@$pattern_files){
        print "$_ ";
    }
    print "\n";
}

print "Before:        ".scalar (keys %packages)."\t packages\n" if ($verbose);
print "Before:        ".scalar (@$pattern_files)."\t patterns\n" if ($verbose);
if ( "$pattern_files" ne "0" ){
    for my $patfile (@$pattern_files){
        my $pattern = ParsePatternFile("$descr_dir/$patfile");
		# FIXME: handle first whitespace better
		my ($dummy,$pattern_name,$pattern_version,$pattern_release,$pattern_arch) = split(/ /,$pattern->{'Pat'},5);
		my $fh = OpenFileWrite( "$outputdir/group.$pattern_name.xml");
        print $fh "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
		print $fh "<group name=\"$pattern_name\" version=\"$pattern_version\" release=\"$pattern_release\">\n";
		print_pattern_tags($fh,$pattern,\%patterntags);
        for my $key (keys %rpmtags){
			if (defined($pattern->{$key})){
				print $fh "    <packagelist relationship=\"$rpmtags{$key}\" id=\"$pattern_name.$rpmtags{$key}\">\n";
				foreach my $rpm (sort(split(/\n/,$pattern->{$key}))){
					writeData($fh,'package',"$rpm");
					$patterns{$pattern_name}{$rpm}=$rpmtags{$key};
# FIXME: too late for SLE11
#					delete $packages{$rpm};
				}
				print $fh "    </packagelist>\n";
			}
		}
		print $fh "</group>\n";
		close ( $fh );
	}
}

print "prel. result : ".scalar (keys %packages)."\t (now baselibs...)\n" if ($verbose);

foreach my $name (keys %unknown_groups){
    my $fh = OpenFileWrite( "$outputdir/group.$name.xml");
    print $fh "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	print $fh "<group name=\"$name\" version=\"11\" release=\"0\">\n";
	print $fh "    <packagelist relationship=\"$patterntags{'Rec'}\">\n";
    foreach my $rpm (sort(keys %packages)){
		if ( $rpm =~ /.*-$unknown_groups{$name}/ ){
			writeData($fh,'package',"$rpm");	
# FIXME: too late for SLE11
#			delete($packages{$rpm});
		}
	}	
	print $fh "    </packagelist>\n";
	print $fh "</group>\n";
	close($fh);
}

print "Left:          ".scalar (keys %packages)."\t (Pakages without classification: rest)\n" if ($verbose);

foreach my $name ('DVD_REST'){
    my $fh = OpenFileWrite( "$outputdir/group.$name.xml");
    print $fh "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print $fh "<group name=\"$name\" version=\"11\" release=\"0\">\n";
    print $fh "    <packagelist relationship=\"$patterntags{'Rec'}\">\n";
    foreach my $rpm (sort(keys %packages)){
        writeData($fh,'package',"$rpm");
    	delete($packages{$rpm});
    }
    print $fh "    </packagelist>\n";
    print $fh "</group>\n";
    close($fh);
}

print "At the end:      ".scalar (keys %packages)."\t (should be 0 ;-)\n" if ($verbose);


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
my $outputpath="/tmp/xml";
my $packagedir="/work/cd/lib/put_built_to_cd/CDs/sles11-dvd-i386/CD1";

our $rootpath=".";
our $output_dir="";
our $content_file="";
our $descr_dir="";
our $verbose=1;
our @meta_packs=('smtp_daemon','banshee-player');
our %rpmtags=( Prq => 'required',
		       Prc => 'recommended',
			   Psg => 'suggested');
our %patterntags=( Obs => 'obsoletes',
				   Fre => 'freshens',
				   Req => 'required',
				   Rec => 'recommended',
				   Prv => 'provides',
				   Sug => 'suggested');
my %unknown_groups=( baselibs_x86_64 => '32bit',
                     baselibs_ia64   => 'x86',
                     baselibs_s390x  => '32bit',
					 baselibs_ppc64  => '64bit');
our %patterns_to_check;
our $pattern_files;
our $used_pattern_files;
our $search_packages_file=0;

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


sub writePatternRelationship {
	my $tag=shift; 
}

sub writeData {
	my $fh=shift;
	my $key=shift || 'package';
	my $value=shift;
	if ($key eq "package"){
#		print $fh "            <package xmlns=\"http://linux.duke.edu/metadata/common\" type=\"rpm\">\n";
#		print $fh "                <name>$value</name>\n";
#		print $fh "            </package>\n";
		print $fh "            <package name=\"$value\" />\n";
	}
}

# get the current packages on the media
opendir(P,$packagedir) || die "Could not open $packagedir : $!\n";
my %packages=grep { ! /^\./  } readdir(P);
closedir(P);

$rootpath="/mounts/dist/install/SLP/SLES-11-LATEST/i386/DVD1";
$content_file="$rootpath/content";
$descr_dir="$rootpath/suse/setup/descr";

# get the current pattern files
$pattern_files=getFiles($descr_dir,'.pat');
$pattern_files=getFiles($descr_dir,'.pat.gz') unless ( $pattern_files ne "0" );

if ( $verbose ){
    print "INFO:    CD-Path           = ".$rootpath."\n";
    print "INFO:    content file      = ".$content_file."\n";
    print "INFO:    descr directory   = ".$descr_dir."\n";
    print "INFO:    pattern files     = ";
    foreach (@$pattern_files){
        print "$_ ";
    }
    print "\n";
}

print "Vorher:        ".scalar (keys %packages)."\t Pakete\n" if ($verbose);
print "Vorher:        ".scalar (@$pattern_files)."\t Pattern\n" if ($verbose);
if ( "$pattern_files" ne "0" ){
    for my $patfile (@$pattern_files){
        my $pattern = ParsePatternFile("$descr_dir/$patfile");
		# FIXME: handle first whitespace better
		my ($dummy,$pattern_name,$pattern_version,$pattern_release,$pattern_arch) = split(/ /,$pattern->{'Pat'},5);
		my $fh = OpenFileWrite( "$outputpath/$pattern_name.xml");
		print $fh "<group name=\"$pattern_name\" version=\"$pattern_version\" release=\"$pattern_release\"\n";
		print $fh "       pattern:ordernumber=\"".$pattern->{'Ord'}."\"\n";
		print $fh "       pattern:category=\"".$pattern->{'Cat'}."\"\n";
		print $fh "       pattern:icon=\"".$pattern->{'Ico'}."\"\n" if (defined($pattern->{'Ico'}));
		print $fh "       pattern:summary=\"".$pattern->{'Sum'}."\"\n";
		print $fh "       pattern:description=\"".join('\n',$pattern->{'Des'})."\"\n";
		print $fh "       pattern:visible=\"".$pattern->{'Vis'}."\"\n";
		print $fh ">\n";
		for my $patkey (keys %patterntags){
			if (defined($pattern->{$patkey})){
				foreach my $patname (split(/\n/,$pattern->{$patkey})){
					print $fh "    <pattern name=\"$patname\" relationship=\"$patterntags{$patkey}\" />\n";
				}
			}
		}
        for my $key (keys %rpmtags){
			if (defined($pattern->{$key})){
				print $fh "    <group relationship=\"$rpmtags{$key}\">\n";
				foreach my $rpm (split(/\n/,$pattern->{$key})){
					writeData($fh,'package',"$rpm");
					delete $packages{$rpm};
				}
				print $fh "    </group>\n";
			}
		}
		print $fh "</group>\n";
		close ( $fh );
	}
}

# jetzt zu den "unbekannten" RPMs...
print "Zwischenstand: ".scalar (keys %packages)."\t (Nun folgen Baselibs)\n" if ($verbose);

foreach my $name (keys %unknown_groups){
    my $fh = OpenFileWrite( "$outputpath/$name.xml");
	print $fh "<group name=\"$name\">\n";
	print $fh "    <group relationship=\"recommended\">\n";
    foreach my $rpm (keys %packages){
		if ( $rpm =~ /.*-$unknown_groups{$name}/ ){
			writeData($fh,'package',"$rpm");	
			delete($packages{$rpm});
		}
	}	
	print $fh "    </group>\n";
	print $fh "</group>\n";
	close($fh);
}

print "Übrig:         ".scalar (keys %packages)."\t (Pakete ohne Zuordnung: Rest)\n" if ($verbose);

foreach my $name ('DVD-REST'){
    my $fh = OpenFileWrite( "$outputpath/$name.xml");
    print $fh "<group name=\"$name\">\n";
    print $fh "    <group relationship=\"suggested\">\n";
    foreach my $rpm (keys %packages){
        writeData($fh,'package',"$rpm");
    	delete($packages{$rpm});
    }
    print $fh "    </group>\n";
    print $fh "</group>\n";
    close($fh);
}

print "Zum Schluss:   ".scalar (keys %packages)."\t (sollte 0 sein ;-)\n" if ($verbose);

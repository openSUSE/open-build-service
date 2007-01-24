#
# Copyright (c) 2006, 2007 Novell Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
################################################################
#
# BSRPMQ.pm -- a simple query API for RPM-files. 
#
# ........... mls       all basic query functions,
# 2004-11-24, jw	renamed from RPM.pm to RPMQ.pm to avoid name-clash with cpan modules.
#			added %STAG, the following methods now accept numeric AND symbolic tags:
#			%ref = RPMQ::rpmq_many($file, @tags);
#			@val = RPMQ::rpmq($filename, $tag);
# 2004-11-25, mls       add support for signature header queries

package BSRPMQ;

my %STAG = (
        "HEADERIMAGE"	   => 61,
        "HEADERSIGNATURES" => 62,
        "HEADERIMMUTABLE"  => 63,
        "HEADERREGIONS"    => 64,
        "HEADERI18NTABLE"  => 100,
        "SIGSIZE"          => 256+1,
	"SIGLEMD5_1"	   => 256+2,	# /*!< internal - obsolete */
        "SIGPGP"	   => 256+3,
        "SIGLEMD5_2"	   => 256+4,	# /*!< internal - obsolete */
        "SIGMD5" 	   => 256+5,
        "SIGGPG" 	   => 256+6,
        "SIGPGP5"	   => 256+7,	# /*!< internal - obsolete */
        "BADSHA1_1"	   => 256+8,
        "BADSHA1_2"	   => 256+9,
        "PUBKEYS" 	   => 256+10,
        "DSAHEADER" 	   => 256+11,
        "RSAHEADER" 	   => 256+12,
        "SHA1HEADER" 	   => 256+13,

	"SIGTAG_SIZE"      => 1000, 	# /*!< internal Header+Payload size in bytes. */
	"SIGTAG_LEMD5_1"   => 1001, 	# /*!< internal Broken MD5, take 1 @deprecated legacy. */
	"SIGTAG_PGP"       => 1002, 	# /*!< internal PGP 2.6.3 signature. */
	"SIGTAG_LEMD5_2"   => 1003, 	# /*!< internal Broken MD5, take 2 @deprecated legacy. */
	"SIGTAG_MD5"       => 1004, 	# /*!< internal MD5 signature. */
	"SIGTAG_GPG"       => 1005, 	# /*!< internal GnuPG signature. */
	"SIGTAG_PGP5"      => 1006, 	# /*!< internal PGP5 signature @deprecated legacy. */
	"SIGTAG_PAYLOADSIZE" => 1007,	# /*!< internal uncompressed payload size in bytes. */
	"SIGTAG_BADSHA1_1" => 256+8,    # /*!< internal Broken SHA1, take 1. */
	"SIGTAG_BADSHA1_2" => 256+9,    # /*!< internal Broken SHA1, take 2. */
	"SIGTAG_SHA1"      => 256+13,   # /*!< internal sha1 header digest. */
	"SIGTAG_DSA"       => 256+11,   # /*!< internal DSA header signature. */
	"SIGTAG_RSA"       => 256+12,   # /*!< internal RSA header signature. */


        "NAME"		=> 1000,
        "VERSION"	=> 1001,
        "RELEASE"	=> 1002,
        "EPOCH"		=> 1003,
        "SERIAL"	=> 1003,
        "SUMMARY"	=> 1004,
        "DESCRIPTION"	=> 1005,
        "BUILDTIME"	=> 1006,
        "BUILDHOST"	=> 1007,
        "INSTALLTIME"	=> 1008,
        "SIZE"		=> 1009,
        "DISTRIBUTION"	=> 1010,
        "VENDOR"	=> 1011,
        "GIF"		=> 1012,
        "XPM"		=> 1013,
        "LICENSE"	=> 1014,
        "COPYRIGHT"	=> 1014,
        "PACKAGER"	=> 1015,
        "GROUP"		=> 1016,
        "SOURCE"	=> 1018,
        "PATCH"		=> 1019,
        "URL"		=> 1020,
        "OS"		=> 1021,
        "ARCH"		=> 1022,
        "PREIN"		=> 1023,
        "POSTIN"	=> 1024,
        "PREUN"		=> 1025,
        "POSTUN"	=> 1026,
        "OLDFILENAMES"	=> 1027,
        "FILESIZES"	=> 1028,
        "FILESTATES"	=> 1029,
        "FILEMODES"	=> 1030,
        "FILERDEVS"	=> 1033,
        "FILEMTIMES"	=> 1034,
        "FILEMD5S"	=> 1035,
        "FILELINKTOS"	=> 1036,
        "FILEFLAGS"	=> 1037,
        "FILEUSERNAME"	=> 1039,
        "FILEGROUPNAME"	=> 1040,
        "ICON"		=> 1043,
        "SOURCERPM"	=> 1044,
        "FILEVERIFYFLAGS"	=> 1045,
        "ARCHIVESIZE"	=> 1046,
        "PROVIDENAME"	=> 1047,
        "PROVIDES"	=> 1047,
        "REQUIREFLAGS"	=> 1048,
        "REQUIRENAME"	=> 1049,
        "REQUIREVERSION"	=> 1050,
        "NOSOURCE"	=> 1051,
        "NOPATCH"	=> 1052,
        "CONFLICTFLAGS"	=> 1053,
        "CONFLICTNAME"	=> 1054,
        "CONFLICTVERSION"	=> 1055,
        "EXCLUDEARCH"	=> 1059,
        "EXCLUDEOS"	=> 1060,
        "EXCLUSIVEARCH"	=> 1061,
        "EXCLUSIVEOS"	=> 1062,
        "RPMVERSION"	=> 1064,
        "TRIGGERSCRIPTS"	=> 1065,
        "TRIGGERNAME"	=> 1066,
        "TRIGGERVERSION"	=> 1067,
        "TRIGGERFLAGS"	=> 1068,
        "TRIGGERINDEX"	=> 1069,
        "VERIFYSCRIPT"	=> 1079,
        "CHANGELOGTIME"	=> 1080,
        "CHANGELOGNAME"	=> 1081,
        "CHANGELOGTEXT"	=> 1082,
        "PREINPROG"	=> 1085,
        "POSTINPROG"	=> 1086,
        "PREUNPROG"	=> 1087,
        "POSTUNPROG"	=> 1088,
        "BUILDARCHS"	=> 1089,
        "OBSOLETENAME"	=> 1090,
        "OBSOLETES"	=> 1090,
        "VERIFYSCRIPTPROG"	=> 1091,
        "TRIGGERSCRIPTPROG"	=> 1092,
        "COOKIE"	=> 1094,
        "FILEDEVICES"	=> 1095,
        "FILEINODES"	=> 1096,
        "FILELANGS"	=> 1097,
        "PREFIXES"	=> 1098,
        "INSTPREFIXES"	=> 1099,
        "SOURCEPACKAGE"	=> 1106,
        "PROVIDEFLAGS"	=> 1112,
        "PROVIDEVERSION"	=> 1113,
        "OBSOLETEFLAGS"	=> 1114,
        "OBSOLETEVERSION"	=> 1115,
        "DIRINDEXES"	=> 1116,
        "BASENAMES"	=> 1117,
        "DIRNAMES"	=> 1118,
        "OPTFLAGS"	=> 1122,
        "DISTURL"	=> 1123,
        "PAYLOADFORMAT"	=> 1124,
        "PAYLOADCOMPRESSOR"	=> 1125,
        "PAYLOADFLAGS"	=> 1126,
        "INSTALLCOLOR"	=> 1127,
        "INSTALLTID"	=> 1128,
        "REMOVETID"	=> 1129,
        "RHNPLATFORM"	=> 1131,
        "PLATFORM"	=> 1132,
        "PATCHESNAME"	=> 1133,
        "PATCHESFLAGS"	=> 1134,
        "PATCHESVERSION"	=> 1135,
        "CACHECTIME"	=> 1136,
        "CACHEPKGPATH"	=> 1137,
        "CACHEPKGSIZE"	=> 1138,
        "CACHEPKGMTIME"	=> 1139,
        "FILECOLORS"	=> 1140,
        "FILECLASS"	=> 1141,
        "CLASSDICT"	=> 1142,
        "FILEDEPENDSX"	=> 1143,
        "FILEDEPENDSN"	=> 1144,
        "DEPENDSDICT"	=> 1145,
        "SOURCEPKGID"	=> 1146,

	"SUGGESTSNAME"	=> 1156,
	"SUGGESTSVERSION"	=> 1157,
	"SUGGESTSFLAGS"		=> 1158,

	"ENHANCESNAME"	=> 1159,
	"ENHANCESVERSION"	=> 1160,
	"ENHANCESFLAGS"		=> 1161,
);

sub RPMSENSE_MISSINGOK () { 0x80000 }
sub RPMSENSE_STRONG    () { 0x8000000 }

sub rpmpq {
  my $rpm = shift;
  local *RPM;

  return undef unless open(RPM, "< $rpm");
  my $head;
  if (sysread(RPM, $head, 75) < 11) {
    close RPM;
    return undef;
  }
  close RPM;
  return unpack('@10Z65', $head);
}

sub rpmq {
  my $rpm = shift;
  my $stag = shift;

  my %ret = rpmq_many($rpm, $stag);
  return @{$ret{$stag} || [undef]};
}

# do not mix numeric tags with symbolic tags.
# special symbolic tag 'FILENAME' exists.
sub rpmq_many {
  my $rpm = shift;
  my @stags = @_;

  my @sigtags = grep {/^SIGTAG_/} @stags;
  @stags = grep {!/^SIGTAG_/} @stags;
  my $dosigs = @sigtags && !@stags;
  @stags = @sigtags if $dosigs;

  my $need_filenames = grep { $_ eq 'FILENAMES' } @stags;
  push @stags, 'BASENAMES', 'DIRNAMES', 'DIRINDEXES', 'OLDFILENAMES' if $need_filenames;
  @stags = grep { $_ ne 'FILENAMES' } @stags if $need_filenames;
  my %stags = map {0+($STAG{$_} or $_) => $_} @stags;

  my ($magic, $sigtype, $headmagic, $cnt, $cntdata, $lead, $head, $index, $data, $tag, $type, $offset, $count);

  local *RPM;
  if (ref($rpm) eq 'ARRAY') {
    ($headmagic, $cnt, $cntdata) = unpack('N@8NN', $rpm->[0]);
    if ($headmagic != 0x8eade801) {
      warn("Bad rpm\n");
      return ();
    }
    if (length($rpm->[0]) < 16 + $cnt * 16 + $cntdata) {
      warn("Bad rpm\n");
      return ();
    }
    $index = substr($rpm->[0], 16, $cnt * 16);
    $data = substr($rpm->[0], 16 + $cnt * 16, $cntdata);
  } else {
    if (ref($rpm) eq 'GLOB') {
      *RPM = $rpm;
    } elsif (!open(RPM, "<$rpm")) {
      warn("$rpm: $!\n");
      return ();
    }
    if (read(RPM, $lead, 96) != 96) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
    ($magic, $sigtype) = unpack('N@78n', $lead);
    if ($magic != 0xedabeedb || $sigtype != 5) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
    if (read(RPM, $head, 16) != 16) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
    ($headmagic, $cnt, $cntdata) = unpack('N@8NN', $head);
    if ($headmagic != 0x8eade801) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
    if (read(RPM, $index, $cnt * 16) != $cnt * 16) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
    $cntdata = ($cntdata + 7) & ~7;
    if (read(RPM, $data, $cntdata) != $cntdata) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
  }

  my %res = ();

  if (@sigtags && !$dosigs) {
    %res = &rpmq_many(["$head$index$data"], @sigtags);
  }
  if (ref($rpm) eq 'ARRAY' && !$dosigs && @stags && @$rpm > 1) {
    my %res2 = &rpmq_many([ $rpm->[1] ], @stags);
    %res = (%res, %res2);
    return %res;
  }

  if (ref($rpm) ne 'ARRAY' && !$dosigs && @stags) {
    if (read(RPM, $head, 16) != 16) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
    ($headmagic, $cnt, $cntdata) = unpack('N@8NN', $head);
    if ($headmagic != 0x8eade801) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
    if (read(RPM, $index, $cnt * 16) != $cnt * 16) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
    if (read(RPM, $data, $cntdata) != $cntdata) {
      warn("Bad rpm $rpm\n");
      close RPM;
      return ();
    }
  }
  close RPM if ref($rpm) ne 'ARRAY';

  return %res unless @stags;	# nothing to do

  while($cnt-- > 0) {
    ($tag, $type, $offset, $count, $index) = unpack('N4a*', $index);
    $tag = 0+$tag;
    if ($stags{$tag}) {
      eval {
        my $otag = $stags{$tag};
	if ($type == 0) {
	  $res{$otag} = [ '' ];
	} elsif ($type == 1) {
	  $res{$otag} = [ unpack("\@${offset}c$count", $data) ];
	} elsif ($type == 2) {
	  $res{$otag} = [ unpack("\@${offset}c$count", $data) ];
	} elsif ($type == 3) {
	  $res{$otag} = [ unpack("\@${offset}n$count", $data) ];
	} elsif ($type == 4) {
	  $res{$otag} = [ unpack("\@${offset}N$count", $data) ];
	} elsif ($type == 5) {
	  $res{$otag} = [ undef ];
	} elsif ($type == 6) {
	  $res{$otag} = [ unpack("\@${offset}Z*", $data) ];
	} elsif ($type == 7) {
	  $res{$otag} = [ unpack("\@${offset}a$count", $data) ];
	} elsif ($type == 8 || $type == 9) {
	  my $d = unpack("\@${offset}a*", $data);
	  my @res = split("\0", $d, $count + 1);
	  $res{$otag} = [ splice @res, 0, $count ];
	} else {
	  $res{$otag} = [ undef ];
	}
      };
      if ($@) {
	warn("Bad rpm $rpm: $@\n");
        return ();
      }
    }
  }
  
  if ($need_filenames) {
    if ($res{'OLDFILENAMES'}) {
      $res{'FILENAMES'} = [ @{$res{'OLDFILENAMES'}} ];
    } else {
      my $i = 0;
      $res{'FILENAMES'} = [ map {"$res{'DIRNAMES'}->[$res{'DIRINDEXES'}->[$i++]]$_"} @{$res{'BASENAMES'}} ];
    }
  }
  return %res;
}

sub rpmq_add_flagsvers {
  my $res = shift;
  my $name = shift;
  my $flags = shift;
  my $vers = shift;
  my $addx = shift;

  return unless $res;
  my @flags = @{$res->{$flags} || []};
  my @vers = @{$res->{$vers} || []};
  for (@{$res->{$name}}) {
    $_ = "?$_" if $addx && $flags[0] & 0x80000;
    $_ = "#$_" if $addx && $flags[0] & 0x8000000;
    if (@flags && ($flags[0] & 0xe) && @vers) {
      $_ .= ' ';
      $_ .= '<' if $flags[0] & 2;
      $_ .= '>' if $flags[0] & 4;
      $_ .= '=' if $flags[0] & 8;
      $_ .= " $vers[0]";
    }
    shift @flags;
    shift @vers;
  }
}

sub rpmq_provreq {
  my $rpm = shift;

  my @prov = ();
  my @req = ();
  my $r;
  my %res = rpmq_many($rpm, 1047, 1049, 1048, 1050, 1112, 1113);
  rpmq_add_flagsvers(\%res, 1047, 1112, 1113);
  rpmq_add_flagsvers(\%res, 1049, 1048, 1050);
  return $res{1047}, $res{1049};
}

1;

__END__

=head1 NAME

RPMQ - a simple query-API for RPM-files

=head1 SYNOPSIS

	use RPMQ;

        $rpmname = RPMQ::rpmpq($rpmfile);		# returns "name-version-rel"
	%r = RPMQ::rpmq_many($rpmfile, @tags);		# returns hash of array-refs
	@v = RPMQ::rpmq($rpmfile, $tag);		# returns array-ref

	($prov, $req) = RPMQ::rpmq_provreq($rpmfile);	# returns 2 array-refs

        %r = RPMQ::rpmq_many($rpmfile, qw{REQUIRENAME REQUIREFLAGS REQUIREVERSION});
  	RPMQ::rpmq_add_flagsvers(\%r,  qw{REQUIRENAME REQUIREFLAGS REQUIREVERSION});
	print join "\n", @{$r{REQUIRENAME}}, "";
	
  
=head1 DESCRIPTION

Common tag names are: 
        "NAME"		=> 1000,
        "VERSION"	=> 1001,
        "RELEASE"	=> 1002,
        "SUMMARY"	=> 1004,
        "DESCRIPTION"	=> 1005,
        "BUILDTIME"	=> 1006,
        "BUILDHOST"	=> 1007,
        "SIZE"		=> 1009,
        "COPYRIGHT"	=> 1014,
        "ARCH"		=> 1022,
        "SOURCERPM"	=> 1044,
        "DISTURL"	=> 1123,

The additional tag 'FILENAMES' is also understood by rpmq_many() and
rpmq(). It returns a list of full filenames (like OLDFILENAMES did in
rpm3) constructed from DIRNAMES, DIRINDEXES and BASENAMES.

=cut

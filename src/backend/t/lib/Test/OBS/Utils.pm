# Copyright (c) 2016 SUSE LLC
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
package Test::OBS::Utils;

use strict;
use warnings;
use File::Find;

sub prepare_compressed_files {
  my @dirs = @_;
  my @f2d;
  find(
	sub { 
	  push @f2d, $File::Find::name if ( $File::Find::name =~ /\.xz$/ ) 
	}, 
	@dirs
  );

  for my $f (splice @f2d) {
	system("xz","--decompress","-k",$f);
	$f =~ s/\.xz$//;
	push @f2d , $f;
  } 

  return @f2d;
}

sub transparent_read_xz {
  my ($file,$subref,@subargs) = @_;
  my $f2d;
  my $ret;
  if ( -e "$file.xz" ) {
	system("xz","--decompress","-k","$file.xz");
	$f2d = $file;
  }


  $ret = $subref->($file,@subargs);

  unlink $f2d if $f2d;

  return $ret;
}

1; 


#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
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
# Build service specific extensions to the build package
#

package BSBuild;

use strict;

sub gen_meta {
  my ($myself, $subp, @deps) = @_;

  my %depseen;
  my @subp = @{$subp || []};
  my $subpackre = '';
  for (@subp) {
    $subpackre .= "|/\Q$_\E/";
  }
  if ($subpackre) {
    $subpackre = substr($subpackre, 1);
    $subpackre = qr/$subpackre/;
  }
  my (%helper1, %helper2, %helper3, %cycle);
  for (@deps) {
    $helper1{$_} = tr/\///;     # count '/'
    /^([^ ]+  )((?:.*\/)?([^\/]*))$/ or die("bad dependency line: $_\n");
    $helper2{$_} = $2;          # path
    $helper3{$_} = "$1$3";      # md5  lastpkg
    if ($subpackre && "/$2/" =~ /$subpackre/) {
      /  ([^\/]+)/ or die("bad dependency line: $_\n");
      $cycle{$1} = 1; # detected a cycle!
    }
  }
  if (%cycle) {
    my $cyclere = '';
    for (sort keys %cycle) {
      $cyclere .= "|\Q/$_/\E";
    }
    $cyclere = substr($cyclere, 1);
    $cyclere = qr/$cyclere/;
    # kill all deps that use a package that we see directly
    @deps = grep {"$_/" !~ /$cyclere/} @deps;
  }
  @deps = sort {$helper1{$a} <=> $helper1{$b} || $helper2{$a} cmp $helper2{$b} || $a cmp $b} @deps;
  my @meta;
  push @meta, $myself if defined($myself) && $myself ne '';
  for my $d (@deps) {
    next if $depseen{$helper3{$d}}; # skip if we already have this pkg with this md5
    next if $subpackre && "/$helper2{$d}/" =~ /$subpackre/;
    $depseen{$helper3{$d}} = 1;
    push @meta, $d;
  }
  return @meta;
}

1;

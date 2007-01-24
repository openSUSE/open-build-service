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

  my %depsseen = ();
  my @subp = @{$subp || []};
  my $subpackre = '';
  for (@subp) {
    $subpackre .= "|/\Q$_\E/";
  }
  if ($subpackre) {
    $subpackre = substr($subpackre, 1);
    $subpackre = qr/$subpackre/;
  }
#  $depsseen{$_} = 1 for @subp;
  my (%helper1, %helper2, %helper3, %bad);
  for (@deps) {
    $helper1{$_} = tr!/!/!;     # count '/'
    /^([^ ]+  )((?:.*\/)?)([^\/]*)$/ or die;
    $helper2{$_} = "$2$3";
    $helper3{$_} = "$1$3";
#    $helper2{$_} = $_;
#    $helper2{$_} =~ s/.*  //;
#    $direct{$helper2{$_}} = 1 if $helper1{$_} == 0;
#    $helper3{$_} = $_;
#    $helper3{$_} =~ s/  .*\//  /;
    if ("/$2$3/" =~ /$subpackre/) {
      /  ([^\/]+)/ or die;
      $bad{$1} = 1;
    }
  }
  @deps = sort {$helper1{$a} <=> $helper1{$b} || $helper2{$a} cmp $helper2{$b} || $a cmp $b} @deps;
  my @meta = ();
  push @meta, $myself if defined($myself) && $myself ne '';
  for my $d (@deps) {
    next if $depsseen{$helper3{$d}};
#    next if grep {$direct{$_}} splice(@{[split('/', $helper2{$d})]}, 1);
    next if $subpackre && "/$helper2{$d}/" =~ /$subpackre/;
    if (%bad && ($d =~ /\/([^\/]+)$/)) {
      next if $bad{$1};
    }
    $depsseen{$helper3{$d}} = 1;
    push @meta, $d;
  }
  return @meta;
}

1;

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

my $genmetaalgo = 0;

sub add_meta {
  my ($new_meta, $m, $bin, $packid) = @_;
  my $oldlen = @$new_meta;
  for (split("\n", ref($m) ? $m->[0] : $m)) {
    s/  /  $bin\//;
    push @$new_meta, $_;
  }
  if (@$new_meta != $oldlen) {
    if (defined($packid) && $new_meta->[$oldlen] =~  /\/\Q$packid\E$/) {
      # do not include our own build results
      splice(@$new_meta, $oldlen);
    } else {
      # fixup first line, it contains the package name and not the binary name
      $new_meta->[$oldlen] =~ s/  .*/  $bin/;
    }
  }
}

sub gen_meta {
  my ($subp, @deps) = @_;

  my @subp = @{$subp || []};
  my $subpackre = '';
  for (@subp) {
    $subpackre .= "|/\Q$_\E/";
  }
  if ($subpackre) {
    $subpackre = substr($subpackre, 1);
    $subpackre = qr/$subpackre/;
  }

  # setup helpers
  my (%helper1, %helper2, %helper3, %cycle);
  for (@deps) {
    $helper1{$_} = tr/\///;	# count '/'
    /^([^ ]+  )((?:.*\/)?([^\/]*))$/ or die("bad dependency line: $_\n");
    $helper2{$_} = $2;		# path
    $helper3{$_} = "$1$3";	# md5  lastpkg
    if ($subpackre && "/$2/" =~ /$subpackre/) {
      /  ([^\/]+)/ or die("bad dependency line: $_\n");
      $cycle{$1} = 1; # detected a cycle!
    }
  }

  # sort
  @deps = sort {$helper1{$a} <=> $helper1{$b} || $helper2{$a} cmp $helper2{$b} || $a cmp $b} @deps;

  undef $subpackre unless %cycle;	# speed things up a bit

  # ignore self-cycles
  if (%cycle) {
    delete $cycle{$_} for @subp;
  }
  # handle cycles
  my %cycdepseen;
  if (%cycle) {
    my $cyclere = '';
    $cyclere .= "|\Q/$_/\E" for sort keys %cycle;
    $cyclere = substr($cyclere, 1);
    $cyclere = qr/$cyclere/;
    if (!$genmetaalgo) {
      # kill all deps that use a package that we see directly
      @deps = grep {"$_/" !~ /$cyclere/} @deps;
    } else {
      for my $d (grep {"$_/" =~ /$cyclere/} @deps) {
        $cycdepseen{$helper3{$d}} ||= $helper1{$d};
      }
    }
  }

  # prune
  my %depseen;
  my @meta;
  for my $d (@deps) {
    next if $depseen{$helper3{$d}};	# skip if we already have this pkg with this md5
    next if $subpackre && "/$helper2{$d}/" =~ /$subpackre/;
    $depseen{$helper3{$d}} = 1;
    push @meta, $d;
  }
  # do extra cycle pruning
  if (%cycdepseen) {
    @meta = grep {!$cycdepseen{$helper3{$_}} || $helper1{$_} < $cycdepseen{$helper3{$_}}} @meta;
  }
  return @meta;
}

sub setgenmetaalgo {
  my ($algo) = @_;
  $algo = 1 if $algo < 0;
  die("BSBuild::setgenmetaalgo: unsupported algo $algo\n") if $algo > 1;
  $genmetaalgo = $algo;
  return $algo;
}

1;

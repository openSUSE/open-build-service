# Copyright (c) 2021 SUSE LLC
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

package BSSrcServer::Modulemd;

use strict;
use warnings;

eval { require YAML::XS; $YAML::XS::LoadBlessed = 0; };
*YAML::XS::Load = sub {die("YAML::XS is not available\n")} unless defined &YAML::XS::Load;

sub assert_str {
  my ($str, $el) = @_;
  die("missing $el\n") unless defined $str;
  die("$el is not a string\n") if ref($str);
  return $str;
}

sub parse_deps {
  my ($d, $el) = @_;
  return [] unless defined $d;
  die("$el dependencies must be hash\n") unless ref($d) eq 'HASH';
  my %deps;
  for my $n (sort keys %$d) {
    my $v = $d->{$n};
    $v = [ $v ] if ref($v) eq '';
    die("$el dependency stream must be array\n") unless ref($v) eq 'ARRAY';
    my @v = @$v;
    if (!@v) {
      $deps{$n} = 1;
    } elsif ($v[0] =~ /^-/) {
      die("$el: mixed dependencies\n") if grep {!s/^-//} @v;
      $deps{"-$n:".join(':', @v)} = 1;
    } else {
      $deps{"$n:".join(':', @v)} = 1 for @v;
    }
  }
  return [ sort keys %deps ];
}

sub read_modulemds {
  my ($yaml) = @_;
  my @mds = YAML::XS::Load($yaml);
  die("no modulemd data\n") unless @mds;
  for my $md (@mds) {
    die("bad modulemd data\n") unless $md && ref($md) eq 'HASH' && $md->{'data'} && $md->{'document'};
    die("unknown modulemd document\n") if $md->{'document'} ne 'modulemd' && $md->{'document'} ne 'modulemd' && $md->{'document'} ne 'modulemd-defaults';
    die("bad modulemd version \n") if $md->{'document'} eq 'modulemd' && $md->{'version'} != 2;
    die("bad modulemd version \n") if $md->{'document'} eq 'modulemd-defaults' && $md->{'version'} != 1;
  }
  return \@mds;
}

sub parse_modulemd {
  my ($yaml) = @_;
  my $mds = read_modulemds($yaml);
  my @mds_modulemd = grep {$_->{'document'} eq 'modulemd'} @$mds;
  die("need exactly one modulemd document\n") unless @mds_modulemd == 1;
  my $d = $mds_modulemd[0];
  $d = $d->{'data'};
  my $r = {};
  $r->{'name'} = assert_str($d->{'name'}, 'name');
  $r->{'stream'} = assert_str($d->{'stream'}, 'stream');
  $r->{'version'} = assert_str($d->{'version'}, 'version') if defined $d->{'version'};
  $r->{'context'} = assert_str($d->{'context'}, 'context') if defined $d->{'context'};
  $r->{'distindex'} = assert_str($d->{'distindex'}, 'distindex') if defined $d->{'distindex'};
  $d->{'dependencies'} = [ $d->{'dependencies'} ] if ref($d->{'dependencies'}) eq 'HASH';
  for my $dd (@{$d->{'dependencies'} || []}) {
    die("dependency block must be hash\n") unless ref($dd) eq 'HASH';
    my $rd = {};
    $rd->{'buildrequires'} = parse_deps($dd->{'buildrequires'}) if $dd->{'buildrequires'};
    $rd->{'requires'} = parse_deps($dd->{'requires'}) if $dd->{'requires'};
    push @{$r->{'dependencies'}}, $rd if %$rd;
  }
  my $buildopts = $d->{'buildopts'};
  if ($buildopts && ref($buildopts) eq 'HASH') {
    if ($buildopts->{'rpms'} && ref($buildopts->{'rpms'}) eq 'HASH') {
      my $macros = $buildopts->{'rpms'}->{'macros'};
      if ($macros && ref($macros) eq '') {
        $macros =~ s/\n?\z/\n/s;
        $r->{'macros'} = $macros;
      }
    }
  }
  return $r;
}

sub tostream {
  my ($md, $modules, $modularitylabel, $modularityplatform) = @_;
  die("no md version\n") unless $md->{'version'};
  if ($md->{'version'} == 1) {
    $md->{'version'} = 2;
    if ($md->{'data'} && ref($md->{'data'}->{'dependencies'}) eq 'HASH') {
      $md->{'data'}->{'dependencies'} = [ $md->{'data'}->{'dependencies'} ];
    }
  }
  if ($md->{'version'} != 2) {
    die("unsupported md version\n");
  }
  $md = $md->{'data'};
  my ($versionprefix, $distprefix, @distprovides) = split(':', $modularityplatform);
  my %distprovides = map {$_ => $_} @distprovides;
  for (@distprovides) {
    $distprovides{"$1-*"} = $_ if /^(.*)-/;
  }
  my $newdeps;
  for my $dd (@{$md->{'dependencies'} || []}) {
    die("dependency block must be hash\n") unless ref($dd) eq 'HASH';
    my $buildrequires = parse_deps($dd->{'buildrequires'});
    my $requires = parse_deps($dd->{'requires'});
    my $good = 1;
    for my $br (@$buildrequires) {
      my ($n, @v) = split(':', $br);
      if ($n =~ s/^-//) {
	$good = 0 if grep {$distprovides{"$n-$_"}} @v; 
      } else {
	$good = 0 if $distprovides{"$n-*"} && !grep {$distprovides{"$n-$_"}} @v; 
      }
      last unless $good;
    }
    next unless $good;

    # add modules data to provides
    for (@{$modules || []}) {
      $distprovides{$_} = $_;
      $distprovides{"$1-*"} = $_ if /^(.*)-/;
    }

    my %brmap;
    for my $br (@$buildrequires) {
      my ($n, @v) = split(':', $br);
      my $newbr;
      if ($n =~ s/^-//) {
	$newbr = $distprovides{"$n-*"};
	die("module $n is not available\n") unless $newbr;
      } else {
        if (@v) {
	  @v = map {"$n-$_"} grep {$distprovides{"$n-$_"}} @v;
	} else {
	  @v = [ $distprovides{"$n-*"} ];
	}
        $newbr = $v[0];
	die("module $n is not available\n") unless $newbr;
      }
      $newbr =~ s/^\Q$n\E-/$n:/;
      $brmap{$br} = $newbr;
      $br = $newbr;
    }
    for my $r (@$requires) {
      $r = $brmap{$r} if defined $brmap{$r};
    }
    $newdeps = {};
    for (@$requires) {
      my ($n, @v) = split(':', $_);
      $newdeps->{'requires'}->{$n} = \@v;
    }
    for (@$buildrequires) {
      my ($n, @v) = split(':', $_);
      $newdeps->{'buildrequires'}->{$n} = \@v;
    }
    last;
  }
  die("could not select dependency block\n") unless $newdeps;
  $md->{'dependencies'} = [ $newdeps ];
  delete $md->{'distindex'};
  my @l = split(':', $modularitylabel);
  $md->{'name'} = $l[0];
  $md->{'stream'} = $l[1];
  $md->{'version'} = $l[2];
  $md->{'context'} = $l[3];
  $md->{'xmd'} = {};
}

1;

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

package BSSched::Modulemd;

use strict;
use warnings;

use JSON::XS ();
use Digest::SHA ();

sub json_sha1 {
  my ($d) = @_; 
  my $json = JSON::XS->new->utf8->canonical->space_after->encode($d);
  return Digest::SHA::sha1_hex($json);
}

sub calc_modularitylabel {
  my ($bconf, $modulemd, $deps) = @_;
  my $timestamp = $modulemd->{'timestamp'};
  my $pfdata = $bconf->{'buildflags:modulemdplatform'};
  return undef unless $pfdata;
  my ($versionprefix, $distprefix) = split(':', $pfdata, 2);
  return undef unless defined $distprefix;
  my %buildrequires;
  for (@{$bconf->{'modules'} || []}) {
    return undef unless /^(.+)-([^-]+)$/s;
    $buildrequires{$1} = $2;
  }
  my $buildctx = json_sha1(\%buildrequires);
  my %requires;
  for my $dep (@{$deps || []}) {
    my ($n, @v) = split(':', $dep);
    my %v = map {$_ => 1} @v;
    $requires{$n} = [ sort keys %v ];
  }
  my $depctx = json_sha1(\%requires);
  my $mdctx = substr(Digest::SHA::sha1_hex("$buildctx:$depctx"), 0, 8);
  $mdctx = $modulemd->{'context'} if $modulemd->{'context'};
  my @gm = gmtime($timestamp);
  my $mdversion = $modulemd->{'version'} || sprintf("%04d%02d%02d%02d%02d%02d", $gm[5] + 1900, $gm[4] + 1, @gm[3,2,1,0]);;
  if (length($mdversion) > 14) {
    return undef unless $versionprefix eq '' || $mdversion =~ /^\Q$versionprefix\E/;
  } else {
    $mdversion = "$versionprefix$mdversion";
  }
  return "$modulemd->{'name'}:$modulemd->{'stream'}:$mdversion:$mdctx";
}

sub select_dependency {
  my ($bconf, $modulemd) = @_;
  my $pfdata = $bconf->{'buildflags:modulemdplatform'};
  return undef unless $pfdata;
  my ($versionprefix, $distprefix, @distprovides) = split(':', $pfdata);
  my %distprovides = map {$_ => 1} @distprovides;
  for (@distprovides) {
    $distprovides{"$1-*"} = 1 if /^(.*)-/;
  }
  return {} unless $modulemd->{'dependencies'};
  for my $dependency (@{$modulemd->{'dependencies'}}) {
    my $good = 1;
    for my $br (@{$dependency->{'buildrequires'} || []}) {
      my ($n, @v) = split(':', $br);
      if ($n =~ s/^-//) {
        $good = 0 if grep {$distprovides{"$n-$_"}}  @v;
      } else {
        $good = 0 if $distprovides{"$n-*"} && !grep {$distprovides{"$n-$_"}} @v;
      }
      last unless $good;
    }
    return $dependency if $good;
  }
  return undef;
}

sub check_conflicting_modules {
  my ($bconf) = @_;
  return undef unless @{$bconf->{'modules'} || []} > 1;
  my %modules = map {$_ => 1} @{$bconf->{'modules'} || []};
  my %streams;
  for (sort keys %modules) {
    push @{$streams{$1}}, $_ if /^(.*)-/;
  }
  my @errors;
  for (sort keys %streams) {
    push @errors, "conflicting module streams for $_: ".join(" | ", @{$streams{$_}}) if @{$streams{$_}} > 1;
  }
  return @errors ? \@errors : undef;
}

sub extend_modules {
  my ($bconf, $modulemd, $buildrequires) = @_;
  my $pfdata = $bconf->{'buildflags:modulemdplatform'};
  return [ "buildflags:modulemdplatform is not set" ] unless $pfdata;
  my ($versionprefix, $distprefix, @distprovides) = split(':', $pfdata);
  # automatically enable the module we're building
  if (!$bconf->{'expandflags:noautoenablemodule'}) {
    my $ourmodule = "$modulemd->{'name'}-$modulemd->{'stream'}";
    if (!grep {$_ eq $ourmodule} @{$bconf->{'modules'} || []}) {
      $bconf->{'modules'} = [ sort (@{$bconf->{'modules'} || []}, $ourmodule) ];
    }
  }
  my %distprovides = map {$_ => 1} @distprovides;
  my @errors = @{ check_conflicting_modules($bconf) || [] };
  my @have = (@{$bconf->{'modules'} || []}, @distprovides);
  my %have = map {$_ => 1} @have;
  for (@have) {
    $have{"$1-*"} = $_ if /^(.*)-/;
  }
  my @needed;
  for my $br (@{$buildrequires || []}) {
    my ($n, @v) = split(':', $br);
    next if $n =~ /^-/;
    next if @v && grep {$have{"$n-$_"}} @v;
    if ($have{"$n-*"}) {
      next if !@v;		# just need any version
      push @errors, "modulemd requires ".join(" | ", map {"$n-$_"} @v)." instead of ".$have{"$n-*"};
      next;
    }
    if (!@v) {
      push @errors, "modulemd requires any stream version of $n";
    } elsif (@v == 1) {
      push @needed, "$n-$v[0]";
    } else {
      push @errors, "modulemd requires ".join(" | ", map {"$n-$_"} @v);
    }
  }
  return \@errors if @errors;
  if (@needed) {
    my %modules = map {$_ => 1} @{$bconf->{'modules'} || []}, @needed;
    $bconf->{'modules'} = [ sort keys %modules ];
  }
  return undef;
}

sub calc_dist {
  my ($bconf, $ml, $distindex) = @_;
  my $pfdata = $bconf->{'buildflags:modulemdplatform'};
  return undef unless $pfdata;
  my ($versionprefix, $distprefix) = split(':', $pfdata);
  return undef unless $distprefix;
  my $ml_x = $ml;
  $ml_x =~ s/:/./g;
  return "$distprefix+$distindex+".substr(Digest::SHA::sha1_hex($ml_x), 0, 8);
}

sub calc_macros {
  my ($bconf, $ml, $distindex, $extramacros) = @_;
  my @ml = split(':', $ml, 4);
  my $dist = calc_dist($bconf, $ml, $distindex);
  my $macros = '';
  $macros .= "%dist $dist\n" if defined $dist;
  $macros .= "%modularitylabel $ml\n";
  $macros .= "%_module_build 1\n";
  $macros .= "%_module_name $ml[0]\n";
  $macros .= "%_module_stream $ml[1]\n";
  $macros .= "%_module_version $ml[2]\n";
  $macros .= "%_module_context $ml[3]\n";
  $macros .= "$extramacros\n" if $extramacros;
  return $macros;
}

1;

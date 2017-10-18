#
# Copyright (c) 2017 SUSE LLC
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
# url <-> project/repo mapper
#

package BSUrlmapper;

use BSConfiguration;
use BSRPC;

my $extrepodir = "$BSConfig::bsdir/repos";

my $urlmapcache = {};

sub urlmapper {
  my ($url, $cache) = @_;
  $url =~ s/\/+$//;
  return undef if $url eq '';
  $cache ||= $urlmapcache;
  if (!exists $cache->{''}) {
    $cache->{''} = undef;
    for my $prp (sort keys %{$BSConfig::prp_ext_map || {}}) {
      my $u = $BSConfig::prp_ext_map->{$prp};
      $u =~ s/\/+$//;
      $cache->{$u} = $prp;
    }
  }
  my $prp = $cache->{$url};
  return $prp if $prp;
  if ($BSConfig::repodownload && $url =~ /^\Q$BSConfig::repodownload\E\/(.+\/.+)/) {
    my $path = $1;
    $path =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    my @p = split('/', $path); 
    while (@p > 1 && $p[0] =~ /:$/) {
      splice(@p, 0, 2, "$p[0]$p[1]");
    }    
    my $project = shift(@p);
    while (@p > 1 && $p[0] =~ /:$/) {
      splice(@p, 0, 2, "$p[0]$p[1]");
    }    
    my $repository = shift(@p);
    return "$project/$repository" if $project && $repository;
  }
  return undef;
}

sub map_to_extrep {
  my ($prp) = @_;

  my $prp_ext = $prp;
  $prp_ext =~ s/:/:\//g;
  my $extrep = "$extrepodir/$prp_ext";
  return $extrep unless $BSConfig::publishredirect;
  if ($BSConfig::publishedredirect_use_regex || $BSConfig::publishedredirect_use_regex) {
    for my $key (sort {$b cmp $a} keys %{$BSConfig::publishredirect}) {
      if ($prp =~ /^$key/) {
        $extrep = $BSConfig::publishredirect->{$key};
        last;
      }
    }
  } elsif (exists($BSConfig::publishredirect->{$prp})) {
    $extrep = $BSConfig::publishredirect->{$prp};
  }
  $extrep = $extrep->($prp, $prp_ext) if $extrep && ref($extrep) eq 'CODE';
  return $extrep;
}

sub get_extrep {
  my ($prp) = @_;
  my $extrep = map_to_extrep($prp);
  return defined($extrep) && ref($extrep) ? $extrep->[0] : $extrep;
}

sub get_downloadurl {
  my ($prp) = @_;
  # check ext_map
  if ($BSConfig::prp_ext_map && exists $BSConfig::prp_ext_map->{$prp}) {
    return $BSConfig::prp_ext_map->{$prp};
  }
  # check :publishredirect
  my $extrep = map_to_extrep($prp);
  $extrep = [ $extrep ] unless ref $extrep;
  return $extrep->[2] if $extrep->[2];
  # default to repodownload url
  return undef unless $BSConfig::repodownload;
  if ($extrep->[0] =~ /^\Q$BSConfig::bsdir\E\/repos\/(.*)$/) {
    my $url = "$BSConfig::repodownload/".BSRPC::urlencode($1).'/';
    $url =~ s!//$!/!;
    return $url;
  }
  my $prp_ext = $prp;
  $prp_ext =~ s/:/:\//g;
  return "$BSConfig::repodownload/".BSRPC::urlencode($prp_ext)."/";
}

sub get_path_downloadurl {
  my ($prp) = @_;
  my ($path, $url);
  # check ext_map
  if ($BSConfig::prp_ext_map && exists $BSConfig::prp_ext_map->{$prp}) {
    $url = $BSConfig::prp_ext_map->{$prp};
    return (undef, undef) unless defined $url;	# not published 
  }
  my $extrep = map_to_extrep($prp);
  $extrep = [ $extrep ] unless ref $extrep;
  $path = $extrep->[1];
  $url = $extrep->[2] if !defined($url);
  if ((!defined($path) || !defined($url)) && $extrep->[0] =~ /^\Q$BSConfig::bsdir\E\/repos\/(.*)$/) {
    $path = $1 if !defined $path;
    $url = "$BSConfig::repodownload/".BSRPC::urlencode($1) if $BSConfig::repodownload && !defined($url);
  }
  if (!defined($url) && $BSConfig::repodownload)  {
    my $prp_ext = $prp;
    $prp_ext =~ s/:/:\//g;
    $url = "$BSConfig::repodownload/".BSRPC::urlencode($prp_ext);
  }
  $url =~ s/\/?$/\// if defined $url;
  return ($path, $url);
}

1;

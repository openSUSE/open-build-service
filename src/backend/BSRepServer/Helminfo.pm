# Copyright (c) 2025 SUSE LLC
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

package BSRepServer::Helminfo;

use JSON::XS ();
use BSVerify;
use BSUtil;
use Digest::MD5 ();
use BSXML;

use strict;

=head1 NAME

BSRepServer::Helminfo

=head1 DESCRIPTION

 This library contains functions to handle the helminfo data returned
 from helm chart builds.

=cut

=head2  helminfo2nevra - convert helminfo data to name/epoch/version/release/arch

 input: $helminfo - helminfo data

 output: hash containing name/epoch/...

=cut

sub helminfo2nevra {
  my ($d) = @_;
  my $lnk = {};
  $lnk->{'name'} = "chart:$d->{'name'}";
  $lnk->{'version'} = defined($d->{'version'}) ? $d->{'version'} : '0';
  $lnk->{'release'} = defined($d->{'release'}) ? $d->{'release'} : '0';
  $lnk->{'arch'} = defined($d->{'arch'}) ? $d->{'arch'} : 'noarch';
  return $lnk;
}

=head2  helminfo2obsbinlnk - convert a helminfo file to an obsbinlnk

 input: $dir - directory of the built chart
        $helminfo - helminfo filename in $dir
        $packid - package name of the built chart

 output: obsbinlnk hash or undef

=cut

sub helminfo2obsbinlnk {
  my ($dir, $helminfo, $packid) = @_;
  my $d = readhelminfo($dir, $helminfo);
  return unless $d;
  my $lnk = helminfo2nevra($d);
  # need to have a source so that it goes into the :full tree
  $lnk->{'source'} = $lnk->{'name'};
  # add self-provides
  push @{$lnk->{'provides'}}, "$lnk->{'name'} = $lnk->{'version'}";
  for my $tag (@{$d->{tags}}) {
    push @{$lnk->{'provides'}}, "charts:$tag" unless "charts:$tag" eq $lnk->{'name'};
  }
  eval {
    BSVerify::verify_nevraquery($lnk);
  };
  return undef if $@;
  my $annotation = {};
  $annotation->{'repo'} = $d->{'repos'} if $d->{'repos'};
  $annotation->{'disturl'} = $d->{'disturl'} if $d->{'disturl'};

  local *F;
  return undef unless open(F, '<', "$dir/$d->{'chart'}");
  my $ctx = Digest::MD5->new;
  $ctx->addfile(*F);
  close F;
  $lnk->{'hdrmd5'} = $ctx->hexdigest();
  $lnk->{'path'} = "../$packid/$d->{'chart'}";
  return $lnk;
}

=head2  readhelminfo - read data from helminfo file and verify data

 input: $dir - directory of the built chart
        $helminfo - helminfo filename in $dir

 output: HashRef containing data from helminfo or undef in case of an error

=cut

sub readhelminfo {
  my ($dir, $helminfo) = @_;
  return undef unless -e "$dir/$helminfo";
  return undef unless (-s _) < 100000;
  my $m = readstr("$dir/$helminfo");
  my $d;
  eval { $d = JSON::XS::decode_json($m); };
  return undef unless $d && ref($d) eq 'HASH';
  my $tags = $d->{'tags'};
  $tags = [] unless $tags && ref($tags) eq 'ARRAY';
  for (@$tags) {
    $_ = undef unless defined($_) && ref($_) eq '';
  }
  @$tags = grep {defined($_)} @$tags;
  my $name = $d->{'name'};
  $name = undef unless defined($name) && ref($name) eq '';
  if (!defined($name) && @$tags) {
    # no name specified, get it from first tag
    $name = $tags->[0];
    $name =~ s/[:\/]/-/g;
  }
  $d->{name} = $name;
  my $chart = $d->{'chart'};
  $d->{'chart'} = $chart = undef unless defined($chart) && ref($chart) eq '';
  delete $d->{'disturl'} unless defined($d->{'disturl'}) && ref($d->{'disturl'}) eq '';
  delete $d->{'buildtime'} unless defined($d->{'buildtime'}) && ref($d->{'buildtime'}) eq '';
  return undef unless defined($name) && defined($chart);
  eval {
    BSVerify::verify_simple($chart);
    BSVerify::verify_filename($chart);
  };
  return undef if $@;
  return $d;
}

sub writehelminfo {
  my ($fn, $fnf, $helminfo) = @_;
  my $helminfo_json = JSON::XS->new->utf8->canonical->pretty->encode($helminfo);
  writestr($fn, $fnf, $helminfo_json);
}

1;



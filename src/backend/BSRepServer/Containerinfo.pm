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

package BSRepServer::Containerinfo;

use JSON::XS ();
use BSVerify;
use BSUtil;
use Digest::MD5 ();
use BSXML;

use strict;

=head1 NAME

BSRepServer::Containerinfo

=head1 DESCRIPTION

 This library contains functions to handle the containerinfo data returned
 from container image builds.

=cut

=head2  containerinfo2obsbinlnk - convert a containerinfo file to an obsbinlnk

 input: $dir - directory of the built container
        $containerinfo - containerinfo filename in $dir
        $packid - package name of the built container

 output: obsbinlnk hash or undef

=cut

sub containerinfo2obsbinlnk {
  my ($dir, $containerinfo, $packid) = @_;
  return undef unless -e "$dir/$containerinfo";
  return undef unless (-s _) < 100000;
  my $m = readstr("$dir/$containerinfo");
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
  my $file = $d->{'file'};
  $file = undef unless defined($file) && ref($file) eq '';
  return undef unless defined($name) && defined($file);
  eval {
    BSVerify::verify_simple($file);
    BSVerify::verify_filename($file);
  };
  return undef if $@;
  return undef unless $file =~ /\.tar(?:\.[^\.]+)?$/s;
  my $lnk = {};
  $lnk->{'name'} = "container:$file";
  $lnk->{'name'} =~ s/\.tar(?:\.[^\.]+)?$//;    # strip tar.xz
  $lnk->{'name'} =~ s/-[^-]+$//;                # strip version
  $lnk->{'version'} = defined($d->{'version'}) ? $d->{'version'} : '0'; 
  $lnk->{'arch'} = 'noarch';
  $lnk->{'source'} = $lnk->{'name'};
  # add self-provides
  push @{$lnk->{'provides'}}, "$lnk->{'name'} = $lnk->{'version'}";

  push @{$lnk->{'provides'}}, "container:$name" if "container:$name" ne $lnk->{'name'};
  for my $tag (@$tags) {
    push @{$lnk->{'provides'}}, "container:$name:$tag";
  }
  eval {
    BSVerify::verify_nevraquery($lnk);
  };
  return undef if $@;
  my $annotation = {};
  $annotation->{'repo'} = $d->{'repos'} if $d->{'repos'};
  if (%$annotation) {
    eval { $lnk->{'annotation'} = BSUtil::toxml($annotation, $BSXML::binannotation) };
    warn($@) if $@;
  }
  local *F;
  return undef unless open(F, '<', "$dir/$file");
  my $ctx = Digest::MD5->new;
  $ctx->addfile(*F);
  close F;
  $lnk->{'hdrmd5'} = $ctx->hexdigest();
  $lnk->{'path'} = "../$packid/$file";
  return $lnk;
}

1;

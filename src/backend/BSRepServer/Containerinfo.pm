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

=head2  containerinfo2nevra - convert containerinfo data to name/epoch/version/release/arch

 input: $containerinfo - containerinfo data

 output: hash containting name/epoch/...

=cut

sub containerinfo2nevra {
  my ($d) = @_;
  my $lnk = {};
  $lnk->{'name'} = "container:$d->{'name'}";
  $lnk->{'version'} = defined($d->{'version'}) ? $d->{'version'} : '0';
  $lnk->{'release'} = defined($d->{'release'}) ? $d->{'release'} : '0';
  $lnk->{'arch'} = defined($d->{'arch'}) ? $d->{'arch'} : 'noarch';
  return $lnk;
}

=head2  containerinfo2obsbinlnk - convert a containerinfo file to an obsbinlnk

 input: $dir - directory of the built container
        $containerinfo - containerinfo filename in $dir
        $packid - package name of the built container

 output: obsbinlnk hash or undef

=cut

sub containerinfo2obsbinlnk {
  my ($dir, $containerinfo, $packid) = @_;
  my $d = readcontainerinfo($dir, $containerinfo);
  return unless $d;
  # currently no other OS containers. Alternative would be to rename them to avoid conflicts.
  return if $d->{'goos'} ne 'linux';
  my $lnk = containerinfo2nevra($d);
  # need to have a source so that it goes into the :full tree
  $lnk->{'source'} = $lnk->{'name'};
  # add self-provides
  push @{$lnk->{'provides'}}, "$lnk->{'name'} = $lnk->{'version'}";
  for my $tag (@{$d->{tags}}) {
    push @{$lnk->{'provides'}}, "container:$tag" unless "container:$tag" eq $lnk->{'name'};
  }
  eval {
    BSVerify::verify_nevraquery($lnk);
  };
  return undef if $@;
  my $annotation = {};
  $annotation->{'repo'} = $d->{'repos'} if $d->{'repos'};
  $annotation->{'disturl'} = $d->{'disturl'} if $d->{'disturl'};
  $annotation->{'buildtime'} = $d->{'buildtime'} if $d->{'buildtime'};
  $annotation->{'binaryid'} = $d->{'imageid'} if $d->{'imageid'};
  if (%$annotation) {
    eval { $lnk->{'annotation'} = BSUtil::toxml($annotation, $BSXML::binannotation) };
    warn($@) if $@;
  }
  local *F;
  if ($d->{'tar_md5sum'}) {
    # this is a normalized container, see BSRepServer::Containertar::normalize_container
    $lnk->{'hdrmd5'} = $d->{'tar_md5sum'};
    $lnk->{'path'} = "../$packid/$d->{'file'}";
    return $lnk;
  }
  return undef unless open(F, '<', "$dir/$d->{'file'}");
  my $ctx = Digest::MD5->new;
  $ctx->addfile(*F);
  close F;
  $lnk->{'hdrmd5'} = $ctx->hexdigest();
  $lnk->{'path'} = "../$packid/$d->{'file'}";
  return $lnk;
}

=head2  readcontainerinfo - read data from containerinfo file and verify data

 input: $dir - directory of the built container
        $containerinfo - containerinfo filename in $dir

 output: HashRef containing data from containerinfo or undef in case of an error

=cut

sub readcontainerinfo {
  my ($dir, $containerinfo) = @_;
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
  if (!defined($name) && @$tags) {
    # no name specified, get it from first tag
    $name = $tags->[0];
    $name =~ s/[:\/]/-/g;
  }
  $d->{name} = $name;
  my $file = $d->{'file'};
  $d->{'file'} = $file = undef unless defined($file) && ref($file) eq '';
  delete $d->{'disturl'} unless defined($d->{'disturl'}) && ref($d->{'disturl'}) eq '';
  delete $d->{'buildtime'} unless defined($d->{'buildtime'}) && ref($d->{'buildtime'}) eq '';
  delete $d->{'imageid'} unless defined($d->{'imageid'}) && ref($d->{'imageid'}) eq '';
  return undef unless defined($name) && defined($file);
  eval {
    BSVerify::verify_simple($file);
    BSVerify::verify_filename($file);
  };
  return undef if $@;
  return $d;
}

sub writecontainerinfo {
  my ($fn, $fnf, $containerinfo) = @_;
  my $containerinfo_json = JSON::XS->new->utf8->canonical->pretty->encode($containerinfo);
  writestr($fn, $fnf, $containerinfo_json);
}

1;

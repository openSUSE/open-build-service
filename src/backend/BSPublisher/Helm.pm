#
# Copyright (c) 2020 SUSE LLC
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
# Container handling of the publisher
#

package BSPublisher::Helm;

use BSTar;

use strict;

sub readcontainerinfo {
  my ($dir, $helmtar) = @_;
  my $h;
  return undef unless open($h, '<', "$dir/$helmtar");
  my $tar = BSTar::list($h);
  return undef unless $tar;
  my %tar = map {$_->{'name'} => $_} @$tar;
  my $manifest_ent = $tar{'manifest.json'};
  return undef unless $manifest_ent && $manifest_ent->{'size'} < 100000;
  my $manifest_json = BSTar::extract($h, $manifest_ent);
  my $manifest = JSON::XS::decode_json($manifest_json);
  close $h;

  my $d; 
  eval { $d = JSON::XS::decode_json($manifest_json) };
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

  my $containerinfo = { 'type' => 'helm' };
  $containerinfo->{'name'} = $name if defined $name;
  $containerinfo->{'tags'} = $tags if @$tags;
  for my $k (qw{chart disturl buildtime version release}) {
    my $v = $d->{$k};
    $containerinfo->{$k} = $v if defined($v) && ref($v) eq '';
  }

  return undef unless $containerinfo->{'chart'} && $tar{$containerinfo->{'chart'}};

  return $containerinfo;
}

1;

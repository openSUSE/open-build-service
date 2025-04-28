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

 output: hash containting name/epoch/...

=cut

sub helminfo2nevra {
  my ($d) = @_;
  my $info = {};
  $info->{'name'} = "helm:$d->{'name'}";
  $info->{'version'} = defined($d->{'version'}) ? $d->{'version'} : '0';
  $info->{'release'} = defined($d->{'release'}) ? $d->{'release'} : '0';
  $info->{'arch'} = defined($d->{'arch'}) ? $d->{'arch'} : 'noarch';
  return $info;
}

=head2  helminfo2obsbininfo - convert a helminfo file to an obsbinlnk

 input: $dir - directory of the built helm chart
        $helminfo - helminfo filename in $dir

 output: obsbininfo hash or undef

=cut

sub helminfo2obsbininfo {
  my ($dir, $helminfo) = @_;
  my $d = readhelminfo($dir, $helminfo);
  return unless $d;
  my $info = helminfo2nevra($d);
  eval { BSVerify::verify_nevraquery($info) };
  return undef if $@;
  return $info;
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
  return undef unless $d->{'name'} && ref($d->{'name'}) eq '';
  return undef unless $d->{'version'} && ref($d->{'version'}) eq '';
  return undef unless !$d->{'tags'} || ref($d->{'tags'}) eq 'ARRAY';
  return undef unless $d->{'chart'} && ref($d->{'chart'}) eq '';
  return $d;
  delete $d->{'disturl'} unless defined($d->{'disturl'}) && ref($d->{'disturl'}) eq '';
  delete $d->{'buildtime'} unless defined($d->{'buildtime'}) && ref($d->{'buildtime'}) eq '';
  return $d;
}

1;

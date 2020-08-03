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
use BSUtil;

use strict;

# this also works as a containerinfo substitute
sub readhelminfo {
  my ($dir, $helminfofile) = @_;
  return undef unless -e "$dir/$helminfofile";
  return undef unless (-s _) < 1000000;
  my $m = readstr("$dir/$helminfofile");
  my $d;
  eval { $d = JSON::XS::decode_json($m); };
  return undef unless $d && ref($d) eq 'HASH';
  if (exists $d->{'tags'}) {
    $d->{'tags'} = [] unless ref($d->{'tags'}) eq 'ARRAY';
    for (splice @{$d->{'tags'}}) {
      push @{$d->{'tags'}}, $_ if defined($_) && ref($_) eq '';
    }
  }
  for my $k (qw{disturl buildtime name version release config_json}) {
    my $v = $d->{$k};
    $d->{$k} = $v if defined($v) && ref($v) eq '';
  }
  return undef unless $d->{'name'} && $d->{'config_json'};
  $d->{'chart'} = $helminfofile;
  $d->{'chart'} =~ s/.*\///;
  $d->{'chart'} =~ s/\.helminfo$/.tgz/;
  $d->{'type'} = 'helm';
  return $d;
}

1;

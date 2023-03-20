# Copyright (c) 2016 SUSE LLC
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
package Test::OBS;


use strict;
use warnings;

use Exporter;
@Test::OBS::ISA       = ("Exporter");
@Test::OBS::EXPORT_OK =(qw/cmp_buildinfo/);
@Test::OBS::EXPORT    = @Test::OBS::EXPORT_OK;

use Test::More;

sub bdepkey {
  my ($x) = @_;
  return 'name='.($x->{'name'}||'').' '.join(' ', map {"$_=$x->{$_}"} grep {$_ ne 'name'} sort keys %$x);
}

sub cmp_buildinfo {
  my ($got, $expected, $comment) = @_;

  delete $_->{'hdrmd5'} for @{$got->{'bdep'} || []};
  $got->{'bdep'}       = [ sort(map {bdepkey($_)} @{$got->{'bdep'} || []}) ];
  $expected->{'bdep'}  = [ sort(map {bdepkey($_)} @{$expected->{'bdep'} || []}) ];
  $got->{subpack}      = [ sort { $a cmp $b }  @{ $got->{subpack}  || []} ];
  $expected->{subpack} = [ sort { $a cmp $b } @{ $expected->{subpack}  || []} ];
  is_deeply($got, $expected, $comment);
}

1;

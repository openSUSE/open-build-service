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
package Test::OBS::Utils;

use strict;
use warnings;

use BSUtil;

sub readstrxz {
  my ($fn, $nonfatal) = @_;
  if ($fn =~ /\.xz$/) {
    local *F;
    if (!-e $fn || !open(F, '-|', 'xz', '--decompress', '-c', $fn)) {
      die("$fn: $!\n") unless $nonfatal;
      return undef;
    }
    my $d = ''; 
    1 while sysread(F, $d, 8192, length($d));
    if (!close(F)) {
      die("$fn: $?\n") unless $nonfatal;
      return undef;
    }
    return $d;
  }
  return readstrxz("$fn.xz", $nonfatal) if !-e $fn && -e "$fn.xz";
  return readstr($fn, $nonfatal);
}

sub readxmlxz {
  my ($fn, $dtd, $nonfatal) = @_; 
  my $d = readstrxz($fn, $nonfatal);
  $d = BSUtil::fromxml($d, $dtd, $nonfatal) if defined $d;
  return $d;
}

1; 

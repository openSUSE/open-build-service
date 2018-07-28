#
# Copyright (c) 2018 SUSE LLC
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
# blobstore functions for the publisher
#

package BSPublisher::Blobstore;

use BSConfiguration;

use strict;

my $blobdir = "$BSConfig::bsdir/blobs";

sub blobstore_chk {
  my ($blobid) = @_;
  return unless $blobid =~ /^sha256:([0-9a-f]{3})([0-9a-f]{61})$/s;
  my @s = stat("$blobdir/sha256/$1/$2");
  unlink("$blobdir/sha256/$1/$2") if ($s[3] || 0) == 1;
}

1;

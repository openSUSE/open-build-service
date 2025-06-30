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
package BSRepserver::Bininfo;

use strict;

use BSUtil;

use BSSched::Bininfo;

=head2 create_bininfo_file - create the .bininfo file describing the built artefacts

 TODO: add description

=cut

sub create_bininfo_file {
  my ($dir) = @_;
  my $bininfo = BSSched::Bininfo::create_bininfo($dir);
  $bininfo->{'.bininfo'} = {};
  BSUtil::store("$dir/.bininfo", undef, $bininfo);
}

1;

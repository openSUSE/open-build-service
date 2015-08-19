#
#
# Copyright (c) 2008 Marcus Huewe
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
# The Download on Demand Metadata Parser for deb md files ("Packages" files)
#

package Meta;

use strict;
use warnings;
use Meta::Rpmmd;
use Meta::Debmd;
use Meta::Susetagsmd;

sub parse {
  my ($fn, $type, $opts) = @_;
  return Meta::Debmd::parse($fn, $opts) if $type eq 'debmd';
  return Meta::Rpmmd::parse($fn, $opts) if $type eq 'rpmmd';
  return Meta::Susetagsmd::parse($fn, $opts) if $type eq 'susetagsmd';
}

1;

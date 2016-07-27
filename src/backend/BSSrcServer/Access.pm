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
package BSSrcServer::Access;

use strict;
use warnings;

use BSRevision;
use BSUtil;

sub checksourceaccess {
  my ($projid, $packid) = @_;

  my $proj = BSRevision::readproj_local($projid, 1);
  return unless $proj;
  my $pack = BSRevision::readpack_local($projid, $packid, 1);
  my $sourceaccess = 1;
  $sourceaccess = BSUtil::enabled('', $proj->{'sourceaccess'}, $sourceaccess, '');
  $sourceaccess = BSUtil::enabled('', $pack->{'sourceaccess'}, $sourceaccess, '') if $pack;
  die("403 source access denied\n") unless $sourceaccess;
  my $access = 1;
  $access = BSUtil::enabled('', $proj->{'access'}, $access, '');
  $access = BSUtil::enabled('', $pack->{'access'}, $access, '') if $pack;
  die("404 package '$packid' does not exist\n") unless $access; # hmm...
  return 1;
}

1;

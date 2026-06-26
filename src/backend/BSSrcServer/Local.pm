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

package BSSrcServer::Local;

use strict;
use warnings;

use BSRevision;

sub getrev {
  my ($projid, $packid, $revid, $linked, $missingok) = @_;
  my $rev = BSRevision::getrev_local($projid, $packid, $revid);
  return $rev if $rev;
  return {'project' => $projid, 'package' => $packid, 'srcmd5' => $BSSrcrep::emptysrcmd5} if $missingok;
  die("404 package '$packid' does not exist in project '$projid'\n");
}

sub findprojects {
  my ($deleted) = @_;
  return BSRevision::lsprojects_local($deleted);
}

sub findpackages {
  my ($projid, $proj, $nonfatal, $origins, $noexpand, $deleted) = @_;
  my @packids = BSRevision::lspackages_local($projid, $deleted);
  if ($origins) {
    for (@packids) {
      $origins->{$_} = $projid unless defined $origins->{$_};
    }
  }
}

sub readproject {
  my ($projid, $proj, $revid, $missingok) = @_;
  $proj ||= BSRevision::readproj_local($projid, 1, $revid);
  $proj->{'name'} ||= $projid if $proj;
  die("404 project '$projid' does not exist\n") if !$missingok && !$proj;
  return $proj;
}

sub readpackage {
  my ($projid, $proj, $packid, $revid, $missingok) = @_;
  my $pack = BSRevision::readpack_local($projid, $packid, 1, $revid);
  $pack->{'project'} ||= $projid if $pack;
  die("404 package '$packid' does not exist in project '$projid'\n") if !$missingok && !$pack;
  return $pack;
}

1;

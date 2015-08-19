#
# Copyright (c) 2010, Novell Inc.
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

package BSAccess;

use BSUtil;
use BSXML;

use strict;

our $projectsdir;

sub set_projectsdir {
  $projectsdir = $_[0];
}

sub has_role {
  my ($userid, $d, $role) = @_;

  return 0 unless $d;
  for (@{$d->{'person'} || []}) {
    next if $_->{'userid'} ne $userid;
    return 1 if !defined($role) || $_->{'role'} eq $role;
  }
  return 0;
}

sub may_read {
  die("projectsdir not set\n") unless $projectsdir;
  return;
}

sub may_write {
  my ($userid, $projid, $packid) = @_;
  die("projectsdir not set\n") unless $projectsdir;
  if (defined $packid) {
    my $pack = readxml("$projectsdir/$projid.pkg/$packid.xml", $BSXML::pack, 1);
    return if has_role($userid, $pack, 'maintainer');
  }
  my $p = $projid;
  while ($p ne '') {
    my $proj = readxml("$projectsdir/$p.xml", $BSXML::proj, 1);
    return if has_role($userid, $proj, 'maintainer');
    last unless $p =~ s/:[^:]*$//s;
  }
  my $proj = readxml("$projectsdir/:master.xml", $BSXML::proj, 1);
  return if has_role($userid, $proj, 'maintainer');
  die("no write access to package $packid in project $projid\n") if defined $packid;
  die("no write access to project $projid\n");
}

1;

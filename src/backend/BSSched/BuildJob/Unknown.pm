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

package BSSched::BuildJob::Unknown;

use strict;
use warnings;

=head1 NAME

BSSched::BuildJob::Unknown - A Class to handle unknown build type errors

=head1 SYNOPSIS

my $h = BSSched::BuildJob::Unknown->new()

$h->check();

$h->expand();

$h->rebuild();

=cut

=head2 new - TODO: add summary

 TODO: add description

=cut

sub new {
  return bless({}, $_[0]);
}

=head2 expand - TODO: add summary

 TODO: add description

=cut

sub expand {
  return 1, splice(@_, 3);
}

=head2 check - return an error

 TODO: add description

=cut

sub check {
  return ('broken', 'unknown package type');
}

=head2 build - return an error

 TODO: add description

=cut

sub build {
  return ('broken', 'unknown package type');
}

1;

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

package BSSched::BuildJob::SimpleImage;

use strict;
use warnings;

use Digest::MD5 ();
use Build;

use BSSched::BuildJob::Package;

=head1 NAME

BSSched::BuildJob::SimpleImage - A Class to handle simple image builds

=head1 SYNOPSIS

my $h = BSSched::BuildJob::SimpleImage->new()

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
  shift;
  goto &Build::get_deps;
}

=head2 check - check if a simple image needs to be rebuilt

 TODO: add description

=cut

sub check {
  goto &BSSched::BuildJob::Package::check;
}

=head2 build - create a simple image build job

 TODO: add description

=cut

sub build {
  goto &BSSched::BuildJob::Package::build;
}

1;

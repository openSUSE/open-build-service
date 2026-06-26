# Copyright (c) 2024 SUSE LLC
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
package Test::Mock::BSSched::BuildJob;

our @ISA = 'BSSched::BuildJob';

use BSSched::BuildJob;

BEGIN {
  *BSSched::BuildJob::fakejobfinished = sub {
    my ($ctx, $packid, $job, $code, $buildinfoskel, $needsign) = @_;
    $ctx->{'fakejob'} = [ $job, $code, $buildinfoskel, $needsign ];
  };
}


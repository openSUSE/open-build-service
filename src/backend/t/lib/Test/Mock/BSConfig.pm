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
package Test::Mock::BSConfig;

use strict;
use FindBin;

$main::INC{'BSConfig.pm'} = 'BSConfig.pm';

# this is the dummy config we use in the unit tests

$BSConfig::bsdir = "$FindBin::Bin/data/shared";
$BSConfig::srcserver = 'srcserver';
$BSConfig::reposerver = 'reposerver';
$BSConfig::repodownload = 'http://download.opensuse.org/repositories';
$BSConfig::debuglevel = 3;

1; 

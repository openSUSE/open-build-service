#
# Copyright (c) 2013 Adrian Schroeter, SUSE Linux Products GmbH.
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
# Generic configuration handler for /configuration.xml and BSConfig.pm settings
#

package BSConfiguration;

use BSConfig;
use BSUtil;
use BSXML;

my $configuration_file = "$BSConfig::bsdir/configuration.xml";
my $xml = readxml($configuration_file, $BSXML::configuration, 1) || {};

# old values from BSConfig.pm are winning
$BSConfig::obsname = $xml->{'name'} if !defined($BSConfig::obsname);
$BSConfig::proxy = $xml->{'http_proxy'} if !defined($BSConfig::proxy);
if (!defined($BSConfig::enable_download_on_demand)) {
  $BSConfig::enable_download_on_demand = 0;
  if ($xml->{'download_on_demand'} && $xml->{'download_on_demand'} eq "on") {
    $BSConfig::enable_download_on_demand = 1;
  }
}
if (!defined($BSConfig::forceprojectkeys)) {
  $BSConfig::forceprojectkeys = 0;
  if ($xml->{'enforce_project_keys'} && $xml->{'enforce_project_keys'} eq "on") {
    $BSConfig::forceprojectkeys = 1;
  }
}

# set defaults
$BSConfig::obsname = "build.some.where" if !defined($BSConfig::obsname);

1;

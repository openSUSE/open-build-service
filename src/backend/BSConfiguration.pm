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

use strict;

use BSConfig;
use BSUtil;
use BSXML;

# old values from BSConfig.pm are winning, remember which have been set
my %bsconfigvalues;
$bsconfigvalues{'obsname'} = 1 if defined $BSConfig::obsname;
$bsconfigvalues{'proxy'} = 1 if defined $BSConfig::proxy;
$bsconfigvalues{'noproxy'} = 1 if defined $BSConfig::noproxy;
$bsconfigvalues{'repodownload'} = 1 if defined $BSConfig::repodownload;
$bsconfigvalues{'enable_download_on_demand'} = 1 if defined $BSConfig::enable_download_on_demand;
$bsconfigvalues{'forceprojectkeys'} = 1 if defined $BSConfig::forceprojectkeys;


my $configuration_file = "$BSConfig::bsdir/configuration.xml";

sub update_from_configuration {
  my $xml = readxml($configuration_file, $BSXML::configuration, 1) || {};
  $BSConfig::obsname = $xml->{'name'} unless $bsconfigvalues{'obsname'};
  $BSConfig::proxy = $xml->{'http_proxy'} unless $bsconfigvalues{'proxy'};
  $BSConfig::noproxy = $xml->{'no_proxy'} unless $bsconfigvalues{'noproxy'};
  $BSConfig::repodownload  = $xml->{'download_url'} unless $bsconfigvalues{'repodownload'};
  if (!$bsconfigvalues{'enable_download_on_demand'}) {
    $BSConfig::enable_download_on_demand = ($xml->{'download_on_demand'} || '') eq 'on' ? 1 : 0;
  }
  if (!$bsconfigvalues{'forceprojectkeys'}) {
    $BSConfig::forceprojectkeys = ($xml->{'enforce_project_keys'} || '') eq 'on' ? 1 : 0;
  }
  $BSConfig::obsname = "build.some.where" unless defined $BSConfig::obsname;
}

update_from_configuration();

1;

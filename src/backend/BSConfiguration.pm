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
$bsconfigvalues{'api_url'} = 1 if defined $BSConfig::api_url;
$bsconfigvalues{'proxy'} = 1 if defined $BSConfig::proxy;
$bsconfigvalues{'noproxy'} = 1 if defined $BSConfig::noproxy;
$bsconfigvalues{'repodownload'} = 1 if defined $BSConfig::repodownload;
$bsconfigvalues{'enable_download_on_demand'} = 1 if defined $BSConfig::enable_download_on_demand;
$bsconfigvalues{'forceprojectkeys'} = 1 if defined $BSConfig::forceprojectkeys;
$bsconfigvalues{'schedulerarchs'} = 1 if defined $BSConfig::schedulerarchs;


my $configurationid = '';
my $configuration_file = "$BSConfig::bsdir/configuration.xml";
my $confiuration_checked_once;

sub update_from_configuration {
  my @s = stat($configuration_file);
  $configurationid = @s ? "$s[9]/$s[7]/$s[1]" : '';
  my $xml = readxml($configuration_file, $BSXML::configuration, 1) || {};
  $BSConfig::obsname = $xml->{'name'} unless $bsconfigvalues{'obsname'};
  $BSConfig::api_url = $xml->{'api_url'} unless $bsconfigvalues{'api_url'};
  $BSConfig::proxy = $xml->{'http_proxy'} unless $bsconfigvalues{'proxy'};
  $BSConfig::noproxy = $xml->{'no_proxy'} unless $bsconfigvalues{'noproxy'};
  $BSConfig::repodownload  = $xml->{'download_url'} unless $bsconfigvalues{'repodownload'};
  if (!$bsconfigvalues{'enable_download_on_demand'}) {
    $BSConfig::enable_download_on_demand = ($xml->{'download_on_demand'} || '') eq 'on' ? 1 : 0;
  }
  if (!$bsconfigvalues{'forceprojectkeys'}) {
    $BSConfig::forceprojectkeys = ($xml->{'enforce_project_keys'} || '') eq 'on' ? 1 : 0;
  }
  if (!$bsconfigvalues{'schedulerarchs'}) {
    $BSConfig::schedulerarchs = $xml->{'schedulers'}->{'arch'} if $xml->{'schedulers'} && $xml->{'schedulers'}->{'arch'};
  }
  $BSConfig::obsname = "build.some.where" unless defined $BSConfig::obsname;
}

sub check_configuration {
  my @s = stat($configuration_file);
  my $id = @s ? "$s[9]/$s[7]/$s[1]" : '';
  update_from_configuration() if $configurationid ne $id;
}

# useful for BSServer where we fork for every request
sub check_configuration_once {
  return if $confiuration_checked_once;
  $confiuration_checked_once = 1;
  check_configuration();
}

update_from_configuration();
BSUtil::setdebuglevel($BSConfig::debuglevel) if $BSConfig::debuglevel;

# set common defaults if not already set in BSConfig.pm
$BSConfig::bsdir                    = $BSConfig::bsdir                    || '/srv/obs';
$BSConfig::logdir                   = $BSConfig::logdir                   || "$BSConfig::bsdir/log";
$BSConfig::rundir                   = $BSConfig::rundir                   || "$BSConfig::bsdir/run";
$BSConfig::servicetempdir           = $BSConfig::servicetempdir           || "$BSConfig::bsdir/service";
$BSConfig::scm_cache_high_watermark = $BSConfig::scm_cache_high_watermark || 80;
$BSConfig::scm_cache_low_watermark  = $BSConfig::scm_cache_low_watermark  || 70;
$BSConfig::service_timeout          = $BSConfig::service_timeout          || 3600;

$BSConfig::cloudupload_pubkey       = $BSConfig::cloudupload_pubkey       || '/etc/obs/cloudupload/_pubkey';

1;

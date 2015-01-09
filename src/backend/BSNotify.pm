#
# Copyright (c) 2008 Klaas Freitag, Novell Inc.
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
# Module to talk to notification systems
#

package BSNotify;

use BSRPC;
use BSConfig;

use strict;

#
# Backend notifications are always routed through the source server. The API
# is processing them via /lastnotifications route and afterwards delivers
# them to the backend notifiy plugins via /notify_plugins.
#
sub notify {
  my ($type, $p, $payload) = @_;

  # strip
  $p = { map {$_ => $p->{$_}} grep {defined($p->{$_}) && !ref($p->{$_})} sort keys %{$p || {}} };

  my $param = {
    'uri' => "$BSConfig::srcserver/notify/$type",
    'request' => 'POST',
    'headers' => [ 'Content-Type: application/x-www-form-urlencoded' ],
    'timeout' => 60,
  };
  if ($payload) {
    $param->{'headers'} = [ 'Content-Type: application/octet-stream' ];
    $param->{'data'} = $payload;
  }
  my @args = map {"$_=$p->{$_}"} sort keys %$p;
  eval {
    BSRPC::rpc($param, undef, @args);
  };
  if ($@) {
    die($@) if $payload;	# payload transfers are fatal
    warn($@) if $@;
  }
}

#
# this is called from the /notify_plugins route that the API calls for all
# events (no matter the origin) if the API is configured to do so.
#
sub notify_plugins($$) {
  my ($type, $paramRef ) = @_;

  return unless $BSConfig::notification_plugin;

  my @hostnames = split(/\s+/, $BSConfig::notification_plugin);

  for my $hostname (@hostnames) {
      my $notifier = &loadPackage($hostname);
      $notifier->notify($type, $paramRef );
  }

}

sub loadPackage {
  my ($componentname) = @_;
  my $file = "plugins/$componentname.pm";

  my $componentfile = $file;
  eval{
     require "$componentfile";
  };
  print "error: $@" if $@;
  my $obj = $componentname->new();
  return $obj;    
}

1;

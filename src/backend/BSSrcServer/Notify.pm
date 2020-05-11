# Copyright (c) 2019 SUSE LLC
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
package BSSrcServer::Notify;

use strict;

use BSConfiguration;

sub loadPackage {
  my ($plugin) = @_;
  eval {
     require "plugins/$plugin.pm";
  };
  warn("error: $@") if $@;
  return $plugin->new();
}

#
# this is called from the /notify_plugins route that the API calls for all
# events (no matter the origin) if the API is configured to do so.
#
sub notify_plugins($$) {
  my ($type, $paramRef) = @_; 

  return unless $BSConfig::notification_plugin;

  my $plugins = $BSConfig::notification_plugin;
  $plugins = [ split(' ', $plugins) ] unless ref($plugins);     # compat
  for my $plugin (@$plugins) {
    my $notifier = loadPackage($plugin);
    $notifier->notify($type, $paramRef);
  }
}

1;

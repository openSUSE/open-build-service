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
use BSConfiguration;

use strict;

sub payload_datafmt {
  my ($payloadref) = @_;
  my $sent = 0;
  return sub {my $chunk = substr($$payloadref, $sent, 65536); $sent += length($chunk); $chunk};
}

#
# Backend notifications are always routed through the source server. The API
# is processing them via /lastnotifications route and afterwards delivers
# them to the backend notifiy plugins via /notify_plugins.
#
sub notify {
  my ($type, $p) = @_;		# $_[2] is the payload, but we do not want a copy to save memory
  my $payloadref = $_[2] ? \$_[2] : undef;

  # strip
  $p = { map {$_ => $p->{$_}} grep {defined($p->{$_}) && !ref($p->{$_})} sort keys %{$p || {}} };

  my $param = {
    'uri' => "$BSConfig::srcserver/notify/$type",
    'request' => 'POST',
    'formurlencode' => 1,
    'timeout' => 60,
  };
  if ($payloadref) {
    my $payloadsize = length($$payloadref);
    my $timeout = 60 + int($payloadsize / 500000);
    $param->{'timeout'} = $timeout > 3600 ? 3600 : $timeout;
    $param->{'headers'} = [ 'Content-Type: application/octet-stream', "Content-Length: $payloadsize" ];
    $param->{'data'} = $payloadref;
    $param->{'datafmt'} = \&payload_datafmt;
    $param->{'formurlencode'} = 0;
  }
  my @args = map {"$_=$p->{$_}"} sort keys %$p;
  eval {
    BSRPC::rpc($param, undef, @args);
  };
  if ($@) {
    die($@) if $payloadref;	# payload transfers are fatal
    warn($@) if $@;
  }
}

1;

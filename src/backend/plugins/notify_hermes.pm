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
# Module to talk to Hermes
#

package notify_hermes;

use BSRPC;
use BSConfig;

use strict;

sub new {
  my $self = {};
  bless $self, shift;
  return $self;
}

sub notify() {
  my ($self, $type, $paramRef) = @_;

  return unless $BSConfig::hermesserver;

  # prepend something BS specific
  my $prefix = $BSConfig::hermesnamespace || "OBS";
  $type ||= "UNKNOWN";
  $type = "${prefix}_$type";

  my @args = ("rm=notify", "_type=$type");

  if ($paramRef) {
    for my $key (sort keys %$paramRef) {
      if (ref $paramRef->{$key}) {
        my $subref = $paramRef->{$key};
        if ($key eq "actions") {
          # hermes can only display one, so pick the first
          $subref = $subref->[0];
          for my $skey (sort keys %$subref) {
            push @args, "$skey=$subref->{$skey}" if defined $subref->{$skey};
          }
        }
      }
      push @args, "$key=$paramRef->{$key}" if defined $paramRef->{$key};
    }
  }

  my $hermesuri = "$BSConfig::hermesserver/index.cgi";

  # print STDERR "Notifying hermes at $hermesuri: <" . join( ', ', @args ) . ">\n";

  my $param = {
    'uri' => $hermesuri,
    'timeout' => 60,
  };
  eval {
    BSRPC::rpc($param, undef, @args);
  };
  warn("Hermes: $@") if $@;
}

1;

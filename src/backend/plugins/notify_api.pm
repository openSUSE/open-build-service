#
# Copyright (c) 2013 Stephan Kulow, SUSE
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
# Module to store events in the API
#

package notify_api;

use BSRPC;
use BSConfig;
use JSON::XS;

use Carp;
require Carp::Always;

use strict;

sub new {
  my $self = {};
  bless $self, shift;
  return $self;
}

sub notify() {
  my ($self, $type, $paramRef ) = @_;

  return unless $BSConfig::apiurl;

  $type = "UNKNOWN" unless $type;

  my $apiuri = "$BSConfig::apiurl/events";
  print STDERR "Notifying API at $apiuri\n";

  $paramRef->{'eventtype'} = $type;
  $paramRef->{'time'} = time();

  my $data = JSON::XS->new->encode($paramRef);

  my $param = {
    'uri' => $apiuri,
    'request' => 'POST',
    'verbatim_uri' => 1,
    'content-length' => length($data),
    'headers' => [ 'Content-Type: application/json', 'Accepts: application/json' ],
    'data' => $data,
  };
  eval {
    BSRPC::rpc( $param, undef, () );
  };
  warn("Notify API: $@") if $@;
}

1;

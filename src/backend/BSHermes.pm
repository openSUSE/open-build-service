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

package BSHermes;

use BSRPC;
use BSConfig;

use strict;

sub notify($$) {
  my ($type, $paramRef ) = @_;

  return unless $BSConfig::hermesserver;

  my @args = ( "rm=notify" );

  $type = "UNKNOWN" unless $type;
  # prepend something BS specific
  my $prefix = $BSConfig::hermesnamespace || "OBS";
  $type =  "${prefix}_$type";

  push @args, "_type=$type";

  if ($paramRef) {
    for my $key (sort keys %$paramRef) {
      next if ref $paramRef->{$key};
      push @args, "$key=$paramRef->{$key}";
    }
  }

  my $hermesuri = "$BSConfig::hermesserver/index.cgi";

  # print STDERR "Notifying hermes at $hermesuri: <" . join( ', ', @args ) . ">\n";

  my $param = {
    'uri' => $hermesuri,
    'timeout' => 60,
  };
  eval {
    BSRPC::rpc( $param, undef, @args );
  };
  warn("Hermes: $@") if $@;
}

# assemble hermes conform parameters for BS Requests
sub requestParams( $$ )
{
  my ($req, $user) = @_;

  my %reqinfo;

  $reqinfo{'id'} = $req->{'id'} || '';
  $reqinfo{'type'} = $req->{'type'} || '';
  $reqinfo{'state'} = '';
  $reqinfo{'when'}  = '';
  if( $req->{'state'} ) {
    $reqinfo{'state'} = $req->{'state'}->{'name'} || '';
    $reqinfo{'when'}  = $req->{'state'}->{'when'} || '';
  }
  $reqinfo{'who'} = $user || 'unknown';

  if( $req->{'type'} eq 'submit' && $req->{'submit'} && $req->{'submit'}->{'source'} &&
      $req->{'submit'}->{'target'}) {
      $reqinfo{'sourceproject'}  = $req->{'submit'}->{'source'}->{'project'};
      $reqinfo{'sourcepackage'}  = $req->{'submit'}->{'source'}->{'package'};
      $reqinfo{'sourcerevision'} = $req->{'submit'}->{'source'}->{'rev'};
      $reqinfo{'targetproject'}  = $req->{'submit'}->{'target'}->{'project'};
      $reqinfo{'targetpackage'}  = $req->{'submit'}->{'target'}->{'package'};

      if( $req->{'history'} ) {
        #FIXME: previous state is assumed to be always at last position in history
        # for maximum correctness find latest history entry by comparing all 'when' attributes
        $reqinfo{'oldstate'} = $req->{'history'}->[-1]->{'name'};
      }

      $reqinfo{'author'} = $req->{'history'} ? $req->{'history'}->[0]->{'who'} : $req->{'state'}->{'who'}
  }
  return \%reqinfo;
}

1;

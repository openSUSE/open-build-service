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
package Test::Mock::BSRPC;

use strict;
use Carp qw/cluck/;

use BSRPC;
use BSUtil;
use Test::OBS::Utils;

BEGIN {
  *BSRPC::rpc = sub {
    my ($param, $xmlargs, @args) = @_;
    $param = {'uri' => $param} if ref($param) ne 'HASH';
    my $uri = $param->{'uri'};

    for (@args) {
      $_ = BSRPC::urlencode($_);
      s/%3D/=/;
    }


    $uri = ( @args ) ? "$uri?" . join('&', @args) : $uri;
    my $org_uri = $uri;

    $uri =~ s#^https?://##;

    if ($Test::Mock::BSRPC::fixtures_map->{$uri}) {
      $uri = $Test::Mock::BSRPC::fixtures_map->{$uri}
    } else {
      $uri =~ s/\//_/g;
      $uri =~ s/_/\//;
    }

    $uri = "$BSConfig::bsdir/$uri";

    my $ret;
    eval {
      $ret = Test::OBS::Utils::readstrxz($uri);

      die("missing fixture: $uri") unless defined $ret;

      my $receiver = $param->{'receiver'};
      if ($receiver) {
	$ret = $receiver->(BSHTTP::str2req($ret), $param, $xmlargs || $param->{'receiverarg'}) if $receiver;
      } elsif ($xmlargs) {
	$ret = BSUtil::fromxml($ret, $xmlargs);
      }
    };

    if  ($@) {
      die <<"END";
$@

Use the following command line to generate them:

curl "$org_uri" > "$uri"

to compress them use:

xz "$uri"

END

    }

    return $ret;

  };
}

1; 

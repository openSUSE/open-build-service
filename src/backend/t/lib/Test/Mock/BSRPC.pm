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

BEGIN {
  require BSRPC;
  import BSRPC;

  *BSRPC::rpc = sub {
	my ($param, $xmlargs, @args) = @_;
	$param = {'uri' => $param} if ref($param) ne 'HASH';
	my $uri = $param->{'uri'};
	for (@args) {
	  $_ = BSRPC::urlencode($_);
	  s/%3D/=/;
	}
	$uri = "$uri?" . join('&', @args);
	$uri =~ s/\//_/g;
	$uri =~ s/_/\//;
	$uri = "$BSConfig::bsdir/$uri";
	die("missing fixture: $uri\n") unless -e $uri;
	if ($xmlargs) {
	  return BSUtil::readxml($uri, $xmlargs);
	} else {
	  return BSUtil::readstr($uri, $xmlargs);
	}
  }

}

1; 

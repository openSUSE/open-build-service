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

BEGIN {
  require BSRPC;
  import BSRPC;

  *BSRPC::rpc = sub {
	my ($param, $xmlargs, @args) = @_;
	my $f2r;
	my $ret;
	$param = {'uri' => $param} if ref($param) ne 'HASH';
	my $uri = $param->{'uri'};
	$uri =~ s#https?://##;

	for (@args) {
	  $_ = BSRPC::urlencode($_);
	  s/%3D/=/;
	}
	$uri = "$uri?" . join('&', @args);
	if ( $Test::Mock::BSRPC::fixtures_map->{$uri} ) {
	  $uri = $Test::Mock::BSRPC::fixtures_map->{$uri}
	} else {
      $uri =~ s/\//_/g;
      $uri =~ s/_/\//;
	}
	$uri = "$BSConfig::bsdir/$uri";

	# hack to get smaller fixtures
	if ( -e "$uri.xz" ) {
	  system("xz",'--decompress','-k',"$uri.xz");
	  $f2r = $uri;
	}

	die("missing fixture: $uri\n") unless -e $uri;

	if ($xmlargs) {
	  $ret = BSUtil::readxml($uri, $xmlargs);
	} else {
	  my $receiver = $param->{'receiver'};
	  $xmlargs ||= $param->{'receiverarg'};
	  if ($receiver) {
		#$ans = $receiver->($ansreq, $param, $xmlargs);
		#$xmlargs = undef;
		open(S,'<',$uri) || die "$uri: $!\n";
		my $ansreq = {
			__socket => \*S
		};
		$ret = $receiver->($ansreq, $param, $xmlargs);
	  } else {
		$ret =  BSUtil::readstr($uri, $xmlargs);
	  }
	}

	if ( $f2r )  { unlink $f2r };

	return $ret;

  }

}

1; 

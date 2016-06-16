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

BEGIN {
  *BSRPC::rpc = sub {
    my ($param, $xmlargs, @args) = @_;
    $param = {'uri' => $param} if ref($param) ne 'HASH';
    my $uri = $param->{'uri'};
    $uri =~ s#https?://##;

    for (@args) {
      $_ = BSRPC::urlencode($_);
      s/%3D/=/;
    }
    $uri = "$uri?" . join('&', @args);
    if ($Test::Mock::BSRPC::fixtures_map->{$uri}) {
      $uri = $Test::Mock::BSRPC::fixtures_map->{$uri}
    } else {
      $uri =~ s/\//_/g;
      $uri =~ s/_/\//;
    }
    $uri = "$BSConfig::bsdir/$uri";

    my $ret = '';
    # hack to get smaller fixtures
    if (-e "$uri.xz") {
      local *F;
      open(F, '-|', 'xz', '--decompress', '-c', "$uri.xz");
      1 while sysread(F, $ret, 8192, length($ret));
      close(F) || die("$uri.xz: $?\n");
    } elsif (-e $uri) {
      $ret= readstr($uri);
    } else {
      die("missing fixture: $uri\n") unless -e $uri;
    }
    my $receiver = $param->{'receiver'};
    if ($receiver) {
      $ret = $receiver->(BSHTTP::str2req($ret), $param, $xmlargs || $param->{'receiverarg'}) if $receiver;
    } elsif ($xmlargs) {
      $ret = BSUtil::fromxml($ret, $xmlargs);
    }
    return $ret;
  };
}

1; 

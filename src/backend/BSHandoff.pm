#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
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
# Handoff a HTTP request via file descriptor passing over an
# Unix Domain Socket
#

package BSHandoff;

use Socket::MsgHdr;
use Socket;
use BSRPC;
use BSServer;

sub handoffsender {
  my ($param, $s, $req, $data) = @_;
  local *FD;
  if (!$param->{'nullhandoff'}) {
    *FD = BSServer::getsocket();
  } else {
    open(FD, '+<', '/dev/null') || die("/dev/null: $!\n");
  }
  my $msgHdr = new Socket::MsgHdr(buflen => length($req), controllen => 256);
  $msgHdr->buf($req);
  $msgHdr->cmsghdr(SOL_SOCKET, SCM_RIGHTS, pack("i", fileno(FD)));
  (sendmsg(SOCK, $msgHdr) == length($req)) || die("sendmsg: $!\n");
}

sub handoff {
  my ($sockname, $path, @args) = @_;
  local *SOCK;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) || die("socket: $!\n");
  connect(SOCK, sockaddr_un($sockname)) || die("connect: $!\n");
  my $param = {
    'uri' => ref($path) ? $path->{'uri'} : $path,
    'socket' => *SOCK,
    'sender' => \&handoffsender,
  };
  my @headers;
  my $req = $BSServer::request;
  if ($req->{'headers'}->{'x-forwarded-for'}) {
    push @headers, "X-Peer: $req->{'headers'}->{'x-forwarded-for'}";
  } elsif ($req->{'headers'}->{'peer'}) {
    push @headers, "X-Peer: $req->{'headers'}->{'peer'}";
  }
  $param->{'headers'} = \@headers if @headers;
  return BSRPC::rpc($param, @args);
}

sub rpc {
  my ($sockname, $path, @args) = @_;
  local *SOCK;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) || die("socket: $!\n");
  connect(SOCK, sockaddr_un($sockname)) || die("connect: $!\n");
  my $param = {
    'uri' => ref($path) ? $path->{'uri'} : $path,
    'socket' => *SOCK,
    'sender' => \&handoffsender,
    'nullhandoff' => 1,
  };
  return BSRPC::rpc($param, @args);
}

sub receive {
  my ($fd, $newfd, $len) = @_;
  my $inHdr = Socket::MsgHdr->new(buflen => $len, controllen => 256);
  my $r = recvmsg($fd, $inHdr, 0);
  return $r unless defined $r;
  my ($level, $type, $data) = $inHdr->cmsghdr();
  die("no socket attached\n") unless $type && $type == SCM_RIGHTS;
  open($newfd, "+<&=".unpack('i', $data)) || die("socket reopen: $!\n");
  return $inHdr->buf();
}

1;

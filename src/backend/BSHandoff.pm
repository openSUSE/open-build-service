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
use BSUtil;
use BSServer;

sub handoffsender {
  my ($param, $s, $req, $data) = @_;
  my $fd;
  die("handoffsender: data arg is not supported\n") if defined $data;
  if (!$param->{'nullhandoff'}) {
    $fd = BSServer::getsocket();
  } else {
    open($fd, '+<', '/dev/null') || die("/dev/null: $!\n");
  }
  my $msgHdr = new Socket::MsgHdr(buflen => length($req), controllen => 256);
  $msgHdr->buf($req);
  $msgHdr->cmsghdr(SOL_SOCKET, SCM_RIGHTS, pack("i", fileno($fd)));
  (sendmsg($param->{'socket'}, $msgHdr) == length($req)) || die("sendmsg: $!\n");
}

sub receivefd {
  my ($fd, $len) = @_;
  my $inHdr = Socket::MsgHdr->new(buflen => $len, controllen => 256);
  my $r = recvmsg($fd, $inHdr, 0);
  return $r unless defined $r;
  my ($level, $type, $data) = $inHdr->cmsghdr();
  die("no socket attached\n") unless $type && $type == SCM_RIGHTS;
  my $newfd;
  open($newfd, "+<&=".unpack('i', $data)) || die("socket reopen: $!\n");
  return ($inHdr->buf(), $newfd);
}

sub handoff {
  my ($path, @args) = @_;
  my $req = $BSServer::request;
  my $conf = $req->{'conf'};
  my $proto = $conf->{'proto'} || 'http';
  $path = { 'uri' => $path } unless ref $path;
  my $sockpath = $path->{'handoffpath'} || $conf->{'handoffpath'};
  die("no handoff path set\n") unless $sockpath;
  my $ajaxpartition = $path->{'ajaxpartition'};
  $sockpath = ($conf->{'ajaxpartitionmap'}->{$ajaxpartition} || $sockpath) if $ajaxpartition && $conf->{'ajaxpartitionmap'} && !$path->{'handoffpath'};
  my $sock;
  socket($sock, PF_UNIX, SOCK_STREAM, 0) || die("socket: $!\n");
  connect($sock, sockaddr_un($sockpath)) || die("connect: $!\n");
  if ($proto eq 'https') {
    exit(0) if BSUtil::xfork();
  }
  my $param = {
    'uri' => $path->{'uri'},
    'socket' => $sock,
    'sender' => \&handoffsender,
  };
  $param->{'nullhandoff'} = 1 if $path->{'nullhandoff'};
  my @headers;
  if ($req->{'headers'}->{'x-forwarded-for'}) {
    push @headers, "X-Peer: $req->{'headers'}->{'x-forwarded-for'}";
  } elsif ($req->{'headers'}->{'peer'}) {
    push @headers, "X-Peer: $req->{'headers'}->{'peer'}";
  }
  $param->{'headers'} = \@headers if @headers;
  if ($proto eq 'https') {
    $param->{'ignorestatus'} = 1;
    $param->{'receiver'} = \&BSServer::reply_receiver;
    $param->{'nullhandoff'} = 1;
  }
  my $r = BSRPC::rpc($param, @args);
  if (!$path->{'noexit'}) {
    BSServer::log_slow_requests($conf, $req);
    exit(0);
  }
  return $r;
}

sub handoff_part {
  my ($ajaxpartition, $path, @args) = @_;
  return handoff({ 'uri' => $path, 'ajaxpartition' => $ajaxpartition }, @args) unless ref $path;
  local $path->{'ajaxpartition'} = $ajaxpartition;
  return handoff($path, @args);
}

sub rpc {
  my ($path, @args) = @_;
  $path = ref($path) ? { %$path } : { 'uri' => $path };
  $path->{'nullhandoff'} = 1;
  $path->{'noexit'} = 1;
  return handoff($path, @args);
}

1;

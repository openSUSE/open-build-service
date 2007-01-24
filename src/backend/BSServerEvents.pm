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
# Event based HTTP Server. Only supports GET requests.
#

package BSServerEvents;

use POSIX;
use Socket;
use Fcntl qw(:DEFAULT);
use Symbol;
use BSEvents;

use strict;

our $gev;	# our event

sub replstream_timeout {
  my ($ev) = @_;
  print "replstream timeout for $ev->{'peer'}\n";
  stream_close($ev->{'readev'}, $ev);
}

sub replrequest_timeout {
  my ($ev) = @_;
  print "replrequest timeout for $ev->{'peer'}\n";
  $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
  close($ev->{'fd'});
  close($ev->{'nfd'}) if $ev->{'nfd'};
  delete $ev->{'fd'};
  delete $ev->{'nfd'};
}

sub replrequest_write {
  my ($ev) = @_;
  my $l = length($ev->{'replbuf'});
  return unless $l;
  $l = 4096 if $l > 4096;
  my $r = syswrite($ev->{'fd'}, $ev->{'replbuf'}, $l);
  if (!defined($r)) {
    if ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK) {
      BSEvents::add($ev);
      return;
    }
    print "write error for $ev->{'peer'}: $!\n";
    $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
    close($ev->{'fd'});
    close($ev->{'nfd'}) if $ev->{'nfd'};
    return;
  }
  if ($r == length($ev->{'replbuf'})) {
    #print "done for $ev->{'peer'}\n";
    $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
    close($ev->{'fd'});
    close($ev->{'nfd'}) if $ev->{'nfd'};
    return;
  }
  $ev->{'replbuf'} = substr($ev->{'replbuf'}, $r) if $r;
  BSEvents::add($ev);
  return;
}

sub reply {
  my ($str, @hi) = @_;
  my $ev = $gev;
  # print "reply to event #$ev->{'id'}\n";
  if ($ev->{'streaming'}) {
    # already in progress, can not do much here...
    $ev->{'replbuf'} .= "\n\n$str" if defined $str;
    $ev->{'type'} = 'write';
    $ev->{'handler'} = \&replrequest_write;
    $ev->{'timeouthandler'} = \&replrequest_timeout;
    BSEvents::add($ev, $ev->{'conf'}->{'replrequest_timeout'});
    return;
  }
  if (@hi && $hi[0] =~ /^status: (\d+.*)/i) {
    $hi[0] = "HTTP/1.1 $1";
  } else {
    unshift @hi, "HTTP/1.1 200 OK";
  }
  push @hi, "Cache-Control: no-cache";
  push @hi, "Connection: close";
  push @hi, "Content-Length: ".length($str) if defined $str;
  my $data = join("\r\n", @hi)."\r\n\r\n";
  $data .= $str if defined $str;
  my $dummy = '';
  sysread($ev->{'fd'}, $dummy, 1024, 0);	# clear extra input
  $ev->{'replbuf'} = $data;
  $ev->{'type'} = 'write';
  $ev->{'handler'} = \&replrequest_write;
  $ev->{'timeouthandler'} = \&replrequest_timeout;
  BSEvents::add($ev, $ev->{'conf'}->{'replrequest_timeout'});
}

sub reply_error  {
  my ($conf, $err) = @_;
  $err ||= "unspecified error";
  $err =~ s/\n$//s;
  my $code = 404;
  my $tag = ''; 
  if ($err =~ /^(\d+)\s*([^\r\n]*)/) {
    $code = $1; 
    $tag = $2; 
  } elsif ($err =~ /^([^\r\n]+)/) {
    $tag = $1; 
  } else {
    $tag = 'Error';
  }
  if ($conf && $conf->{'errorreply'}) {
    $conf->{'errorreply'}->($err, $code, $tag);
  } else {
    reply("$err\n", "Status: $code $tag", 'Content-Type: text/plain');
  }
}

sub reply_stream {
  my ($rev, @args) = @_;
  push @args, 'Transfer-Encoding: chunked';
  unshift @args, 'Content-Type: application/octet-stream' unless grep {/^content-type:/i} @args;
  reply(undef, @args);
  my $ev = $gev;
  BSEvents::rem($ev);
  print "reply_stream $rev -> $ev\n";
  $ev->{'readev'} = $rev;
  $ev->{'handler'} = \&stream_write_handler;
  $ev->{'timeouthandler'} = \&replstream_timeout;
  $ev->{'streaming'} = 1;
  $rev->{'writeev'} = $ev;
  $rev->{'handler'} = \&stream_read_handler unless $rev->{'handler'};
  BSEvents::add($ev, 0);
  BSEvents::add($rev);	# do this last (because of "always" type)
}

sub reply_file {
  my ($fd, @args) = @_;
  my $rev = BSEvents::new('always');
  $rev->{'fd'} = $fd;
  $rev->{'makechunks'} = 1;
  reply_stream($rev, @args);
}

sub getrequest_timeout {
  my ($ev) = @_;
  print "getrequest timeout for $ev->{'peer'}\n";
  $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
  close($ev->{'fd'});
  close($ev->{'nfd'}) if $ev->{'nfd'};
}

sub getrequest {
  my ($ev) = @_;
  my $buf;
  local $gev = $ev;

  eval {
    $ev->{'reqbuf'} = '' unless exists $ev->{'reqbuf'};
    my $r;
    if ($ev->{'reqbuf'} eq '' && exists $ev->{'conf'}->{'getrequest_recvfd'}) {
      my $newfd = gensym;
      $r = $ev->{'conf'}->{'getrequest_recvfd'}->($ev->{'fd'}, $newfd, 1024);
      if (defined($r)) {
        $ev->{'nfd'} = $newfd;
        $ev->{'reqbuf'} = $r;
        $r = length($r);
      }
    } else {
      $r = sysread($ev->{'fd'}, $ev->{'reqbuf'}, 1024, length($ev->{'reqbuf'}));
    }
    if (!defined($r)) {
      if ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK) {
        BSEvents::add($ev);
        return;
      }
      print "read error for $ev->{'peer'}: $!\n";
      $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
      close($ev->{'fd'});
      close($ev->{'nfd'}) if $ev->{'nfd'};
      return;
    }
    if (!$r) {
      print "EOF for $ev->{'peer'}\n";
      $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
      close($ev->{'fd'});
      close($ev->{'nfd'}) if $ev->{'nfd'};
      return;
    }
    if ($ev->{'reqbuf'} !~ /^(.*?)\r?\n/s) {
      BSEvents::add($ev);
      return;
    }
    my ($act, $path, $vers, undef) = split(' ', $1, 4);
    die("400 No method name\n") if !$act;
    if ($vers) {
      die("501 Bad method: $act\n") if $act ne 'GET';
      if ($ev->{'reqbuf'} !~ /^(.*?)\r?\n\r?\n(.*)$/s) {
	BSEvents::add($ev);
	return;
      }
    } elsif ($act ne 'get') {
      die("501 Bad method, must be GET\n") if $act ne 'GET';
    }
    my $query_string = '';
    if ($path =~ /^(.*?)\?(.*)$/) {
      $path = $1;
      $query_string = $2;
    }
    $path =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    die("501 invalid path\n") unless $path =~ /^\//;
    my $req = {'action' => $act, 'path' => $path, 'query' => $query_string};
    my $conf = $ev->{'conf'};
    $conf->{'dispatch'}->($conf, $req);
  };
  reply_error($ev->{'conf'}, $@) if $@;
}

sub newconnect {
  my ($ev) = @_;
  #print "newconnect!\n";
  BSEvents::add($ev);
  my $newfd = gensym;
  my $peeraddr = accept($newfd, *{$ev->{'fd'}});
  return unless $peeraddr;
  fcntl($newfd, F_SETFL, O_NONBLOCK);
  my $peer = 'unknown';
  my $peerport;
  eval {
    my $peera;
    ($peerport, $peera) = sockaddr_in($peeraddr);
    $peer = inet_ntoa($peera);
  };
  my $cev = BSEvents::new('read', \&getrequest);
  $cev->{'fd'} = $newfd;
  $cev->{'peer'} = $peer;
  $cev->{'peerport'} = $peerport if $peerport;
  $cev->{'timeouthandler'} = \&getrequest_timeout;
  $cev->{'conf'} = $ev->{'conf'};
  if ($cev->{'conf'}->{'setkeepalive'}) {
    setsockopt($cev->{'fd'}, SOL_SOCKET, SO_KEEPALIVE, pack("l",1));
  }
  BSEvents::add($cev, $ev->{'conf'}->{'getrequest_timeout'});
}

sub cloneconnect {
  my (@reply) = @_;
  my $ev =  $gev;
  fcntl($ev->{'nfd'}, F_SETFL, O_NONBLOCK);
  my $nev = BSEvents::new('read', $ev->{'handler'});
  $nev->{'fd'} = $ev->{'nfd'};
  delete $ev->{'nfd'};
  $nev->{'conf'} = $ev->{'conf'};
  my $peer = 'unknown';
  eval {
    my $peername = getpeername($nev->{'fd'});
    if ($peername) {
      my ($peerport, $peera) = sockaddr_in($peername);
      $peer = inet_ntoa($peera);
    }
  };
  $nev->{'peer'} = $peer;
  BSServerEvents::reply(@reply) if @reply;
  $gev = $nev;	# switch to new event
  if ($nev->{'conf'}->{'setkeepalive'}) {
    setsockopt($nev->{'fd'}, SOL_SOCKET, SO_KEEPALIVE, pack("l",1));
  }
  return $nev;
}

sub stream_close {
  my ($ev, $wev) = @_;
  if ($ev) {
    BSEvents::rem($ev) if $ev->{'fd'} && !$ev->{'paused'};
    $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
    close $ev->{'fd'} if $ev->{'fd'};
    delete $ev->{'fd'};
    delete $ev->{'writeev'};
  }
  if ($wev) {
    BSEvents::rem($wev) if $wev->{'fd'} && !$wev->{'paused'};
    $wev->{'closehandler'}->($wev) if $wev->{'closehandler'};
    close $wev->{'fd'} if $wev->{'fd'};
    delete $wev->{'fd'};
    delete $wev->{'readev'};
  }
}

sub stream_read_handler {
  my ($ev) = @_;
  #print "stream_read_handler $ev\n";
  my $wev = $ev->{'writeev'};
  $wev->{'replbuf'} = '' unless exists $wev->{'replbuf'};
  my $r;
  if ($ev->{'makechunks'}) {
    my $b = '';
    $r = sysread($ev->{'fd'}, $b, 4096);
    $wev->{'replbuf'} .= sprintf("%X\r\n", length($b)).$b."\r\n" if defined $r;
  } else {
    $r = sysread($ev->{'fd'}, $wev->{'replbuf'}, 4096, length($wev->{'replbuf'}));
  }
  if (!defined($r)) {
    if ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK) {
      BSEvents::add($ev);
      return;
    }
    print "stream_read_handler: $!\n";
    # can't do much here, fallthrough in EOF code
  }
  if (!$r) {
    print "stream_read_handler: EOF\n";
    $ev->{'eof'} = 1;
    $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
    close $ev->{'fd'};
    delete $ev->{'fd'};
    if ($wev && $wev->{'paused'}) {
      if (length($wev->{'replbuf'})) {
        delete $wev->{'paused'};
        BSEvents::add($wev)
      } else {
        stream_close($ev, $wev);
      }
    }
    return;
  }
  if ($wev->{'paused'}) {
    delete $wev->{'paused'};
    BSEvents::add($wev);
    # check if add killed us
    return unless $ev->{'fd'};
  }
  if (length($wev->{'replbuf'}) >= 16384) {
    print "write buffer too full, throttle\n";
    $ev->{'paused'} = 1;
  } else {
    BSEvents::add($ev);
  }
}

sub stream_write_handler {
  my ($ev) = @_;
  my $rev = $ev->{'readev'};
  #print "stream_write_handler $ev (rev=$rev)\n";
  my $l = length($ev->{'replbuf'});
  return unless $l;
  $l = 4096 if $l > 4096;
  my $r = syswrite($ev->{'fd'}, $ev->{'replbuf'}, $l);
  if (!defined($r)) {
    if ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK) {
      BSEvents::add($ev);
      return;
    }
    print "stream_write_handler: $!\n";
    $ev->{'paused'} = 1;
    # support multiple writers
    if ($rev->{'writeev'} != $ev) {
      # leave reader open
      print "reader stays open\n";
      stream_close(undef, $ev);
    } else {
      stream_close($rev, $ev);
    }
    return;
  }
  $ev->{'replbuf'} = substr($ev->{'replbuf'}, $r) if $r;
  if ($rev->{'paused'} && length($ev->{'replbuf'}) <= 8192) {
    delete $rev->{'paused'};
    BSEvents::add($rev);
  }
  if (length($ev->{'replbuf'})) {
    BSEvents::add($ev);
  } else {
    $ev->{'paused'} = 1;
    stream_close($rev, $ev) if $rev->{'eof'};
  }
}

sub addserver {
  my ($fd, $conf) = @_;
  my $sockev = BSEvents::new('read', \&newconnect);
  $sockev->{'fd'} = $fd;
  $sockev->{'conf'} = $conf;
  BSEvents::add($sockev);
  return $sockev;
}

1;

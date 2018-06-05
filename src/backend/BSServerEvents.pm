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
use BSHTTP;
use BSCpio;
use Data::Dumper;

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
  delete $ev->{'requestevents'}->{$ev->{'id'}} if $ev->{'requestevents'};
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
    delete $ev->{'requestevents'}->{$ev->{'id'}} if $ev->{'requestevents'};
    return;
  }
  if ($r == length($ev->{'replbuf'})) {
    #print "done for $ev->{'peer'}\n";
    $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
    close($ev->{'fd'});
    close($ev->{'nfd'}) if $ev->{'nfd'};
    delete $ev->{'requestevents'}->{$ev->{'id'}} if $ev->{'requestevents'};
    return;
  }
  $ev->{'replbuf'} = substr($ev->{'replbuf'}, $r) if $r;
  BSEvents::add($ev);
  return;
}

sub reply {
  my ($str, @hdrs) = @_;
  my $ev = $gev;
  my $conf = $ev->{'conf'};
  # print "reply to event #$ev->{'id'}\n";
  if (!exists($ev->{'fd'})) {
    $ev->{'handler'}->($ev) if $ev->{'handler'};
    $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
    print "$str\n" if defined($str) && $str ne '';
    delete $ev->{'requestevents'}->{$ev->{'id'}} if $ev->{'requestevents'};
    return;
  }
  if ($ev->{'streaming'}) {
    # already in progress, can not do much here...
    $ev->{'replbuf'} .= "\n\n$str" if defined $str;
    $ev->{'type'} = 'write';
    $ev->{'handler'} = \&replrequest_write;
    $ev->{'timeouthandler'} = \&replrequest_timeout;
    BSEvents::add($ev, $conf->{'replrequest_timeout'});
    return;
  }
  $ev->{'request'}->{'state'} = 'replying';
  if (@hdrs && $hdrs[0] =~ /^status: (\d+.*)/i) {
    my $msg = $1;
    $msg =~ s/:/ /g;
    $hdrs[0] = "HTTP/1.1 $msg";
  } else {
    unshift @hdrs, "HTTP/1.1 200 OK";
  }
  push @hdrs, "Cache-Control: no-cache";
  push @hdrs, "Connection: close";
  push @hdrs, "Content-Length: ".length($str) if defined $str;
  my $data = join("\r\n", @hdrs)."\r\n\r\n";
  $data .= $str if defined $str;
  my $dummy = '';
  sysread($ev->{'fd'}, $dummy, 1024, 0);	# clear extra input
  $ev->{'replbuf'} = $data;
  $ev->{'type'} = 'write';
  $ev->{'handler'} = \&replrequest_write;
  $ev->{'timeouthandler'} = \&replrequest_timeout;
  BSEvents::add($ev, $conf->{'replrequest_timeout'});
}

sub reply_error  {
  my ($conf, $errstr) = @_;
  my ($err, $code, $tag, @hdrs) = BSServer::parse_error_string($conf, $errstr);
  if ($conf && $conf->{'errorreply'}) {
    $conf->{'errorreply'}->($err, $code, $tag, @hdrs);
  } else {
    reply("$err\n", "Status: $code $tag", 'Content-Type: text/plain', @hdrs);
  }
}

sub reply_stream {
  my ($rev, @hdrs) = @_;
  push @hdrs, 'Transfer-Encoding: chunked' if $rev->{'makechunks'};
  unshift @hdrs, 'Content-Type: application/octet-stream' unless grep {/^content-type:/i} @hdrs;
  reply(undef, @hdrs);
  my $ev = $gev;
  BSEvents::rem($ev);
  #print "reply_stream $rev -> $ev\n";
  $ev->{'readev'} = $rev;
  $ev->{'handler'} = \&stream_write_handler;
  $ev->{'timeouthandler'} = \&replstream_timeout;
  $ev->{'streaming'} = 1;
  $rev->{'writeev'} = $ev;
  $rev->{'handler'} ||= \&stream_read_handler;
  BSEvents::add($ev, 0);
  BSEvents::add($rev);	# do this last (because of "always" type)
}

sub reply_file {
  my ($filename, @hdrs) = @_;
  my $param = {'chunked' => 1};
  if (ref($filename) eq 'HASH' && exists($filename->{'filename'})) {
    $param = $filename;
    $filename = $filename->{'filename'};
  }
  my $fd = $filename;
  if (!ref($fd)) {
    $fd = gensym;
    open($fd, '<', $filename) || die("$filename: $!\n");
  }
  my $rev = BSEvents::new('always');
  $rev->{'fd'} = $fd;
  $rev->{'makechunks'} = 1 if $param->{'chunked'};
  $rev->{'filegrows'} = 1 if $param->{'filegrows'};
  $rev->{'maxbytes'} = $param->{'maxbytes'} if defined $param->{'maxbytes'};
  reply_stream($rev, @hdrs);
  return $rev;
}

sub reply_file_grown {
  my ($eof) = @_;
  my $ev = $gev;
  my $rev = $ev->{'readev'};
  return unless $rev && $rev->{'type'} eq 'always';
  delete $rev->{'filegrows'} if $eof;
  BSEvents::add($rev) unless $rev->{'paused'};
}

sub cpio_nextfile {
  my ($ev) = @_;

  my $data = '';
  while (1) {
    #print "cpio_nextfile\n";
    $data .= delete($ev->{'filespad'}) if defined $ev->{'filespad'};
    my $files = $ev->{'files'};
    my $filesno = defined($ev->{'filesno'}) ? $ev->{'filesno'} + 1 : 0;
    my $ent;
    if ($filesno >= @$files) {
      $ent = delete $ev->{'cpioerrors'};
      if (!$ent || $ent->{'data'} eq '') {
	$data .= BSCpio::makecpiohead();
	return $data;
      }
    } else {
      $ev->{'filesno'} = $filesno;
      $ent = $files->[$filesno];
    }
    my @s;
    my $name = $ent->{'name'};
    if ($ent->{'error'}) {
      $ev->{'cpioerrors'}->{'data'} .= "$name: $ent->{'error'}\n";
    } elsif (exists($ent->{'file'}) || exists($ent->{'filename'})) {
      my $file = exists($ent->{'file'}) ? $ent->{'file'} : $ent->{'filename'};
      my ($fd, $error) = BSCpio::openentfile($ent, $file, \@s);
      if ($error) {
        close($fd) if $fd && !ref($file);
        $ev->{'cpioerrors'}->{'data'} .= $error;
	next;
      }
      $ev->{'fd'} = $fd;
      my ($header, $pad) = BSCpio::makecpiohead($ent, \@s);
      $data .= $header;
      $ev->{'filespad'} = $pad;
      return $data;
    } else {
      $s[7] = length($ent->{'data'});
      $s[9] = $ent->{'mtime'} || time();
      my ($header, $pad) = BSCpio::makecpiohead($ent, \@s);
      $data .= "$header$ent->{'data'}";
      $ev->{'filespad'} = $pad;
    }
  }
}

sub cpio_closehandler {
  my ($ev) = @_;
  my $files = $ev->{'files'};
  my $filesno = defined($ev->{'filesno'}) ? $ev->{'filesno'} + 1 : 0;
  while ($filesno < @$files) {
    my $ent = $files->[$filesno];
    close($ent->{'file'}) if ref($ent->{'file'});
    close($ent->{'filename'}) if ref($ent->{'filename'});
    $filesno++;
  }
}

sub reply_cpio {
  my ($files, @hdrs) = @_;
  my $rev = BSEvents::new('always');
  $rev->{'files'} = $files;
  $rev->{'cpioerrors'} = { 'name' => '.errors', 'data' => '' };
  $rev->{'makechunks'} = 1;
  $rev->{'eofhandler'} = \&cpio_nextfile;
  $rev->{'closehandler'} = \&cpio_closehandler;
  unshift @hdrs, 'Content-Type: application/x-cpio';
  reply_stream($rev, @hdrs);
}

sub getrequest_timeout {
  my ($ev) = @_;
  print "getrequest timeout for $ev->{'peer'}\n";
  $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
  close($ev->{'fd'});
  close($ev->{'nfd'}) if $ev->{'nfd'};
  delete $ev->{'requestevents'}->{$ev->{'id'}} if $ev->{'requestevents'};
}

sub getrequest {
  my ($ev) = @_;
  my $buf;
  local $gev = $ev;

  my $conf = $ev->{'conf'};
  my $req = $ev->{'request'};
  my $peer = $req->{'peer'};
  eval {
    $ev->{'reqbuf'} = '' unless exists $ev->{'reqbuf'};
    my $r;
    if ($ev->{'reqbuf'} eq '' && exists $conf->{'getrequest_recvfd'}) {
      my $newfd = gensym;
      $r = $conf->{'getrequest_recvfd'}->($ev->{'fd'}, $newfd, 1024);
      if (defined($r)) {
	if (-c $newfd) {
	  close $newfd;	# /dev/null case, no handoff requested
	} else {
          $ev->{'nfd'} = $newfd;
	}
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
      print "read error for $peer: $!\n";
      $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
      close($ev->{'fd'});
      close($ev->{'nfd'}) if $ev->{'nfd'};
      delete $ev->{'requestevents'}->{$ev->{'id'}} if $ev->{'requestevents'};
      return;
    }
    if (!$r) {
      print "EOF for $peer\n";
      $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
      close($ev->{'fd'});
      close($ev->{'nfd'}) if $ev->{'nfd'};
      delete $ev->{'requestevents'}->{$ev->{'id'}} if $ev->{'requestevents'};
      return;
    }
    if ($ev->{'reqbuf'} !~ /^(.*?)\r?\n/s) {
      BSEvents::add($ev);
      return;
    }
    my ($act, $path, $vers, undef) = split(' ', $1, 4);
    die("400 No method name\n") if !$act;
    my $headers = {};
    if ($vers) {
      die("501 Bad method: $act\n") if $act ne 'GET';
      if ($ev->{'reqbuf'} !~ /^(.*?)\r?\n\r?\n(.*)$/s) {
	BSEvents::add($ev);
	return;
      }
      BSHTTP::gethead($headers, "Request: $1");
    } else {
      die("501 Bad method, must be GET\n") if $act ne 'GET';
    }
    my $query_string = '';
    if ($path =~ /^(.*?)\?(.*)$/) {
      $path = $1;
      $query_string = $2;
    }
    $path =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    die("501 invalid path\n") unless $path =~ /^\//;
    %$req = ( %$req, 'action' => $act, 'path' => $path, 'query' => $query_string, 'headers' => $headers, 'state' => 'processing' );
    # FIXME: should not use global
    local $BSServer::request = $req;
    my @r = $conf->{'dispatch'}->($conf, $req);
    if ($conf->{'stdreply'}) {
      $conf->{'stdreply'}->(@r);
    } elsif (@r && (@r != 1 || defined($r[0]))) {
      reply(@r);
    }
  };
  if ($@) {
    local $BSServer::request = $req;
    reply_error($conf, $@);
  }
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
  my $conf = $ev->{'conf'};
  my $request = { 'conf' => $conf, 'peer' => $peer, 'starttime' => time(), 'state' => 'receiving', 'server' => $ev->{'server'} };
  $request->{'peerport'} = $peerport if $peerport;
  my $nev = BSEvents::new('read', \&getrequest);
  $nev->{'request'} = $request;
  $nev->{'fd'} = $newfd;
  $nev->{'peer'} = $peer;
  $nev->{'timeouthandler'} = \&getrequest_timeout;
  $nev->{'conf'} = $conf;
  if ($conf->{'setkeepalive'}) {
    setsockopt($nev->{'fd'}, SOL_SOCKET, SO_KEEPALIVE, pack("l",1));
  }
  $nev->{'requestevents'} = $ev->{'server'}->{'requestevents'};
  $nev->{'requestevents'}->{$nev->{'id'}} = $nev;
  BSEvents::add($nev, $conf->{'getrequest_timeout'});
}

sub cloneconnect {
  my (@reply) = @_;
  my $ev = $gev;
  return $ev unless exists $ev->{'nfd'};
  fcntl($ev->{'nfd'}, F_SETFL, O_NONBLOCK);
  my $conf = $ev->{'conf'};
  my $nev = BSEvents::new('read', $ev->{'handler'});
  $nev->{'fd'} = $ev->{'nfd'};
  delete $ev->{'nfd'};
  my $nreq = { %{$ev->{'request'} || {}} };
  $nev->{'conf'} = $conf;
  $nev->{'request'} = $nreq;
  $nev->{'requestevents'} = $ev->{'requestevents'};
  my $peer = 'unknown';
  my $peerport;
  eval {
    my $peeraddr = getpeername($nev->{'fd'});
    if ($peeraddr) {
      my $peera;
      ($peerport, $peera) = sockaddr_in($peeraddr);
      $peer = inet_ntoa($peera);
    }
  };
  $nreq->{'peer'} = $peer;
  $nreq->{'peerport'} = $peerport if $peerport;
  $nev->{'peer'} = $peer;
  $nev->{'requestevents'}->{$nev->{'id'}} = $nev;
  if (@reply) {
    if ($conf->{'stdreply'}) {
      $conf->{'stdreply'}->(@reply);
    } elsif (@reply != 1 || defined($reply[0])) {
      reply(@reply);
    }
  }
  $gev = $nev;	# switch to new event
  if ($conf->{'setkeepalive'}) {
    setsockopt($nev->{'fd'}, SOL_SOCKET, SO_KEEPALIVE, pack("l",1));
  }
  return $nev;
}

sub background {
  my (@reply) = @_;
  my $ev = $gev;
  return $ev unless $ev && exists $ev->{'fd'};	# already in background?
  my $nev = BSEvents::new('never');
  for (keys %$ev) {
    $nev->{$_} = $ev->{$_} unless $_ eq 'id' || $_ eq 'handler' || $_ eq 'fd';
  }
  $nev->{'request'} = { %{$ev->{'request'}} } if $ev->{'request'};
  if (@reply) {
    if ($ev->{'conf'}->{'stdreply'}) {
      $ev->{'conf'}->{'stdreply'}->(@reply);
    } elsif (@reply != 1 || defined($reply[0])) {
      reply(@reply);
    }
  }
  $gev = $nev;	# switch to new event
  return $nev;
}

sub stream_close {
  my ($ev, $wev, $err, $werr) = @_;
  if ($ev) {
    print "$err\n" if $err;
    BSEvents::rem($ev) if $ev->{'fd'} && !$ev->{'paused'};
    $ev->{'closehandler'}->($ev, $err) if $ev->{'closehandler'};
    close $ev->{'fd'} if $ev->{'fd'};
    delete $ev->{'fd'};
    delete $ev->{'writeev'};
  }
  if ($wev) {
    print "$werr\n" if $werr;
    BSEvents::rem($wev) if $wev->{'fd'} && !$wev->{'paused'};
    $wev->{'closehandler'}->($wev, $werr) if $wev->{'closehandler'};
    close $wev->{'fd'} if $wev->{'fd'};
    delete $wev->{'fd'};
    delete $wev->{'readev'};
    delete $wev->{'requestevents'}->{$wev->{'id'}} if $wev->{'requestevents'};
  }
}

#
# read from a file descriptor (socket or file)
# - convert to chunks if 'makechunks'
# - put data into write event
# - do flow control
#

sub stream_read_handler {
  my ($ev) = @_;
  #print "stream_read_handler $ev\n";
  my $wev = $ev->{'writeev'};
  $wev->{'replbuf'} = '' unless exists $wev->{'replbuf'};
  my $r;
  if ($ev->{'fd'}) {
    my $bite = defined($ev->{'maxbytes'}) && $ev->{'maxbytes'} < 4096 ? $ev->{'maxbytes'} : 4096;
    if ($ev->{'makechunks'}) {
      my $b = '';
      $r = sysread($ev->{'fd'}, $b, $bite);
      $wev->{'replbuf'} .= sprintf("%X\r\n", length($b)).$b."\r\n" if $r;
    } else {
      $r = sysread($ev->{'fd'}, $wev->{'replbuf'}, $bite, length($wev->{'replbuf'}));
    }
    if (!defined($r)) {
      if ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK) {
        BSEvents::add($ev);
        return;
      }
      print "stream_read_handler: $!\n";
      # can't do much here, fallthrough in EOF code
    } elsif (defined($ev->{'maxbytes'})) {
      $ev->{'maxbytes'} -= $r;
      $r = 0 if $ev->{'maxbytes'} <= 0;
    }
  }
  if (!$r) {
#    print "stream_read_handler: EOF\n";
    # filegrows case: just return. we need to continue with some other trigger
    if (defined($r) && $ev->{'filegrows'} && $ev->{'type'} eq 'always' && (!defined($ev->{'maxbytes'}) || $ev->{'maxbytes'} > 0)) {
      return;
    }
    if ($ev->{'eofhandler'}) {
      close $ev->{'fd'} if $ev->{'fd'};
      delete $ev->{'fd'};
      my $data = $ev->{'eofhandler'}->($ev);
      if (defined($data) && $data ne '') {
        if ($ev->{'makechunks'}) {
	  # keep those chunks small, otherwise our receiver will choke
          while (length($data) > 4096) {
	    my $d = substr($data, 0, 4096);
            $wev->{'replbuf'} .= sprintf("%X\r\n", length($d)).$d."\r\n";
	    $data = substr($data, 4096);
          }
          $wev->{'replbuf'} .= sprintf("%X\r\n", length($data)).$data."\r\n";
	} else {
          $wev->{'replbuf'} .= $data;
	}
      }
      if ($ev->{'fd'}) {
        stream_read_handler($ev);	# redo with new fd
        return;
      }
    }
    $wev->{'replbuf'} .= "0\r\n\r\n" if $ev->{'makechunks'};
    $ev->{'eof'} = 1;
    $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
    close $ev->{'fd'} if $ev->{'fd'};
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
    # check if add() killed us
    return unless $ev->{'fd'};
  }
  if (length($wev->{'replbuf'}) >= 16384) {
    #print "write buffer too full, throttle\n";
    $ev->{'paused'} = 1;
  }
  BSEvents::add($ev) unless $ev->{'paused'};
}

#
# write to a file descriptor (socket)
# - do flow control
#

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
    # support multiple writers ($ev will be a $jev in that case)
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
  # flow control: have we reached the low water mark?
  if ($rev->{'paused'} && length($ev->{'replbuf'}) <= 8192) {
    delete $rev->{'paused'};
    BSEvents::add($rev);
    if ($rev->{'writeev'} != $ev) {
      my $wev = $rev->{'writeev'};
      if ($wev->{'paused'} && length($wev->{'replbuf'})) {
	#print "pushing old data\n";
	delete $wev->{'paused'};
	BSEvents::add($wev);
      }
    }
  }
  if (length($ev->{'replbuf'})) {
    BSEvents::add($ev);
  } else {
    $ev->{'paused'} = 1;
    stream_close($rev, $ev) if $rev->{'eof'};
  }
}

sub periodic_handler {
  my ($ev) = @_;
  my $server = $ev->{'server'};
  my $conf = $server->{'conf'};
  return unless $conf->{'periodic'};
  $conf->{'periodic'}->($conf, $server);
  BSEvents::add($ev, $conf->{'periodic_interval'} || 3) if $conf->{'periodic'};
}

# Connectivity check. We cheat here, as TCP does not provide a way to
# check if the other side can receive data. Instead we check for EOF,
# i.e. if we received a FIN. This does not work if the other side
# did only shutdown the sender (but who does that?).
sub concheck_handler {
  my ($cev) = @_;
  my $server = $cev->{'server'};
  my $requestevents = $server->{'requestevents'} || {};
  while (1) {
    my $rvec = '';
    for my $ev (values %$requestevents) {
      next unless $ev->{'fd'};
      my $req = $ev->{'request'};
      next if !$req || $req->{'state'} eq 'receiving';
      vec($rvec, fileno(*{$ev->{'fd'}}), 1) = 1;
    }
    last if $rvec eq '';
    my $nfound = select($rvec, undef, undef, 0);
    last unless $nfound;
    for my $ev (values %$requestevents) {
      next unless $ev->{'fd'};
      my $req = $ev->{'request'};
      next if !$req || $req->{'state'} eq 'receiving';
      next unless vec($rvec, fileno(*{$ev->{'fd'}}), 1);
      my $buf = '';
      my $r = sysread($ev->{'fd'}, $buf, 1024);
      next if $r;
      if (!defined($r)) {
	next if $! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK;
	print "concheck: read error for $ev->{'peer'}: $!\n";
      } else {
	print "concheck: EOF for $ev->{'peer'}\n";
      }
      $ev->{'closehandler'}->($ev) if $ev->{'closehandler'};
      close($ev->{'fd'});
      close($ev->{'nfd'}) if $ev->{'nfd'};
      delete $requestevents->{$ev->{'id'}};
      BSEvents::rem($ev);	# just in case...
    }
  }
  BSEvents::add($cev, $server->{'conf'}->{'concheck_interval'} || 6);
}

sub addserver {
  my ($fd, $conf) = @_;
  my $server = { 'starttime' => time(), 'conf' => $conf, 'requestevents' => {} };
  my $sockev = BSEvents::new('read', \&newconnect);
  $sockev->{'fd'} = $fd;
  $sockev->{'conf'} = $conf;
  $sockev->{'server'} = $server;
  BSEvents::add($sockev);
  if ($conf->{'periodic'}) {
    my $per_ev = BSEvents::new('timeout', \&periodic_handler);
    $per_ev->{'server'} = $server;
    BSEvents::add($per_ev, $conf->{'periodic_interval'} || 3);
  }
  my $con_ev = BSEvents::new('timeout', \&concheck_handler);
  $con_ev->{'server'} = $server;
  BSEvents::add($con_ev, $conf->{'concheck_interval'} || 60);
  return $sockev;
}

sub getrequestevents {
  my ($server) = @_;
  my $requestevents = $server->{'requestevents'} || {};
  return map {$requestevents->{$_}} sort {$a <=> $b} keys %$requestevents;
}

1;

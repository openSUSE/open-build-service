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
# Simple HTTP Server implementation, worker based. Each request
# generates a new process, requests can be dispatched over a
# dispatch table.
#

# global variables:
#   *MS   - master socket
#   *CLNT - client socket
#   *LCK  - lock for exclusive access to *MS

package BSServer;

use Data::Dumper;

use Socket;
use POSIX;
use Fcntl qw(:DEFAULT :flock);
BEGIN { Fcntl->import(':seek') unless defined &SEEK_SET; }
use Symbol;

use BSHTTP;
use BSUtil;

use strict;

my $server;
my $MS2;	# secondary server port
my $serverstatus_ok;

our $request;		# FIXME: should not be global

our $slot;		# put in request?

sub deamonize {
  my (@args) = @_;

  if (@args && $args[0] eq '-f') {
    my $pid = xfork();
    exit(0) if $pid;
  }
  POSIX::setsid();
  $SIG{'PIPE'} = 'IGNORE';
  $| = 1; # flush all output immediately
}

sub serveropen {
  # creates MS (=master socket) socket
  # 512 connections in the queue maximum
  # $port:
  #     reference              - port is assigned by system and is returned using this reference
  #     string starting with & - named socket according to the string (&STDOUT, &1)
  #     other string           - tcp socket on $port (assumes it is a number)
  # $user, $group:
  #     if defined, try to set appropriate UID, EUID, GID, EGID ( $<, $>, $(, $) )
  my ($port, $user, $group) = @_;
  # check if $user and $group exist on this system
  my $tcpproto = getprotobyname('tcp');
  my @ports;
  if (ref($port)) {
    @ports = ( $port );
  } else {
    @ports = split(',', $port, 2);
  }
  my $s = \*MS;
  for $port (@ports) {
    if (!ref($port) && $port =~ /^&/) {
      open($s, "<$port") || die("socket open: $!\n");
    } else {
      socket($s , PF_INET, SOCK_STREAM, $tcpproto) || die "socket: $!\n";
      setsockopt($s, SOL_SOCKET, SO_REUSEADDR, pack("l",1));
      if (ref($port)) {
        bind($s, sockaddr_in(0, INADDR_ANY)) || die "bind: $!\n";
        ($$port) = sockaddr_in(getsockname($s));
      } else {
        bind($s, sockaddr_in($port, INADDR_ANY)) || die "bind: $!\n";
      }
    }
    listen($s , 512) || die "listen: $!\n";
    $s = \*MS2 if @ports > 1;
    $MS2 = \*MS2 if @ports > 1;
  }
  BSUtil::drop_privs_to($user, $group);
  $server = { 'starttime' => time() };
}

sub serveropen_unix {
  # creates MS (=master socket) socket
  # 512 connections in the queue maximum
  # creates named socket according to $filename
  # race-condition safe (locks)
  # $user, $group:
  #     if defined, try to set appropriate UID, EUID, GID, EGID ( $<, $>, $(, $) )
  my ($filename, $user, $group) = @_;
  BSUtil::drop_privs_to($user, $group);

  # we need a lock for exclusive socket access
  mkdir_p($1) if $filename =~ /^(.*)\//;
  open(LCK, '>', "$filename.lock") || die("$filename.lock: $!\n");
  flock(LCK, LOCK_EX | LOCK_NB) || die("$filename: already in use\n");
  socket(MS, PF_UNIX, SOCK_STREAM, 0) || die("socket: $!\n");
  unlink($filename);
  bind(MS, sockaddr_un($filename)) || die("bind: $!\n");
  listen(MS , 512) || die "listen: $!\n";
}

sub getserverlock {
  return *LCK;
}

sub getserversocket {
  return *MS;
}

sub getserversocket2 {
  return $MS2;
}

sub setserversocket {
  if (defined($_[0])) {
    (*MS) = @_;
  } else {
    undef *MS;
  }
}

sub serverclose {
  close MS;
  close $MS2 if $MS2;
  undef $MS2;
  undef $server;
}

sub getsocket {
  return *CLNT;
}

sub setsocket {
  # with argument    - set current client socket
  # without argument - close it
  my $req = $BSServer::request || {};
  $req->{'peer'} = 'unknown';
  delete $req->{'peerport'};
  if (defined($_[0])) {
    (*CLNT) = @_;
  } else {
    undef *CLNT;
    return;
  }
  eval {
    my $peername = getpeername(CLNT);
    if ($peername) {
      my ($peerport, $peera);
      ($peerport, $peera) = sockaddr_in($peername);
      $req->{'peerport'} = $peerport;
      $req->{'peer'} = inet_ntoa($peera);
    }
  }
}

sub setstatus {
  my ($state, $data) = @_;
  my $slot = $BSServer::slot;
  return unless defined $slot;
  # +10 to skip time, pid, group, and extra
  return unless defined(sysseek(STA, $slot * 256 + 10, Fcntl::SEEK_SET));
  $data = pack("nZ244", $state, $data);
  syswrite(STA, $data, length($data));
}

sub serverstatus {
  my @res;
  return @res unless $serverstatus_ok;
  return @res unless defined(sysseek(STA, 0, Fcntl::SEEK_SET));
  my $sta;
  my $slot = 0;
  while ((sysread(STA, $sta, 256) || 0) == 256) {
    my ($ti, $pid, $group, $extra, $state, $data) = unpack("NNCCnZ244", $sta);
    push @res, { 'slot' => $slot, 'starttime' => $ti, 'pid' => $pid, 'state' => $state, 'data' => $data };
    $res[-1]->{'group'} = $group if $group;
    $slot++;
  }
  return @res;
}

sub serverstatus_str {
  my ($group) = @_;
  my $now = time();
  my $str = '';
  for my $s (serverstatus()) {
    my $state = $s->{'state'};
    next unless $state;
    next if defined($group) && ($s->{'group'} || 0) != $group;
    my $d = $now - $s->{'starttime'};
    if ($state == 1) {
      $state = 'F';
    } elsif ($state == 2) {
      $state = 'R';
    } else {
      $state = '?';
    }
    $state .= $s->{'group'} || '' unless defined $group;
    $str .= sprintf "%s %3d %5d %s\n", $state, $d, $s->{'pid'}, $s->{'data'};
  }
  return $str;
}

sub maxchildreached {
  my ($what, $group, $full, $data) = @_;
  if ($full) {
    BSUtil::printlog("$what limit reached");
    $data->{'start'} = time();
    $data->{'startstatus'} = serverstatus_str($group);
  } else {
    my $d = time() - $data->{'start'};
    BSUtil::printlog("$what limit ok, duration $d seconds");
    if ($d >= 3) {
      print "--- serverstatus at start:\n$data->{'startstatus'}";
      print "--- serverstatus at end:\n".serverstatus_str($group);
    }
    delete $data->{'start'};
    delete $data->{'startstatus'};
  }
}

sub server {
  my ($conf) = @_;

  $conf ||= {};
  my $maxchild = $conf->{'maxchild'};
  my $maxchild2 = $conf->{'maxchild2'};
  my $timeout = $conf->{'timeout'};
  my %chld;
  my %chld2;
  my $peeraddr;
  my $group = 0;
  my $slot;
  my $periodic_next = 0;
  my @idle;
  my $idle_next = 0;
  my $chld_full = 0;
  my $chld2_full = 0;
  my $chld_full_data = {};
  my $chld2_full_data = {};

  if ($conf->{'serverstatus'} && !$serverstatus_ok) {
    open(STA, '+>', $conf->{'serverstatus'}) || die("could not open $conf->{'serverstatus'}: $!\n");
    $serverstatus_ok = 1;
  }

  while (1) {
    my $tout = $timeout || 5;	# reap every 5 seconds
    if ($conf->{'periodic'}) {
      my $due = $periodic_next - time();
      if ($due <= 0) {
	$conf->{'periodic'}->($conf, $server);
        my $periodic_interval = $conf->{'periodic_interval'} || 3;
	$periodic_next += $periodic_interval - $due;
	$due = $periodic_interval;
      }
      $tout = $due if $tout > $due;
    }
    # listen on MS until there is an incoming connection
    my $rin = '';
    if ($MS2) {
      vec($rin, fileno(MS), 1) = 1 if !defined($maxchild) || keys(%chld) < $maxchild;
      vec($rin, fileno($MS2), 1) = 1 if !defined($maxchild2) || keys(%chld2) < $maxchild2;
    } else {
      vec($rin, fileno(MS), 1) = 1;
    }
    my $r = select($rin, undef, undef, $tout);
    if (!defined($r) || $r == -1) {
      die("select: $!\n") unless $! == POSIX::EINTR;
      $r = undef;
    }
    # now we know there is a connection on MS waiting to be accepted
    my $pid;
    if ($r) {
      my $chldp = \%chld;
      if ($MS2 && !vec($rin, fileno(MS), 1)) {
        $chldp = \%chld2;
        $peeraddr = accept(CLNT, $MS2);
	$group = 1;
      } else {
        $peeraddr = accept(CLNT, MS);
	$group = 0;
      }
      next unless $peeraddr;
      if (defined($pid = fork())) {
	$slot = @idle ? shift(@idle) : $idle_next++;
	last if $pid == 0;	# child
	$chldp->{$pid} = $slot;
      }
      close CLNT;
    }

    # log if we reached the maxchild limit
    if (defined($maxchild) && $chld_full != (keys(%chld) >= $maxchild ? 1 : 0)) {
      if (!$chld_full || !vec($rin, fileno(MS), 1)) {
        $chld_full = $chld_full ? 0 : 1;
        maxchildreached('maxchild', 0, $chld_full, $chld_full_data);
      }
    }
    if ($MS2 && defined($maxchild2) && $chld2_full != (keys(%chld2) >= $maxchild2 ? 1 : 0)) {
      if (!$chld2_full || !vec($rin, fileno($MS2), 1)) {
        $chld2_full = $chld2_full ? 0 : 1;
        maxchildreached('maxchild2', 1, $chld2_full, $chld2_full_data);
      }
    }

    # if there are already $maxchild connected, make blocking waitpid
    # otherwise make non-blocking waitpid
    while (1) {
      my $hang = 0;
      $hang = POSIX::WNOHANG if !defined($maxchild) || keys(%chld) < $maxchild;
      $hang = POSIX::WNOHANG if $MS2 && (!defined($maxchild2) || keys(%chld2) < $maxchild2);
      $pid = waitpid(-1, $hang);
      last unless $pid > 0;
      my $slot = delete $chld{$pid};
      $slot = delete $chld2{$pid} unless defined $slot;
      if (defined($slot)) {
        if ($serverstatus_ok && defined(sysseek(STA, $slot * 256, Fcntl::SEEK_SET))) {
	  syswrite(STA, "\0" x 256, 256);
	}
        if ($slot == $idle_next - 1) {
	  $idle_next--;
	} else {
	  push @idle, $slot;
	}
      }
    }
    # timeout was set in the $conf and select timeouted on this value
    return undef if !$r && defined($r) && defined($timeout);
  }

  # from now on, this is only the child process
  close MS;
  if ($MS2) {
    close $MS2;
    undef $MS2;
  }
  my $req = {
    'peer' => 'unknown',
    'conf' => $conf,
    'server' => $server,
    'starttime' => time(),
    'group' => $group,
  };
  if ($serverstatus_ok) {
    # reopen so that we do not share the file offset
    close(STA);
    if (open(STA, '+<', $conf->{'serverstatus'})) {
      $BSServer::slot = $slot;
      fcntl(STA, F_SETFD, FD_CLOEXEC);
      if (defined(sysseek(STA, $BSServer::slot * 256, Fcntl::SEEK_SET))) {
        syswrite(STA, pack("NNCCnZ244", $req->{'starttime'}, $$, $group, 0, 1, 'forked'), 256);
      }
    } else {
      undef $serverstatus_ok;
    }
  }
  $BSServer::request = $req;
  eval {
    my ($peerport, $peera) = sockaddr_in($peeraddr);
    $req->{'peerport'} = $peerport;
    $req->{'peer'} = inet_ntoa($peera);
  };

  setsockopt(CLNT, SOL_SOCKET, SO_KEEPALIVE, pack("l",1)) if $conf->{'setkeepalive'};

  # run the accept hook if configured
  if ($conf->{'accept'}) {
    eval {
      $conf->{'accept'}->($conf, $req);
    };
    reply_error($conf, $@) if $@;
  }

  if (!$conf->{'dispatch'}) {
    # the old way... please use a dispatch function in new code
    $SIG{'__DIE__'} = sub { die(@_) if $^S; reply_error($conf, $_[0]); };
    return $req;
  }

  eval {
    do {
      local $SIG{'ALRM'} = sub {print "read request timout for peer $req->{'peer'}\n" ; POSIX::_exit(0);};
      alarm(60);	# should be enough to read the request
      readrequest($req);
      alarm(0);
    };
    my @r = $conf->{'dispatch'}->($conf, $req);
    if (!$req->{'replying'}) {
      if ($conf->{'stdreply'}) {
	$conf->{'stdreply'}->(@r);
      } else {
	reply(@r);
      }
    }
  };
  return @{$req->{'returnfromserver'}} if $req->{'returnfromserver'} && !$@;
  reply_error($conf, $@) if $@;
  close CLNT;
  log_slow_requests($conf, $req) if $conf->{'slowrequestlog'};
  exit(0);
}

sub msg {
  my $peer = ($BSServer::request || {})->{'peer'};
  if (defined($peer)) {
    BSUtil::printlog("$peer: $_[0]");
  } else {
    BSUtil::printlog($_[0]);
  }
}

# write reply to CLNT
# $str: reply string
# @hdrs: http header lines, 1st line can contain status
sub reply {
  my ($str, @hdrs) = @_;

  my $req = $BSServer::request || {};
  if (@hdrs && $hdrs[0] =~ /^status: ((\d+).*)/i) {
    my $msg = $1;
    $msg =~ s/:/ /g;
    $hdrs[0] = "HTTP/1.1 $msg";
    $req->{'statuscode'} ||= $2;
  } else {
    unshift @hdrs, "HTTP/1.1 200 OK";
    $req->{'statuscode'} ||= 200;
  }
  push @hdrs, "Cache-Control: no-cache";
  push @hdrs, "Connection: close";
  push @hdrs, "Content-Length: ".length($str) if defined($str);
  my $data = join("\r\n", @hdrs)."\r\n\r\n";
  $data .= $str if defined $str;

#  if ($replying && $replying == 2) {
#    # Already replying. As we're in chunked mode, we can attach
#    # the error as chunk header.
#    $hdrs[0] =~ s/^.*? /Status: /;
#    $data = "0\r\n$hdrs[0]\r\n\r\n";
#  }

  # discard the body so that the client gets our answer instead
  # of a sigpipe.
  if (exists($req->{'__data'}) && !$req->{'__eof'} && !$req->{'need_continue'}) {
    eval { discard_body() };
  }

  # work around linux tcp implementation problem, the read side
  # must be empty otherwise a tcp-reset is done when we close
  # the socket, leading to data loss
  fcntl(CLNT, F_SETFL,O_NONBLOCK);
  my $dummy = '';
  1 while sysread(CLNT, $dummy, 1024, 0);
  fcntl(CLNT, F_SETFL,0);

  my $l;
  while (length($data)) {
    $l = syswrite(CLNT, $data, length($data));
    die("write error: $!\n") unless $l;
    $req->{'replying'} = 1;
    $data = substr($data, $l);
  }
}

# "parse" error string into code and tag
sub parse_error_string {
  my ($conf, $err) = @_;

  $err ||= "unspecified error";
  $err =~ s/\n$//s;
  my $code = 400;
  my $tag = '';
  if ($err =~ /^(\d+)\s+([^\r\n]*)/) {
    $code = $1;
    $tag = $2;
  } elsif ($err =~ /^([^\r\n]+)/) {
    $tag = $1;
    $code = 500 if $tag =~ /Too many open files/;
    $code = 500 if $tag =~ /No space left on device/;
    $code = 500 if $tag =~ /Not enough space/;
    $code = 500 if $tag =~ /Resource temporarily unavailable/;
  } else {
    $tag = 'Error';
  }
  my @hdrs;
  push @hdrs, "WWW-Authenticate: $conf->{'wwwauthenticate'}" if $code == 401 && $conf && $conf->{'wwwauthenticate'};
  return ($err, $code, $tag, @hdrs);
}

sub log_slow_requests {
  my ($conf, $req) = @_;
  return unless $req && $conf->{'slowrequestlog'} && $conf->{'slowrequestthr'} && $req->{'starttime'};
  my $duration = time() - $req->{'starttime'};
  return unless $duration >= $conf->{'slowrequestthr'};
  my $msg = sprintf("%s: %3ds %-7s %-22s %s%s\n", BSUtil::isotime($req->{'starttime'}), $duration, "[$$]",
      "$req->{'action'} ($req->{'peer'})", $req->{'path'}, ($req->{'query'}) ? "?$req->{'query'}" : '');
  eval { BSUtil::appendstr($conf->{'slowrequestlog'}, $msg) };
}

sub reply_error  {
  my ($conf, $errstr) = @_;
  my ($err, $code, $tag, @hdrs) = parse_error_string($conf, $errstr);
  # send reply through custom function or standard reply
  eval {
    if ($conf && $conf->{'errorreply'}) {
      $conf->{'errorreply'}->($err, $code, $tag, @hdrs);
    } else {
      reply("$err\n", "Status: $code $tag", 'Content-Type: text/plain', @hdrs);
    }
  };
  my $reply_err = $@;
  close CLNT;
  my $req = $BSServer::request || {};
  $req->{'statuscode'} ||= $code;
  log_slow_requests($conf, $req) if $conf->{'slowrequestlog'};
  if ($reply_err) {
    warn("$req->{'peer'} [$$]: $err\n");
    $err = "reply_error: $reply_err";
  }
  die("$req->{'peer'} [$$]: $err\n");
}

sub done {
  my ($noexit) = @_;
  close CLNT;
  exit(0) unless $noexit;
}

sub getpeerdata {
  my $peername = getpeername(CLNT);
  return (undef, undef) unless $peername;
  my ($port, $addr) = sockaddr_in($peername);
  $addr = inet_ntoa($addr) if $addr;
  return ($port, $addr);
}

sub readrequest {
  my ($req) = @_;
  my $qu = '';
  my $request;
  # read first query line
  while (1) {
    if ($qu =~ /^(.*?)\r?\n/s) {
      $request = $1;
      last;
    }
    die($qu eq '' ? "empty query\n" : "received truncated query\n") if !sysread(CLNT, $qu, 1024, length($qu));
  }
  my ($act, $path, $vers, undef) = split(' ', $request, 4);
  my $rawheaders;
  die("400 No method name\n") if !$act;
  if ($vers) {
    die("501 Bad method: $act\n") if $act ne 'GET' && $act ne 'HEAD' && $act ne 'POST' && $act ne 'PUT' && $act ne 'DELETE' && $act ne 'PATCH';
    # read in all headers
    while ($qu !~ /^(.*?)\r?\n\r?\n(.*)$/s) {
      die("501 received truncated query\n") if !sysread(CLNT, $qu, 1024, length($qu));
    }
    $qu =~ /^(.*?)\r?\n\r?\n(.*)$/s;	# redo regexp to work around perl bug
    $qu = $2;
    $rawheaders = "Request: $1";	# put 1st line of http request into $headers{'request'}
  } else {
    # no version -> HTTP 0.9 request
    die("501 Bad method, must be GET\n") if $act ne 'GET';
    $qu = '';
  }
  my $query_string = '';
  if ($path =~ /^(.*?)\?(.*)$/) {
    $path = $1;
    $query_string = $2;
  }
  $path =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;	# unescape path
  die("501 invalid path\n") unless $path =~ /^\//s; # forbid relative paths
  my %headers;
  BSHTTP::gethead(\%headers, $rawheaders);
  $req->{'action'} = $act;
  $req->{'path'} = $path;
  $req->{'query'} = $query_string;
  $req->{'headers'} = \%headers;
  $req->{'rawheaders'} = $rawheaders;
  if ($act eq 'POST' || $act eq 'PUT' || $act eq 'PATCH') {
    # send HTTP 1.1's 100-continue answer if requested by the client
    if ($headers{'expect'}) {
      die("417 unknown expect\n") unless lc($headers{'expect'}) eq '100-continue';
      $req->{'need_continue'} = 1;
    }

    my $transfer_encoding = lc($headers{'transfer-encoding'} || '');
    if ($act eq 'POST' && $headers{'content-type'} && lc($headers{'content-type'}) eq 'application/x-www-form-urlencoded') {
      die("cannot do x-www-form-urlencoded with chunks\n") if $transfer_encoding eq 'chunked';
      # form-urlencoded, read body and append to query string
      send_continue() if $req->{'need_continue'};
      my $cl = $headers{'content-length'} || 0;
      while (length($qu) < $cl) {
        sysread(CLNT, $qu, $cl - length($qu), length($qu)) || die("400 Truncated body\n");
      }
      $query_string .= '&' if $cl && $query_string ne '';
      $query_string .= substr($qu, 0, $cl);
      $req->{'query'} = $query_string;
    } elsif (defined($headers{'content-length'}) || $transfer_encoding eq 'chunked') {
      $req->{'__data'} = $qu;
    }
  }
}

sub swrite {
  BSHTTP::swrite(\*CLNT, @_);
}

sub header {
  my $req = $BSServer::request || {};
  return ($req->{'headers'} || {})->{lc($_[0])};
}

sub have_content {
  my $req = $BSServer::request || {};
  return exists($req->{'__data'}) ? 1 : 0;
}

sub get_content_type {
  die("get_content_type: no content attached\n") unless have_content();
  return header('content-type');
}


###########################################################################

sub send_continue {
  my $req = $BSServer::request;
  return unless delete $req->{'need_continue'};
  my $data = "HTTP/1.1 100 continue\r\n\r\n";
  while (length($data)) {
    my $l = syswrite(CLNT, $data, length($data));
    die("write error: $!\n") unless $l;
    $data = substr($data, $l);
  }
}

sub discard_body {
  my $req = $BSServer::request;
  return unless exists($req->{'__data'}) && !$req->{'__eof'};
  1 while read_data(8192) ne '';
}

###########################################################################

sub read_file {
  my ($filename, @args) = @_;
  die("read_file: no content attached\n") unless have_content();
  my $req = $BSServer::request;
  send_continue() if $req->{'need_continue'};
  local $req->{'__socket'} = \*CLNT;
  return BSHTTP::file_receiver($req, {'filename' => $filename, @args});
}

sub read_cpio {
  my ($dirname, @args) = @_;
  die("read_cpio: no content attached\n") unless have_content();
  my $req = $BSServer::request;
  send_continue() if $req->{'need_continue'};
  local $req->{'__socket'} = \*CLNT;
  return BSHTTP::cpio_receiver($req, {'directory' => $dirname, @args});
}

sub read_data {
  my ($maxl, $exact) = @_;
  die("read_data: no content attached\n") unless have_content();
  my $req = $BSServer::request;
  send_continue() if $req->{'need_continue'};
  local $req->{'__socket'} = \*CLNT;
  return BSHTTP::read_data($req, $maxl, $exact);
}

###########################################################################

sub reply_cpio {
  my ($files, @hdrs) = @_;
  my $req = $BSServer::request || {};
  reply(undef, 'Content-Type: application/x-cpio', 'Transfer-Encoding: chunked', @hdrs);
  $req->{'replying'} = 2;
  BSHTTP::cpio_sender({'cpiofiles' => $files, 'chunked' => 1}, \*CLNT);
  swrite("0\r\n\r\n");
}

sub reply_file {
  my ($file, @hdrs) = @_;
  my $req = $BSServer::request || {};
  my $chunked;
  $chunked = 1 if grep {/^transfer-encoding:\s*chunked/i} @hdrs;
  my $cl = (grep {/^content-length:/i} @hdrs)[0];
  if (!$cl && !$chunked) {
    # detect file size
    if (!ref($file)) {
      my $fd = gensym;
      open($fd, '<', $file) || die("$file: $!\n");
      $file = $fd;
    }
    if (-f $file) {
      my $size = -s $file;
      $cl = "Content-Length: $size";
      push @hdrs, $cl;
    } else {
      push @hdrs, 'Transfer-Encoding: chunked';
      $chunked = 1;
    }
  }
  unshift @hdrs, 'Content-Type: application/octet-stream' unless grep {/^content-type:/i} @hdrs;
  reply(undef, @hdrs);
  $req->{'replying'} = 2 if $chunked;
  my $param = {'filename' => $file};
  $param->{'bytes'} = $1 if $cl && $cl =~ /(\d+)/;	# limit to content length
  $param->{'chunked'} = 1 if $chunked;
  BSHTTP::file_sender($param, \*CLNT);
  swrite("0\r\n\r\n") if $chunked;
}

sub reply_receiver {
  my ($req, $param) = @_;

  my $replyreq = $BSServer::request || {};
  my $hdr = $req->{'headers'};
  $param->{'reply_receiver_called'} = 1;
  my $st = $hdr->{'status'};
  my $ct = $hdr->{'content-type'} || 'text/plain';
  my $cl = $hdr->{'content-length'};
  my $chunked;
  $chunked = 1 if $hdr->{'transfer-encoding'} && lc($hdr->{'transfer-encoding'}) eq 'chunked';
  my @hdrs;
  push @hdrs, "Status: $st" if $st;
  push @hdrs, "Content-Type: $ct";
  push @hdrs, "Content-Length: $cl" if defined($cl) && !$chunked;
  push @hdrs, 'Transfer-Encoding: chunked' if $chunked;
  if ($param->{'reply_receiver_forward_hdrs'}) {
    push @hdrs, BSHTTP::forwardheaders($req, 'status', 'content-type', 'content-length', 'transfer-encoding', 'cache-control', 'connection');
  }
  reply(undef, @hdrs);
  $replyreq->{'replying'} = 2 if $chunked;
  while(1) {
    my $data = BSHTTP::read_data($req, 8192);
    last unless defined($data) && $data ne '';
    swrite($data, $chunked);
  }
  swrite("0\r\n\r\n") if $chunked;
}

###########################################################################

# sender (like file_sender in BSHTTP) that forwards received data

sub forward_sender {
  my ($param, $sock) = @_;
  my $data;
  while (($data = read_data(8192)) ne '') {
    BSHTTP::swrite($sock, $data, $param->{'chunked'});
  }
  return '';
}

1;

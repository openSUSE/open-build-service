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

#   $peer - address:port of connected client

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

my $MS2;	# secondary server port

# FIXME: store in request and make request available
our $request;
our $peer;
our $peerport;
our $slot;
our $forwardedfor;
our $replying;	# we're sending the answer (2 == in chunked mode)

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
}

sub getsocket {
  return *CLNT;
}

sub setsocket {
  # with argument    - set current client socket
  # without argument - close it
  $peer = 'unknown';
  if (defined($_[0])) {
    (*CLNT) = @_;
  } else {
    undef *CLNT;
    return;
  }
  eval {
    my $peername = getpeername(CLNT);
    if ($peername) {
      my $peera;
      ($peerport, $peera) = sockaddr_in($peername);
      $peer = inet_ntoa($peera);
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
  return @res unless defined $BSServer::slot;
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
  my $periodic_next = 0;
  my @idle;
  my $idle_next = 0;

  if ($conf->{'serverstatus'}) {
    open(STA, '>', $conf->{'serverstatus'});
  }

  while (1) {
    my $tout = $timeout || 5;
    if ($conf->{'periodic'}) {
      my $due = $periodic_next - time();
      if ($due <= 0) {
	$conf->{'periodic'}->($conf);
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
      vec($rin, fileno($MS2), 1) = 1 if !defined($maxchild2) || keys(%chld2) < $maxchild;
    } else {
      vec($rin, fileno(MS), 1) = 1;
    }
    my $r = select($rin, undef, undef, $tout);
    if (!defined($r) || $r == -1) {
      next if $! == POSIX::EINTR;
      die("select: $!\n");
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
      my $slot = @idle ? shift(@idle) : $idle_next++;
      $pid = fork();
      if (defined($pid)) {
        if ($pid == 0) {
	  # child
	  $BSServer::slot = $slot if $conf->{'serverstatus'};
	  last;
	}
        $chldp->{$pid} = $slot;
      }
      close CLNT;
    }
    # if there are already $maxchild connected, make blocking waitpid
    # otherwise make non-blocking waitpid
    while (1) {
      my $hang = 0;
      $hang = POSIX::WNOHANG if !defined($maxchild) || keys(%chld) < $maxchild;
      $hang = POSIX::WNOHANG if $MS2 && (!defined($maxchild2) || keys(%chld) < $maxchild2);
      $pid = waitpid(-1, $hang);
      last unless $pid > 0;
      my $slot = delete $chld{$pid};
      $slot = delete $chld2{$pid} unless defined $slot;
      if (defined($slot)) {
        if ($conf->{'serverstatus'} && defined(sysseek(STA, $slot * 256, Fcntl::SEEK_SET))) {
	  syswrite(STA, "\0" x 256, 256);
	}
        if ($slot == $idle_next - 1) {
	  $idle_next--;
	} else {
	  push @idle, $slot;
	}
      }
    }
    # timeout was set in the $conf and select timeouted on this value. There was no new connection -> exit.
    return 0 if !$r && defined $timeout;
  }
  # from now on, this is only the child process
  close MS;
  if ($MS2) {
    close $MS2;
    undef $MS2;
  }
  if ($conf->{'serverstatus'}) {
    close(STA);
    if (open(STA, '+<', $conf->{'serverstatus'})) {
      fcntl(STA, F_SETFD, FD_CLOEXEC);
      if (defined(sysseek(STA, $BSServer::slot * 256, Fcntl::SEEK_SET))) {
        syswrite(STA, pack("NNCCnZ244", time(), $$, $group, 0, 1, 'forked'), 256);
      }
    } else {
      undef $BSServer::slot;
    }
  }
  $peer = 'unknown';
  eval {
    my $peera;
    ($peerport, $peera) = sockaddr_in($peeraddr);
    $peer = inet_ntoa($peera);
  };

  setsockopt(CLNT, SOL_SOCKET, SO_KEEPALIVE, pack("l",1)) if $conf->{'setkeepalive'};
  if ($conf->{'accept'}) {
    eval {
      $conf->{'accept'}->($conf, $peer);
    };
    reply_error($conf, $@) if $@;
  }
  if ($conf->{'dispatch'}) {
    eval {
      my $req;
      do {
        local $SIG{'ALRM'} = sub {POSIX::_exit(0);};
        alarm(60);	# should be enough to read the request
        $req = readrequest();
        alarm(0);
      };
      $conf->{'dispatch'}->($conf, $req);
    };
    reply_error($conf, $@) if $@;
    close CLNT;
    exit(0);
  }
  $SIG{'__DIE__'} = sub { die(@_) if $^S; reply_error($conf, $_[0]); };
  return 1;
}

sub msg {
  my @lt = localtime(time);
  if (defined($peer)) {
    printf "%04d-%02d-%02d %02d:%02d:%02d: %s: %s\n", $lt[5] + 1900, $lt[4] + 1, @lt[3,2,1,0], $peer, $_[0];
  } else {
    printf "%04d-%02d-%02d %02d:%02d:%02d: %s\n", $lt[5] + 1900, $lt[4] + 1, @lt[3,2,1,0], $_[0];
  }
}

# write reply to CLNT
# $str: reply string
# @hi: http header lines, 1st line can contain status
sub reply {
  my ($str, @hi) = @_;

  if (@hi && $hi[0] =~ /^status: (\d+.*)/i) {
    my $msg = $1;
    $msg =~ s/:/ /g;
    $hi[0] = "HTTP/1.1 $msg";
  } else {
    unshift @hi, "HTTP/1.1 200 OK";
  }
  push @hi, "Cache-Control: no-cache";
  push @hi, "Connection: close";
  push @hi, "Content-Length: ".length($str) if defined($str);
  my $data = join("\r\n", @hi)."\r\n\r\n";
  $data .= $str if defined $str;

#  if ($replying && $replying == 2) {
#    # Already replying. As we're in chunked mode, we can attach
#    # the error as chunk header.
#    $hi[0] =~ s/^.*? /Status: /;
#    $data = "0\r\n$hi[0]\r\n\r\n";
#  }

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
    $replying = 1;
    $data = substr($data, $l);
  }
}

sub reply_error  {
  my ($conf, $err) = @_; 
  $err ||= "unspecified error";
  $err =~ s/\n$//s;
  my $code = 400;
  my $tag = '';
  # "parse" err string 
  if ($err =~ /^(\d+)\s+([^\r\n]*)/) {
    $code = $1;
    $tag = $2;
  } elsif ($err =~ /^([^\r\n]+)/) {
    $tag = $1;
  } else {
    $tag = 'Error';
  }
  # send reply through custom function or standard reply
  if ($conf && $conf->{'errorreply'}) {
    $conf->{'errorreply'}->($err, $code, $tag);
  } else {
    reply("$err\n", "Status: $code $tag", 'Content-Type: text/plain');
  }
  close CLNT;
  die("$peer: $err\n");
}

my $post_hdrs;

sub done {
  close CLNT;
  exit(0);
}

sub getpeerdata {
  my $peername = getpeername(CLNT);
  return (undef, undef) unless $peername;
  my ($port, $addr) = sockaddr_in($peername);
  $addr = inet_ntoa($addr) if $addr;
  return ($port, $addr);
}

sub gethead {
  # parses http header and fills hash
  # $h: reference to the hash to be filled
  # $t: http header as string
  my ($h, $t) = @_;

  my ($field, $data);
  for (split(/[\r\n]+/, $t)) {
    next if $_ eq '';
    if (/^[ \t]/) {
      next unless defined $field;
      s/^\s*/ /;
      $h->{$field} .= $_;
    } else {
      ($field, $data) = split(/\s*:\s*/, $_, 2);
      $field =~ tr/A-Z/a-z/;
      if ($h->{$field} && $h->{$field} ne '') {
        $h->{$field} = $h->{$field}.','.$data;
      } else {
        $h->{$field} = $data;
      }
    }
  }
}

sub parse_cgi {
  # $req:
  #      the part of URI after ?
  # $multis:
  #      hash of separators
  #      key does not exist - multiple cgi values are not allowed
  #      key is undef - multiple cgi values are put into array
  #      key is - then value is used as separator between cgi values
  my ($req, $multis, $singles) = @_;

  my $query_string = $req->{'query'};
  my %cgi;
  my @query_string = split('&', $query_string);
  while (@query_string) {
    my ($name, $value) = split('=', shift(@query_string), 2);
    next unless defined $name && $name ne '';
    # convert from URI format
    $name  =~ tr/+/ /;
    $name  =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    if (defined($value)) {
      # convert from URI format
      $value =~ tr/+/ /;
      $value =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    } else {
      $value = 1;	# assume boolean
    }
    if ($multis && exists($multis->{$name})) {
      if (defined($multis->{$name})) {
        if (exists($cgi{$name})) {
	  $cgi{$name} .= "$multis->{$name}$value";
        } else {
          $cgi{$name} = $value;
        }
      } else {
        push @{$cgi{$name}}, $value;
      }
    } elsif ($singles && $multis && !exists($singles->{$name}) && exists($multis->{'*'})) {
      if (defined($multis->{'*'})) {
        if (exists($cgi{$name})) {
	  $cgi{$name} .= "$multis->{'*'}$value";
        } else {
          $cgi{$name} = $value;
        }
      } else {
        push @{$cgi{$name}}, $value;
      }
    } else {
      die("parameter '$name' set multiple times\n") if exists $cgi{$name};
      $cgi{$name} = $value;
    }
  }
  return \%cgi;
}

# return only the singles from a query
sub parse_cgi_singles {
  my ($req) = @_;
  my $query_string = $req->{'query'};
  my %cgi;
  for my $qu (split('&', $query_string)) {
    my ($name, $value) = split('=', $qu, 2);
    $name  =~ tr/+/ /;
    $name  =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    if (exists $cgi{$name}) {
      $cgi{$name} = undef;
      next;
    }
    $value = 1 unless defined $value;
    $value =~ tr/+/ /;
    $value =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    $cgi{$name} = $value;
  }
  for (keys %cgi) {
    delete $cgi{$_} unless defined $cgi{$_};
  }
  return \%cgi;
}

sub readrequest {
  my ($qu) = @_;
  $qu = '' unless defined $qu;
  undef $post_hdrs;
  my $req;
  # read first query line
  while (1) {
    if ($qu =~ /^(.*?)\r?\n/s) {
      $req = $1;
      last;
    }
    die($qu eq '' ? "empty query\n" : "received truncated query\n") if !sysread(CLNT, $qu, 1024, length($qu));
  }
  my ($act, $path, $vers, undef) = split(' ', $req, 4);
  my %headers;
  die("400 No method name\n") if !$act;
  if ($vers) {
    die("501 Bad method: $act\n") if $act ne 'GET' && $act ne 'HEAD' && $act ne 'POST' && $act ne 'PUT' && $act ne 'DELETE';
    # read in all headers
    while ($qu !~ /^(.*?)\r?\n\r?\n(.*)$/s) {
      die("501 received truncated query\n") if !sysread(CLNT, $qu, 1024, length($qu));
    }
    $qu =~ /^(.*?)\r?\n\r?\n(.*)$/s;	# redo regexp to work around perl bug
    $qu = $2;
    gethead(\%headers, "Request: $1");	# put 1st line of http request into $headers{'request'}
  } else {
    # no version -> HTTP 0.9 request
    die("501 Bad method, must be GET\n") if $act ne 'GET';
    $qu = '';
  }
  $forwardedfor = $headers{'x-forwarded-for'};
  my $query_string = '';
  if ($path =~ /^(.*?)\?(.*)$/) {
    $path = $1;
    $query_string = $2;
  }
  $path =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;	# unescape path
  die("501 invalid path\n") unless $path =~ /^\//s; # forbid relative paths
  my $res = {};
  $res->{'action'} = $act;
  $res->{'path'} = $path;
  $res->{'query'} = $query_string;
  $res->{'headers'} = \%headers;
  if ($act eq 'POST' || $act eq 'PUT') {
    # send HTTP 1.1's 100-continue answer if requested by the client
    if ($headers{'expect'}) {
      die("417 unknown expect\n") unless lc($headers{'expect'}) eq '100-continue';
      my $data = "HTTP/1.1 100 continue\r\n\r\n";
      while (length($data)) {
        my $l = syswrite(CLNT, $data, length($data));
        die("write error: $!\n") unless $l;
        $data = substr($data, $l);
      }
    }
    
    if ($act eq 'PUT' || !$headers{'content-type'} || lc($headers{'content-type'}) ne 'application/x-www-form-urlencoded') {
      $headers{'__data'} = $qu;
      $post_hdrs = \%headers; # $post_hdrs is global (module local) variable
      return $res;
    }
    my $cl = $headers{'content-length'} || 0;
    while (length($qu) < $cl) {
      sysread(CLNT, $qu, $cl - length($qu), length($qu)) || die("400 Truncated body\n");
    }
    $query_string .= '&' if $query_string ne '';
    $query_string .= substr($qu, 0, $cl);
    $res->{'query'} = $query_string;
    $qu = substr($qu, $cl);
  }
  return $res;
}

sub swrite {
  BSHTTP::swrite(\*CLNT, $_[0]);
}

sub get_content_type {
  die("get_content_type: invalid request\n") unless $post_hdrs;
  return $post_hdrs->{'content-type'};
}

sub header {
  die("header: invalid request\n") unless $post_hdrs;
  return $post_hdrs->{$_[0]};
}

sub have_content {
  return $post_hdrs ? 1 : 0;
}

###########################################################################

sub read_file {
  my ($fn, @args) = @_;
  die("read_file: invalid request\n") unless $post_hdrs;
  $post_hdrs->{'__socket'} = \*CLNT;
  my $res = BSHTTP::file_receiver($post_hdrs, {'filename' => $fn, @args});
  delete $post_hdrs->{'__socket'};
  return $res;
}

sub read_cpio {
  my ($dn, @args) = @_;
  die("read_cpio: invalid request\n") unless $post_hdrs;
  $post_hdrs->{'__socket'} = \*CLNT;
  my $res = BSHTTP::cpio_receiver($post_hdrs, {'directory' => $dn, @args});
  delete $post_hdrs->{'__socket'};
  return $res;
}

sub read_data {
  my ($maxl, $exact) = @_;
  die("read_data: invalid request\n") unless $post_hdrs;
  $post_hdrs->{'__socket'} = \*CLNT;
  my $res = BSHTTP::read_data($post_hdrs, $maxl, $exact);
  delete $post_hdrs->{'__socket'};
  return $res;
}

###########################################################################

sub reply_cpio {
  my ($files, @args) = @_;
  reply(undef, 'Content-Type: application/x-cpio', 'Transfer-Encoding: chunked', @args);
  $replying = 2;
  BSHTTP::cpio_sender({'cpiofiles' => $files, 'chunked' => 1}, \*CLNT);
  BSHTTP::swrite(\*CLNT, "0\r\n\r\n");
}

sub reply_file {
  my ($file, @args) = @_;
  my $chunked;
  $chunked = 1 if grep {/^transfer-encoding:\s*chunked/i} @args;
  my @cl = grep {/^content-length:/i} @args;
  if (!@cl && !$chunked) {
    # detect file size
    if (!ref($file)) {
      my $fd = gensym;
      open($fd, '<', $file) || die("$file: $!\n");
      $file = $fd;
    }
    if (-f $file) {
      my $size = -s $file;
      @cl = ("Content-Length: $size");
      push @args, $cl[0];
    } else {
      push @args, 'Transfer-Encoding: chunked';
      $chunked = 1;
    }
  }
  unshift @args, 'Content-Type: application/octet-stream' unless grep {/^content-type:/i} @args;
  reply(undef, @args);
  $replying = 2 if $chunked;
  my $param = {'filename' => $file};
  $param->{'bytes'} = $1 if @cl && $cl[0] =~ /(\d+)/;
  $param->{'chunked'} = 1 if $chunked;
  BSHTTP::file_sender($param, \*CLNT);
  BSHTTP::swrite(\*CLNT, "0\r\n\r\n") if $chunked;
}

sub reply_receiver {
  my ($hdr, $param) = @_;

  $param->{'reply_receiver_called'} = 1;
  my @args;
  my $st = $hdr->{'status'};
  my $ct = $hdr->{'content-type'} || 'text/plain';
  my $cl = $hdr->{'content-length'};
  my $chunked;
  $chunked = 1 if $hdr->{'transfer-encoding'} && lc($hdr->{'transfer-encoding'}) eq 'chunked';
  push @args, "Status: $st" if $st; 
  push @args, "Content-Type: $ct";
  push @args, "Content-Length: $cl" if defined($cl) && !$chunked;
  push @args, 'Transfer-Encoding: chunked' if $chunked;
  reply(undef, @args); 
  $replying = 2 if $chunked;
  while(1) {
    my $data = BSHTTP::read_data($hdr, 8192);
    last unless defined($data) && $data ne '';
    $data = sprintf("%X\r\n", length($data)).$data."\r\n" if $chunked;
    swrite($data);
  }
  swrite("0\r\n\r\n") if $chunked;
}

###########################################################################

# sender (like file_sender in BSHTTP) that forwards received data

sub forward_sender {
  return read_data(8192);
}

###########################################################################

sub dispatch_checkcgi {
  my ($cgi, @known) = @_;
  my %known = map {$_ => 1} @known;
  my @bad = grep {!$known{$_}} keys %$cgi;
  die("unknown parameter '".join("', '", @bad)."'\n") if @bad;
}

sub compile_dispatches {
  my ($disps, $verifyers, $callfunction) = @_;
  my @disps = @$disps;
  $verifyers ||= {};
  my @out;
  while (@disps) {
    my $p = shift @disps;
    my $f = shift @disps;
    my $needsauth;
    my $cgisingles;
    if ($p =~ /^!([^\/\s]*)\s*(.*?)$/) {
      $needsauth = $1 || 'auth';
      $p = $2;
    }
    if ($p eq '/') {
      my $cpld = [ qr/^(?:GET|HEAD|POST):\/$/ ];
      $cpld->[2] = $needsauth eq '-' ? undef : $needsauth if $needsauth;
      push @out, $cpld, $f;
      next;
    }
    my @cgis = split(' ', $p);
    s/%([a-fA-F0-9]{2})/chr(hex($1))/ge for @cgis;
    $p = shift @cgis;
    my @p = split('/', $p, -1);
    my $code = "my (\@args);\n";
    my $code2 = '';
    my $num = 1;
    my @args;
    my $known = '';
    for my $pp (@p) {
      if ($pp =~ /^\$(.*)$/) {
        my $var = $1;
        my $vartype = $var;
	($var, $vartype) = ($1, $2) if $var =~ /^(.*):(.*)/;
        die("no verifyer for $vartype\n") unless $vartype eq '' || $verifyers->{$vartype};
        $pp = "([^\\/]*)";
        $code .= "\$cgi->{'$var'} = \$$num;\n";
        $code2 .= "\$verifyers->{'$vartype'}->(\$cgi->{'$var'});\n" if $vartype ne '';
	push @args, $var;
	$known .= ", '$var'";
        $num++;
      } else {
        $pp = "\Q$pp\E";
      }
    }
    $p[0] .= ".*" if @p == 1 && $p[0] =~ /^[A-Z]*\\:$/;
    $p[0] = '[^:]*:.*' if $p[0] eq '\\:.*';
    $p[0] = "(?:GET|HEAD|POST):$p[0]" if $p[0] !~ /:/;
    $p[-1] = '.*' if $p[-1] eq '\.\.\.';
    $p[-1] = '(.*)' if $p[-1] eq "([^\\/]*)" && $args[-1] eq '...';
    my $multis = '';
    my $singles = '';
    my $hasstar;
    for my $pp (@cgis) {
      my ($arg, $qual) = (0, '{1}');
      $arg = 1 if $pp =~ s/^\$//;
      $qual = $1 if $pp =~ s/([+*?])$//;
      my $var = $pp;
      if ($var =~ /^(.*)=(.*)$/) {
	$cgisingles ||= {};
	$cgisingles->{$1} = $2;
	$singles .= ', ' if $singles ne '';
	$singles .= "'$1' => undef";
	$known .= ", '$1'";
	next;
      }
      my $vartype = $var;
      ($var, $vartype) = ($1, $2) if $var =~ /^(.*):(.*)/;
      die("no verifyer for $vartype\n") unless $vartype eq '' || $verifyers->{$vartype};
      $code2 .= "die(\"parameter '$var' is missing\\n\") unless exists \$cgi->{'$var'};\n" if $qual ne '*' && $qual ne '?';
      $hasstar = 1 if $var eq '*';
      if ($qual eq '+' || $qual eq '*') {
	$multis .= ', ' if $multis ne '';
	$multis .= "'$var' => undef";
        $code2 .= "\$verifyers->{'$vartype'}->(\$_) for \@{\$cgi->{'$var'} || []};\n" if $vartype ne '';
      } else {
	$singles .= ', ' if $singles ne '';
	$singles .= "'$var' => undef";
        $code2 .= "\$verifyers->{'$vartype'}->(\$cgi->{'$var'}) if exists \$cgi->{'$var'};\n" if $vartype ne '';
      }
      push @args, $var if $arg;
      $known .= ", '$var'";
    }
    if ($hasstar) {
      $code = "my \$cgi = parse_cgi(\$req, {$multis}, {$singles});\n$code";
    } else {
      $code = "my \$cgi = parse_cgi(\$req, {$multis});\n$code";
    }
    $code2 .= "push \@args, \$cgi->{'$_'};\n" for @args;
    $code2 .= "&dispatch_checkcgi(\$cgi$known);\n" unless $hasstar;
    if ($callfunction) {
      $code .= "$code2\$callfunction->(\$f, \$cgi, \@args);\n";
    } else {
      $code .= "$code2\$f->(\$cgi, \@args);\n";
    }
    my $np = join('/', @p);
    my $cpld = [ qr/^$np$/ ];
    $cpld->[1] = $cgisingles if $cgisingles;
    $cpld->[2] = $needsauth eq '-' ? undef : $needsauth if $needsauth;
    my $fnew;
    if ($f) {
      eval "\$fnew = sub {my (\$conf, \$req) = \@_;\n$code};";
      die("compile_dispatches: $@\n") if $@;
    }
    push @out, $cpld, $fnew;
  }
  return \@out;
}

sub dispatch {
  my ($conf, $req) = @_;
  $BSServer::request = $req;
  my $disps = $conf->{'dispatches'};
  my $stdreply = $conf->{'stdreply'};
  die("500 no dispatches configured\n") unless $disps;
  my @disps = @$disps;
  my $path = "$req->{'action'}:$req->{'path'}";
  if (1) {
    # path is already urldecoded
    die("400 path is not utf-8\n") unless BSUtil::checkutf8($path);
    my $q = $req->{'query'};
    $q =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge if defined($q) && $q =~ /\%/s;
    die("400 query string is not utf-8\n") unless BSUtil::checkutf8($q);
  }
  my $ppath = $path;
  # strip trailing slash
  $ppath =~ s/\/+$// if substr($ppath, -1, 1) eq '/' && $ppath !~ /^[A-Z]*:\/$/s;
  my $auth;
  my $cgisingles;
  while (@disps) {
    my ($p, $f) = splice(@disps, 0, 2);
    next unless $ppath =~ /$p->[0]/;
    if ($p->[1]) {
      $cgisingles ||= parse_cgi_singles($req);
      next if grep {($cgisingles->{$_} || '') ne $p->[1]->{$_}} keys %{$p->[1]};
    }
    $auth = $p->[2] if @$p > 2;	# optional auth overwrite
    next unless $f;
    if ($auth) {
      die("500 no authenticate method defined\n") unless $conf->{'authenticate'};
      my @r = $conf->{'authenticate'}->($conf, $req, $auth);
      if (@r) {
        return $stdreply->(@r) if $stdreply;
	return @r;
      }
    }
    return $stdreply->($f->($conf, $req)) if $stdreply;
    return $f->($conf, $req);
  }
  die("400 unknown request: $path\n");
}

1;

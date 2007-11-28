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

use Socket;
use Fcntl qw(:DEFAULT :flock);
use POSIX;

use BSHTTP;

use strict;

our $peer;
our $peerport;

sub xfork {
  # behaves as blocking fork, but uses non-blocking fork
  # tries to fork every 5 seconds, until fork succeeds without blocking
  my $pid;
  while (1) {
    $pid = fork();
    last if defined $pid;
    die("fork: $!\n") if $! != POSIX::EAGAIN;
    sleep(5);
  }
  return $pid;
}

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
  # 512 connections maximum
  # $port:  
  #     reference              - port is assigned by system and is returned using this reference
  #     string starting with & - named socket according to the string (&STDOUT, &1)
  #     other string           - tcp socket on $port (assumes it is a number)
  # $user, $group:
  #     if defined, try to set appropriate UID, EUID, GID, EGID ( $<, $>, $(, $) )
  my ($port, $user, $group) = @_;
  # check if $user and $group exist on this system
  !defined($user) || defined($user = (getpwnam($user))[2]) || die("unknown user\n");
  !defined($group) || defined($group = (getgrnam($group))[2]) || die("unknown group\n");
  my $tcpproto = getprotobyname('tcp');
  if (!ref($port) && $port =~ /^&/) {
    open(MS, "<$port") || die("socket open: $!\n");
  } else {
    socket(MS , PF_INET, SOCK_STREAM, $tcpproto) || die "socket: $!\n";
    setsockopt(MS, SOL_SOCKET, SO_REUSEADDR, pack("l",1));
    if (ref($port)) {
      bind(MS, sockaddr_in(0, INADDR_ANY)) || die "bind: $!\n";
      ($$port) = sockaddr_in(getsockname(MS));
    } else {
      bind(MS, sockaddr_in($port, INADDR_ANY)) || die "bind: $!\n";
    }
  }
  if (defined $group) {
    ($(, $)) = ($group, $group);
    die "setgid: $!\n" if ($) != $group);
  }
  if (defined $user) {
    ($<, $>) = ($user, $user);
    die "setuid: $!\n" if ($> != $user);
  }
  if (ref($port) || $port !~ /^&/) {
    listen(MS , 512) || die "listen: $!\n";
  }
}

sub serveropen_unix {
  # creates MS (=master socket) socket
  # 512 connections maximum
  # creates named socket according to $filename
  # race-condition safe (locks)
  # $user, $group:
  #     if defined, try to set appropriate UID, EUID, GID, EGID ( $<, $>, $(, $) )
  my ($filename, $user, $group) = @_;
  !defined($user) || defined($user = (getpwnam($user))[2]) || die("unknown user\n");
  !defined($group) || defined($group = (getgrnam($group))[2]) || die("unknown group\n");
  if (defined $group) {
    ($(, $)) = ($group, $group);
    die "setgid: $!\n" if ($) != $group);
  }
  if (defined $user) {
    ($<, $>) = ($user, $user);
    die "setuid: $!\n" if ($> != $user);
  }
  # we need a lock for exclusive socket access
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

sub setserversocket {
  if (defined($_[0])) {
    (*MS) = @_;
  } else {
    undef *MS;
  }
}

sub serverclose {
  close MS;
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

sub server {
  my ($conf) = @_;

  $conf ||= {};
  my $maxchild = $conf->{'maxchild'};
  my $timeout = $conf->{'timeout'};
  my %chld = ();
  my $peeraddr;

  while (1) {
    # listen on MS until there is an incoming connection
    my $rin = '';
    vec($rin, fileno(MS), 1) = 1;
    my $r = select($rin, undef, undef, $timeout || 5);
    if (!defined($r) || $r == -1) {
      next if $! == POSIX::EINTR;
      die("select: $!\n");
    }
    # now we know there is a connection on MS waiting to be accepted
    my $pid;
    if ($r) {
      $peeraddr = accept(CLNT, MS);
      next unless $peeraddr;
      $pid = fork();
      last if $pid == 0;
      die if $pid == -1; # XXX pid cannot be -1 according to perl manual on fork
      close CLNT;
      $chld{$pid} = 1;
    }
    # if there are already $maxchild connected, make blocking waitpid
    # otherwise make non-blocking waitpid
    while (($pid = waitpid(-1, defined($maxchild) && keys(%chld) > $maxchild ? 0 : POSIX::WNOHANG)) > 0) {
      delete $chld{$pid};
    }
    # timeout was set in the $conf and select timeouted on this value. There was no new connection -> exit.
    return 0 if !$r && defined $timeout;
  }
  # from now on, this is only the child process
  $peer = 'unknown';
  eval {
    my $peera;
    ($peerport, $peera) = sockaddr_in($peeraddr);
    $peer = inet_ntoa($peera);
  };

  setsockopt(CLNT, SOL_SOCKET, SO_KEEPALIVE, pack("l",1)) if $conf->{'setkeepalive'};
  if ($conf->{'accept'}) {
    eval {
      # XXX what does conf->accept do? nothing sets conf->accept
      $conf->{'accept'}->($conf, $peer);
    };
    reply_error($conf, $@) if $@;
    close CLNT;
    exit(0);
  }
  if ($conf->{'dispatch'}) {
    eval {
      my $req = readrequest();
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

sub reply {
  # $str:
  #     some data to be written after http header
  # @hi:
  #     http header lines, 1st line can contain status
  # reads and discards all data from CLNT, writes reply to CLNT
  my ($str, @hi) = @_;

  if (@hi && $hi[0] =~ /^status: (\d+.*)/i) {
    $hi[0] = "HTTP/1.1 $1";
  } else {
    unshift @hi, "HTTP/1.1 200 OK";
  }
  push @hi, "Cache-Control: no-cache";
  push @hi, "Connection: close";
  push @hi, "Content-Length: ".length($str) if defined($str);
  my $data = join("\r\n", @hi)."\r\n\r\n";
  $data .= $str if defined $str;
  fcntl(CLNT, F_SETFL,O_NONBLOCK);
  my $dummy = '';
  1 while sysread(CLNT, $dummy, 1024, 0);
  fcntl(CLNT, F_SETFL,0);
  my $l;  
  while (length($data)) {
    $l = syswrite(CLNT, $data, length($data));
    die("write error: $!\n") unless $l;
    $data = substr($data, $l);
  }
}

sub reply_error  {
  my ($conf, $err) = @_; 
  $err ||= "unspecified error";
  $err =~ s/\n$//s;
  my $code = 404;
  my $tag = '';
  # "parse" err string 
  if ($err =~ /^(\d+)\s*([^\r\n]*)/) {
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
  my ($req, $multis) = @_;

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
        push @{$cgi{$name}}, $value; # this can possibly initialize $cgi{$name}
      }
    } else {
      die("parameter '$name' set multiple times\n") if exists $cgi{$name};
      $cgi{$name} = $value;
    }
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
    # sysreads appends read data at the end of $qu
    die($qu eq '' ? "empty query\n" : "received truncated query\n") if !sysread(CLNT, $qu, 1024, length($qu));
  }
  my ($act, $path, $vers, undef) = split(' ', $req, 4);
  my %headers;
  die("400 No method name\n") if !$act;
  if ($vers) {
    die("501 Bad method: $act\n") if $act ne 'GET' && $act ne 'HEAD' && $act ne 'POST' && $act ne 'PUT' && $act ne 'DELETE';
    # really ugly way of reading until request ends (regexp on the whole string every time!)
    while ($qu !~ /^(.*?)\r?\n\r?\n(.*)$/s) {
      die("501 received truncated query\n") if !sysread(CLNT, $qu, 1024, length($qu));
    }
    $qu =~ /^(.*?)\r?\n\r?\n(.*)$/s;
    $qu = $2;
    gethead(\%headers, "Request: $1"); # put 1st line of http request into $headers{'Request'}
  } else {
    # if there is no version in http request (HTTP/1.1), assume that there are no more headers
    die("501 Bad method, must be GET\n") if $act ne 'GET';
    $qu = ''; # and assume that there are no more request data
  }
  my $query_string = '';
  if ($path =~ /^(.*?)\?(.*)$/) {
    $path = $1;
    $query_string = $2;
  }
  $path =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge; # here comes the conversion from URI  again
  die("501 invalid path\n") unless $path =~ /^\//s; # forbid relative paths
  my $res = {};
  $res->{'action'} = $act;
  $res->{'path'} = $path;
  $res->{'query'} = $query_string;
  $res->{'headers'} = \%headers;
  if ($act eq 'POST' || $act eq 'PUT') {
    # if client expects our response, respond
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
    $query_string = '';
    my $cl = $headers{'content-length'} || 0;
    while (length($qu) < $cl) {
      sysread(CLNT, $qu, $cl - length($qu), length($qu)) || die("400 Truncated body\n");
    }
    $query_string = substr($qu, 0, $cl);
    $res->{'query'} = $query_string;
    $qu = substr($qu, $cl);
  }
  return $res;
}

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

sub get_content_type {
  die("get_content_type: invalid request\n") unless $post_hdrs;
  return $post_hdrs->{'content-type'};
}

sub reply_cpio {
  my ($files, @args) = @_;
  reply(undef, 'Content-Type: application/x-cpio', 'Transfer-Encoding: chunked', @args);
  BSHTTP::cpio_sender({'chunked' => 1, 'cpiofiles' => $files}, \*CLNT);
  BSHTTP::swrite(\*CLNT, "0\r\n\r\n")
}

sub reply_file {
  my ($file, @args) = @_;
  push @args, 'Transfer-Encoding: chunked';
  unshift @args, 'Content-Type: application/octet-stream' unless grep {/^content-type:/i} @args;
  reply(undef, @args);
  BSHTTP::file_sender({'chunked' => 1, 'filename' => $file}, \*CLNT);
  BSHTTP::swrite(\*CLNT, "0\r\n\r\n")
}

sub reply_receiver {
  my ($hdr, $param) = @_;

  $param->{'reply_receiver_called'} = 1;
  my @args;
  my $st = $hdr->{'status'};
  my $ct = $hdr->{'content-type'} || 'text/plain';
  my $chunked = 0;
  $chunked = 1 if $hdr->{'transfer-encoding'} && lc($hdr->{'transfer-encoding'}) eq 'chunked';
  push @args, "Status: $st" if $st; 
  push @args, "Content-Type: $ct";
  push @args, 'Transfer-Encoding: chunked' if $chunked;
  reply(undef, @args); 
  while(1) {
    my $data = BSHTTP::read_data($hdr);
    last unless $data;
    $data = sprintf("%X\r\n", length($data)).$data."\r\n" if $chunked;
    swrite($data);
  }
  swrite("0\r\n\r\n") if $chunked;
}

sub forward_sender {
  return read_data(8192);
}

sub header {
  die("header: invalid request\n") unless $post_hdrs;
  return $post_hdrs->{$_[0]};
}

sub swrite {
  BSHTTP::swrite(\*CLNT, $_[0]);
}

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
    my $needsauth = 0;
    $needsauth = 1 if $p =~ s/^!//;
    if ($p eq '/') {
      push @out, '^(?:GET|HEAD|POST):/$', $f;
      next;
    }
    my @cgis = split(' ', $p);
    s/%([a-fA-F0-9]{2})/chr(hex($1))/ge for @cgis;
    $p = shift @cgis;
    my @p = split('/', $p);
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
    $p[0] = "(?:GET|HEAD|POST):$p[0]" if $p[0] !~ /:/;
    my $multis = '';
    for my $pp (@cgis) {
      my ($arg, $qual) = (0, '{1}');
      $arg = 1 if $pp =~ s/^\$//;
      $qual = $1 if $pp =~ s/([+*?])$//;
      my $var = $pp;
      my $vartype = $var;
      ($var, $vartype) = ($1, $2) if $var =~ /^(.*):(.*)/;
      die("no verifyer for $vartype\n") unless $vartype eq '' || $verifyers->{$vartype};
      $code2 .= "die(\"parameter '$var' is missing\\n\") unless exists \$cgi->{'$var'};\n" if $qual ne '*' && $qual ne '?';
      if ($qual eq '+' || $qual eq '*') {
	$multis .= ', ' if $multis ne '';
	$multis .= "'$var' => undef";
        $code2 .= "\$verifyers->{'$vartype'}->(\$_) for \@{\$cgi->{'$var'} || []};\n" if $vartype ne '';
      } else {
        $code2 .= "\$verifyers->{'$vartype'}->(\$cgi->{'$var'}) if exists \$cgi->{'$var'};\n" if $vartype ne '';
      }
      push @args, $var if $arg;
      $known .= ", '$var'";
    }
    $code = "my \$cgi = parse_cgi(\$req, {$multis});\n$code";
    if ($needsauth) {
      $code = "die(\"500 no authenticate method defined\\n\") unless \$conf->{'authenticate'};\nmy \@auth = \$conf->{'authenticate'}->(\$conf, \$req);\nreturn \@auth if \@auth;\n$code";
    }
    $code2 .= "push \@args, \$cgi->{'$_'};\n" for @args;
    $code2 .= "&dispatch_checkcgi(\$cgi$known);\n";
    if ($callfunction) {
      $code .= "$code2\$callfunction->(\$f, \$cgi, \@args);\n";
    } else {
      $code .= "$code2\$f->(\$cgi, \@args);\n";
    }
    my $np = join('/', @p);
    push @out, "^$np\$";
    eval "push \@out, sub {my (\$conf, \$req) = \@_;\n$code};";
    die("compile_dispatches: $@\n") if $@;
  }
  return \@out;
}

sub dispatch {
  my ($conf, $req) = @_;
  my $disps = $conf->{'dispatches'};
  my $stdreply = $conf->{'stdreply'};
  die("500 no dispatches configured\n") unless $disps;
  my @disps = @$disps;
  my $path = "$req->{'action'}:$req->{'path'}";
  my $ppath = $path;
  $ppath =~ s/\/+$// if substr($ppath, -1, 1) eq '/' && $ppath !~ /^[A-Z]*:\/$/s;
  while (@disps) {
    my ($p, $f) = splice(@disps, 0, 2);
    next unless $ppath =~ /$p/;
    return $stdreply->($f->($conf, $req)) if $stdreply;
    return $f->($conf, $req);
  }
  die("500 unknown request: $path\n");
}

1;

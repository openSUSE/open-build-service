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
# implementation of state change watchers. Can watch for file
# changes, RPC results, and file download data. Handle with care.
#

package BSWatcher;

use BSServer;
use BSServerEvents;
use BSRPC;
use BSEvents;
use BSHTTP;
use POSIX;
use Socket;
use Symbol;
use XML::Structured;
use Data::Dumper;

use strict;

sub reply {
  my $jev = $BSServerEvents::gev;
  return BSServer::reply(@_) unless $jev;
  return BSServerEvents::reply(@_);
}

sub reply_file {
  my $jev = $BSServerEvents::gev;
  return BSServer::reply_file(@_) unless $jev;
  return BSServerEvents::reply_file(@_);
}

#
# things we add to the connection event:
#
# redohandler
# args
#

my %filewatchers;
my %filewatchers_s;
my $filewatchers_ev;
my $filewatchers_ev_active;

my %rpcs;

sub redo_request {
  my ($jev) = @_;
  local $BSServerEvents::gev = $jev;
  my $conf = $jev->{'conf'};
  eval {
    my @res = $jev->{'redohandler'}->(@{$jev->{'args'} || []});
    $conf->{'stdreply'}->(@res) if $conf->{'stdreply'};
    return;
  };
  BSServerEvents::reply_error($conf, $@) if $@;
}

sub filewatcher_handler {
  # print "filewatcher_handler\n";
  BSEvents::add($filewatchers_ev, 1);
  for my $file (sort keys %filewatchers) {
    next unless $filewatchers{$file};
    my @s = stat($file);
    my $s = @s ? "$s[9]/$s[7]/$s[1]" : "-/-/-";
    next if ($s eq $filewatchers_s{$file});
    print "file $file changed!\n";
    $filewatchers_s{$file} = $s;
    for my $jev (@{$filewatchers{$file}}) {
      redo_request($jev);
    }
  }
}

sub addfilewatcher {
  my ($file) = @_;

  my $jev = $BSServerEvents::gev;
  return unless $jev;
  $jev->{'closehandler'} = \&deljob;
  if ($filewatchers{$file}) {
    print "addfilewatcher to already watched $file\n";
    push @{$filewatchers{$file}}, $jev unless grep {$_ eq $jev} @{$filewatchers{$file}};
    return;
  }
  print "addfilewatcher $file\n";
  if (!$filewatchers_ev) {
    $filewatchers_ev = BSEvents::new('timeout', \&filewatcher_handler);
  }
  if (!$filewatchers_ev_active) {
    BSEvents::add($filewatchers_ev, 1);
    $filewatchers_ev_active = 1;
  }
  my @s = stat($file);
  my $s = @s ? "$s[9]/$s[7]/$s[1]" : "-/-/-";
  push @{$filewatchers{$file}}, $jev;
  $filewatchers_s{$file} = $s;
}

sub deljob {
  my ($jev) = @_;
  print "deljob #$jev->{'id'}\n";
  for (keys %filewatchers) {
    next unless grep {$_ == $jev} @{$filewatchers{$_}};
    @{$filewatchers{$_}} = grep {$_ != $jev} @{$filewatchers{$_}};
    if (!@{$filewatchers{$_}}) {
      delete $filewatchers{$_};
      delete $filewatchers_s{$_};
    }
  }
  if (!%filewatchers && $filewatchers_ev_active) {
    BSEvents::rem($filewatchers_ev);
    $filewatchers_ev_active = 0;
  }
  for my $uri (keys %rpcs) {
    my $ev = $rpcs{$uri};
    next unless $ev;
    next unless grep {$_ == $jev} @{$ev->{'joblist'}};
    @{$ev->{'joblist'}} = grep {$_ != $jev} @{$ev->{'joblist'}};
    if (!@{$ev->{'joblist'}}) {
      print "deljob: rpc $uri no longer needed\n";
      if ($ev->{'streaming'}) {
	# kill it!
        BSServerEvents::stream_close($ev, $ev->{'writeev'});
      }
    }
  }
}

my %hostlookupcache;
my $tcpproto = getprotobyname('tcp');

sub rpc_error {
  my ($ev, $err) = @_;
  $ev->{'rpcstate'} = 'error';
  print "rpc_error: $err\n";
  my $uri = $ev->{'rpcuri'};
  delete $rpcs{$uri};
  close $ev->{'fd'} if $ev->{'fd'};
  delete $ev->{'fd'};
  for my $jev (@{$ev->{'joblist'} || []}) {
    $jev->{'rpcdone'} = $uri;
    $jev->{'rpcerror'} = $err;
    redo_request($jev);
    delete $jev->{'rpcdone'};
    delete $jev->{'rpcerror'};
  }
}

sub rpc_result {
  my ($ev, $res) = @_;
  $ev->{'rpcstate'} = 'done';
  my $uri = $ev->{'rpcuri'};
  print "got result for $uri\n";
  delete $rpcs{$uri};
  close $ev->{'fd'} if $ev->{'fd'};
  delete $ev->{'fd'};
  for my $jev (@{$ev->{'joblist'} || []}) {
    $jev->{'rpcdone'} = $uri;
    $jev->{'rpcresult'} = $res;
    redo_request($jev);
    delete $jev->{'rpcdone'};
    delete $jev->{'rpcresult'};
  }
}

sub rpc_adddata {
  my ($jev, $data) = @_;

  $data = sprintf("%X\r\n", length($data)).$data."\r\n";
  $jev->{'replbuf'} .= $data;
  if ($jev->{'paused'}) {
    delete $jev->{'paused'};
    BSEvents::add($jev);
  }
}

sub rpc_recv_stream_close_handler {
  my ($ev) = @_;
  #print "rpc_recv_stream_close_handler\n";
  my $rev = $ev->{'readev'};
  my @jobs = @{$rev->{'joblist'} || []};
  my $trailer = $ev->{'chunktrailer'} || '';
  for my $jev (@jobs) {
    $jev->{'replbuf'} .= "0\r\n$trailer\r\n";
    if ($jev->{'paused'}) {
      delete $jev->{'paused'};
      BSEvents::add($jev);
    }
    $jev->{'readev'} = {'eof' => 1, 'rpcuri' => $rev->{'rpcuri'}};
  }
  # the stream rpc is finished!
  print "stream rpc $rev->{'rpcuri'} is finished!\n";
  delete $rpcs{$rev->{'rpcuri'}};
}

sub rpc_recv_stream_handler {
  my ($ev) = @_;
  my $rev = $ev->{'readev'};

  #print "rpc_recv_stream_handler\n";
  $ev->{'paused'} = 1;	# always need more bytes!
nextchunk:
  $ev->{'replbuf'} =~ s/^\r?\n//s;
  if ($ev->{'replbuf'} !~ /\r?\n/s) {
    return unless $rev->{'eof'};
    print "rpc_recv_stream_handler: premature EOF\n";
    BSServerEvents::stream_close($rev, $ev);
    return;
  }
  if ($ev->{'replbuf'} !~ /^([0-9a-fA-F]+)/) {
    print "rpc_recv_stream_handler: bad chunked data\n";
    BSServerEvents::stream_close($rev, $ev);
    return;
  }
  my $cl = hex($1);
  # print "rpc_recv_stream_handler: chunk len $cl\n";
  if ($cl < 0 || $cl >= 16000) {
    print "rpc_recv_stream_handler: illegal chunk size\n";
    BSServerEvents::stream_close($rev, $ev);
    return;
  }
  if ($cl == 0) {
    # wait till trailer is complete
    if ($ev->{'replbuf'} !~ /\n\r?\n/s) {
      return unless $rev->{'eof'};
      print "rpc_recv_stream_handler: premature EOF\n";
      BSServerEvents::stream_close($rev, $ev);
      return;
    }
    print "rpc_recv_stream_handler: chunk EOF\n";
    my $trailer = $ev->{'replbuf'};
    $trailer =~ s/^(.*?\r?\n)/\r\n/s;	# delete chunk header
    $trailer =~ s/\n\r?\n.*//s;		# delete stuff after trailer
    $trailer =~ s/\r$//s;
    $trailer = substr($trailer, 2) if $trailer ne '';
    $trailer .= "\r\n" if $trailer ne '';
    $ev->{'chunktrailer'} = $trailer;
    BSServerEvents::stream_close($rev, $ev);
    return;
  }
  $ev->{'replbuf'} =~ /^(.*?\r?\n)/s;
  if (length($1) + $cl > length($ev->{'replbuf'})) {
    return unless $rev->{'eof'};
    print "rpc_recv_stream_handler: premature EOF\n";
    BSServerEvents::stream_close($rev, $ev);
    return;
  }

  my $data = substr($ev->{'replbuf'}, length($1), $cl);
  my $nextoff = length($1) + $cl;
  
  my @jobs = @{$rev->{'joblist'} || []};
  my @stay = ();
  my @leave = ();

  for my $jev (@jobs) {
    if (length($jev->{'replbuf'}) >= 16384) {
      push @stay, $jev;
    } else {
      push @leave, $jev;
    }
  }
  if ($rev->{'eof'}) {
    # must not hold back data at eof
    @leave = @jobs;
    @stay = ();
  }
  if (!@leave) {
    # too full! wait till there is more room
    print "stay=".@stay.", leave=".@leave.", blocking\n";
    return;
  }

  # advance our uri
  my $newuri = $rev->{'rpcuri'};
  my $newpos = length($data);
  if ($newuri =~ /start=(\d+)/) {
    $newpos += $1;
    $newuri =~ s/start=\d+/start=$newpos/;
  } elsif ($newuri =~ /\?/) {
    $newuri .= '&' unless $newuri =~ /\?$/;
    $newuri .= "start=$newpos";
  } else {
    $newuri .= "?start=$newpos";
  }
  print "stay=".@stay.", leave=".@leave.", newpos=$newpos\n";

  if ($rpcs{$newuri}) {
    my $nev = $rpcs{$newuri};
    print "joining ".@leave." jobs with $newuri!\n";
    for my $jev (@leave) {
      push @{$nev->{'joblist'}}, $jev unless grep {$_ == $jev} @{$nev->{'joblist'}};
      $jev->{'readev'} = $nev;
    }
    $rev->{'joblist'} = [ @stay ];
    for my $jev (@leave) {
      rpc_adddata($jev, $data);
    }
    if (!@stay) {
      BSServerEvents::stream_close($rev, $ev);
    }
    # too full! wait till there is more room
    return;
  }

  my $olduri = $rev->{'rpcuri'};
  $rpcs{$newuri} = $rev;
  delete $rpcs{$olduri};
  $rev->{'rpcuri'} = $newuri;

  if (@stay) {
    # worst case: split of
    $rev->{'joblist'} = [ @leave ];
    print "splitting ".@stay." jobs from $newuri!\n";
    # put old output event on hold
    for my $jev (@stay) {
      delete $jev->{'readev'};
      if (!$jev->{'paused'}) {
        BSEvents::rem($jev);
      }
      delete $jev->{'paused'};
    }
    # this is scary
    eval {
      local $BSServerEvents::gev = $stay[0];
      rpc($olduri);
      die("could not restart rpc\n") unless $rpcs{$olduri};
    };
    if ($@ || !$rpcs{$olduri}) {
      # terminate all old rpcs
      my $err = $@ || "internal error\n";
      for my $jev (@stay) {
	rpc_error($jev, $err);
      }
    } else {
      my $nev = $rpcs{$olduri};
      for my $jev (@stay) {
        push @{$nev->{'joblist'}}, $jev unless grep {$_ == $jev} @{$nev->{'joblist'}};
      }
    }
  }

  for my $jev (@leave) {
    rpc_adddata($jev, $data);
  }

  $ev->{'replbuf'} = substr($ev->{'replbuf'}, $nextoff);

  goto nextchunk if length($ev->{'replbuf'});

  if ($rev->{'eof'}) {
    print "rpc_recv_stream_handler: EOF\n";
    BSServerEvents::stream_close($rev, $ev);
  }
}

sub rpc_recv_stream {
  my ($ev, $data) = @_;


  $ev->{'rpcstate'} = 'streaming';
  #
  # setup output streams for all jobs
  #
  my @args = ();
  push @args, 'Transfer-Encoding: chunked';
  unshift @args, 'Content-Type: application/octet-stream' unless grep {/^content-type:/i} @args;
  for my $jev (@{$ev->{'joblist'} || []}) {
    if (!$jev->{'streaming'}) {
       local $BSServerEvents::gev = $jev;
       BSServerEvents::reply(undef, @args);
       BSEvents::rem($jev);
       $jev->{'streaming'} = 1;
       delete $ev->{'timeouthandler'};
    }
    $jev->{'handler'} = \&BSServerEvents::stream_write_handler;
    $jev->{'readev'} = $ev;
    if (length($jev->{'replbuf'})) {
      delete $jev->{'paused'};
      BSEvents::add($jev, 0);
    } else {
      $jev->{'paused'} = 1;
    }
  }

  #
  # setup input stream from rpc client
  #
  $ev->{'streaming'} = 1;
  my $wev = BSEvents::new('always');
  # print "new rpc input stream $ev $wev\n";
  $wev->{'replbuf'} = $data;
  $wev->{'readev'} = $ev;
  $ev->{'writeev'} = $wev;
  $wev->{'handler'} = \&rpc_recv_stream_handler;
  $wev->{'closehandler'} = \&rpc_recv_stream_close_handler;
  $ev->{'handler'} = \&BSServerEvents::stream_read_handler;
  BSEvents::add($ev);
  BSEvents::add($wev);	# do this last
}

sub rpc_recv_handler {
  my ($ev) = @_;
  my $r = sysread($ev->{'fd'}, $ev->{'recvbuf'}, 1024, length($ev->{'recvbuf'}));
  if (!defined($r)) {
    if ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK) {
      BSEvents::add($ev);
      return;
    }
    rpc_error($ev, "read error from $ev->{'rpcdest'}: $!");
    return;
  }
  my $ans;
  $ev->{'rpceof'} = 1 if !$r;
  $ans = $ev->{'recvbuf'};
  if ($ans !~ /\n\r?\n/s) {
    if ($ev->{'rpceof'}) {
      rpc_error($ev, "EOF from $ev->{'rpcdest'}");
      return;
    }
    BSEvents::add($ev);
    return;
  }
  if ($ans !~ s/^HTTP\/\d+?\.\d+?\s+?(\d+[^\r\n]*)/Status: $1/s) {
    rpc_error($ev, "bad answer from $ev->{'rpcdest'}");
    return;
  }
  my $status = $1;
  $ans =~ /^(.*?)\n\r?\n(.*)$/s;
  my $headers = $1;
  $ans = $2;
  if ($status !~ /^200[^\d]/) {
    rpc_error($ev, "remote error: $status");
    return;
  }
  my %headers;
  BSHTTP::gethead(\%headers, $headers);
  if ($headers{'content-type'} && lc($headers{'content-type'}) eq 'application/octet-stream') {
    if (!$headers{'transfer-encoding'} || lc($headers{'transfer-encoding'}) ne 'chunked') {
      rpc_error($ev, "must be chunked for streaming");
      return;
    }
    # stream into cache file
    rpc_recv_stream($ev, $ans);
    return;
  }
  if ($headers{'transfer-encoding'} && lc($headers{'transfer-encoding'}) eq 'chunked') {
    rpc_error($ev, "chunked not supported at the moment");
    return;
  }
  my $cl = $headers{'content-length'};
  if (!$ev->{'rpceof'} && (!$cl || length($ans) < $cl)) {
    BSEvents::add($ev);
    return;
  }
  if ($cl && length($ans) < $cl) {
    rpc_error($ev, "EOF from $ev->{'rpcdest'}");
    return;
  }
  $ans = substr($ans, 0, $cl) if $cl;
  rpc_result($ev, $ans);
}

sub rpc_send_handler {
  my ($ev) = @_;
  my $l = length($ev->{'sendbuf'});
  return unless $l;
  $l = 4096 if $l > 4096;
  my $r = syswrite($ev->{'fd'}, $ev->{'sendbuf'}, $l);
  if (!defined($r)) {
    if ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK) {
      BSEvents::add($ev);
      return;
    }
    rpc_error($ev, "write error to $ev->{'rpcdest'}: $!");
    return;
  }
  if ($r != length($ev->{'sendbuf'})) {
    $ev->{'sendbuf'} = substr($ev->{'sendbuf'}, $r) if $r;
    BSEvents::add($ev);
    return;
  }
  # print "done sending to $ev->{'rpcdest'}, now receiving\n";
  delete $ev->{'sendbuf'};
  $ev->{'recvbuf'} = '';
  $ev->{'type'} = 'read';
  $ev->{'rpcstate'} = 'receiving';
  $ev->{'handler'} = \&rpc_recv_handler;
  BSEvents::add($ev);
}

sub rpc_connect_timeout {
  my ($ev) = @_;
  rpc_error($ev, "connect to $ev->{'rpcdest'}: timeout");
}

sub rpc_connect_handler {
  my ($ev) = @_;
  my $err;
  #print "rpc_connect_handler\n";
  $err = getsockopt($ev->{'fd'}, SOL_SOCKET, SO_ERROR);
  if (!defined($err)) {
    $err = "getsockopt: $!";
  } else {
    $err = unpack("I", $err);
    if ($err == 0 || $err == POSIX::EISCONN) {
      $err = undef;
    } else {
      $! = $err;
      $err = "connect to $ev->{'rpcdest'}: $!";
    }
  }
  if ($err) {
    rpc_error($ev, $err);
    return;
  }
  #print "rpc_connect_handler: connected!\n";
  $ev->{'rpcstate'} = 'sending';
  delete $ev->{'timeouthandler'};
  $ev->{'handler'} = \&rpc_send_handler;
  BSEvents::add($ev, 0);
}

sub rpc {
  my ($uri, $xmlargs, @args) = @_;

  my $jev = $BSServerEvents::gev;
  return BSRPC::rpc($uri, $xmlargs, @args) unless $jev;
  my @xhdrs;
  my $param = {};
  if (ref($uri) eq 'HASH') {
    $param = $uri;
    $uri = $param->{'uri'};
    @xhdrs = @{$param->{'headers'} || []};
  }
  $uri = BSRPC::urlencode($uri) unless $param->{'verbatim_uri'};
  if (@args) {
    for (@args) {
      s/([\000-\040<>\"#&\+=%[\177-\377])/sprintf("%%%02X",ord($1))/sge;
      s/%3D/=/;
    }
    if ($uri =~ /\?/) {
      $uri .= '&'.join('&', @args); 
    } else {
      $uri .= '?'.join('&', @args); 
    }
  }
  if ($jev->{'rpcdone'} && $uri eq $jev->{'rpcdone'}) {
    die("$jev->{'rpcerror'}\n") if exists $jev->{'rpcerror'};
    my $ans = $jev->{'rpcresult'};
    if ($xmlargs) {
      die("answer is not xml\n") if $ans !~ /<.*?>/s;
      return XMLin($xmlargs, $ans);
    }
    return $ans;
  }
  $jev->{'closehandler'} = \&deljob;
  if ($rpcs{$uri}) {
    print "rpc $uri already in progress, ".@{$rpcs{$uri}->{'joblist'} || []}." entries\n";
    push @{$rpcs{$uri}->{'joblist'}}, $jev unless grep {$_ eq $jev} @{$rpcs{$uri}->{'joblist'}};
    return;
  }

  # new rpc, create rpc event
  die("bad uri: $uri\n") unless $uri =~ /^http:\/\/([^\/:]+)(:\d+)?(\/.*)$/;
  my ($host, $port, $path) = ($1, $2, $3);
  my $hostport = $port ? "$host$port" : $host;
  $port = substr($port || ":80", 1);
  if (!$hostlookupcache{$host}) {
    # should do this async, but that's hard to do in perl
    my $hostaddr = inet_aton($host);
    die("unknown host '$host'\n") unless $hostaddr;
    $hostlookupcache{$host} = $hostaddr;
  }
  unshift @xhdrs, "Host: $hostport" unless grep {/^host:/si} @xhdrs;;
  my $req = "GET $path HTTP/1.1\r\n".join("\r\n", @xhdrs)."\r\n\r\n";
  my $fd = gensym;
  socket($fd, PF_INET, SOCK_STREAM, $tcpproto) || die("socket: $!\n");
  fcntl($fd, F_SETFL,O_NONBLOCK);
  my $ev = BSEvents::new('write', \&rpc_send_handler);
  $ev->{'fd'} = $fd;
  $ev->{'sendbuf'} = $req;
  $ev->{'rpcdest'} = "$host:$port";
  $ev->{'rpcuri'} = $uri;
  $ev->{'rpcstate'} = 'connecting';
  push @{$ev->{'joblist'}}, $jev;
  $rpcs{$uri} = $ev;
  print "new rpc $uri\n";
  if (!connect($fd, sockaddr_in($port, $hostlookupcache{$host}))) {
    if ($! == POSIX::EINPROGRESS) {
      $ev->{'handler'} = \&rpc_connect_handler;
      $ev->{'timeouthandler'} = \&rpc_connect_timeout;
      BSEvents::add($ev, 60);	# 60s connect timeout
      return;
    }
    close $ev->{'fd'};
    delete $ev->{'fd'};
    delete $rpcs{$uri};
    die("connect to $host:$port: $!\n");
  }
  $ev->{'rpcstate'} = 'sending';
  BSEvents::add($ev);
}

sub getstatus {
  my $ret = {};
  for my $filename (sort keys %filewatchers) {
    my $fw = {'filename' => $filename, 'state' => $filewatchers_s{$filename}};
    for my $jev (@{$filewatchers{$filename}}) {
      my $j = {'ev' => $jev->{'id'}};
      $j->{'fd'} = fileno(*{$jev->{'fd'}}) if $jev->{'fd'};
      push @{$fw->{'job'}}, $j;
    }
    push @{$ret->{'watcher'}}, $fw;
  }
  for my $uri (sort keys %rpcs) {
    my $ev = $rpcs{$uri};
    my $r = {'uri' => $uri, 'ev' => $ev->{'id'}};
    $r->{'fd'} = fileno(*{$ev->{'fd'}}) if $ev->{'fd'};
    $r->{'state'} = $ev->{'rpcstate'} if $ev->{'rpcstate'};
    for my $jev (@{$ev->{'joblist'} || []}) {
      my $j = {'ev' => $jev->{'id'}};
      $j->{'fd'} = fileno(*{$jev->{'fd'}}) if $jev->{'fd'};
      push @{$r->{'job'}}, $j;
    }
    push @{$ret->{'rpc'}}, $r;
  }
  return $ret;
}

sub addhandler {
  my ($f, @args) = @_;
  my $jev = $BSServerEvents::gev;
  $jev->{'redohandler'} = $f;
  $jev->{'args'} = [ @args ];
  return $f->(@args);
}

sub compile_dispatches {
  my ($dispatches, $verifyers) = @_;
  return BSServer::compile_dispatches($dispatches, $verifyers, \&addhandler);
}

1;

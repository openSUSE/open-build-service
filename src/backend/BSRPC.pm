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
# Run a HTTP query operation. Single thread only.
#

package BSRPC;

use Socket;
use POSIX;
use XML::Structured;
use Symbol;
use MIME::Base64;

use BSHTTP;

use strict;

our $useragent = 'BSRPC 0.9.1';
our $noproxy;
our $logtimeout;
our $autoheaders;
our $dnscachettl = 3600;
our $authenticator;

our $ssl_keyfile;
our $ssl_certfile;
our $ssl_verify = {};

our $tossl;

my %hostlookupcache;
my %cookiestore;	# our session store to keep iChain fast
my $ssl_newctx;
my $ssl_ctx;

sub import {
  if (grep {$_ eq ':https'} @_) {
    require BSSSL;
    $tossl = \&BSSSL::tossl;
    $ssl_newctx = \&BSSSL::newctx;
  }
}

sub set_clientcert {
  my ($sslconf) = @_;
  return unless $sslconf;
  $ssl_keyfile = $sslconf->{'keyfile'};
  $ssl_certfile = $sslconf->{'certfile'};
  if (exists($sslconf->{'verify'})) {
    $ssl_verify = $sslconf->{'verify'};
    $ssl_ctx = undef;
  }
}

my $tcpproto = getprotobyname('tcp');

sub urlencode {
  return BSHTTP::urlencode($_[0]);
}

sub createuri {
  my ($param, @args) = @_;
  my $uri = $param->{'uri'};
  if (!$param->{'verbatim_uri'}) {
    # encode uri, but do not encode the host part
    if ($uri =~ /^(https?:\/\/[^\/]*\/)(.*)$/s) {
      $uri = $1; 
      $uri .= BSHTTP::urlencode($2);
    } else {
      $uri = BSHTTP::urlencode($uri);
    }
  }
  $uri .= (($uri =~ /\?/) ? '&' : '?') . BSHTTP::queryencode(@args) if @args;
  $uri .= "#".BSHTTP::urlencode($param->{'fragment'}) if defined $param->{'fragment'};
  return $uri;
}

sub useproxy {
  my ($param, $host) = @_;

  my $nop = $noproxy;
  if (!defined($nop)) {
    # XXX: should not get stuff from BSConfig, but compatibility...
    $nop = $BSConfig::noproxy if defined($BSConfig::noproxy);
  }
  return 1 if !defined $nop;
  # strip leading and tailing whitespace
  $nop =~ s/^\s+//;
  $nop =~ s/\s+$//;
  # noproxy is a list separated by commas and optional whitespace
  for (split(/\s*,\s*/, $nop)) {
    s/^\.?/./s; 
    return 0 if ".$host" =~ /\Q$_\E$/s;
  }
  return 1;
}

sub addautoheaders {
  my ($hdrs, $aheaders) = @_;
  for (@{$aheaders || $autoheaders || []}) {
    my $k = (split(':', $_, 2))[0];
    push @$hdrs, $_ unless grep {/^\Q$k\E:/i} @$hdrs;
  }
}

sub createreq {
  my ($param, $uri, $proxy, $cookiestore, @xhdrs) = @_;

  my $act = $param->{'request'} || 'GET';
  if (exists($param->{'socket'})) {
    my $req = "$act $uri HTTP/1.1\r\n".join("\r\n", @xhdrs)."\r\n\r\n";
    return ('', undef, undef, $req, undef);
  }
  my ($proxyauth, $proxytunnel);
  die("bad uri: $uri\n") unless $uri =~ /^(https?):\/\/(?:([^\/\@]*)\@)?([^\/:]+|(?:\[[:0-9A-Fa-f]+\]))(:\d+)?(\/.*)$/;
  my ($proto, $auth, $host, $port, $path) = ($1, $2, $3, $4, $5);
  my $hostport = $port ? "$host$port" : $host;
  undef $proxy if $proxy && !useproxy($param, $host);
  if ($proxy) {
    die("bad proxy uri: $proxy\n") unless "$proxy/" =~ /^(https?):\/\/(?:([^\/\@]*)\@)?([^\/:]+|(?:\[[:0-9A-Fa-f]+\]))(:\d+)?(\/.*)$/;
    ($proto, $proxyauth, $host, $port) = ($1, $2, $3, $4);
    $path = $uri unless $uri =~ /^https:/;
  }
  $port = substr($port || ($proto eq 'http' ? ":80" : ":443"), 1);
  if ($param->{'_stripauthhost'} && $host ne $param->{'_stripauthhost'}) {
    @xhdrs = grep {!/^authorization:/i} @xhdrs;
    delete $param->{'authenticator'};
  }
  unshift @xhdrs, "Connection: close" unless $param->{'noclose'} || $param->{'keepalive'};
  unshift @xhdrs, "User-Agent: $useragent" unless !defined($useragent) || grep {/^user-agent:/si} @xhdrs;
  unshift @xhdrs, "Host: $hostport" unless grep {/^host:/si} @xhdrs;
  if (defined($auth) && !grep {/^authorization:/si} @xhdrs) {
    $auth =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    unshift @xhdrs, "Authorization: Basic ".encode_base64($auth, '');
  }
  if (defined($proxyauth) && !grep {/^proxy-authorization:/si} @xhdrs) {
    $proxyauth =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    unshift @xhdrs, "Proxy-Authorization: Basic ".encode_base64($proxyauth, '');
  }
  if ($proxy && $uri =~ /^https/) {
    if ($hostport =~ /:\d+$/) {
      $proxytunnel = "CONNECT $hostport HTTP/1.1\r\nHost: $hostport\r\n";
    } else {
      $proxytunnel = "CONNECT $hostport:443 HTTP/1.1\r\nHost: $hostport:443\r\n";
    }
    $proxytunnel .= shift(@xhdrs)."\r\n" if defined $proxyauth;
    $proxytunnel .= "\r\n";
  }
  push @xhdrs, map {"Cookie: $_"} getcookies($cookiestore, $uri) if $cookiestore && %$cookiestore;
  my $req = "$act $path HTTP/1.1\r\n".join("\r\n", @xhdrs)."\r\n\r\n";
  return ($proto, $host, $port, $req, $proxytunnel);
}

sub getcookies {
  my ($cookiestore, $uri) = @_;
  return () unless $uri =~ /^(https?:\/\/(?:[^\/\@]*\@)?[^\/:]+(?::\d+)?)\//;
  my $domain = lc($1);
  return  @{$cookiestore->{$domain} || []};
}

sub updatecookies {
  my ($cookiestore, $uri, $setcookie) = @_;
  return unless $cookiestore && $uri && $setcookie;
  return unless $uri =~ /^(https?:\/\/(?:[^\/\@]*\@)?[^\/:]+(?::\d+)?)\//;
  my $domain = lc($1);
  my %cookienames;
  my @cookie;
  for my $cookie (split(',', $setcookie)) {
    # XXX: limit to path=/ cookies?
    $cookie =~ s/;.*//;
    push @cookie, $cookie if $cookie =~ /^(.*?)=/ && !$cookienames{$1}++;
  }
  for my $cookie (@{$cookiestore->{$domain} || []}) {
    push @cookie, $cookie if $cookie =~ /^(.*?)=/ && !$cookienames{$1}++;
  }
  splice(@cookie, 10) if @cookie > 10;
  $cookiestore->{$domain} = \@cookie;
}

sub args {
  my ($h, @k) = @_;
  return map {
    my ($v, $k) = ($h->{$_}, $_);
    !defined($v) ? () : ref($v) eq 'ARRAY' ? map {"$k=$_"} @$v : "$k=$v";
  } @k;
}

sub readanswerheaderblock {
  my ($sock, $ans) = @_;
  $ans = '' unless defined $ans;
  do {
    my $r = sysread($sock, $ans, 1024, length($ans));
    if (!$r) {
      die("received truncated answer: $!\n") if !defined($r) && $! != POSIX::EINTR && $! != POSIX::EWOULDBLOCK;
      die("received truncated answer\n") if defined $r;
    }
  } while ($ans !~ /\n\r?\n/s);
  die("bad HTTP answer\n") unless $ans =~ s/^HTTP\/\d+?\.\d+?\s+?(\d+[^\r\n]*)/Status: $1/s;
  return ($1, $ans);
}

my $ai_addrconfig = eval { Socket::AI_ADDRCONFIG() } || 0;

sub lookuphost {
  my ($host, $port, $cache) = @_;
  $host=~ s/^\[|\]$//g;
  my $hostaddr;
  if ($cache && $cache->{$host} && $cache->{$host}->[1] > time()) {
    $hostaddr = $cache->{$host}->[0];
  } else {
    if (defined &Socket::getaddrinfo) {
      my $hints = { 'socktype' => SOCK_STREAM, 'flags' => $ai_addrconfig };
      my ($err, @ai) = Socket::getaddrinfo($host, undef, $hints);
      return undef if $err;
      my @aif = grep {$_->{'family'} == AF_INET} @ai;
      @aif = grep {$_->{'family'} == AF_INET6} @ai unless @aif;
      $hostaddr = $aif[0]->{'addr'} if @aif;
    } else {
      $hostaddr = inet_aton($host);
      $hostaddr = sockaddr_in(0, $hostaddr) if $hostaddr;
    }
    return undef unless $hostaddr;
    $cache->{$host} = [ $hostaddr, time() + $dnscachettl ] if $cache;
  }
  if (defined($port)) {
    if (sockaddr_family($hostaddr) == AF_INET6) {
      (undef, $hostaddr) = sockaddr_in6($hostaddr);
      $hostaddr = sockaddr_in6($port, $hostaddr);
    } else {
      (undef, $hostaddr) = sockaddr_in($hostaddr);
      $hostaddr = sockaddr_in($port, $hostaddr);
    }
  }
  return $hostaddr;
}

sub opensocket {
  my ($hostaddr) = @_;
  my $sock;
  if (sockaddr_family($hostaddr) == AF_INET6) {
    socket($sock, PF_INET6, SOCK_STREAM, $tcpproto) || die("socket: $!\n");
  } else {
    socket($sock, PF_INET, SOCK_STREAM, $tcpproto) || die("socket: $!\n");
  }
  setsockopt($sock, SOL_SOCKET, SO_KEEPALIVE, pack("l",1));
  return $sock;
}

sub setup_ssl_client {
  my ($sock, $param, $host) = @_;

  die("https not supported\n") unless $tossl || $param->{'https'};
  my ($keyfile, $certfile) = ($ssl_keyfile, $ssl_certfile);
  ($keyfile, $certfile) = ($param->{'ssl_keyfile'}, $param->{'ssl_certfile'}) if $param->{'ssl_keyfile'} || $param->{'ssl_certfile'};
  my $verify = $param->{'ssl_verify'} || ($ssl_verify ? ($ssl_verify->{'mode'} || 'fail_unverified') : undef);
  $verify = undef if $verify && $verify eq 'off';
  my $ctx = $param->{'ssl_ctx'};
  if ($verify && !$ctx) {
    # openssl only supports setting the verify location in the context
    $ssl_ctx ||= $ssl_newctx->('verify_file' => $ssl_verify->{'verify_file'}, 'verify_dir' => $ssl_verify->{'verify_dir'});
    $ctx = $ssl_ctx;
  }
  ($param->{'https'} || $tossl)->($sock, 'mode' => 'connect', 'connect_timeout' => $param->{'ssl_connect_timeout'}, 'nonblocking' => $param->{'nonblocking'}, 'keyfile' => $keyfile, 'certfile' => $certfile, 'verify' => $verify, 'ctx' => $ctx, 'sni' => $host);
  verify_sslpeerfingerprint($sock, $param->{'sslpeerfingerprint'}) if $param->{'sslpeerfingerprint'};
}

sub verify_sslpeerfingerprint {
  my ($sock, $sslfingerprint) = @_;
  die("bad sslpeerfingerprint '$sslfingerprint'\n") unless $sslfingerprint =~ /^(.*?):(.*)$/s;
  my $pfp =  tied(*{$sock})->peerfingerprint($1);
  die("peer fingerprint does not match: $2 != $pfp\n") if $2 ne $pfp;
}

sub probe_keepalive {
  my ($sock) = @_;
  my $rin = '';
  vec($rin, fileno($sock), 1) = 1;
  my $r = select($rin, undef, undef, 0);
  return defined($r) && $r == 0 ? 1 : 0;
}

sub call_authenticator {
  my ($param, @args) = @_;
  my $auth = $param->{'authenticator'} || $authenticator;
  if (ref($auth) eq 'HASH') {
    return undef unless $param->{'uri'} =~ /^(https?):\/\/(?:([^\/\@]*)\@)?([^\/:]+)(:\d+)?(\/.*)$/;
    my $authrealm = ($2 ? "$2\@" : '') . $3 . ($4 || '');
    $auth = $auth->{$authrealm};
  }
  if (ref($auth) eq 'ARRAY') {
    for my $au (@$auth) {
      my $r = $au->($param, @args);
      return $r if defined $r;
    }
    return undef;
  }
  return $auth->($param, @args) if $auth && ref($auth) eq 'CODE';
  return undef;
}

#
# handled paramters:
# timeout
# uri
# data
# datafmt
# headers (array)
# chunked
# request
# verbatim_uri
# socket
# https
# continuation
# verbose
# sender
# async
# replyheaders
# receiver
# ignorestatus
# receiverarg
# maxredirects
# proxy
# formurlencode
# sslpeerfingerprint
# ssl_verify
# ssl_keyfile
# ssl_certfile
# ssl_ctx
#

sub rpc {
  my ($param, $xmlargs, @args) = @_;

  $param = {'uri' => $param} if ref($param) ne 'HASH';

  # process timeout setup
  if ($param->{'timeout'}) {
    my %paramcopy = %$param;
    my $timeout = delete $paramcopy{'timeout'};
    $paramcopy{'running_timeout'} = $timeout;
    my $ans;
    local $SIG{'ALRM'} = sub {
      alarm(0);
      print "rpc timeout($timeout sec), uri: '$param->{uri}'\n" if $logtimeout;
      die("rpc timeout\n");
    };
    eval {
      eval {
        alarm($timeout);
        $ans = rpc(\%paramcopy, $xmlargs, @args);
      };
      alarm(0);
      die($@) if $@;
    };
    die($@) if $@;
    return $ans;
  }

  my @xhdrs = @{$param->{'headers'} || []};
  my $chunked = $param->{'chunked'} ? 1 : undef;

  # do data conversion
  my $data = $param->{'data'};
  if ($param->{'datafmt'} && defined($data)) {
    my $datafmt = $param->{'datafmt'};
    if (ref($datafmt) eq 'CODE') {
      $data = $datafmt->($data);
    } else {
      $data = XMLout($datafmt, $data);
    }
  }

  # do from urlencoding if requested
  my $formurlencode = $param->{'formurlencode'};
  if (!defined($data) && ($param->{'request'} || '') eq 'POST' && @args) {
    if (grep {/^content-type:\sapplication\/x-www-form-urlencoded$/i} @xhdrs) {
      $formurlencode = 1;		# compat
    } elsif ($formurlencode) {
      push @xhdrs, 'Content-Type: application/x-www-form-urlencoded';
    }
    if ($formurlencode) {
      $data = BSHTTP::queryencode(@args);
      @args = ();
    }
  }

  push @xhdrs, "Content-Length: ".length($data) if defined($data) && !ref($data) && !$chunked && !grep {/^content-length:/i} @xhdrs;
  push @xhdrs, "Transfer-Encoding: chunked" if $chunked;
  if (($authenticator || $param->{'authenticator'}) && !grep {/^authorization:/i} @xhdrs) {
    # ask authenticator for cached authorization
    my $auth = call_authenticator($param);
    push @xhdrs, "Authorization: $auth" if $auth;
  }
  my $uri = createuri($param, @args);
  my $proxy = $param->{'proxy'};
  addautoheaders(\@xhdrs);
  my ($proto, $host, $port, $req, $proxytunnel) = createreq($param, $uri, $proxy, \%cookiestore, @xhdrs);
  if ($proto eq 'https' || $proxytunnel) {
    die("https not supported\n") unless $tossl || $param->{'https'};
  }

  # connect to server
  my $keepalive;
  my ($keepalivecookie, $keepalivecount, $keepalivestart);
  my $sock;
  my $is_ssl;
  if (exists($param->{'socket'})) {
    $sock = $param->{'socket'};
  } else {
    die("rpc continuation without socket\n") if $param->{'continuation'};
    my $hostaddr = lookuphost($host, $port, \%hostlookupcache);
    die("unknown host '$host'\n") unless $hostaddr;
    $keepalive = $param->{'keepalive'};
    $keepalivecookie = "$proto://$hostaddr/".($proxytunnel || '');
    if ($keepalive && $keepalive->{'socket'}) {
      if (($keepalive->{'cookie'} || '') eq $keepalivecookie && probe_keepalive($keepalive->{'socket'})) {
	$sock = $keepalive->{'socket'};
	$keepalivestart = $keepalive->{'start'} || time();
	$keepalivecount = ($keepalive->{'count'} || 0) + 1;
      }
    }
    %$keepalive = () if $keepalive;	# clean old data in case we die
    if (!$sock) {
      if ($keepalive) {
	$keepalivestart = time();
	$keepalivecount = 0;
      }
      $sock = opensocket($hostaddr);
      connect($sock, $hostaddr) || die("connect to $host:$port: $!\n");
      if ($proxytunnel) {
        BSHTTP::swrite($sock, $proxytunnel);
        my ($status, $ans) = readanswerheaderblock($sock);
        die("proxy tunnel: CONNECT method failed: $status\n") unless $status =~ /^200[^\d]/;
      }
      if ($proto eq 'https' || $proxytunnel) {
	setup_ssl_client($sock, $param, $host, $tossl);
	$is_ssl = 1;
      }
    } else {
      if ($proto eq 'https' || $proxytunnel) {
	verify_sslpeerfingerprint($sock, $param->{'sslpeerfingerprint'}) if $param->{'sslpeerfingerprint'};
	$is_ssl = 1;
      }
    }
  }

  # send request
  if (!$param->{'continuation'}) {
    $data = '' unless defined $data;
    if ($param->{'verbose'}) {
      print "> $_\n" for split("\r\n", $req);
      #print "> $data\n" unless ref($data);
    }
    if (!ref($data)) {
      # append body to request (chunk encoded if requested)
      if ($chunked) {
	$data = sprintf("%X\r\n", length($data)).$data."\r\n" if $data ne '';
	$data .= "0\r\n\r\n";
      }
      $req .= $data;
      undef $data;
    }
    if ($param->{'sender'}) {
      $param->{'sender'}->($param, $sock, $req, $data);
    } elsif (!ref($data)) {
      BSHTTP::swrite($sock, $req);
    } else {
      BSHTTP::swrite($sock, $req);
      while(1) {
	$req = $data->($param, $sock);
	last if !defined($req) || !length($req);
        BSHTTP::swrite($sock, $req, $chunked);
      }
      BSHTTP::swrite($sock, "0\r\n\r\n") if $chunked;
    }
  }

  # return here if in async mode
  if ($param->{'async'} && !$param->{'continuation'}) {
    my $ret = {};
    $ret->{'uri'} = $uri;
    $ret->{'socket'} = $sock;
    $ret->{'async'} = 1;
    $ret->{'continuation'} = 1;
    $ret->{'request'} = $param->{'request'} || 'GET';
    $ret->{'verbose'} = $param->{'verbose'} if $param->{'verbose'};
    $ret->{'replyheaders'} = $param->{'replyheaders'} if $param->{'replyheaders'};
    $ret->{'receiver'} = $param->{'receiver'} if $param->{'receiver'};
    $ret->{'receiverarg'} = $xmlargs if $xmlargs;
    $ret->{'is_ssl'} = 1 if $is_ssl;
    fcntl($sock, F_SETFL, O_NONBLOCK);
    return $ret;
  }

  fcntl($sock, F_SETFL, 0) if $param->{'continuation'};

  # read answer from server, first the header block
  my ($status, $ans) = readanswerheaderblock($sock);
  $ans =~ /^(.*?)\n\r?\n(.*)$/s;
  my $headers = $1;
  $ans = $2;
  if ($param->{'verbose'}) {
    print "< $_\n" for split(/\r?\n/, $headers);
  }
  my %headers;
  BSHTTP::gethead(\%headers, $headers);

  # no keepalive if the server says so
  undef $keepalive if lc($headers{'connection'} || '') eq 'close';
  undef $keepalive if !defined($headers{'content-length'}) && lc($headers{'transfer-encoding'} || '') ne 'chunked';

  # process header
  #
  # HTTP Status Code Definitions
  # Successful 2xx
  # https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
  #
  updatecookies(\%cookiestore, $param->{'uri'}, $headers{'set-cookie'}) if $headers{'set-cookie'};
  if ($status =~ /^2\d\d[^\d]/) {
    undef $status;
  } else {
    #if ($param->{'verbose'}) {
    #  1 while sysread($sock, $ans, 1024, length($ans));
    #  print "< $ans\n";
    #}
    if ($status =~ /^30[27][^\d]/ && ($param->{'ignorestatus'} || 0) != 2) {
      close $sock;
      die("error: no redirects allowed\n") unless defined $param->{'maxredirects'};
      die("error: status 302 but no 'location' header found\n") unless exists $headers{'location'};
      die("error: max number of redirects reached\n") if $param->{'maxredirects'} < 1;
      my %myparam = %$param;
      $myparam{'uri'} = $headers{'location'};
      $myparam{'maxredirects'} = $param->{'maxredirects'} - 1;
      $myparam{'_stripauthhost'} = $host;	# strip authentication on redirect to different domain
      $myparam{'verbatim_uri'} = 1;
      return rpc(\%myparam, $xmlargs, @args);
    }
    if ($status =~ /^401[^\d]/ && $headers{'www-authenticate'} && !$param->{'authenticator_norecurse'} && ($authenticator || $param->{'authenticator'})) {
      # unauthorized, ask callback for authorization
      my $auth = call_authenticator($param, $headers{'www-authenticate'}, \%headers);
      if ($auth) {
        close $sock;
        my %myparam = (%$param, 'authenticator_norecurse' => 1);
        $myparam{'headers'} = [ grep {!/^authorization:/i} @{$myparam{'headers'} || []} ];
        push @{$myparam{'headers'}}, "Authorization: $auth";
        return rpc(\%myparam, $xmlargs, @args);
      }
    }
    if (!$param->{'ignorestatus'}) {
      close $sock;
      die("$1 remote error: $2 ($uri)\n") if $status =~ /^(\d+) +(.*?)$/;
      die("remote error: $status\n");
    }
  }
  ${$param->{'replyheaders'}} = \%headers if $param->{'replyheaders'};

  # read and process rest of answer
  my $ansreq = {
    'headers' => \%headers,
    'rawheaders' => $headers,
    '__socket' => $sock,
    '__data' => $ans,
  };
  if (($param->{'request'} || 'GET') eq 'HEAD') {
    if ($keepalive) {
      $keepalive->{'socket'} = $sock;
      $keepalive->{'cookie'} = $keepalivecookie;
      $keepalive->{'start'} = $keepalivestart;
      $keepalive->{'count'} = $keepalivecount;
      $keepalive->{'last'} = time();
    } else {
      close $sock;
      undef $sock;
    }
    return \%headers unless $param->{'receiver'};
    delete $ansreq->{'__socket'};
    delete $ansreq->{'__data'};
    $ansreq->{'__cl'} = -1;	# eof
  }
  my $receiver = $param->{'receiver'};
  $xmlargs ||= $param->{'receiverarg'};
  if ($receiver) {
    $ans = $receiver->($ansreq, $param, $xmlargs);
    $xmlargs = undef;
  } else {
    $ans = BSHTTP::read_data($ansreq, undef, 1);
  }
  if ($keepalive && $sock) {
    $keepalive->{'socket'} = $sock;
    $keepalive->{'cookie'} = $keepalivecookie;
    $keepalive->{'start'} = $keepalivestart;
    $keepalive->{'count'} = $keepalivecount;
    $keepalive->{'last'} = time();
  } else {
    close $sock if $sock;
  }

  #if ($param->{'verbose'}) {
  #  print "< $ans\n";
  #}
  if ($xmlargs) {
    if (ref($xmlargs) eq 'CODE') {
      $ans = $xmlargs->($ans);
    } else {
      die("answer is not xml\n") if $ans !~ /<.*?>/s;
      $ans = XMLin($xmlargs, $ans);
    }
  }
  return $ans;
}

sub rpc_isfinished {
  my ($param) = @_;
  die("not an async request\n") unless $param->{'continuation'};
  my $sock = $param->{'socket'};
  if ($param->{'is_ssl'}) {
    my $d = tied(*{$sock})->data_available();
    return 0 if defined($d) && !$d;
  }
  return 1;
}

1;

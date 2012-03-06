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
use XML::Structured;
use Symbol;
use MIME::Base64;
use Data::Dumper;

use BSHTTP;
use BSConfig;

use strict;

our $useragent = 'BSRPC 0.9.1';

my %hostlookupcache;
my %cookiestore;	# our session store to keep iChain fast
my $tossl;

my $noproxy;
$noproxy = $BSConfig::noproxy if defined($BSConfig::noproxy);

sub import {
  if (grep {$_ eq ':https'} @_) {
    require BSSSL;
    $tossl = \&BSSSL::tossl;
  }
}


my $tcpproto = getprotobyname('tcp');

sub urlencode {
  my $url = $_[0];
  $url =~ s/([\000-\040<>;\"#\?&\+=%[\177-\377])/sprintf("%%%02X",ord($1))/sge;
  return $url;
}

sub createuri {
  my ($param, @args) = @_;
  my $uri = $param->{'uri'};
  if (!$param->{'verbatim_uri'} && $uri =~ /^(https?:\/\/[^\/]*\/)(.*)$/s) {
    $uri = $1; 
    $uri .= BSRPC::urlencode($2);
  }
  if (@args) {
    for (@args) {
      $_ = urlencode($_);
      s/%3D/=/;	# convert first now escaped '=' back
    }   
    if ($uri =~ /\?/) {
      $uri .= '&'.join('&', @args); 
    } else {
      $uri .= '?'.join('&', @args); 
    }   
  }
  return $uri;
}

sub useproxy {
  my ($host, $noproxy) = @_;

  # strip leading and tailing whitespace
  $noproxy =~ s/^\s+//;
  $noproxy =~ s/\s+$//;
  # noproxy is a list separated by commas and optional whitespace
  for (split(/\s*,\s*/, $noproxy)) {
    return 0 if $host =~ m/(^|\.)$_$/;
  }
  return 1;
}

sub createreq {
  my ($param, $uri, $proxy, $cookiestore, @xhdrs) = @_;

  my $act = $param->{'request'} || 'GET';
  if (exists($param->{'socket'})) {
    my $req = "$act $uri HTTP/1.1\r\n".join("\r\n", @xhdrs)."\r\n\r\n";
    return ('', undef, undef, $req, undef);
  }
  my ($proxyauth, $proxytunnel);
  die("bad uri: $uri\n") unless $uri =~ /^(https?):\/\/(?:([^\/\@]*)\@)?([^\/:]+)(:\d+)?(\/.*)$/;
  my ($proto, $auth, $host, $port, $path) = ($1, $2, $3, $4, $5);
  my $hostport = $port ? "$host$port" : $host;
  undef $proxy if $proxy && defined($noproxy) && !useproxy($host, $noproxy);
  if ($proxy) {
    die("bad proxy uri: $proxy\n") unless "$proxy/" =~ /^(https?):\/\/(?:([^\/\@]*)\@)?([^\/:]+)(:\d+)?(\/.*)$/;
    ($proto, $proxyauth, $host, $port) = ($1, $2, $3, $4);
    $path = $uri unless $uri =~ /^https:/;
  }
  $port = substr($port || ($proto eq 'http' ? ":80" : ":443"), 1);
  unshift @xhdrs, "Connection: close" unless $param->{'noclose'};
  unshift @xhdrs, "User-Agent: $useragent" unless !defined($useragent) || grep {/^user-agent:/si} @xhdrs;
  unshift @xhdrs, "Host: $hostport" unless grep {/^host:/si} @xhdrs;
  if (defined $auth) {
    $auth =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    unshift @xhdrs, "Authorization: Basic ".encode_base64($auth, '');
  }
  if (defined $proxyauth) {
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
  if ($cookiestore && %$cookiestore) {
    if ($uri =~ /((:?https?):\/\/(?:([^\/]*)\@)?(?:[^\/:]+)(?::\d+)?)(?:\/.*)$/) {
      push @xhdrs, map {"Cookie: $_"} @{$cookiestore->{$1} || []};
    }
  }
  my $req = "$act $path HTTP/1.1\r\n".join("\r\n", @xhdrs)."\r\n\r\n";
  return ($proto, $host, $port, $req, $proxytunnel);
}

#
# handled paramters:
# timeout
# uri
# data
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
#

sub rpc {
  my ($uri, $xmlargs, @args) = @_;

  my $data = '';
  my @xhdrs;
  my $chunked;
  my $param = {'uri' => $uri};

  if (ref($uri) eq 'HASH') {
    $param = $uri;
    my $timeout = $param->{'timeout'};
    if ($timeout) {
      my %paramcopy = %$param;
      delete $paramcopy{'timeout'};
      my $ans;
      local $SIG{'ALRM'} = sub {alarm(0); die("rpc timeout\n");};
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
    $uri = $param->{'uri'};
    $data = $param->{'data'};
    @xhdrs = @{$param->{'headers'} || []};
    $chunked = 1 if $param->{'chunked'};
    if (!defined($data) && $param->{'request'} && $param->{'request'} eq 'POST' && @args && grep {/^content-type:\sapplication\/x-www-form-urlencoded$/i} @xhdrs) {
      for (@args) {
	$_ = urlencode($_);
        s/%3D/=/;	# convert now escaped = back
      }
      $data = join('&', @args);
      @args = ();
    }
    push @xhdrs, "Content-Length: ".length($data) if defined($data) && !ref($data) && !$chunked && !grep {/^content-length:/i} @xhdrs;
    push @xhdrs, "Transfer-Encoding: chunked" if $chunked;
    $data = '' unless defined $data;
  }
  $uri = createuri($param, @args);
  my $proxy = $param->{'proxy'};
  my ($proto, $host, $port, $req, $proxytunnel) = createreq($param, $uri, $proxy, \%cookiestore, @xhdrs);
  if ($proto eq 'https' || $proxytunnel) {
    die("https not supported\n") unless $tossl || $param->{'https'};
  }
  local *S;
  if (exists($param->{'socket'})) {
    *S = $param->{'socket'};
  } else {
    if (!$hostlookupcache{$host}) {
      my $hostaddr = inet_aton($host);
      die("unknown host '$host'\n") unless $hostaddr;
      $hostlookupcache{$host} = $hostaddr;
    }
    socket(S, PF_INET, SOCK_STREAM, $tcpproto) || die("socket: $!\n");
    setsockopt(S, SOL_SOCKET, SO_KEEPALIVE, pack("l",1));
    connect(S, sockaddr_in($port, $hostlookupcache{$host})) || die("connect to $host:$port: $!\n");
    if ($proxytunnel) {
      BSHTTP::swrite(\*S, $proxytunnel);
      my $ans = '';
      do {
	die("received truncated answer\n") if !sysread(S, $ans, 1024, length($ans));
      } while ($ans !~ /\n\r?\n/s);
      die("bad answer\n") unless $ans =~ s/^HTTP\/\d+?\.\d+?\s+?(\d+[^\r\n]*)/Status: $1/s;
      my $status = $1;
      die("proxy tunnel: CONNECT method failed: $status\n") unless $status =~ /^200[^\d]/;
    }
    ($param->{'https'} || $tossl)->(\*S, $param->{'ssl_keyfile'}, $param->{'ssl_certfile'}, 1) if $proto eq 'https' || $proxytunnel;
  }
  if (!$param->{'continuation'}) {
    if ($param->{'verbose'}) {
      print "> $_\n" for split("\r\n", $req);
      #print "> $data\n" unless ref($data);
    }
    $req .= "$data" unless ref($data);
    if ($param->{'sender'}) {
      $param->{'sender'}->($param, \*S, $req);
    } else {
      while(1) {
	BSHTTP::swrite(\*S, $req);
	last unless ref $data;
	$req = &$data($param, \*S);
	if (!defined($req) || !length($req)) {
	  $req = $data = '';
	  $req = "0\r\n\r\n" if $chunked;
	  next;
	}
	$req = sprintf("%X\r\n", length($req)).$req."\r\n" if $chunked;
      }
    }
    if ($param->{'async'}) {
      my $ret = {};
      $ret->{'uri'} = $uri;
      my $fd = gensym;
      *$fd = \*S;
      $ret->{'socket'} = $fd;
      $ret->{'async'} = 1;
      $ret->{'continuation'} = 1;
      $ret->{'request'} = $param->{'request'} || 'GET';
      $ret->{'verbose'} = $param->{'verbose'} if $param->{'verbose'};
      $ret->{'replyheaders'} = $param->{'replyheaders'} if $param->{'replyheaders'};
      $ret->{'receiver'} = $param->{'receiver'} if $param->{'receiver'};
      $ret->{$_} = $param->{$_} for grep {/^receiver:/} keys %$param;
      $ret->{'receiverarg'} = $xmlargs if $xmlargs;
      return $ret;
    }
  }
  my $ans = '';
  do {
    die("received truncated answer\n") if !sysread(S, $ans, 1024, length($ans));
  } while ($ans !~ /\n\r?\n/s);
  die("bad answer\n") unless $ans =~ s/^HTTP\/\d+?\.\d+?\s+?(\d+[^\r\n]*)/Status: $1/s;
  my $status = $1;
  $ans =~ /^(.*?)\n\r?\n(.*)$/s;
  my $headers = $1;
  $ans = $2;
  if ($param->{'verbose'}) {
    print "< $_\n" for split(/\r?\n/, $headers);
  }
  my %headers;
  BSHTTP::gethead(\%headers, $headers);
  if ($status =~ /^200[^\d]/) {
    undef $status;
  } elsif ($status =~ /^302[^\d]/) {
    # XXX: should we do the redirect if $param->{'ignorestatus'} is defined?
    close S;
    die("error: no redirects allowed\n") unless defined $param->{'maxredirects'};
    die("error: status 302 but no 'location' header found\n") unless exists $headers{'location'};
    die("error: max number of redirects reached\n") if $param->{'maxredirects'} < 1;
    my %myparam = %$param;
    $myparam{'uri'} = $headers{'location'};
    $myparam{'maxredirects'} = $param->{'maxredirects'} - 1;
    return rpc(\%myparam, $xmlargs, @args);
  } else {
    #if ($param->{'verbose'}) {
    #  1 while sysread(S, $ans, 1024, length($ans));
    #  print "< $ans\n";
    #}
    if ($status =~ /^(\d+) +(.*?)$/) {
      die("$1 remote error: $2\n") unless $param->{'ignorestatus'};
    } else {
      die("remote error: $status\n") unless $param->{'ignorestatus'};
    }
  }
  if ($headers{'set-cookie'} && $param->{'uri'}) {
    my @cookie = split(',', $headers{'set-cookie'});
    s/;.*// for @cookie;
    if ($param->{'uri'} =~ /((:?https?):\/\/(?:([^\/]*)\@)?(?:[^\/:]+)(?::\d+)?)(?:\/.*)$/) {
      my %cookie = map {$_ => 1} @cookie;
      push @cookie, grep {!$cookie{$_}} @{$cookiestore{$1} || []};
      splice(@cookie, 10) if @cookie > 10;
      $cookiestore{$1} = \@cookie;
    }
  }
  if (($param->{'request'} || '') eq 'HEAD') {
    close S;
    ${$param->{'replyheaders'}} = \%headers if $param->{'replyheaders'};
    return \%headers;
  }
  $headers{'__socket'} = \*S;
  $headers{'__data'} = $ans;
  my $receiver;
  $receiver = $param->{'receiver:'.lc($headers{'content-type'} || '')};
  $receiver ||= $param->{'receiver'};
  $xmlargs ||= $param->{'receiverarg'};
  if ($receiver) {
    $ans = $receiver->(\%headers, $param, $xmlargs);
    $xmlargs = undef;
  } else {
    $ans = BSHTTP::read_data(\%headers, undef, 1);
  }
  close S;
  delete $headers{'__socket'};
  delete $headers{'__data'};
  ${$param->{'replyheaders'}} = \%headers if $param->{'replyheaders'};
  #if ($param->{'verbose'}) {
  #  print "< $ans\n";
  #}
  if ($xmlargs) {
    die("answer is not xml\n") if $ans !~ /<.*?>/s;
    my $res = XMLin($xmlargs, $ans);
    return $res;
  }
  return $ans;
}

1;

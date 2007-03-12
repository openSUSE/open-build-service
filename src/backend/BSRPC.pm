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

use BSHTTP;

use strict;

my %hostlookupcache;

my $tcpproto = getprotobyname('tcp');

sub urlencode {
  my $url = $_[0];
  $url =~ s/([\000-\040<>\"#\?&\+=%[\177-\377])/sprintf("%%%02X",ord($1))/sge;
  return $url;
}

sub rpc {
  my ($uri, $xmlargs, @args) = @_;

  my $data = '';
  my @xhdrs;
  my $chunked;
  my $param = {};
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
    push @xhdrs, "Content-Length: ".length($data) if defined($data) && !ref($data) && !$chunked && !grep {/^content-length:/i} @xhdrs;
    push @xhdrs, "Transfer-Encoding: chunked" if $chunked;
    $data = '' unless defined $data;
  }
  $uri = urlencode($uri) unless $param->{'verbatim_uri'};
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
  my ($host, $port, $path);
  if (exists($param->{'socket'})) {
    *S = *{$param->{'socket'}};
    $path = $uri;
  } else {
    die("bad uri: $uri\n") unless $uri =~ /^http:\/\/([^\/:]+)(:\d+)?(\/.*)$/;
    ($host, $port, $path) = ($1, $2, $3);
    my $hostport = $port ? "$host$port" : $host;
    $port = substr($port || ":80", 1);
    if (!$hostlookupcache{$host}) {
      my $hostaddr = inet_aton($host);
      die("unknown host '$host'\n") unless $hostaddr;
      $hostlookupcache{$host} = $hostaddr;
    }
    socket(S, PF_INET, SOCK_STREAM, $tcpproto) || die("socket: $!\n");
    connect(S, sockaddr_in($port, $hostlookupcache{$host})) || die("connect to $host:$port: $!\n");
    unshift @xhdrs, "Host: $hostport" unless grep {/^host:/si} @xhdrs;
  }

  my $act = $param->{'request'} || 'GET';
  my $req = "$act $path HTTP/1.1\r\n".join("\r\n", @xhdrs)."\r\n\r\n";
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
  my $ans = '';
  do {
    die("received truncated answer\n") if !sysread(S, $ans, 1024, length($ans));  } while ($ans !~ /\n\r?\n/s);
  die("bad answer\n") unless $ans =~ s/^HTTP\/\d+?\.\d+?\s+?(\d+[^\r\n]*)/Status: $1/s;
  my $status = $1;
  $ans =~ /^(.*?)\n\r?\n(.*)$/s;
  my $headers = $1;
  $ans = $2;
  my %headers;
  BSHTTP::gethead(\%headers, $headers);
  if ($status !~ /^200[^\d]/) {
    die("Remote error: $status\n") unless $param->{'ignorestatus'};
  } else {
    undef $status;
  }
  if ($act eq 'HEAD') {
    close S;
    ${$param->{'replyheaders'}} = \%headers if $param->{'replyheaders'};
    return \%headers;
  }
  $headers{'__socket'} = \*S;
  $headers{'__data'} = $ans;
  my $receiver;
  $receiver = $param->{'receiver:'.lc($headers{'content-type'} || '')};
  $receiver ||= $param->{'receiver'};
  if ($receiver) {
    $ans = $receiver->(\%headers, $param);
  } else {
    $ans = BSHTTP::read_data(\%headers, undef, 1);
  }
  close S;
  delete $headers{'__socket'};
  delete $headers{'__data'};
  ${$param->{'replyheaders'}} = \%headers if $param->{'replyheaders'};
  if ($xmlargs) {
    die("answer is not xml\n") if $ans !~ /<.*?>/s;
    my $res = XMLin($xmlargs, $ans);
    return $res;
  }
  return $ans;
}

1;

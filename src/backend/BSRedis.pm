#
# Copyright (c) 2019 SUSE Inc.
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
# Redis functions
#

package BSRedis;

use Encode;
use Socket;
use POSIX;

use BSRPC;

my $tcpproto = getprotobyname('tcp');

sub new {
  my ($class, %opt) = @_;
  my $self = { %opt };
  die("need to specify a redis server\n") unless $self->{'server'};
  $self->{'port'} ||= 6379;
  bless $self, $class || 'BSRedis';
  return $self;
}

sub connect {
  my ($self) = @_;
  return if $self->{'sock'};
  my $hostaddr = inet_aton($self->{'server'});
  die("unknown host '$self->{'server'}'\n") unless $hostaddr;
  my $sock;
  socket($sock, PF_INET, SOCK_STREAM, $tcpproto) || die("socket: $!\n");
  setsockopt($sock, SOL_SOCKET, SO_KEEPALIVE, pack("l",1));
  connect($sock, sockaddr_in($self->{'port'}, $hostaddr)) || die("connect to $self->{'server'}:$self->{'port'}: $!\n");
  $self->{'sock'} = $sock;
  $self->{'buf'} = '';
  $self->run('AUTH', $self->{'password'}) if defined $self->{'password'};
}

sub quit {
  my ($self) = @_;
  return unless $self->{'sock'};
  $self->run('QUIT');
  close(delete $self->{'sock'}) if $self->{'sock'};
}

sub send {
  my ($self, @args) = @_;
  my $line = '*'.scalar(@args)."\r\n";
  for (@args) {
    if (!defined($_)) {
      $line .= "\$-1\r\n";
    } else {
      Encode::_utf8_off($_);
      $line .= '$'.length($_)."\r\n$_\r\n";
    }
  }
  $self->connect() unless $self->{'sock'};
  my $sock = $self->{'sock'};
  while ($line) {
    my $len = syswrite($sock, $line, length($line));
    die("redis syswrite: $!\n") unless $len;
    substr($line, 0, $len, '');
  }
}

sub close_and_die {
  my ($self, $msg) = @_;
  close(delete $self->{'sock'}) if $self->{'sock'};
  die($msg);
}

sub recv_line {
  my ($self) = @_;
  my $sock = $self->{'sock'};
  die unless $sock;
  while (1) {
    if ($self->{'buf'} =~ /^(.*?)\r\n/s) {
      substr($self->{'buf'}, 0, length($1) + 2, '');
      return $1;
    }
    my $r = sysread($sock, $self->{'buf'}, 4096, length($self->{'buf'}));
    if (!$r) {
      $self->close_and_die("redis: received truncated answer: $!\n") if !defined($r) && $! != POSIX::EINTR && $! != POSIX::EWOULDBLOCK;
      $self->close_and_die("redis: received truncated answer\n") if defined $r;
    }
  }
}

sub recv_blob {
  my ($self, $len) = @_;
  my $sock = $self->{'sock'};
  die unless $sock;
  while (length($self->{'buf'}) < $len) {
    if (!$r) {
      $self->close_and_die("redis: received truncated answer: $!\n") if !defined($r) && $! != POSIX::EINTR && $! != POSIX::EWOULDBLOCK;
      $self->close_and_die("redis: received truncated answer\n") if defined $r;
    }
  }
  return substr($self->{'buf'}, 0, $len, '');
}

sub recv_int {
  my ($self) = @_;
  my $sock = $self->{'sock'};

  my $line = recv_line($self);
  my $type = substr($line, 0, 1);
  if ($type eq '-') {
    return undef, substr($line, 1);
  } elsif ($type eq '+' || $type eq ':') {
    return substr($line, 1), undef;
  } elsif ($type eq '$') {
    my $len = substr($line, 1);
    return undef, undef if $len < 0;
    my $blob = recv_blob($self, $len + 2);
    $self->close_and_die("redis: received bad blob answer\n") if substr($blob, $len, 2, '') ne "\r\n";
    return $blob, undef;
  } elsif ($type eq '*') {
    my $nelm = substr($line, 1);
    return undef, undef if $nelm < 0;
    my @ret;
    my @err;
    while ($nelm-- > 0) {
      my ($ret, $err) = recv_int($self);
      push @ret, $ret;
      push @err, $err if defined $err;
    }
    return \@ret, (@err ? join("\n", @err) : undef);
  } else {
    $self->close_and_die("redis: unknown return type '$type'\n");
  }
}

sub recv {
  my ($self) = @_;
  my ($ret, $err) = recv_int($self);
  die("$err\n") if defined $err;
  return $ret;
}

sub run {
  my ($self, @args) = @_;
  $self->send(@args);
  return $self->recv();
}

1;

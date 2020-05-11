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
# event scheduling functions
#

# TODO: switch to poll()

package BSEvents;

use POSIX;

my $nextid = 0;
my $emptyvec = "\0\0\0\0\0\0\0\0" x 16;

my %events;
my $events_rvec = $emptyvec;
my $events_wvec = $emptyvec;
my %events_rvec;
my %events_wvec;

sub new {
  my ($type, $handler) = @_;
  if ($type eq 'timeout') {
    return {'id' => $nextid++, 'type' => $type, 'timeouthandler' => $handler};
  }
  return {'id' => $nextid++, 'type' => $type, 'handler' => $handler};
}

sub add {
  my ($ev, $timeout) = @_;
  die("event has no id\n") unless exists $ev->{'id'};
  if ($ev->{'type'} eq 'always') {
    $ev->{'handler'}->($ev) if $ev->{'handler'};
    return;
  }
  #print "add ev #$ev->{'id'}\n";
  if (defined($timeout)) {
    if ($timeout) {
      $ev->{'timeout'} = time() + $timeout;
    } else {
      delete $ev->{'timeout'};
    }
  }
  die("event #$ev->{'id'} already added\n") if $events{$ev->{'id'}};
  $events{$ev->{'id'}} = $ev;
  if ($ev->{'type'} eq 'read') {
    $ev->{'vec'} = $emptyvec;
    #printf "add read ev #$ev->{'id'} fd %d\n", fileno(*{$ev->{'fd'}});
    vec($ev->{'vec'}, fileno(*{$ev->{'fd'}}), 1) = 1;
    die("fd out of range\n") if length($ev->{'vec'}) != 128;
    $events_rvec |= $ev->{'vec'};
    die("event for file descriptor added twice\n") if $events_rvec{$ev->{'vec'}};
    $events_rvec{$ev->{'vec'}} = $ev;
  } elsif ($ev->{'type'} eq 'write') {
    $ev->{'vec'} = $emptyvec;
    #printf "add write ev #$ev->{'id'} fd %d\n", fileno(*{$ev->{'fd'}});
    vec($ev->{'vec'}, fileno(*{$ev->{'fd'}}), 1) = 1;
    die("fd out of range\n") if length($ev->{'vec'}) != 128;
    $events_wvec |= $ev->{'vec'};
    die("event for file descriptor added twice\n") if $events_wvec{$ev->{'vec'}};
    $events_wvec{$ev->{'vec'}} = $ev;
  } else {
    delete $ev->{'vec'};
  }
}

sub set_timeout {
  my ($ev, $timeout) = @_;
  die("event has no id\n") unless exists $ev->{'id'};
  die("event #$ev->{'id'} is not active \n") unless $events{$ev->{'id'}};
  if ($timeout) {
    $ev->{'timeout'} = time() + $timeout;
  } else {
    delete $ev->{'timeout'};
  }
}

sub rem {
  my ($ev) = @_;
  return unless $events{$ev->{'id'}};
  if ($ev->{'type'} eq 'read') {
    #print "delete read ev #$ev->{'id'}\n";
    $events_rvec &= ~$ev->{'vec'};
    delete $events_rvec{$ev->{'vec'}};
  } elsif ($ev->{'type'} eq 'write') {
    #print "delete write ev #$ev->{'id'}\n";
    $events_wvec &= ~$ev->{'vec'};
    delete $events_wvec{$ev->{'vec'}};
  }
  delete $events{$ev->{'id'}};
}

sub schedule {

  while (1) {
    #print "select loop, num events=".(keys %events)."\n";
    my $timeout;
    for my $ev (values %events) {
      $timeout = $ev->{'timeout'} if $ev->{'timeout'} && (!defined($timeout) || $ev->{'timeout'} < $timeout);
    }
    my $rvec = $events_rvec;
    my $wvec = $events_wvec;
    my $now = time();
    if (defined($timeout) && $timeout <= $now) {
      for my $id (sort keys %events) {
	my $ev = $events{$id};
	next unless $ev && $ev->{'timeout'} && $ev->{'timeout'} <= $now;
        #print "timeout for event #$ev->{'id'}\n" if $ev->{'fd'};
	rem($ev);
	$ev->{'timeouthandler'}->($ev) if $ev->{'timeouthandler'};
      }
      next;
    }
    my $nfound = select($rvec, $wvec, undef, defined($timeout) ? $timeout - $now : undef);
    if (!defined($nfound) || $nfound == -1) {
      next if $! == POSIX::EINTR;
      die("select: $!\n");
    }
    next unless $nfound;
    my $ev;
    $ev = $events_rvec{$rvec};
    if ($ev) {
      #print "fast call for read #$ev->{'id'} fd ".fileno(*{$ev->{'fd'}})."\n";
      rem($ev);
      $ev->{'handler'}->($ev);
      undef $rvec;
    }
    $ev = $events_wvec{$wvec};
    if ($ev) {
      #print "fast call for write #$ev->{'id'} fd ".fileno(*{$ev->{'fd'}})."\n";
      rem($ev);
      $ev->{'handler'}->($ev);
      undef $wvec;
    }
    $rvec = undef if defined($rvec) && $rvec eq $emptyvec;
    $wvec = undef if defined($wvec) && $wvec eq $emptyvec;
    next unless defined($rvec) || defined($wvec);
    #print "slow call!\n";
    for my $id (sort keys %events) {
      my $ev = $events{$id};
      next unless $ev;
      if (defined($rvec) && $ev->{'type'} eq 'read' && vec($rvec, fileno(*{$ev->{'fd'}}), 1)) {
        #print "slow call for read #$ev->{'id'} fd ".fileno(*{$ev->{'fd'}})."\n";
        rem($ev);
        $ev->{'handler'}->($ev);
        next;
      }
      if (defined($wvec) && $ev->{'type'} eq 'write' && vec($wvec, fileno(*{$ev->{'fd'}}), 1)) {
        #print "slow call for write #$ev->{'id'} fd ".fileno(*{$ev->{'fd'}})."\n";
        rem($ev);
        $ev->{'handler'}->($ev);
        next;
      }
    }
  }
}

sub allevents {
  return values(%events);
}

1;

#
# Copyright (c) 2016 SUSE LLC
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

package BSRunner;

use POSIX;
use Fcntl qw(:DEFAULT :flock);

use BSUtil;

use strict;

sub reap {
  my ($maxchild, $chld, $chld_flavor) = @_;

  my $pid;
  while (($pid = waitpid(-1, defined($maxchild) && keys(%$chld) > $maxchild ? 0 : POSIX::WNOHANG)) > 0) {
    my $cflavor = delete $chld->{$pid};
    delete $chld_flavor->{$cflavor}->{$pid} if defined $cflavor && $chld_flavor->{$cflavor};
  }
}

sub run {
  my ($conf) = @_;

  my $ping = $conf->{'ping'};

  my $maxchild = $conf->{'maxchild'};
  my $maxchild_flavor = $conf->{'maxchild_flavor'};

  my %chld;
  my %chld_flavor;
  my $pid;
  my $server = { 'starttime' => time() };

  while(1) {
    BSUtil::drainping($ping);

    my @events = $conf->{'lsevents'}->($conf);
    my $havedelayed;
    my $havereaped;

    for my $event (@events) {
      last if grep {-e $_} sort %{$conf->{'filechecks'} || {}};

      my $req = { 'conf' => $conf, 'event' => $event, 'server' => $server };
      my ($notdue, $nofork);
      ($req, $notdue, $nofork) = $conf->{'getevent'}->($req);
      $havedelayed = 1 if $notdue;
      next unless $req;

      my $flavor;
      if ($conf->{'getflavor'} && $maxchild_flavor) {
	$flavor = $conf->{'getflavor'}->($req);
	if (defined($flavor) && $maxchild_flavor->{$flavor}) {
	  if (keys(%{$chld_flavor{$flavor} || {}}) >= $maxchild_flavor->{$flavor}) {
	    $havedelayed = 1;
	    next;
	  }
	}
        $req->{'flavor'} = $flavor if defined $flavor;
      }

      if ($nofork || !$maxchild || $maxchild == 1) {
	reap(0, \%chld, \%chld_flavor) if $nofork && $nofork == 2 && %chld;
	eval {
	  $conf->{'dispatch'}->($req);
	};
	warn($@) if $@;
	next;
      }

      if (!($pid = xfork())) {
        $req->{'forked'} = 1;
	$conf->{'dispatch'}->($req);
	exit(0);
      }

      $chld{$pid} = $flavor;
      $chld_flavor{$flavor}->{$pid} = undef if defined $flavor;
      reap($maxchild, \%chld, \%chld_flavor);
      $havereaped = 1;
    }

    reap($maxchild, \%chld, \%chld_flavor) if $havedelayed && !$havereaped && %chld;

    for my $fc (sort %{$conf->{'filechecks'} || {}}) {
      next unless -e $fc;
      reap(0, \%chld, \%chld_flavor) if %chld;
      $conf->{'filechecks'}->{$fc}->($conf, $fc);
    }

    if ($havedelayed) {
      BSUtil::waitping($ping, 10);
    } else {
      if ($conf->{'testmode'}) {
	print "test mode, all events processed, exiting...\n";
	last;
      }
      print "waiting for an event...\n";
      BSUtil::waitping($ping);
    }
  }
}

1;

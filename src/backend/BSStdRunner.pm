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

package BSStdRunner;

use POSIX;
use IO::Handle;
use Fcntl qw(:DEFAULT :flock);


use BSUtil;
use BSConfiguration;
use BSXML;
use BSRunner;

use strict;

my $bsdir = $BSConfig::bsdir || "/srv/obs";
my $rundir = $BSConfig::rundir ||  $BSConfig::rundir || "$bsdir/run";

sub lsevents {
  my ($conf) = @_;
  my $myeventdir = $conf->{'eventdir'};
  my @ev = grep {!/^\./} sort(ls($myeventdir));
  if ($conf->{'inprogress'}) {
    my %inprog = map {$_ => 1} grep {s/::inprogress$//} @ev;
    @ev = grep {!$inprog{$_}} @ev if %inprog;
  }
  return @ev;
}

sub getevent {
  my ($req) = @_;
  my $ev = readxml("$req->{'conf'}->{'eventdir'}/$req->{'event'}", $BSXML::event, 1);
  return undef unless $ev;
  return (undef, 1) if $ev->{'due'} && $ev->{'due'} > time();
  $req->{'ev'} = $ev;
  return $req;
}

sub fc_exit {
  my ($conf, $fc) = @_;
  unlink($fc);
  close($conf->{'runlock'});
  BSUtil::printlog("$conf->{'name'} exiting...");
  exit(0);
}

sub fc_restart {
  my ($conf, $fc) = @_;
  unlink($fc);
  close($conf->{'runlock'});
  BSUtil::printlog("$conf->{'name'} restarting...");
  exec($0);
  die("$0: $!\n");
}

sub dispatch {
  my ($req) = @_;

  my $conf = $req->{'conf'};
  my $myeventdir = $conf->{'eventdir'};

  my $evname = $req->{'event'};
  my $ev = $req->{'ev'};
  my $type = $ev->{'type'};
  if (!$type) {
    print "event $evname has no type\n";
    unlink("$myeventdir/$evname");
    return;
  }

  my $dis = $conf->{'compiled_dispatches'}->{$type};
  if (!$dis) {
    print "event $evname has unknown type '$type'\n";
    unlink("$myeventdir/$evname");
    return;
  }
  my @missing = grep {!defined($ev->{$_})} @{$dis->{'must'}};
  if (@missing) {
    print "event $evname has missing elements: @missing\n";
    unlink("$myeventdir/$evname");
    return;
  }

  if ($conf->{'inprogress'}) {
    rename("$myeventdir/$evname", "$myeventdir/${evname}::inprogress");
    $req->{'inprogress'} = 1;
  }

  my @args = map {$ev->{$_}} @{$dis->{'param'}};
  my $r;
  eval {
    $r = $dis->{'dispatch'}->($req, @args);
  };
  if ($@) {
    warn($@);
    $r = undef;
  }
  if ($conf->{'inprogress'}) {
    if ($r) {
      unlink("$myeventdir/${evname}::inprogress");
    } else {
      rename("$myeventdir/${evname}::inprogress", "$myeventdir/$evname");
    }
    delete $req->{'inprogress'};
  } else {
    unlink("$myeventdir/$evname") if $r;
  }
  return $r;
}

sub compile_dispatches {
  my ($conf) = @_;

  my %dis;
  die("no dispatches configured\n") unless $conf->{'dispatches'};
  my @disps = @{$conf->{'dispatches'}};
  while (@disps) {
    my ($p, $f) = splice(@disps, 0, 2);
    my @vars = split(' ', $p);
    s/%([a-fA-F0-9]{2})/chr(hex($1))/ge for @vars;
    $p = shift @vars;
    my $dis = {'must' => [], 'param' => [], 'dispatch' => $f};
    for my $var (@vars) {
      my ($arg, $quant) = (0, '');
      $arg = 1 if $var =~ s/^\$//;
      $quant = $1 if $var =~ s/([?])$//;
      my $vartype = $var;
      ($var, $vartype) = ($1, $2) if $var =~ /^(.*):(.*)/;
      push @{$dis->{'must'}}, $var unless $quant eq '?';
      push @{$dis->{'param'}}, $var if $arg;
    }
    $dis{$p} = $dis;
  }
  $conf->{'compiled_dispatches'} = \%dis;
}

sub setdue {
  my ($req, $due) = @_;

  my $myeventdir = $req->{'conf'}->{'eventdir'};
  my $ev = $req->{'ev'};
  my $evname = $req->{'event'};
  $evname .= '::inprogress' if $req->{'inprogress'};
  $ev->{'due'} = $due;
  writexml("$myeventdir/.$evname$$", "$myeventdir/$evname", $ev, $BSXML::event);
  BSUtil::ping("$myeventdir/.ping");
}

sub run {
  my ($name, $args, $conf) = @_;

  exit(0) if @$args && $args->[0] eq '--test';
  
  die("no eventdir configured\n") unless $conf->{'eventdir'};
  BSUtil::mkdir_p_chown($bsdir, $BSConfig::bsuser, $BSConfig::bsgroup);
  BSUtil::drop_privs_to($BSConfig::bsuser||$BSConfig::bsuser, $BSConfig::bsgroup||$BSConfig::bsgroup);
  BSUtil::set_fdatasync_before_rename() unless $BSConfig::disable_data_sync || $BSConfig::disable_data_sync;

  $| = 1;
  $SIG{'PIPE'} = 'IGNORE';

  my $myeventdir = $conf->{'eventdir'};
  my $runname = $conf->{'runname'} || $name;

  BSUtil::restartexit($ARGV[0], $name, "$rundir/$runname", "$myeventdir/.ping");

  if (@$args && ($args->[0] eq '--testmode' || $args->[0] eq '--test-mode')) {
    $conf->{'testmode'} = 1;
    $conf->{'maxchild'} = 1;
  }
  mkdir_p($rundir);
  open(RUNLOCK, '>>', "$rundir/$runname.lock") || die("$rundir/$runname.lock: $!\n");
  flock(RUNLOCK, LOCK_EX | LOCK_NB) || die("$name is already running!\n");
  utime undef, undef, "$rundir/$runname.lock";

  mkdir_p($myeventdir);
  if (! -p "$myeventdir/.ping") {
    POSIX::mkfifo("$myeventdir/.ping", 0666) || die("$myeventdir/.ping: $!");
    chmod(0666, "$myeventdir/.ping");
  }

  sysopen(PING, "$myeventdir/.ping", POSIX::O_RDWR) || die("$myeventdir/.ping: $!");

  $conf->{'name'} = $name;
  $conf->{'ping'} = \*PING;
  $conf->{'runlock'} = \*RUNLOCK;

  $conf->{'dispatch'} ||= \&dispatch;
  $conf->{'lsevents'} ||= \&lsevents;
  $conf->{'getevent'} ||= \&getevent;
  $conf->{'run'} ||= \&BSRunner::run;

  $conf->{'filechecks'} ||= {};
  $conf->{'filechecks'}->{"$rundir/$runname.exit"} ||= \&fc_exit;
  $conf->{'filechecks'}->{"$rundir/$runname.restart"} ||= \&fc_restart;

  compile_dispatches($conf);

  if ($conf->{'inprogress'}) {
    for my $evname (grep {s/::inprogress$//s} ls($myeventdir)) {
      rename("$myeventdir/${evname}::inprogress", "$myeventdir/$evname");
    }
  }

  BSUtil::printlog("$name started\n");
  $conf->{'run'}->($conf);
}

package BSStdRunner::prepend;

sub PUSHED {
  return bless {}, $_[0];
}

sub WRITE {
  my ($obj, $buf, $fh) = @_;
  my $prefix = $obj->{'prefix'};
  if (!defined($prefix)) {
    $obj->{'prefix'} = $buf;
  } elsif (length($buf)) {
    my $xbuf = "\n$buf";
    $xbuf =~ s/\n$//s;
    $xbuf =~ s/\n/\n$prefix/g;
    print $fh substr($xbuf, 1)."\n";
    $fh->flush();
  }
  return length($buf);
}

1;

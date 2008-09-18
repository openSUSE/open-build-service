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
# Common code for Build Service HTTP Servers. Replys are XML,
# automatic restarts can be done by touching <server>.restart
#

package BSStdServer;

use Fcntl;

use BSWatcher;
use BSServer;
use BSVerify;
use BSServerEvents;
use BSXML;
use BSUtil;
use BSConfig;
use XML::Structured;

our $isajax;	# is this the ajax process?

our $return_ok = "<status code=\"ok\" />\n";

my $rundir = "$BSConfig::bsdir/run";

sub stdreply {
  my @rep = @_;
  return unless @rep && defined($rep[0]);
  if (ref($rep[0]) eq 'HASH') {
    $rep[1] = XMLout($rep[1], $rep[0]);
    shift @rep;
  }
  push @rep, 'Content-Type: text/xml' if @rep == 1;
  BSWatcher::reply(@rep);
}

sub errreply {
  my ($err, $code, $tag) = @_;
  my $opresult = {'code' => $code, 'summary' => $tag};
  my $opresultxml;
  eval {
    $opresultxml = XMLout($BSXML::opstatus, $opresult);
  };
  $opresultxml ||= "<status code=\"500\"\n  <summary>internal error in errreply</summary>\n</status>\n";
  BSWatcher::reply($opresultxml, "Status: $code $tag", 'Content-Type: text/xml');
}

sub authenticate {
  my ($conf, $req, $auth) = @_;
  return () unless $BSConfig::ipaccess;
  my %auths;
  my $peer = $BSServer::peer;
  for (sort keys %$BSConfig::ipaccess) {
    $auths{$BSConfig::ipaccess->{$_}} = 1 if $peer =~ /^$_$/s;
  }
  return () if grep {$auths{$_}} split(',', $auth);
  die("500 access denied @{[sort keys %auths]} $auth\n");
  die("500 access denied\n");
}

sub dispatch {
  my ($conf, $req) = @_;
  if ($isajax) {
    print "$req->{'action'} $req->{'path'}?$req->{'query'} (AJAX)\n";
    BSServerEvents::cloneconnect("OK\n", "Content-Type: text/plain");
  } else {
    print "$req->{'action'} $req->{'path'}?$req->{'query'}\n";
  }
  BSServer::dispatch($conf, $req);
}

sub periodic {
  my ($conf, $forks) = @_;
  return unless -e "$rundir/$conf->{'name'}.restart";
  BSServer::msg("$conf->{'name'} restarting...");
  if (system($0, "--test")) {
    BSServer::msg("$0 failed, aborting restart");
    return;
  }
  unlink("$rundir/$conf->{'name'}.restart");
  kill(15, @$forks) if $forks && @$forks;
  # clear close-on-exec bit
  fcntl(BSServer::getserversocket(), F_SETFD, 0);
  exec($0, '--restart', fileno(BSServer::getserversocket()));
  die("$0: $!\n");
}

sub periodic_ev {
  my ($ev) = @_;
  my $sev = $ev->{'server_ev'};
  my $conf = $ev->{'conf'};
  my @s = stat(BSServer::getserverlock());
  if ($s[3]) {
    BSEvents::add($ev, 3);
    return;
  }
  close($sev->{'fd'});
  BSEvents::rem($sev);
  BSServer::msg("AJAX: $conf->{'name'} exiting.");
  exit(0);
}

sub server {
  my ($name, $args, $conf, $aconf) = @_;

  exit 0 if $args && @$args && $args->[0] eq '--test';
  mkdir_p($rundir);
  if ($conf) {
    $conf->{'dispatches'} = BSServer::compile_dispatches($conf->{'dispatches'}, $BSVerify::verifyers) if $conf->{'dispatches'};
    $conf->{'dispatch'} = \&dispatch unless exists $conf->{'dispatch'};
    $conf->{'stdreply'} = \&stdreply unless exists $conf->{'stdreply'};
    $conf->{'errorreply'} = \&errreply unless exists $conf->{'errorreply'};
    $conf->{'authenticate'} = \&authenticate unless exists $conf->{'authenticate'};
    $conf->{'name'} = $name;
    $conf->{'timeout'} = 1;
  }
  if ($aconf) {
    $aconf->{'dispatches'} = BSWatcher::compile_dispatches($aconf->{'dispatches'}, $BSVerify::verifyers) if $aconf->{'dispatches'};
    $aconf->{'dispatch'} = \&dispatch unless exists $aconf->{'dispatch'};
    $aconf->{'stdreply'} = \&stdreply unless exists $aconf->{'stdreply'};
    $aconf->{'errorreply'} = \&errreply unless exists $aconf->{'errorreply'};
    $aconf->{'name'} = $name;
  }
  BSServer::deamonize(@{$args || []});
  if ($conf) {
    if ($args && @$args && $args->[0] eq '--restart') {
      BSServer::serveropen("&=$args->[1]", $BSConfig::bsuser, $BSConfig::bsgroup);
    } else {
      BSServer::serveropen($conf->{'port'}, $BSConfig::bsuser, $BSConfig::bsgroup);
    }
    unlink("$aconf->{'socketpath'}.lock") if $aconf;
  }
  if ($aconf) {
    if (!$conf || xfork() == 0) {
      $isajax = 1;
      BSServer::serveropen_unix($aconf->{'socketpath'}, $BSConfig::bsuser, $BSConfig::bsgroup);
      my $sev = BSServerEvents::addserver(BSServer::getserversocket(), $aconf);
      my $per_ev = BSEvents::new('timeout', \&periodic_ev);
      $per_ev->{'server_ev'} = $sev;
      $per_ev->{'conf'} = $aconf;
      BSEvents::add($per_ev, 3);
      BSServer::msg("AJAX: $name started");
      eval {
        BSEvents::schedule();
      };
      writestr("$rundir/$name.AJAX.died", undef, $@);
      die("AJAX: died\n");
    }
  }
  # intialize xml converter to speed things up
  XMLin(['startup' => '_content'], '<startup>x</startup>');

  BSServer::msg("$name started on port $conf->{port}");
  my @forks;
  if ($conf->{'fork'}) {
    for my $h (@{$conf->{'fork'}}) {
      my $fpid = xfork();
      if ($fpid == 0) {
        $h->();
        exit(0);
      }
      push @forks, $fpid;
    }
  }
  while (1) {
    BSServer::server($conf) && die("server returned\n");
    periodic($conf, \@forks);
  }
  # not reached
}

1;

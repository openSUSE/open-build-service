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

use strict;

our $isajax;	# is this the ajax process?

our $return_ok = "<status code=\"ok\" />\n";

my $rundir = $BSConfig::rundir || "$BSConfig::bsdir/run";

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
  my ($err, $code, $tag, @hdrs) = @_;
  my $opresult = {'code' => $code, 'summary' => $tag};
  $opresult->{'details'} = $err if $err && $err ne $tag && $err ne "$tag\n";
  my $opresultxml;
  eval {
    $opresultxml = XMLout($BSXML::opstatus, $opresult);
  };
  $opresultxml ||= "<status code=\"500\"\n  <summary>internal error in errreply</summary>\n</status>\n";
  BSWatcher::reply($opresultxml, "Status: $code $tag", 'Content-Type: text/xml', @hdrs);
}

sub authenticate {
  my ($conf, $req, $auth) = @_;
  return () unless $BSConfig::ipaccess;
  my %auths;
  my $peer = $BSServer::peer;
  for my $ipre (sort keys %$BSConfig::ipaccess) {
    next unless $peer =~ /^$ipre$/s;
    $auths{$_} = 1 for split(',', $BSConfig::ipaccess->{$ipre});
  }
  return () if grep {$auths{$_}} split(',', $auth);
  warn("500 access denied for $peer by \$ipaccess rules in BSConfig\n");
  die("500 access denied by \$ipaccess rules\n");
}

sub dispatch {
  my ($conf, $req) = @_;
  my @lt = localtime(time);
  my $msg = "$req->{'action'} $req->{'path'}?$req->{'query'}";
  BSServer::setstatus(2, $msg) if $conf->{'serverstatus'};
  $msg = sprintf "%04d-%02d-%02d %02d:%02d:%02d [%d]: %s", $lt[5] + 1900, $lt[4] + 1, @lt[3,2,1,0], $$, $msg;
  $msg .= " (AJAX)" if $isajax;
  print "$msg\n";
  if ($isajax) {
    BSServerEvents::cloneconnect("OK\n", "Content-Type: text/plain");
  }
  BSServer::dispatch($conf, $req);
}

sub periodic {
  my ($conf) = @_;
  if (-e "$rundir/$conf->{'name'}.exit") {
    BSServer::msg("$conf->{'name'} exiting...");
    unlink("$conf->{'ajaxsocketpath'}.lock") if $conf->{'ajaxsocketpath'};
    unlink("$rundir/$conf->{'name'}.exit");
    exit(0);
  }
  if (-e "$rundir/$conf->{'name'}.restart") {
    BSServer::msg("$conf->{'name'} restarting...");
    if (system($0, "--test")) {
      BSServer::msg("$0 failed, aborting restart");
      return;
    }
    unlink("$rundir/$conf->{'name'}.restart");
    # clear close-on-exec bit
    fcntl(BSServer::getserversocket(), F_SETFD, 0);
    exec($0, '--restart', fileno(BSServer::getserversocket()));
    die("$0: $!\n");
  }
}

sub periodic_ajax {
  my ($conf) = @_;
  my @s = stat(BSServer::getserverlock());
  return if $s[3];
  my $sev = $conf->{'server_ev'};
  close($sev->{'fd'});
  BSEvents::rem($sev);
  BSServer::msg("AJAX: $conf->{'name'} exiting.");
  exit(0);
}

sub serverstatus {
  my ($cgi) = @_;
  my @res;
  for my $s (BSServer::serverstatus()) {
    next unless $s->{'state'};
    push @res, {
      'id' => $s->{'slot'},
      'starttime' => $s->{'starttime'},
      'pid' => $s->{'pid'},
      'request' => $s->{'data'},
    };
  }
  return ({'job' => \@res}, $BSXML::serverstatus);
}

sub isrunning {
  my ($name, $conf) = @_;
  return 1 unless $conf;	# can't check
  # hmm, might want to use a lock instead...
  eval {
    BSServer::serveropen($conf->{'port'});
    BSServer::serverclose();
  };
  return $@ && "$@" =~ /bind:/ ? 1 : 0;
}

sub server {
  my ($name, $args, $conf, $aconf) = @_;

  if ($args && @$args) {
    if ($args->[0] eq '--test') {
      exit 0;
    }
    if ($args->[0] eq '--stop' || $args->[0] eq '--exit') {
      if (!isrunning($name, $conf)) {
	print "server not running\n";
	exit 0;
      }
      print("exiting server...\n");
      BSUtil::touch("$rundir/$name.exit");
      BSUtil::waituntilgone("$rundir/$name.exit");
      exit 0;
    }
    if ($args->[0] eq '--restart' && @$args == 1) {
      if (!isrunning($name, $conf)) {
	die("server not running\n");
      }
      print("restarting server...\n");
      BSUtil::touch("$rundir/$name.restart");
      BSUtil::waituntilgone("$rundir/$name.restart");
      exit 0;
    }
  }

  my $bsdir = $BSConfig::bsdir || "/srv/obs";
  BSUtil::mkdir_p_chown($bsdir, $BSConfig::bsuser, $BSConfig::bsgroup) || die("unable to create $bsdir\n");

  if ($conf) {
    $conf->{'dispatches'} = BSServer::compile_dispatches($conf->{'dispatches'}, $BSVerify::verifyers) if $conf->{'dispatches'};
    $conf->{'dispatch'} ||= \&dispatch;
    $conf->{'stdreply'} ||= \&stdreply;
    $conf->{'errorreply'} ||= \&errreply;
    $conf->{'authenticate'} ||= \&authenticate;
    $conf->{'periodic'} ||= \&periodic;
    $conf->{'periodic_interval'} ||= 1;
    $conf->{'serverstatus'} ||= "$rundir/$name.status";
    $conf->{'name'} = $name;
  }
  if ($aconf) {
    $aconf->{'dispatches'} = BSWatcher::compile_dispatches($aconf->{'dispatches'}, $BSVerify::verifyers) if $aconf->{'dispatches'};
    $aconf->{'dispatch'} ||= \&dispatch;
    $aconf->{'stdreply'} ||= \&stdreply;
    $aconf->{'errorreply'} ||= \&errreply;
    $aconf->{'periodic'} ||= \&periodic_ajax;
    $aconf->{'periodic_interval'} ||= 1;
    $aconf->{'name'} = $name;
  }
  BSServer::deamonize(@{$args || []});
  if ($conf) {
    if ($args && @$args && $args->[0] eq '--restart') {
      BSServer::serveropen("&=$args->[1]", $BSConfig::bsuser, $BSConfig::bsgroup);
    } else {
      BSServer::serveropen($conf->{'port'}, $BSConfig::bsuser, $BSConfig::bsgroup);
    }
    $conf->{'ajaxsocketpath'} = $aconf->{'socketpath'} if $aconf;
    unlink("$aconf->{'socketpath'}.lock") if $aconf;
  }
  if ($aconf) {
    if (!$conf || xfork() == 0) {
      $isajax = 1;
      BSServer::serveropen_unix($aconf->{'socketpath'}, $BSConfig::bsuser, $BSConfig::bsgroup);
      my $sev = BSServerEvents::addserver(BSServer::getserversocket(), $aconf);
      $aconf->{'server_ev'} = $sev;	# for periodic_ajax
      BSServer::msg("AJAX: $name started");
      eval {
        BSEvents::schedule();
      };
      writestr("$rundir/$name.AJAX.died", undef, $@);
      die("AJAX: died\n");
    }
  }
  mkdir_p($rundir);
  # intialize xml converter to speed things up
  XMLin(['startup' => '_content'], '<startup>x</startup>');

  BSServer::msg("$name started on port $conf->{port}");
  BSServer::server($conf);
  die("server returned\n");
}

1;

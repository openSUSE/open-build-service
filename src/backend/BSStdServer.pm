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
use BSDispatch;
use BSVerify;
use BSServerEvents;
use BSXML;
use BSRPC;
use BSUtil;
use BSConfiguration;
use XML::Structured;

use strict;

our $isajax;	# is this the ajax process?

our $return_ok = "<status code=\"ok\" />\n";

our $memoized_files = {};
our $memoized_size = 0;
our $memoize_fn;
our $memoize_max_size;

sub stdreply {
  my @rep = @_;
  return unless @rep && defined($rep[0]);
  if (ref($rep[0]) eq 'HASH') {
    if (ref($rep[1]) eq 'CODE') {
      $rep[1] = $rep[1]->($rep[0]);
    } else {
      $rep[1] = XMLout($rep[1], $rep[0]);
    }
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

sub authorize {
  my ($conf, $req, $auth) = @_;
  return () unless $BSConfig::ipaccess;
  my %auths;
  my $peer = $req->{'peer'};
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

  return BSDispatch::dispatch($conf, $req) if $req->{'req_mode'};
  my $peer = $isajax ? 'AJAX' : $req->{'peer'};
  my $msg = sprintf("%-22s %s%s",
    "$req->{'action'} ($peer)", $req->{'path'},
    defined($req->{'query'}) ? "?$req->{'query'}" : '',
  );
  $req->{'slowrequestlog'} = $req->{'group'} ? $conf->{'slowrequestlog2'} : $conf->{'slowrequestlog'};
  my $requestid = ($req->{'headers'} || {})->{'x-request-id'};
  if ($requestid && $requestid =~ /^[-_\.a-zA-Z0-9]+\z/s) {
    $req->{'requestid'} = $requestid;
    if ($isajax) {
      my $jev = $BSServerEvents::gev;
      push @{$jev->{'autoheaders'}}, "X-Request-ID: $requestid";
    } else {
      push @{$BSRPC::autoheaders}, "X-Request-ID: $requestid";
    }
  }
  if ($conf->{'serverstatus'}) {
    my $statusmsg = $msg;
    if ($requestid) {
      $statusmsg = ' ['.substr($requestid, 0, 64).']';
      $statusmsg = substr($msg, 0, 244 - length($statusmsg)).$statusmsg;
    }
    BSServer::setstatus(2, $statusmsg);
  }
  $msg .= " [$requestid]" if $requestid;
  BSUtil::printlog($msg);
  BSServerEvents::cloneconnect("OK\n", "Content-Type: text/plain") if $isajax;
  return BSDispatch::dispatch($conf, $req);
}

my $configurationcheck = 0;

sub periodic {
  my ($conf) = @_;
  my $rundir = $conf->{'rundir'};
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
    my $arg;
    my $sock = BSServer::getserversocket();
    # clear close-on-exec bit
    fcntl($sock, F_SETFD, 0);
    $arg = fileno($sock);
    my $sock2 = BSServer::getserversocket2();
    if ($sock2) {
      fcntl($sock2, F_SETFD, 0);
      $arg .= ','.fileno($sock2);
    }
    my @args;
    push @args, '--logfile', $conf->{'logfile'} if $conf->{'logfile'};
    exec($0, '--restart', $arg, @args);
    die("$0: $!\n");
  }
  memoize_files($memoize_fn, $memoize_max_size) if $memoize_fn;
  if ($configurationcheck++ > 10) {
    BSConfiguration::check_configuration();
    $configurationcheck = 0;
  }
}

sub periodic_ajax {
  my ($conf) = @_;
  if (!$conf->{'exiting'}) {
    my @s = stat(BSServer::getserverlock());
    return if $s[3];
    my $sev = $conf->{'server_ev'};
    close($sev->{'fd'});
    BSEvents::rem($sev);
    BSServer::msg("AJAX: $conf->{'name'} exiting.");
    $conf->{'exiting'} = 10 + 1;
  }
  my @events = BSEvents::allevents();
  if (@events <= 1 || --$conf->{'exiting'} == 0) {
    BSServer::msg("AJAX: $conf->{'name'} goodbye.");
    exit(0);
  }
}

sub memoize_one_file {
  my ($fn, $msize) = @_;
  
  BSUtil::printlog("memoizing $fn");
  my $sizechange = 0;
  my $fd;
  if (!open($fd, '<', $fn)) {
    my $mf = delete $memoized_files->{$fn};
    $sizechange -= length($mf->[1]) if $mf;
  } else {
    my @s = stat($fd);
    return 0 unless @s;
    my $mf = $memoized_files->{$fn};
    if ($mf) {
      return 0 if "$s[9]/$s[7]/$s[1]" eq $mf->[0];
      delete $memoized_files->{$fn};
      $sizechange -= length($mf->[1]);
    }
    return $sizechange if $msize && $s[7] > $msize;
    my $d = '';
    1 while sysread($fd, $d, 8192, length($d));
    next unless $s[7] == length($d);
    $memoized_files->{$fn} = [ "$s[9]/$s[7]/$s[1]", $d ];
    $sizechange += length($d);
  }
  return $sizechange;
}

sub memoize_files {
  my ($fnlist, $msize) = @_;
  return unless -s $fnlist;
  my $file;
  return unless open($file, '<', $fnlist);
  unlink($fnlist);
  my $sizechange = 0;
  my ($fn, $d, @s);
  while ($fn = <$file>) {
    next unless chop($fn) eq "\n";
    next if $fn eq '' || $fn =~ /\0/s || $fn !~ /^\//;
    $sizechange += memoize_one_file($fn, $msize);
  }
  $memoized_size += $sizechange;
  my $inmb = $memoized_size / (1024*1024);
  BSUtil::printlog(sprintf("memoized_size is %.2f MB", $inmb));# if abs($sizechange)/($memoized_size || 1) > 0.1;
  close $file;
}

sub add_to_memoization_list {
  my ($fn) = @_;
  my $fd;
  if ($memoize_fn && BSUtil::lockopen($fd, '>>', $memoize_fn)) {
    (syswrite($fd, "$fn\n") || 0) == length("$fn\n") || warn("$memoize_fn write: $!\n");
    close($fd) || warn("$memoize_fn close: $!\n");
  }
}

sub check_memoized {
  my ($fn, $nonfatal) = @_;
  return undef unless $memoize_fn;
  return undef if !defined($fn) || $fn eq '' || $fn =~ /\0/s || $fn !~ /^\//;
  # opening and closing files helps check permissions
  my $mf = $memoized_files->{$fn};
  my $f;
  if (!open($f, '<', $fn)) {
    add_to_memoization_list($fn) if $mf;
    return undef;
  }
  my @s = stat($f);
  return undef unless @s;
  close($f);
  return $mf->[1] if $mf && $mf->[0] eq "$s[9]/$s[7]/$s[1]";
  add_to_memoization_list($fn);
  return undef;
}

sub readstr_memoized {
  my ($fn, $nonfatal) = @_;
  my $d = check_memoized($fn, $nonfatal);
  return $d if defined $d;
  return readstr($fn, $nonfatal);
}

sub readxml_memoized {
  my ($fn, $dtd, $nonfatal) = @_;
  my $d = check_memoized($fn, $nonfatal);
  if (defined($d)) {
    $d = BSUtil::fromxml($d, $dtd, 1);
    return $d if defined($d) || ($nonfatal || 0) == 1;
  }
  return readxml($fn, $nonfatal);
}

sub retrieve_memoized {
  my ($fn, $nonfatal) = @_;
  my $d;
  $d = check_memoized($fn, $nonfatal) unless ref($fn);
  if (defined($d)) {
    $d = BSUtil::fromstorable($d, 1);
    return $d if defined($d) || ($nonfatal || 0) == 1;
  }
  return BSUtil::retrieve($fn, $nonfatal);
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
    $res[-1]->{'group'} = $s->{'group'} if $s->{'group'};
  }
  my $serverstatus = {
    'job' => \@res,
    'starttime' => $BSServer::request->{'server'}->{'starttime'},
  };
  return ($serverstatus, $BSXML::serverstatus);
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

sub critlogger {
  my ($conf, $msg) = @_;
  return unless $conf && $conf->{'critlogfile'};
  my $logstr = sprintf "%s: %-7s %s\n", BSUtil::isotime(time), "[$$]", $msg;
  BSUtil::appendstr($conf->{'critlogfile'}, $logstr);
}

sub server {
  my ($name, $args, $conf, $aconf) = @_;
  my $logfile;
  my $request;

  if (@{$args || []} && $args->[0] eq '--logfile') {
    shift @$args;
    $logfile = shift @$args;
    BSUtil::openlog($logfile, $BSConfig::logdir, $BSConfig::bsuser, $BSConfig::bsgroup);
  }

  if ($args && @$args) {
    my $rundir = ($conf ? $conf->{'rundir'} : undef) || $BSConfig::rundir || "$BSConfig::bsdir/run";
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
    if ($args->[0] eq '--req') {
      shift @$args;
      $request = shift @$args;
      die("need a server config for --req\n") unless $conf;
    }
  }

  my $bsdir = $BSConfig::bsdir || "/srv/obs";
  BSUtil::mkdir_p_chown($bsdir, $BSConfig::bsuser, $BSConfig::bsgroup) || die("unable to create $bsdir\n");

  if ($conf) {
    $conf->{'rundir'} ||= $BSConfig::rundir || "$BSConfig::bsdir/run";
    $conf->{'verifiers'} ||= $BSVerify::verifiers;
    $conf->{'dispatch'} ||= \&dispatch;
    $conf->{'stdreply'} ||= \&stdreply;
    $conf->{'errorreply'} ||= \&errreply;
    $conf->{'authorize'} ||= \&authorize;
    $conf->{'periodic'} ||= \&periodic;
    $conf->{'periodic_interval'} ||= 1;
    $conf->{'serverstatus'} ||= "$conf->{'rundir'}/$name.status";
    $conf->{'setkeepalive'} = 1 unless defined $conf->{'setkeepalive'};
    $conf->{'run'} ||= \&BSServer::server;
    $conf->{'slowrequestlog'} ||= "$BSConfig::logdir/$name.slow.log" if $conf->{'slowrequestthr'};
    $conf->{'slowrequestlog2'} ||= "$BSConfig::logdir/${name}2.slow.log" if $conf->{'slowrequestthr'} && $conf->{'port2'};
    $conf->{'critlogfile'} ||= "$BSConfig::logdir/$name.crit.log";
    $conf->{'name'} = $name;
    $conf->{'logfile'} = $logfile if $logfile;
    $conf->{'ssl_keyfile'} ||= $BSConfig::ssl_keyfile if $BSConfig::ssl_keyfile;
    $conf->{'ssl_certfile'} ||= $BSConfig::ssl_certfile if $BSConfig::ssl_certfile;
    BSDispatch::compile($conf);
  }
  if ($request) {
    $conf->{'authorize'} = sub {};
    BSUtil::drop_privs_to($BSConfig::bsuser, $BSConfig::bsgroup);
    my $fd;
    open($fd, '>&STDOUT') || die;
    open('STDOUT', '>&STDERR') || die;
    my $req = { 'peer' => 'unknown', 'conf' => $conf, 'starttime' => time(), 'action' => 'GET', 'query' => '', '__socket' => $fd, 'req_mode' => 1, 'no_drain_clnt' => 1 };
    $BSServer::request = $req;
    $req->{'action'} = $1 if $request =~ s/^([A-Z]+)://;
    $req->{'path'} = $request;
    ($req->{'path'}, $req->{'query'}) = ($1, $2) if $request =~ /^(.*?)\?(.*)$/;
    $req->{'path'} =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    my @r = $conf->{'dispatch'}->($conf, $req);
    $conf->{'stdreply'}->(@r) unless $req->{'replying'};
    exit(0);
  }
  if ($aconf) {
    require BSHandoff;
    $aconf->{'rundir'} ||= $BSConfig::rundir || "$BSConfig::bsdir/run";
    $aconf->{'verifiers'} ||= $BSVerify::verifiers;
    $aconf->{'dispatch'} ||= \&dispatch;
    $aconf->{'stdreply'} ||= \&stdreply;
    $aconf->{'errorreply'} ||= \&errreply;
    $aconf->{'periodic'} ||= \&periodic_ajax;
    $aconf->{'periodic_interval'} ||= 1;
    $aconf->{'dispatches_call'} ||= \&BSWatcher::dispatches_call;
    $aconf->{'getrequest_recvfd'} ||= \&BSHandoff::receivefd;
    $aconf->{'setkeepalive'} = 1 unless defined $aconf->{'setkeepalive'};
    $aconf->{'getrequest_timeout'} = 10 unless exists $aconf->{'getrequest_timeout'};
    $aconf->{'replrequest_timeout'} = 10 unless exists $aconf->{'replrequest_timeout'};
    $aconf->{'run'} ||= \&BSEvents::schedule;
    $aconf->{'name'} = $name;
    BSDispatch::compile($aconf);
  }
  BSServer::deamonize(@{$args || []});
  if ($conf) {
    my $port = $conf->{'port'};
    my $port2 = $conf->{'port2'};
    if ($args && @$args && $args->[0] eq '--restart') {
      my @ports = split(',', $args->[1]);
      $port = "&=$ports[0]" if defined $ports[0];
      $port2 = "&=$ports[1]" if $port2 && defined $ports[1];
      POSIX::close($ports[1]) if !$port2 && defined $ports[1];
    }
    BSServer::serveropen($port2 ? "$port,$port2" : $port, $BSConfig::bsuser, $BSConfig::bsgroup);
  }
  if ($conf && $aconf) {
    $conf->{'ajaxsocketpath'} = $aconf->{'socketpath'};
    $conf->{'handoffpath'} = $aconf->{'socketpath'};
    unlink("$aconf->{'socketpath'}.lock");
  }
  BSUtil::setcritlogger(sub { critlogger($conf, $_[0]) });
  if ($aconf) {
    if (!$conf || xfork() == 0) {
      $isajax = 1;
      BSServer::serverclose() if $conf;
      BSServer::serveropen_unix($aconf->{'socketpath'}, $BSConfig::bsuser, $BSConfig::bsgroup);
      my $sev = BSServerEvents::addserver(BSServer::getserversocket(), $aconf);
      $aconf->{'server_ev'} = $sev;	# for periodic_ajax
      BSServer::msg("AJAX: $name started");
      eval {
        $aconf->{'run'}->($aconf);
      };
      writestr("$aconf->{'rundir'}/$name.AJAX.died", undef, $@);
      BSUtil::diecritical("AJAX died: $@");
    }
  }
  my $rundir = $conf->{'rundir'};
  mkdir_p($rundir);
  if (!POSIX::access($rundir, POSIX::W_OK)) {
    my $user = getpwuid($<) || $<;
    my $group = getgrgid($() || $(;
    die("cannot write to rundir '$rundir' as user '$user' group '$group'\n");
  }
  # intialize xml converter to speed things up
  XMLin(['startup' => '_content'], '<startup>x</startup>');

  if ($conf->{'port2'}) {
    BSServer::msg("$name started on ports $conf->{port} and $conf->{port2}");
  } else {
    BSServer::msg("$name started on port $conf->{port}");
  }
  if ($conf->{'memoize'}) {
    $memoize_fn = $conf->{'memoize'};
    $memoize_max_size = $conf->{'memoize_max_size'} if $conf->{'memoize_max_size'};
  }
  $conf->{'run'}->($conf);
  die("server returned\n");
}

1;

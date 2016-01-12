# Copyright (c) 2015 SUSE LLC
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
package BSSched::Remote;

# gctx functions
#   beginwatchcollection
#   endwatchcollection
#   addwatchremote
#   updateremoteprojs
#   remoteprojid
#   fetchremoteproj
#   fetchremoteconfig
#   remotemap2remoteprojs
#   setupremotewatcher
#   getremoteevents
#   addrepo_remote_unpackcpio
#   convertpackagebinarylist
#   cleanup_remotepackstatus

# ctx functions
#   addrepo_remote
#   addrepo_remote_resume
#   read_gbininfo_remote
#   read_gbininfo_remote_resume
#
# gctx usage
#   watchremote
#   needremoteproj	(tmp)
#   projpacks
#   remoteprojs
#   arch
#   remoteproxy
#   obsname
#   asyncmode
#   rctx
#   repodatas
#   repodatas_alien
#   remotecache
#   prpnotready
#   remotegbininfos
#   remotepackstatus
#   remotepackstatus_cleanup
#
# ctx usage
#   gctx
#   prp

use strict;
use warnings;

use Digest::MD5 ();

use BSUtil;
use BSSolv;
use BSRPC;
use BSSched::RPC;
use BSSched::EventSource::Retry;	# for addretryevent
use BSConfiguration;

=head2 beginwatchcollection - TODO: add summary

 TODO: add description

=cut

sub beginwatchcollection {
  my ($gctx) = @_;
  %{$gctx->{'watchremote'}} = ();	# reset all watches
  $gctx->{'needremoteproj'} = {};	# tmp
}

=head2 endwatchcollection - TODO: add summary

 TODO: add description

=cut

sub endwatchcollection {
  my ($gctx) = @_;
  my $needremoteproj = delete $gctx->{'needremoteproj'};
  updateremoteprojs($gctx, $needremoteproj);
}

=head2 addwatchremote -  register for a possibly remote resource

 input:  $type: type of resource (project/package/repository)
	 $projid: local name of the project
	 $watch: extra data to match
=cut

sub addwatchremote {
  my ($gctx, $type, $projid, $watch) = @_;

  my $projpacks = $gctx->{'projpacks'};
  return undef if $projpacks->{$projid} && !$projpacks->{$projid}->{'remoteurl'};
  my $proj = remoteprojid($gctx, $projid);
  my $needremoteproj = $gctx->{'needremoteproj'} || {};
  # we don't need the project data for package watches
  $needremoteproj->{$projid} = $proj if $type ne 'package';
  return undef unless $proj;
  my $watchremote = $gctx->{'watchremote'};
  if ($proj->{'partition'}) {
    $watchremote->{$BSConfig::srcserver}->{"$type/$proj->{'remoteproject'}$watch"} = $projid;
  } else {
    $watchremote->{$proj->{'remoteurl'}}->{"$type/$proj->{'remoteproject'}$watch"} = $projid;
  }
  return $proj;
}

=head2 updateremoteprojs - sync remoteprojs with data from watch collection

This function deletes all no longer needed elements from the
remoteprojs hash. It also calls fetchremoteproj for missing
entries, which should actually not happen as the remotemap
should already contain all needed entries.

=cut

sub updateremoteprojs {
  my ($gctx, $needremoteproj) = @_;

  my $remoteprojs = $gctx->{'remoteprojs'};
  for my $projid (keys %$remoteprojs) {
    my $r = $needremoteproj->{$projid};
    if (!$r) {
      delete $remoteprojs->{$projid};	# no longer needed
      next;
    }
    my $or = $remoteprojs->{$projid};
    next if $or && $or->{'partition'};  # XXX how do we update them?
    next if $or && $or->{'remoteurl'} eq $r->{'remoteurl'} && $or->{'remoteproject'} eq $r->{'remoteproject'};
    delete $remoteprojs->{$projid};	# changed, need to refetch
  }
  for my $projid (sort keys %$needremoteproj) {
    my $r = $needremoteproj->{$projid};
    fetchremoteproj($gctx, $r, $projid) if $r && !$remoteprojs->{$projid};
  }
}

=head2 remoteprojid - TODO: add summary

 TODO: add description

=cut

sub remoteprojid {
  my ($gctx, $projid) = @_;
  my $rsuf = '';
  my $origprojid = $projid;

  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  return $remoteprojs->{$projid} if $remoteprojs->{$projid} && $remoteprojs->{$projid}->{'partition'};
  my $proj = $projpacks->{$projid};
  if ($proj) {
    return undef unless $proj->{'remoteurl'};
    if (!$proj->{'remoteproject'}) {
      $proj = { %$proj };
      delete $proj->{'remoteurl'};
      return $proj;
    }
    return {
      'name' => $projid,
      'root' => $projid,
      'remoteroot' => $proj->{'remoteproject'},
      'remoteurl' => $proj->{'remoteurl'},
      'remoteproject' => $proj->{'remoteproject'},
    };
  }
  while ($projid =~ /^(.*)(:.*?)$/) {
    $projid = $1;
    $rsuf = "$2$rsuf";
    $proj = $projpacks->{$projid};
    if ($proj) {
      return undef unless $proj->{'remoteurl'};
      if ($proj->{'remoteproject'}) {
	$rsuf = "$proj->{'remoteproject'}$rsuf";
      } else {
	$rsuf =~ s/^://;
      }
      return {
	'name' => $origprojid,
	'root' => $projid,
	'remoteroot' => $proj->{'remoteproject'},
	'remoteurl' => $proj->{'remoteurl'},
	'remoteproject' => $rsuf,
      };
    }
  }
  return undef;
}

=head2 fetchremoteproj - TODO: add summary

 TODO: add description

=cut

sub fetchremoteproj {
  my ($gctx, $proj, $projid) = @_;
  return undef unless $proj && $proj->{'remoteurl'} && $proj->{'remoteproject'};
  $projid ||= $proj->{'name'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  return $remoteprojs->{$projid} if exists $remoteprojs->{$projid};
  print "WARNING: fetching remote project data for $projid\n";
  my $rproj;
  my $param = {
    'uri' => "$BSConfig::srcserver/source/$projid/_meta",
    'timeout' => 60,
  };
  eval {
    $rproj = BSRPC::rpc($param, $BSXML::proj);
  };
  if ($@) {
    warn($@);
    my $error = $@;
    $error =~ s/\n$//s;
    $rproj = {'error' => $error};
    BSSched::EventSource::Retry::addretryevent($gctx, {'type' => 'project', 'project' => $projid}) if BSSched::RPC::is_transient_error($error);
  }
  return undef unless $rproj;
  delete $rproj->{'mountproject'};
  for (qw{name root remoteroot remoteurl remoteproject}) {
    $rproj->{$_} = $proj->{$_};
  }
  $remoteprojs->{$projid} = $rproj;
  return $rproj;
}

=head2 fetchremoteconfig - TODO: add summary

 TODO: add description

=cut

sub fetchremoteconfig {
  my ($gctx, $projid) = @_;

  my $remoteprojs = $gctx->{'remoteprojs'};
  my $proj = $remoteprojs->{$projid};
  return undef if !$proj || $proj->{'error'};
  return $proj->{'config'} if exists $proj->{'config'};
  return '' if $proj->{'partition'};
  print "WARNING: fetching remote project config for $projid\n";
  my $c;
  my $param = {
    'uri' => "$BSConfig::srcserver/source/$projid/_config",
    'timeout' => 60,
  };
  eval {
    $c = BSRPC::rpc($param);
  };
  if ($@) {
    warn($@);
    $proj->{'error'} = $@;
    $proj->{'error'} =~ s/\n$//s;
    BSSched::EventSource::Retry::addretryevent($gctx, {'type' => 'project', 'project' => $projid}) if BSSched::RPC::is_transient_error($proj->{'error'});
    return undef;
  }
  $proj->{'config'} = $c;
  return $c;
}

=head2 remotemap2remoteprojs - update remoteprojs with the remotemap data

 TODO: add description

=cut

sub remotemap2remoteprojs {
  my ($gctx, $remotemap) = @_;

  my $remoteprojs = $gctx->{'remoteprojs'};
  for my $proj (@{$remotemap || []}) {
    my $projid = delete $proj->{'project'};
    if (!$proj->{'remoteurl'} && !$proj->{'error'}) {
      # remote project is gone (partition case)
      delete $remoteprojs->{$projid};
      next;
    }
    my $oproj = $remoteprojs->{$projid};
    undef $oproj if $oproj && ($oproj->{'remoteurl'} ne $proj->{'remoteurl'} || $oproj->{'remoteproject'} ne $proj->{'remoteproject'});
    my $c = $proj->{'config'};
    $c = $oproj->{'config'} if !defined($c) && $oproj;
    my $error = $proj->{'error'};
    delete $proj->{'error'};
    $proj = $oproj if $proj->{'proto'} && $oproj && !$oproj->{'proto'};
    delete $proj->{'config'};
    $proj->{'config'} = $c if defined $c;
    if ($error) {
      $proj->{'error'} = $error;
      BSSched::EventSource::Retry::addretryevent($gctx, {'type' => 'project', 'project' => $projid}) if $error =~ /interconnect error:/;
    }    
    $remoteprojs->{$projid} = $proj;
  }
}

=head2 setupremotewatcher - TODO: add summary

 TODO: add description

=cut

sub setupremotewatcher {
  my ($gctx, $remoteurl, $watchremote, $start) = @_;
  my $myarch = $gctx->{'arch'};
  if ($start) {
    print "setting up watcher for $remoteurl, start=$start\n";
  } else {
    print "setting up watcher for $remoteurl\n";
  }
  # collaps filter list, watch complete project if more than 3 packages are watched
  my @filter;
  my %filterpackage;
  for (sort keys %$watchremote) {
    if (substr($_, 0, 8) eq 'package/') {
      my @s = split('/', $_);
      if (!defined($s[2])) {
	unshift @{$filterpackage{$s[1]}}, undef;
      } else {
	push @{$filterpackage{$s[1]}}, $_;
      }
    } else {
      push @filter, $_;
    }
  }
  for (sort keys %filterpackage) {
    if (!defined($filterpackage{$_}->[0]) || @{$filterpackage{$_}} > 3) {
      push @filter, "package/$_";
    } else {
      push @filter, @{$filterpackage{$_}};
    }
  }
  my $param = {
    'uri' => "$remoteurl/lastevents",
    'async' => 1,
    'request' => 'POST',
    'headers' => [ 'Content-Type: application/x-www-form-urlencoded' ],
    'proxy' => $gctx->{'remoteproxy'},
  };
  my @args;
  my $obsname = $gctx->{'obsname'};
  push @args, "obsname=$obsname/$myarch" if $obsname;
  push @args, map {"filter=$_"} @filter;
  push @args, "start=$start" if $start;
  my $ret;
  eval {
    $ret = BSRPC::rpc($param, $BSXML::events, @args);
  };
  if ($@) {
    warn($@);
    print "retrying in 60 seconds\n";
    $ret = {'retry' => time() + 60};
  }
  $ret->{'remoteurl'} = $remoteurl;
  return $ret;
}

=head2 setupremotewatcher - TODO: add summary

 TODO: add description

=cut

sub getremoteevents {
  my ($gctx, $watcher, $watchremote, $starthash) = @_;

  my $myarch = $gctx->{'arch'};
  my $remoteurl = $watcher->{'remoteurl'};
  my $start = $starthash->{$remoteurl};
  print "response from watcher for $remoteurl\n";
  my $ret;
  eval {
    $ret = BSRPC::rpc($watcher);
  };
  if ($@) {
    warn $@;
    close($watcher->{'socket'}) if defined $watcher->{'socket'};
    delete $watcher->{'socket'};
    $watcher->{'retry'} = time() + 60;
    print "retrying in 60 seconds\n";
    return ();
  }
  my @remoteevents;
  if ($ret->{'sync'} && $ret->{'sync'} eq 'lost') {
    # ok to lose sync on call with no start (actually not, FIXME)
    if ($start) {
      print "lost sync with server, was at $start\n";
      print "next: $ret->{'next'}\n" if $ret->{'next'};
      # synthesize all events we watch
      for my $watch (sort keys %$watchremote) {
	my $projid = $watchremote->{$watch};
	next unless defined $projid;
	my @s = split('/', $watch);
	if ($s[0] eq 'project') {
	  push @remoteevents, {'type' => 'project', 'project' => $projid};
	} elsif ($s[0] eq 'package') {
	  push @remoteevents, {'type' => 'package', 'project' => $projid, 'package' => $s[2]};
	} elsif ($s[0] eq 'repository' || $s[0] eq 'repoinfo') {
	  push @remoteevents, {'type' => $s[0], 'project' => $projid, 'repository' => $s[2], 'arch' => $s[3]};
	}
      }
    }
  }
  for my $ev (@{$ret->{'event'} || []}) {
    next unless $ev->{'project'};
    my $watch;
    if ($ev->{'type'} eq 'project') {
      $watch = "project/$ev->{'project'}";
    } elsif ($ev->{'type'} eq 'package') {
      $watch = "package/$ev->{'project'}/$ev->{'package'}";
      $watch = "package/$ev->{'project'}" unless defined $watchremote->{$watch};
    } elsif ($ev->{'type'} eq 'repository' || $ev->{'type'} eq 'repoinfo') {
      $watch = "$ev->{'type'}/$ev->{'project'}/$ev->{'repository'}/$myarch";
    } else {
      next;
    }
    my $projid = $watchremote->{$watch};
    next unless defined $projid;
    push @remoteevents, {%$ev, 'project' => $projid};
  }
  $starthash->{$remoteurl} = $ret->{'next'} if $ret->{'next'};
  return @remoteevents;
}


###########################################################################
###
### remote BuildRepo (aka full tree) support
###

sub addrepo_remote {
  my ($ctx, $pool, $prp, $arch, $remoteproj) = @_;

  my ($projid, $repoid) = split('/', $prp, 2);
  return undef if !$remoteproj || $remoteproj->{'error'};

  my $cachemd5 = Digest::MD5::md5_hex("$prp/$arch");
  substr($cachemd5, 2, 0, '/');

  my $gctx = $ctx->{'gctx'};
  print "    fetching remote repository state for $prp\n";
  my $param = {
    'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$repoid/$arch/_repository",
    'timeout' => 200,
    'receiver' => \&BSHTTP::cpio_receiver,
    'proxy' => $gctx->{'remoteproxy'},
  };
  if ($gctx->{'asyncmode'}) {
    $param->{'async'} = { '_resume' => \&addrepo_remote_resume, '_prp' => $prp, '_arch' => $arch };
  }
  my $cpio;
  my $solvok;
  eval {
    die('unsupported view\n') unless $remoteproj->{'partition'} || defined($BSConfig::usesolvstate) && $BSConfig::usesolvstate;
    $param->{'async'}->{'_solvok'} = 1 if $param->{'async'};
    $cpio = $ctx->xrpc("repository/$prp/$arch", $param, undef, 'view=solvstate');
    $solvok = 1 if $cpio;
  };
  if ($@ && $@ =~ /unsupported view/) {
    $solvok = undef;
    delete $param->{'async'}->{'_solvok'} if $param->{'async'};
    eval {
      $cpio = $ctx->xrpc("repository/$prp/$arch", $param, undef, 'view=cache');
    };
  }
  if ($@) {
    return addrepo_remote_unpackcpio($ctx->{'gctx'}, $pool, $prp, $arch, $cpio, undef, $@);
  }
  return 0 if $param->{'async'} && $cpio;       # hack: false but not undef
  return addrepo_remote_unpackcpio($ctx->{'gctx'}, $pool, $prp, $arch, $cpio, $solvok);
}

sub addrepo_remote_resume {
  my ($ctx, $handle, $error, $cpio) = @_;
  my $gctx = $ctx->{'gctx'};
  my $pool = BSSolv::pool->new();
  my $r = addrepo_remote_unpackcpio($gctx, $pool, $handle->{'_prp'}, $handle->{'_arch'}, $cpio, $handle->{'_solvok'}, $error);
  $ctx->setchanged($handle) unless !$r && $error && BSSched::RPC::is_transient_error($error);
}

sub addrepo_remote_unpackcpio {
  my ($gctx, $pool, $prp, $arch, $cpio, $solvok, $error) = @_;

  my $repodata;
  my $myarch = $gctx->{'arch'};

  if ($arch eq $myarch) {
    my $repodatas = $gctx->{'repodatas'};
    $repodatas->{$prp} ||= {};
    $repodata = $repodatas->{$prp};
  } else {
    my $repodatas_alien = $gctx->{'repodatas_alien'};
    $repodatas_alien->{"$prp/$arch"} ||= {};
    $repodata = $repodatas_alien->{"$prp/$arch"};
  }

  my $remotecache = $gctx->{'remotecache'};
  my $cachemd5 = Digest::MD5::md5_hex("$prp/$arch");
  substr($cachemd5, 2, 0, '/');

  if ($error) {
    chomp $error;
    warn("$error\n");
    if (BSSched::RPC::is_transient_error($error)) {
      my ($projid, $repoid) = split('/', $prp, 2);
      BSSched::EventSource::Retry::addretryevent($gctx, {'type' => 'repository', 'project' => $projid, 'repository' => $repoid, 'arch' => $arch});
      if (-s "$remotecache/$cachemd5.solv") {
        # try last solv file
        my $r;
        eval {$r = $pool->repofromfile($prp, "$remotecache/$cachemd5.solv");};
        if ($r) {
          $repodata->{'lastscan'} = time();
          $repodata->{'random'} = rand();
          $repodata->{'solvfile'} = "$remotecache/$cachemd5.solv";
          return $r;
        }
      }
    }
    $repodata->{'lastscan'} = time();
    $repodata->{'random'} = rand();
    $repodata->{'error'} = $error;
    return undef;
  }

  my %cpio = map {$_->{'name'} => $_->{'data'}} @{$cpio || []};
  my $repostate = $cpio{'repositorystate'};
  $repostate = BSUtil::fromxml($repostate, $BSXML::repositorystate, 2) if $repostate;
  if ($arch eq $myarch) {
    my $prpnotready = $gctx->{'prpnotready'};
    delete $prpnotready->{$prp};
    if ($repostate && $repostate->{'blocked'}) {
      $prpnotready->{$prp} = { map {$_ => 1} @{$repostate->{'blocked'}} };
    }
  }
  my $r;
  my $solv;
  if (exists $cpio{'repositorysolv'} && $solvok) {
    eval {$r = $pool->repofromstr($prp, $cpio{'repositorysolv'}); };
    warn($@) if $@;
  } elsif (exists $cpio{'repositorycache'}) {
    my $cache;
    my $havedod;
    if (defined &BSSolv::thawcache) {
      eval { $cache = BSSolv::thawcache($cpio{'repositorycache'}); };
    } else {
      eval { $cache = BSUtil::fromstorable($cpio{'repositorycache'}); };
    }
    delete $cpio{'repositorycache'};    # free mem
    warn($@) if $@;
    return undef unless $cache;
    delete $cache->{'/url'};
    delete $cache->{'/dodcookie'};
    delete $cache->{'/external/'};
    # free some unused entries to save mem
    for (values %$cache) {
      $havedod = 1 if ($_->{'hdrmd5'} || '') eq 'd0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0';
      delete $_->{'path'};
      delete $_->{'id'};
    }
    # add special "havedod" marker
    $cache->{'/dodcookie'} = 'remote repository with dod packages' if $havedod;
    $r = $pool->repofromdata($prp, $cache);
  } else {
    # return empty repo
    $r = $pool->repofrombins($prp, '');
    $repodata->{'solv'} = $r->tostr();  # small enough to keep it incore
  }
  return undef unless $r;
  # write solv file
  $repodata->{'solvfile'} = "$remotecache/$cachemd5.solv";
  mkdir_p("$remotecache/".substr($cachemd5, 0, 2));
  BSSched::BuildRepo::writesolv("$remotecache/$cachemd5.solv.new$$", "$remotecache/$cachemd5.solv", $r);
  $repodata->{'lastscan'} = time();
  $repodata->{'random'} = rand();
  return $r;
}


###########################################################################
###
### remote BuildResult (aka gbininfo) support
###

sub read_gbininfo_remote {
  my ($ctx, $prpa, $remoteproj, $packstatus) = @_;

  return undef unless $remoteproj;
  return undef if $remoteproj->{'error'};

  my $gctx = $ctx->{'gctx'};
  my $remotegbininfos = $gctx->{'remotegbininfos'};
  my $cachemd5 = Digest::MD5::md5_hex($prpa);
  substr($cachemd5, 2, 0, '/');

  my $now = time();

  # first check error case
  if ($remotegbininfos->{$prpa} && $remotegbininfos->{$prpa}->{'error'} && ($remotegbininfos->{$prpa}->{'lastfetch'} || 0) > $now - 3600) {
    return undef;
  }

  # check if we can use the cache
  my $rpackstatus;
  if ($packstatus) {
    my $remotepackstatus = $gctx->{'remotepackstatus'};
    if ($remotepackstatus->{$prpa} && $gctx->{'asyncmode'}) {
      my $prp = $ctx->{'prp'};
      $rpackstatus = $remotepackstatus->{$prpa} if grep {$_ eq $prp} @{$remotepackstatus->{$prpa}->{'/users'} || []};
    }
  }
  if ((!$packstatus || $rpackstatus) && $remotegbininfos->{$prpa} && ($remotegbininfos->{$prpa}->{'lastfetch'} || 0) > $now - 3600) {
    my $remotecache = $gctx->{'remotecache'};
    if (-s "$remotecache/$cachemd5.bininfo") {
      my $gbininfo = BSUtil::retrieve("$remotecache/$cachemd5.bininfo", 1);
      if ($gbininfo) {
        if ($packstatus) {
          for my $pkg (keys %$gbininfo) {
            $packstatus->{$pkg} = $rpackstatus->{$pkg} if $rpackstatus->{$pkg};
          }
        }
        return $gbininfo;
      }
    }
  }

  print "    fetching remote project binary state for $prpa\n";
  my ($projid, $repoid, $arch) = split('/', $prpa, 3);
  my $param = {
    'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$repoid/$arch",
    'timeout' => 200,
    'proxy' => $gctx->{'remoteproxy'},
  };
  if ($gctx->{'asyncmode'}) {
    $param->{'async'} = { '_resume' => \&read_gbininfo_remote_resume, '_prpa' => $prpa };
  }
  my $packagebinarylist;
  eval {
    if ($remoteproj->{'partition'}) {
      $param->{'async'}->{'_isgbininfo'} = 1 if $param->{'async'};
      $packagebinarylist = $ctx->xrpc("bininfo/$prpa", $param, \&BSUtil::fromstorable, "view=gbininfocode");
    } else {
      $packagebinarylist = $ctx->xrpc("bininfo/$prpa", $param, $BSXML::packagebinaryversionlist, "view=binaryversionscode");
    }
  };
  if ($@) {
    warn($@);
    my $error = $@;
    $error =~ s/\n$//s;
    ($projid, $repoid) = split('/', $ctx->{'prp'}, 2);
    if ( BSSched::RPC::is_transient_error($error) ) {
      BSSched::EventSource::Retry::addretryevent(
	$ctx->{'gctx'}, 
        {
          'type' => 'recheck', 
          'project' => $projid, 
          'repository' => $repoid}
      );
    }
    return undef;
  }
  return 0 if $packagebinarylist && $param->{'async'};
  my $gbininfo;
  ($gbininfo, $rpackstatus) = convertpackagebinarylist($gctx, $prpa, $packagebinarylist, undef, undef, $remoteproj->{'partition'} ? 1 : undef);
  if ($packstatus && $rpackstatus) {
    $packstatus->{$_} = $rpackstatus->{$_} for keys %$rpackstatus;
    delete $packstatus->{'/users'};
  }
  return $gbininfo;
}

sub read_gbininfo_remote_resume {
  my ($ctx, $handle, $error, $packagebinarylist) = @_;
  my $gctx = $ctx->{'gctx'};
  convertpackagebinarylist($gctx, $handle->{'_prpa'}, $packagebinarylist, $error, $ctx->{'prp'}, $handle->{'_isgbininfo'});
  $ctx->setchanged($handle);
}

sub convertpackagebinarylist {
  my ($gctx, $prpa, $packagebinarylist, $error, $packstatususer, $isgbininfo) = @_;

  my $remotegbininfos = $gctx->{'remotegbininfos'};
  if ($error) {
    chomp $error;
    warn("$error\n");
    $error ||= 'internal error';
    $remotegbininfos->{$prpa} = { 'lastfetch' => time(), 'error' => $error };
    return (undef, undef);
  }
  my $gbininfo = {};
  my $rpackstatus = {};
  if ($isgbininfo) {
    $gbininfo = $packagebinarylist || {};
    for my $pkg (keys %$gbininfo) {
      my $bi = $gbininfo->{$pkg};
      $rpackstatus->{$pkg} = delete($bi->{'.code'}) if exists $bi->{'.code'};
    }
  } else {
    for my $binaryversionlist (@{$packagebinarylist->{'binaryversionlist'} || []}) {
      my %bins;
      for my $binary (@{$binaryversionlist->{'binary'} || []}) {
        my $filename = $binary->{'name'};
        # XXX: should not rely on the filename here!
        if ($filename =~ /^(?:::import::.*::)?(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/) {
          $bins{$filename} = {'filename' => $filename, 'name' => $1, 'arch' => $2};
        } elsif ($filename =~ /^([^\/]+)_[^\/]*_([^\/]*)\.deb$/) {
          $bins{$filename} = {'filename' => $filename, 'name' => $1, 'arch' => $2};
        } elsif ($filename =~ /^([^\/]+)-[^-]+-[^-]+-([a-zA-Z][^\/\.\-]*)\.pkg\.tar\..z$/) {
          $bins{$filename} = {'filename' => $filename, 'name' => $1, 'arch' => $2};
        } elsif ($filename eq '.nouseforbuild') {
          $bins{$filename} = {};
        } else {
          $bins{$filename} = {'filename' => $filename}; # XXX: what about the md5sum for appdata?
        }
        $bins{$filename}->{'hdrmd5'} = $binary->{'hdrmd5'} if $binary->{'hdrmd5'};
        $bins{$filename}->{'leadsigmd5'} = $binary->{'leadsigmd5'} if $binary->{'leadsigmd5'};
      }
      my $pkg = $binaryversionlist->{'package'};
      $gbininfo->{$pkg} = \%bins;
      $rpackstatus->{$pkg} = $binaryversionlist->{'code'} if $binaryversionlist->{'code'};
    }
  }
  my $remotecache = $gctx->{'remotecache'};
  my $cachemd5 = Digest::MD5::md5_hex($prpa);
  substr($cachemd5, 2, 0, '/');
  mkdir_p("$remotecache/".substr($cachemd5, 0, 2));
  BSUtil::store("$remotecache/$cachemd5.bininfo.new$$", "$remotecache/$cachemd5.bininfo", $gbininfo);

  $remotegbininfos->{$prpa} = { 'lastfetch' => time() };

  if ($packstatususer) {
    my $remotepackstatus = $gctx->{'remotepackstatus'};
    my $remotepackstatus_cleanup = $gctx->{'remotepackstatus_cleanup'};
    $rpackstatus->{'/users'} = [];
    $rpackstatus->{'/users'} = [ @{$remotepackstatus->{$prpa}->{'/users'} || []} ] if $remotepackstatus->{$prpa};
    push @{$rpackstatus->{'/users'}}, $packstatususer unless grep {$_ eq $packstatususer} @{$rpackstatus->{'/users'}};
    push @{$remotepackstatus_cleanup->{$packstatususer}}, $prpa;
    $remotepackstatus->{$prpa} = $rpackstatus;
  }

  return ($gbininfo, $rpackstatus);
}

sub cleanup_remotepackstatus {
  my ($gctx, $prp) = @_;

  my $remotepackstatus = $gctx->{'remotepackstatus'};
  my $remotepackstatus_cleanup = $gctx->{'remotepackstatus_cleanup'};
  return unless $remotepackstatus_cleanup->{$prp};
  print "    cleaning up remote packstatus\n";
  for my $prpa (@{$remotepackstatus_cleanup->{$prp}}) {
    my $rpackstatus = $remotepackstatus->{$prpa};
    my @users = grep {$_ ne $prp} @{$rpackstatus->{'/users'} || []};
    $rpackstatus->{'/users'} = \@users;
    print "      - $prpa: ".@users." users\n";
    delete $remotepackstatus->{$prpa} unless @users;
  }
  delete $remotepackstatus_cleanup->{$prp};
}

1;

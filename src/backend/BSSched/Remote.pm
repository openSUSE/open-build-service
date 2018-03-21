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
#   addwatchremote
#   updateremoteprojs
#   getchangedremoteprojs
#   remoteprojid
#   fetchremote_sync
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
use BSConfiguration;

=head2 addwatchremote -  register for a possibly remote resource

 input:  $type: type of resource (project/package/repository)
	 $projid: local name of the project
	 $watch: extra data to match
=cut

sub addwatchremote {
  my ($gctx, $type, $projid, $watch) = @_;

  my $projpacks = $gctx->{'projpacks'};
  return undef if $projpacks->{$projid} && !$projpacks->{$projid}->{'remoteurl'};
  my $proj;
  my $watchremote_cache = $gctx->{'watchremote_cache'} || {};
  if (exists($watchremote_cache->{$projid})) {
    $proj = $watchremote_cache->{$projid};
  } else {
    $proj = remoteprojid($gctx, $projid);
    $watchremote_cache->{$projid} = $proj;
  }
  # we don't need the project data for package watches
  $gctx->{'needremoteproj'}->{$projid} = $proj if $type ne 'package';
  return undef unless $proj;
  my $watchremote = $gctx->{'watchremote'};
  if ($proj->{'partition'}) {
    $watchremote->{$BSConfig::srcserver}->{"$type/$proj->{'remoteproject'}$watch"} = $projid;
  } else {
    $watchremote->{$proj->{'remoteurl'}}->{"$type/$proj->{'remoteproject'}$watch"} = $projid;
  }
  # also set watchremote_repos so that we can free no longer needed
  # repository data
  $gctx->{'watchremote_repos'}->{"$projid$watch"} = 1 if $type eq 'repository';
  return $proj;
}

=head2 setup_watches - create watches for all dependencies on remote projects

 TODO: add description

=cut

sub setup_watches {
  my ($gctx) = @_;

  my $projpacks = $gctx->{'projpacks'};
  # clear old data
  %{$gctx->{'watchremote'}} = ();	# reset all watches

  # init tmp hashes
  $gctx->{'needremoteproj'} = {};	# tmp
  $gctx->{'watchremote_cache'} = {};	# tmp
  $gctx->{'watchremote_repos'} = {};	# tmp

  # add watches for all linked packages
  my $projpacks_linked = $gctx->{'projpacks_linked'};
  if (%$projpacks_linked) {
    my %watched;
    for my $lprojid (sort keys %$projpacks_linked) {
      next if $projpacks->{$lprojid} && !$projpacks->{$lprojid}->{'remoteurl'};
      next unless remoteprojid($gctx, $lprojid);
      for my $li (@{$projpacks_linked->{$lprojid}}) {
	my $lpackid = $li->{'package'};
	next if $watched{"$lprojid/$lpackid"};
	addwatchremote($gctx, 'package', $lprojid, $lpackid eq ':*' ? '' : "/$lpackid");
	$watched{"$lprojid/$lpackid"} = 1;
      }
    }
  }

  # add watches for project links
  my $expandedprojlink = $gctx->{'expandedprojlink'};
  if (%$expandedprojlink) {
    my %watched;
    for my $projid (keys %$expandedprojlink) {
      $watched{$_} = 1 for @{$expandedprojlink->{$projid}};
    }
    for my $projid (sort keys %watched) {
      next if $projpacks->{$projid} && !$projpacks->{$projid}->{'remoteurl'};
      addwatchremote($gctx, 'project', $projid, '');
    }
  }

  # add watches for all prp dependencies
  # this includes the prpsearchpath plus the extra deps from kiwi/aggregates/...
  # (we just watch the repository for the extra deps as it costs too much to
  # watch every single package)
  my $rprpdeps = $gctx->{'rprpdeps'};
  if (%$rprpdeps) {
    my $myarch = $gctx->{'arch'};
    my %projdeps;
    for my $prp (keys %$rprpdeps) {
      my ($projid, $repoid) = split('/', $prp, 2);
      push @{$projdeps{$projid}}, $repoid;
    }
    for my $projid (sort keys %projdeps) {
      next if $projpacks->{$projid} && !$projpacks->{$projid}->{'remoteurl'};
      next unless remoteprojid($gctx, $projid);
      # we need the config for all path elements, so we also add a project watch
      addwatchremote($gctx, 'project', $projid, '');
      for my $repoid (sort @{$projdeps{$projid}}) {
	addwatchremote($gctx, 'repository', $projid, "/$repoid/$myarch");
      }
    }
  }

  delete $gctx->{'watchremote_cache'};	# free mem

  # make sure we have the needed project data and delete the entries
  # we no longer need
  my $needremoteproj = delete $gctx->{'needremoteproj'};
  updateremoteprojs($gctx, $needremoteproj);

  # drop unwatched remote repos
  my $watchremote_repos = delete $gctx->{'watchremote_repos'};
  my $repocache = $gctx->{'repodatas'};
  if ($repocache) {
    for my $prpa (grep {!$watchremote_repos->{$_}} $repocache->getremote()) {
      print "dropping remote cache for $prpa\n";
      my ($projid, $repoid, $arch) = split('/', $prpa, 3);
      $repocache->drop("$projid/$repoid", $arch);
    }
  }
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
  my $remotemissing = $gctx->{'remotemissing'};
  for my $projid (keys %$remoteprojs) {
    my $or = $remoteprojs->{$projid};
    next if $or && $or->{'partition'};  # XXX how do we update them?
    my $r = $needremoteproj->{$projid};
    if (!$r) {
      delete $remoteprojs->{$projid};	# no longer needed
      next;
    }
    next if $or && $or->{'remoteurl'} eq $r->{'remoteurl'} && $or->{'remoteproject'} eq $r->{'remoteproject'};
    delete $remoteprojs->{$projid};	# changed, need to refetch
  }
  for my $projid (sort keys %$needremoteproj) {
    my $r = $needremoteproj->{$projid};
    fetchremoteproj($gctx, $r, $projid) if $r && !$remoteprojs->{$projid} && !exists($remotemissing->{$projid});
  }
}

=head2 remoteprojid - TODO: add summary

 TODO: add description

=cut

sub remoteprojid {
  my ($gctx, $projid) = @_;
  my $rsuf = '';
  my $origprojid = $projid;

  # check partition case, all partition projects are already in remoteprojs
  my $remoteprojs = $gctx->{'remoteprojs'};
  return $remoteprojs->{$projid} if $remoteprojs->{$projid} && $remoteprojs->{$projid}->{'partition'};

  # go up hierarchy until we find a remote project
  my $projpacks = $gctx->{'projpacks'};
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

  # nope, not a remote project
  return undef;
}

=head2 fetchremote_sync - add a missing remoteprojs entry with a synchronous call

 TODO: add description

=cut

sub fetchremote_sync {
  my ($gctx, $projid) = @_;
  print "WARNING: fetching remote project data for $projid\n";
  my @args;
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
  push @args, "project=$projid";
  my $param = {
    'uri' => "$BSConfig::srcserver/getprojpack",
    'timeout' => 60,
  };
  my $projpacksin;
  eval {
    $projpacksin = BSRPC::rpc($param, $BSXML::projpack, 'withconfig', 'withremotemap', "arch=$gctx->{'arch'}", @args);
  };
  my $remoteprojs = $gctx->{'remoteprojs'};
  if ($@) {
    warn($@);
    my $error = $@;
    $error =~ s/\n$//s;
    $remoteprojs->{$projid} = {'error' => $error};
    $gctx->{'retryevents'}->addretryevent({'type' => 'project', 'project' => $projid}) if BSSched::RPC::is_transient_error($error);
  } else {
    remotemap2remoteprojs($gctx, $projpacksin->{'remotemap'});
  }
  return $remoteprojs->{$projid};
}

=head2 fetchremoteproj - add missing entries to the remoteprojs hash

 TODO: add description

=cut

sub fetchremoteproj {
  my ($gctx, $proj, $projid) = @_;
  return undef unless $proj && $proj->{'remoteurl'} && $proj->{'remoteproject'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  return $remoteprojs->{$projid} if exists $remoteprojs->{$projid};
  my $remotemissing = $gctx->{'remotemissing'};
  return undef if $remotemissing->{$projid};
  return fetchremote_sync($gctx, $projid);	# force in missing entry
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
  $proj = fetchremote_sync($gctx, $projid);	# force in missing entry
  return undef if !$proj || $proj->{'error'};
  return $proj->{'config'};
}

=head2 remotemap2remoteprojs - update remoteprojs with the remotemap data

 TODO: add description

=cut

sub remotemap2remoteprojs {
  my ($gctx, $remotemap) = @_;

  my $remoteprojs = $gctx->{'remoteprojs'};
  for my $proj (@{$remotemap || []}) {
    my $projid = delete $proj->{'project'};
    my $oproj = $remoteprojs->{$projid};
    if (!$proj->{'remoteurl'} && !$proj->{'error'}) {
      # remote project is gone (partition case)
      delete $remoteprojs->{$projid};
      $gctx->{'remoteprojs_changed'}->{$projid} = 1 if $oproj;
      next;
    }
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
      $gctx->{'retryevents'}->addretryevent({'type' => 'project', 'project' => $projid}) if $error =~ /interconnect error:/;
    }
    if (!$proj->{'proto'} && !BSUtil::identical($proj, $oproj, {'error' => 1, 'person' => 1, 'group' => 1})) {
      $gctx->{'remoteprojs_changed'}->{$projid} = 1;
    }
    $remoteprojs->{$projid} = $proj;
  }
  # update remotemissing map
  my $projpacks = $gctx->{'projpacks'};
  my $remotemissing = $gctx->{'remotemissing'};
  for my $projid (keys %$remotemissing) {
    if ($projpacks->{$projid}) {
      delete $remotemissing->{$projid};		# no longer missing
    } elsif ($remoteprojs->{$projid}) {
      if (!defined($remoteprojs->{$projid}->{'config'})) {
        next unless $remotemissing->{$projid};	# keep the "in progress" flag
      }
      delete $remotemissing->{$projid};		# no longer missing
    }
  }
}

sub getchangedremoteprojs {
  my ($gctx, $clear) = @_;
  return () unless %{$gctx->{'remoteprojs_changed'} || {}};
  my @changed = sort keys %{$gctx->{'remoteprojs_changed'}};
  %{$gctx->{'remoteprojs_changed'}} = () if $clear;
  return @changed;
}

###########################################################################
###
### remote BuildRepo (aka full tree) support
###

sub addrepo_remote {
  my ($ctx, $pool, $prp, $arch, $remoteproj) = @_;

  my ($projid, $repoid) = split('/', $prp, 2);
  return undef if !$remoteproj || $remoteproj->{'error'};

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
    my @args = ('view=solvstate');
    push @args, 'noajax=1' if $remoteproj->{'partition'};
    $cpio = $ctx->xrpc("repository/$prp/$arch", $param, undef, @args);
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

  my $myarch = $gctx->{'arch'};

  my $remotecache = $gctx->{'remotecache'};
  my $cachemd5 = Digest::MD5::md5_hex("$prp/$arch");
  substr($cachemd5, 2, 0, '/');

  my $repocache = $gctx->{'repodatas'};

  if ($error) {
    chomp $error;
    warn("$error\n");
    if (BSSched::RPC::is_transient_error($error)) {
      my ($projid, $repoid) = split('/', $prp, 2);
      $gctx->{'retryevents'}->addretryevent({'type' => 'repository', 'project' => $projid, 'repository' => $repoid, 'arch' => $arch});
      my $solvfile = "$remotecache/$cachemd5.solv";
      if (-s $solvfile) {
        # try last solv file
        my $r;
        eval {$r = $pool->repofromfile($prp, $solvfile);};
        if ($r) {
	  $repocache->setcache($prp, $arch, 'solvfile' => $solvfile, 'isremote' => 1) if $repocache;
	  return $r;
        }
      }
    }
    $repocache->setcache($prp, $arch, 'error' => $error, 'isremote' => 1) if $repocache;
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
  my $isempty;
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
    $repocache->setcache($prp, $arch, 'solv' => $r->tostr(), 'isremote' => 1) if $repocache;
    $isempty = 1;
  }
  return undef unless $r;
  # write solv file
  mkdir_p("$remotecache/".substr($cachemd5, 0, 2));
  my $solvfile = "$remotecache/$cachemd5.solv";
  BSSched::BuildRepo::writesolv("$solvfile$$", $solvfile, $r);
  $repocache->setcache($prp, $arch, 'solvfile' => $solvfile, 'isremote' => 1) if $repocache && !$isempty;
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
    $gctx->{'retryevents'}->addretryevent({'type' => 'recheck', 'project' => $projid, 'repository' => $repoid}) if BSSched::RPC::is_transient_error($error);
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
    if (BSSched::RPC::is_transient_error($error)) {
      my ($projid, $repoid, $arch) = split('/', $prpa, 3);
      $gctx->{'retryevents'}->addretryevent({'type' => 'scanprjbinaries', 'project' => $projid, 'repository' => $repoid, 'arch' => $arch});
    }
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

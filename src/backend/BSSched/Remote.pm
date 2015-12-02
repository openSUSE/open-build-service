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

use strict;
use warnings;

use BSRPC;
use BSSched::RPC;
use BSConfiguration;

=head2 beginwatchcollection - TODO: add summary

 TODO: add description

=cut

sub beginwatchcollection {
  my ($gctx) = @_;
  %{$gctx->{'watchremote'}} = ();
  $gctx->{'watchremoteprojs'} = {};     # tmp
}

=head2 endwatchcollection - TODO: add summary

 TODO: add description

=cut

sub endwatchcollection {
  my ($gctx) = @_;
  updateremoteprojs($gctx);
  delete $gctx->{'watchremoteprojs'};   # clean up
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
  my $watchremoteprojs = $gctx->{'watchremoteprojs'} || {};
  # we don't need the project data for package watches
  $watchremoteprojs->{$projid} = $proj if $type ne 'package';
  return undef unless $proj;
  my $watchremote = $gctx->{'watchremote'};
  if ($proj->{'partition'}) {
    $watchremote->{$BSConfig::srcserver}->{"$type/$proj->{'remoteproject'}$watch"} = $projid;
  } else {
    $watchremote->{$proj->{'remoteurl'}}->{"$type/$proj->{'remoteproject'}$watch"} = $projid;
  }
  return $proj;
}

=head2 updateremoteprojs - sync remoteprojs with watches data

This function deletes all no longer needed elements from the
remoteprojs hash. It also calls fetchremoteproj for missing
entries, which should actually not happen.

=cut

sub updateremoteprojs {
  my ($gctx) = @_;

  my $remoteprojs = $gctx->{'remoteprojs'};
  my $watchremoteprojs = $gctx->{'watchremoteprojs'};
  for my $projid (keys %$remoteprojs) {
    my $r = $watchremoteprojs->{$projid};
    if (!$r) {
      delete $remoteprojs->{$projid};
      next;
    }
    my $or = $remoteprojs->{$projid};
    next if $or && $or->{'partition'};  # XXX how do we update them?
    next if $or && $or->{'remoteurl'} eq $r->{'remoteurl'} && $or->{'remoteproject'} eq $r->{'remoteproject'};
    delete $remoteprojs->{$projid};
  }
  for my $projid (sort keys %$watchremoteprojs) {
    my $r = $watchremoteprojs->{$projid};
    fetchremoteproj($gctx, $r, $projid) if $r;
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
    main::addretryevent($gctx, {'type' => 'project', 'project' => $projid}) if BSSched::RPC::is_transient_error($error);
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
    main::addretryevent($gctx, {'type' => 'project', 'project' => $projid}) if BSSched::RPC::is_transient_error($proj->{'error'});
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
      main::addretryevent($gctx, {'type' => 'project', 'project' => $projid}) if $error =~ /interconnect error:/;
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

1;

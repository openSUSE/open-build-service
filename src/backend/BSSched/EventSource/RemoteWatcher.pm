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

package BSSched::EventSource::RemoteWatcher;

use strict;
use warnings;

use Data::Dumper;

use BSRPC;
use BSXML;

our $uselasteventsproxy = 1;

=head1

  Remote watchers

=cut

sub new {
  my ($class, $myarch, $remoteurl, $watchremote, %conf) = @_;
  my $start = $conf{'start'};
  if ($start) {
    print "setting up watcher for $remoteurl, start=$start\n";
  } else {
    print "setting up watcher for $remoteurl\n";
  }
  # collaps filter list, watch complete project if more than 3 packages are watched
  my @filter;
  my %filterpackage;
  for (sort keys %$watchremote) {
    next if $_ eq 'watchlist';
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
  push @filter, 'none' unless @filter;	# just in case, will never match
  my $param = {
    'uri' => "$remoteurl/lastevents",
    'async' => 1,
    'request' => 'POST',
    'formurlencode' => 1,
  };
  my $client = $BSConfig::partition ? "$BSConfig::partition/$myarch" : $myarch;
  my @args;
  if ($remoteurl eq $BSConfig::srcserver) {
    push @args, "client=$client";
  } elsif ($uselasteventsproxy) {
    $param->{'uri'} = "$BSConfig::srcserver/lasteventsproxy";
    push @args, "client=$client";
    push @args, "remoteurl=$remoteurl";
  } else {
    $param->{'proxy'} = $conf{'remoteproxy'};
    push @args, "obsname=$conf{'obsname'}/$myarch" if $conf{'obsname'};
  }
  push @args, map {"filter=$_"} @filter;
  push @args, "start=$start" if $start;
  my $ret = eval { BSRPC::rpc($param, $BSXML::events, @args) };
  if ($@) {
    warn($@);
    print "retrying in 60 seconds\n";
    $ret = { 'retry' => time() + 60 };
  } else {
    $ret = { 'rpc' => $ret, 'socket' => $ret->{'socket'} };
  }
  if (!exists($watchremote->{'watchlist'})) {
    $watchremote->{'watchlist'} = join("\0", sort keys %$watchremote);
  }
  $ret->{'watchlist'} = $watchremote->{'watchlist'};
  $ret->{'remoteurl'} = $remoteurl;
  $ret->{'arch'} = $myarch;
  return bless $ret, $class;
}

=head2 isobsolete - check is a watcher's watchlist is up to date

 TODO: add description

=cut

sub isobsolete {
  my ($watcher, $watchremote) = @_;
  if ($watchremote && !exists($watchremote->{'watchlist'})) {
    $watchremote->{'watchlist'} = join("\0", sort keys %$watchremote);
  }
  if (!$watchremote || $watchremote->{'watchlist'} ne $watcher->{'watchlist'}) {
    my $rpc = $watcher->{'rpc'};
    close($rpc->{'socket'}) if $rpc && defined($rpc->{'socket'});
    delete $watcher->{'socket'};
    delete $watcher->{'rpc'};
    return 1;
  }
  return 0;
}

=head2 create_resync_events - create synthetic events for all watches

 called when some events are no longer available.

=cut

sub create_resync_events {
  my ($watchremote) = @_;

  my @remoteevents;
  for my $watch (sort keys %$watchremote) {
    next if $watch eq 'watchlist';
    my $projid = $watchremote->{$watch};
    next unless defined $projid;
    my @s = split('/', $watch);
    if ($s[0] eq 'project') {
      push @remoteevents, {'type' => 'project', 'project' => $projid};
    } elsif ($s[0] eq 'package') {
      if (!$s[2]) {
	push @remoteevents, {'type' => 'package', 'project' => $projid};	# watched all packages
      } else {
	push @remoteevents, {'type' => 'package', 'project' => $projid, 'package' => $s[2]};
      }
    } elsif ($s[0] eq 'repository' || $s[0] eq 'repoinfo') {
      push @remoteevents, {'type' => $s[0], 'project' => $projid, 'repository' => $s[2], 'arch' => $s[3]};
    }
  }
  return @remoteevents;
}

=head2 getevents - TODO: add summary

 TODO: add description

=cut

sub getevents {
  my ($watcher, $watchremote, $starthash) = @_;

  my $myarch = $watcher->{'arch'};
  my $remoteurl = $watcher->{'remoteurl'};
  my $start = $starthash->{$remoteurl};
  print "response from watcher for $remoteurl\n";
  my $ret;
  die("watcher with no rpc\n") unless $watcher->{'rpc'};
  eval {
    $ret = BSRPC::rpc($watcher->{'rpc'});
  };
  if ($@) {
    warn $@;
    delete $watcher->{'socket'};
    delete $watcher->{'rpc'};
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
      push @remoteevents, create_resync_events($watchremote);
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
      $watch = "repository/$ev->{'project'}/$ev->{'repository'}/$myarch";
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

sub isfinished {
  my ($watcher) = @_;
  return 1 unless $watcher->{'rpc'};
  my $isfinished = eval { BSRPC::rpc_isfinished($watcher->{'rpc'}) };
  return $@ || $isfinished ? 1 : 0;
}

1;

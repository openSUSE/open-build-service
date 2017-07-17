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
package BSSrcServer::Projlink;

use strict;
use warnings;

use BSRevision;
use BSSrcrep;
use BSAccess;

use BSSrcServer::Local;

my $frozenlinks_cache;

#############################################################################

our $getrev = \&BSSrcServer::Local::getrev;
our $findpackages = \&BSSrcServer::Local::findpackages;
our $readpackage = \&BSSrcServer::Local::readpackage;
our $readproject = \&BSSrcServer::Local::readproject;

#############################################################################


sub get_frozenlinks {
  my ($projid) = @_;
  return $frozenlinks_cache->{$projid} if $frozenlinks_cache && exists $frozenlinks_cache->{$projid};
  my $rev = BSRevision::getrev_meta($projid);
  my $files = BSRevision::lsrev($rev);
  my $frozen;
  if ($files->{'_frozenlinks'}) {
    my $frozenx = BSRevision::revreadxml($rev, '_frozenlinks', $files->{'_frozenlinks'}, $BSXML::frozenlinks);
    $frozen = {};
    for my $fp (@{$frozenx->{'frozenlink'} || []}) {
      my $n = defined($fp->{'project'}) ? $fp->{'project'} : '/all';
      for my $p (@{$fp->{'package'} || []}) {
        my $pn = delete $p->{'name'};
        $frozen->{$n}->{$pn} = $p if defined($pn) && $p->{'srcmd5'};
      }
    }
  }
  $frozenlinks_cache->{$projid} = $frozen if $frozenlinks_cache;
  return $frozen;
}

sub getrev_projlink {
  my ($projid, $proj, $packid, $revid, $linked, $missingok) = @_;

  my $collect_error;
  $linked ||= [];
  my $frozen = get_frozenlinks($projid) || {};
  for my $link (@{$proj->{'link'} || []}) {
    my $lprojid = $link->{'project'};
    next if $lprojid eq $projid;
    next if grep {$_->{'project'} eq $lprojid && $_->{'package'} eq $packid} @$linked;
    push @$linked, {'project' => $lprojid, 'package' => $packid};
    my $frozenp = $frozen->{'/all'} || $frozen->{$lprojid};
    my $rev;
    if ($frozenp && $frozenp->{$packid} && !($revid && $revid =~ /^[0-9a-f]{32}$/)) {
      eval {
        $rev = $getrev->($lprojid, $packid, $frozenp->{$packid}->{'srcmd5'}, $linked);
        $rev->{'vrev'} = $frozenp->{$packid}->{'vrev'} if defined $frozenp->{$packid}->{'vrev'};
      };
    } else {
      eval {
        $rev = $getrev->($lprojid, $packid, $revid, $linked);
      };
    }
    next if $collect_error;
    if ($@ && $@ !~ /^404/) {
      if ($BSSrcServer::Remote::collect_remote_getrev && $BSSrcServer::Remote::collect_remote_getrev && $@ =~ /collect_remote_getrev$/) {
        # special case for project links, we don't know if the package exists yet,
        # so collect from all link elements
        $collect_error = $@;
        next;
      }
      die($@);
    }
    next unless $rev;
    # make sure that we may access the sources of this package
    BSSrcServer::Access::checksourceaccess($lprojid, $packid);
    # make the tree available
    BSSrcrep::copytree($projid, $packid, $lprojid, $packid, $rev->{'srcmd5'});
    $rev->{'originproject'} ||= $lprojid;
    $rev->{'project'} = $projid;
    if ($link->{'vrevmode'}) {
      $rev->{'vrev'} ||= 0;
      die("vrevmode error for $rev->{'vrev'}\n") unless $rev->{'vrev'} =~ s/^(\d+).*?$/($1+1)/e;
      $rev->{'vrev'} .= '.1' if $link->{'vrevmode'} eq 'extend';
    }
    return $rev;
  }
  die($collect_error) if $collect_error;
  return undef;
}

sub findpackages_projlink {
  my ($projid, $proj, $nonfatal, $origins) = @_;

  my $frozen = get_frozenlinks($projid) || {};
  my %checked = ($projid => 1);
  my @todo = map {$_->{'project'}} @{$proj->{'link'}};
  my %packids;
  while (@todo) {
    my $lprojid = shift @todo;
    next if $checked{$lprojid};
    $checked{$lprojid} = 1;
    my $lorigins = defined($origins) ? {} : undef;
    my $frozenp = $frozen->{'/all'} || $frozen->{$lprojid};
    my @lpackids;
    if ($frozenp) {
      @lpackids = sort keys %$frozenp;
      if ($lorigins) {
        $lorigins->{$_} = $lprojid for @lpackids;
      }
    } else {
      my $lproj = BSRevision::readproj_local($lprojid, 1);
      my $llink;
      $llink = delete $lproj->{'link'} if $lproj;
      @lpackids = $findpackages->($lprojid, $lproj, $nonfatal || -1, $lorigins);
      unshift @todo, map {$_->{'project'}} @$llink if $llink;
    }
    @lpackids = grep {$_ ne '_product' && !/^_product:/} @lpackids if $packids{'_product'};
    $packids{$_} = 1 for @lpackids;
    if ($origins && $lorigins) {
      for (@lpackids) {
        $origins->{$_} = $lorigins->{$_} unless defined $origins->{$_};
      }
    }
  }
  return sort(keys %packids);
}

sub readpackage_projlink {
  my ($projid, $proj, $packid, $rev, $missingok) = @_;

  die("readpackage_projlink: revid is not supported\n") if $rev;
  my %checked = ($projid => 1);
  my @todo = map {$_->{'project'}} @{$proj->{'link'}};
  while (@todo) {
    my $lprojid = shift @todo;
    next if $checked{$lprojid};
    $checked{$lprojid} = 1;
    my $lproj = BSRevision::readproj_local($lprojid, 1);
    my $llink;
    $llink = delete $lproj->{'link'} if $lproj;
    my $pack = $readpackage->($lprojid, $lproj, $packid, undef, 1);
    return $pack if $pack;
    unshift @todo, map {$_->{'project'}} @$llink if $llink;
  }
  die("404 package '$packid' does not exist in project '$projid'\n") unless $missingok;
  return undef;
}

sub enable_frozenlinks_cache {
  $frozenlinks_cache ||= {};
}

sub disable_frozenlinks_cache {
  $frozenlinks_cache = undef;
}

sub getnewvrev {
  my ($projid, $proj) = @_;
  my %seen = ($projid => 1);
  my $max = 0;
  my ($maxvrevmode, $vrevmode);
  my @todo = map {($_, 0)} @{$proj->{'link'} || []};
  while (@todo) {
    my ($link, $level) = splice(@todo, 0, 2);
    my $lprojid = $link->{'project'};
    next if $seen{$lprojid};
    $seen{$lprojid} = 1;
    if ($link->{'vrevmode'}) {
      $vrevmode = $link->{'vrevmode'} if !$level;
      $level++;
      ($max, $maxvrevmode) = ($level, $vrevmode) if $max < $level;
    }
    my $lproj = $readproject->($lprojid, undef, undef, 1);
    unshift @todo, map {($_, $level)} @{$lproj->{'link'} || []} if $lproj;
  }
  $max .= '.1' if $maxvrevmode && $maxvrevmode eq 'extend';
  return $max;
}

1;

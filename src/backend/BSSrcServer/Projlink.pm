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

my $frozenlinks_cache;

#############################################################################

our $getrev = sub {
  my ($projid, $packid, $revid, $linked, $missingok) = @_;
  my $rev = BSRevision::getrev_local($projid, $packid, $revid);
  return $rev if $rev;
  return {'project' => $projid, 'package' => $packid, 'srcmd5' => $BSSrcrep::emptysrcmd5} if $missingok;
  die("404 package '$packid' does not exist in project '$projid'\n");
};

our $findpackages = sub {
  my ($projid, $proj, $nonfatal, $origins, $noexpand, $deleted) = @_;
  my @packids = BSRevision::lspackages_local($projid, $deleted);
  if ($origins) {
    for (@packids) {
      $origins->{$_} = $projid unless defined $origins->{$_};
    }
  }
};

our $getpackage = sub {
  my ($projid, $proj, $packid, $revid) = @_;
  my $pack = BSRevision::readpack_local($projid, $packid, 1);
  $pack->{'project'} ||= $projid if $pack;
  return $pack;
};

#############################################################################


sub get_frozenlinks {
  my ($projid) = @_;
  return $frozenlinks_cache->{$projid} if $frozenlinks_cache && exists $frozenlinks_cache->{$projid};
  my $rev = BSRevision::getrev_meta($projid);
  my $files = BSSrcrep::lsrev($rev);
  my $frozen;
  if ($files->{'_frozenlinks'}) {
    my $frozenx = BSSrcrep::repreadxml($rev, '_frozenlinks', $files->{'_frozenlinks'}, $BSXML::frozenlinks);
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
  my $frozen = get_frozenlinks($projid);
  for my $lprojid (map {$_->{'project'}} @{$proj->{'link'} || []}) {
    next if $lprojid eq $projid;
    next if grep {$_->{'project'} eq $lprojid && $_->{'package'} eq $packid} @$linked;
    push @$linked, {'project' => $lprojid, 'package' => $packid};
    my $frozenp = $frozen->{'/all'} || $frozen->{$lprojid};
    my $rev;
    if ($frozenp->{$packid} && !($revid && $revid =~ /^[0-9a-f]{32}$/)) {
      eval {
        $rev = $getrev->($lprojid, $packid, $frozenp->{$packid}->{'srcmd5'}, $linked, $missingok);
        $rev->{'vrev'} = $frozenp->{$packid}->{'vrev'} if defined $frozenp->{$packid}->{'vrev'};
      };
    } else {
      eval {
        $rev = $getrev->($lprojid, $packid, $revid, $linked, $missingok);
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
    return $rev;
  }
  die($collect_error) if $collect_error;
  return undef;
}

sub findpackages_projlink {
  my ($projid, $proj, $nonfatal, $origins) = @_;

  my $frozen = get_frozenlinks($projid);
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

sub getpackage_projlink {
  my ($projid, $proj, $packid, $rev, $missingok) = @_;

  die("getpackage_projlink: revid is not supported\n") if $rev;
  my %checked = ($projid => 1);
  my @todo = map {$_->{'project'}} @{$proj->{'link'}};
  while (@todo) {
    my $lprojid = shift @todo;
    next if $checked{$lprojid};
    $checked{$lprojid} = 1;
    my $lproj = BSRevision::readproj_local($lprojid, 1);
    my $llink;
    $llink = delete $lproj->{'link'} if $lproj;
    my $pack = $getpackage->($lprojid, $lproj, $packid, undef, 1);
    return $pack if $pack;
    unshift @todo, map {$_->{'project'}} @$llink if $llink;
  }
  die("404 package '$packid' does not exist in project '$projid'\n") unless $missingok;
  return undef;
}

1;

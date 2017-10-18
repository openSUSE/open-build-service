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

package BSSched::Access;

use strict;
use warnings;

use BSUtil;

sub checkaccess {
  my ($gctx, $type, $projid, $packid, $repoid) = @_;
  my $access = 1;
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $myarch = $gctx->{'arch'};
  my $proj = $projpacks->{$projid};
  $proj = $remoteprojs->{$projid} if !$proj && ($remoteprojs->{$projid} || {})->{'partition'};
  if ($proj) {
    my $pdata;
    $pdata = ($proj->{'package'} || {})->{$packid} if defined $packid;
    $access = BSUtil::enabled($repoid, $proj->{$type}, $access, $myarch);
    $access = BSUtil::enabled($repoid, $pdata->{$type}, $access, $myarch) if $pdata;
  } else {
    # remote project access checks are handled by the remote server
    $access = 0 unless $remoteprojs->{$projid} && !$remoteprojs->{$projid}->{'partition'};
  }
  return $access;
}

# check if every user from oprojid may access projid
sub checkroles {
  my ($gctx, $type, $projid, $packid, $oprojid, $opackid) = @_;
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $proj = $projpacks->{$projid};
  my $oproj = $projpacks->{$oprojid};
  $proj = $remoteprojs->{$projid} if !$proj && ($remoteprojs->{$projid} || {})->{'partition'};
  $oproj = $remoteprojs->{$oprojid} if !$oproj && ($remoteprojs->{$oprojid} || {})->{'partition'};
  return 0 unless $proj && $oproj;
  if ($projid eq $oprojid) {
    return 1 if !defined $opackid;
    return 1 if ($packid || '') eq ($opackid || '');
  }
  my @roles;
  if (defined($packid)) {
    my $pdata = ($proj->{'package'} || {})->{$packid} || {};
    push @roles, @{$pdata->{'person'} || []}, @{$pdata->{'group'} || []};
  }
  push @roles, @{$proj->{'person'} || []}, @{$proj->{'group'} || []};
  while ($projid =~ /^(.+):/) {
    $projid = $1;
    $proj = $projpacks->{$projid} || {};
    push @roles, @{$proj->{'person'} || []}, @{$proj->{'group'} || []};
  }
  my @oroles;
  if (defined($opackid)) {
    my $pdata = ($oproj->{'package'} || {})->{$opackid} || {};
    push @oroles, @{$pdata->{'person'} || []}, @{$pdata->{'group'} || []};
  }
  push @oroles, @{$oproj->{'person'} || []}, @{$oproj->{'group'} || []};
  while ($oprojid =~ /^(.+):/) {
    $oprojid = $1;
    $oproj = $projpacks->{$oprojid} || {};
    push @oroles, @{$oproj->{'person'} || []}, @{$oproj->{'group'} || []};
  }
  # make sure every user from oprojid can also access projid
  # XXX: check type and roles
  for my $r (@oroles) {
    next if $r->{'role'} eq 'bugowner';
    my @rx;
    if (exists $r->{'userid'}) {
      push @rx, grep {exists($_->{'userid'}) && $_->{'userid'} eq $r->{'userid'}} @roles;
    } elsif (exists $r->{'groupid'}) {
      push @rx, grep {exists($_->{'groupid'}) && $_->{'groupid'} eq $r->{'groupid'}} @roles;
    }
    return 0 unless grep {$_->{'role'} eq $r->{'role'} || $_->{'role'} eq 'maintainer'} @rx;
  }
  return 1;
}

# check if we may access repo $aprp from repo $prp
sub checkprpaccess {
  my ($gctx, $aprp, $prp) = @_;
  return 1 if $aprp eq $prp;
  my ($aprojid, $arepoid) = split('/', $aprp, 2);
  # ok if aprp is not protected
  return 1 if checkaccess($gctx, 'access', $aprojid, undef, $arepoid);
  my ($projid, $repoid) = split('/', $prp, 2);
  # not ok if prp is unprotected
  return 0 if checkaccess($gctx, 'access', $projid, undef, $repoid);
  # both prp and aprp are proteced.
  return 1 if $aprojid eq $projid;	# they hopefully know what they are doing
  # check if publishing flags match unless aprojid is remote
  my $remoteprojs = $gctx->{'remoteprojs'};
  if ((!$remoteprojs->{$aprojid} || $remoteprojs->{$aprojid}->{'partition'}) && !checkaccess($gctx, 'publish', $aprojid, undef, $arepoid)) {
    return 0 if checkaccess($gctx, 'publish', $projid, undef, $repoid);
  }
  # check if the roles match
  return checkroles($gctx, 'access', $aprojid, undef, $projid, undef);
}

1;

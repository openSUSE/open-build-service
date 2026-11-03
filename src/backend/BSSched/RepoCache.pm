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
package BSSched::RepoCache;

use strict;
use warnings;

sub new {
  my ($class, $arch, $reporoot) = @_;
  my $self = {
    'arch' => $arch,
    'reporoot' => $reporoot,
  };
  return bless $self, $class;
}

sub _getmodulerepodata {
  my ($self, $repodata, $reqmodules, $create) = @_;
  my $repomodules = $repodata->{'modules'};
  return $repodata unless @{$repomodules || []} && @{$reqmodules || []};
  my %repomodules = map {$_ => 1} @$repomodules;
  my @modules = grep {$repomodules{$_}} @$reqmodules;
  return $repodata unless @modules;
  my $modulestr = '/'.join('/', sort @modules);
  $repodata->{"modules$modulestr"} ||= {} if $create;
  return $repodata->{"modules$modulestr"};
}

sub setcache {
  my ($self, $prp, $arch, %conf) = @_;

  my $repodata = $self->{"$prp/$arch"};
  $self->{"$prp/$arch"} = $repodata = {} unless $repodata;
  my $reqmodules = delete $conf{'reqmodules'};
  my $repomodules = $conf{'modules'};
  if (@{$repomodules || []}) {
    $repodata->{'modules'} = $repomodules;
    $repodata = $self->_getmodulerepodata($repodata, $reqmodules, 1);
  } else {
    delete $repodata->{'modules'};
  }
  delete $repodata->{$_} for qw{solv solvfile error lastscan random isremote};
  $repodata->{$_} = $conf{$_} for keys %conf;
  # we don't cache local alien repos
  if ($arch eq $self->{'arch'} || $repodata->{'isremote'}) {
    $repodata->{'lastscan'} = time();
    $repodata->{'random'} = rand();
  }
}

sub addrepo {
  my ($self, $pool, $prp, $arch) = @_;

  my $repodata = $self->{"$prp/$arch"};
  return 0 unless $repodata;

  # we use different caches for the requested module sets
  if (@{$repodata->{'modules'} || []}) {
    my @reqmodules;
    @reqmodules = $pool->getmodules() if defined &BSSolv::pool::getmodules;
    $repodata = $self->_getmodulerepodata($repodata, \@reqmodules);
    return 0 unless $repodata;
  }

  if ($repodata->{'lastscan'} && $repodata->{'lastscan'} + 24 * 3600 + ($repodata->{'random'} || 0) * 1800 > time()) {
    if ($repodata->{'error'}) {
      print "    repo $prp/$arch: $repodata->{'error'}\n";
      return undef;
    }
    if (exists $repodata->{'solv'}) {
      my $r;
      eval {$r = $pool->repofromstr($prp, $repodata->{'solv'});};
      return $r if $r;
      delete $repodata->{'solv'};	# bad data
    }
    my $solvfile = $repodata->{'solvfile'} || "$self->{'reporoot'}/$prp/$arch/:full.solv";
    if (-s $solvfile) {
      my $r;
      if ($repodata->{'solvfile'}) {
	my $now = time();
        my @s = stat _;
        utime($now, $s[9], $solvfile) if $s[8] + 60 < $now; # update atime (remote cache case)
      }
      eval {$r = $pool->repofromfile($prp, $solvfile);};
      return $r if $r;
    }
  }

  # can't use it. free some mem
  delete $repodata->{$_} for qw{solv solvfile error lastscan random isremote};
  return 0;
}

sub drop {
  my ($self, $prp, $arch) = @_;
  if (defined($prp)) {
    delete $self->{"$prp/$arch"};
  } else {
    %$self = ( 'arch' => $self->{'arch'}, 'reporoot' => $self->{'reporoot'} );
  }
}

sub dropmeta {
  my ($self, $prp, $arch) = @_;
  delete $self->{"$prp/$arch"}->{'meta'} if $self->{"$prp/$arch"};
}

sub dropsolv {
  my ($self, $prp, $arch) = @_;
  delete $self->{"$prp/$arch"}->{'solv'} if $self->{"$prp/$arch"};
}

sub getrepomodules {
  my ($self, $prp, $arch) = @_;
  my $repodata = $self->{"$prp/$arch"};
  return ($self->{"$prp/$arch"} || {})->{'modules'};
}

sub getremote {
  my ($self) = @_;
  my @remote = grep {/\// && $self->{$_}->{'isremote'}} keys %$self;
  return sort(@remote);
}

1;

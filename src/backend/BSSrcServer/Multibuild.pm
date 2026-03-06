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
package BSSrcServer::Multibuild;

use strict;
use warnings;

use BSConfiguration;
use BSUtil;
use BSRevision;
use BSSrcrep;
use BSXML;
use BSVerify;

our $multibuildcache = {};

my $projectsdir = "$BSConfig::bsdir/projects";

sub globalenabled {
  my ($disen, $default) = @_;
  return $default unless $disen;
  my @dis = grep { !defined($_->{'arch'}) && !defined($_->{'repository'}) } @{$disen->{'disable'} || []};
  return 1 if !@dis && $default;
  my @ena = grep { !defined($_->{'arch'}) && !defined($_->{'repository'}) } @{$disen->{'enable'} || []};
  return @dis ? 0 : $default unless @ena;
  return @ena ? 1 : $default unless @dis;
  return 0;
}

sub getcache {
  my ($projid, $ignorecache) = @_;
  if ($BSServerEvents::gev) {
    $BSServerEvents::gev->{'multibuildcache'} ||= {};
    $multibuildcache = $BSServerEvents::gev->{'multibuildcache'};
  }
  my $mc;
  $mc = $multibuildcache->{$projid} unless $ignorecache;
  if (!$mc) {
    $multibuildcache->{$projid} = $mc = BSUtil::retrieve("$projectsdir/$projid.pkg/:multibuild", 1) || {};
  }
  return $mc;
}

sub putcache {
  my ($projid, $mc) = @_;
  if (%$mc) {
    mkdir_p("$projectsdir/$projid.pkg") unless -d "$projectsdir/$projid.pkg";
    BSUtil::store("$projectsdir/$projid.pkg/.:multibuild.$$", "$projectsdir/$projid.pkg/:multibuild", $mc);
  } else {
    unlink("$projectsdir/$projid.pkg/:multibuild");
  }
}

sub find_mbname {
  my ($files) = @_;
  my $mbname = '_multibuild';
  # support service generated multibuild files, see findfile
  if ($files->{'_service'}) {
    for (sort keys %$files) {
      next unless /^_service:.*:(.*?)$/s;
      $mbname = $_ if $1 eq '_multibuild';
    }
  }
  return $mbname;
}

sub getmultibuild_fromfiles {
  my ($projid, $packid, $files) = @_;
  my $mbname = find_mbname($files);
  my $mb;
  if ($files->{$mbname}) {
    $mb = BSSrcrep::filereadxml($projid, $packid, $mbname, $files->{$mbname}, $BSXML::multibuild, 1);
    eval { BSVerify::verify_multibuild($mb) };
    if ($@) {
      warn("$projid/$packid/$mbname: $@");
      return undef;
    }
    $mb->{'_md5'} = $files->{$mbname} if $mb;
  }
  return $mb;
}

sub updatemultibuild {
  my ($projid, $packid, $files, $isprojpack) = @_;
  return undef if $packid eq '_product';	# no multibuilds for those
  return undef if $packid =~ /:/;		# master packages only
  my $mc = getcache($projid);

  # check if something changed
  my $mbname = find_mbname($files);
  if (!$files->{$mbname}) {
    return undef if !$mc->{$packid};
  } else {
    return $mc->{$packid} if $mc->{$packid} && $mc->{$packid}->{'_md5'} eq $files->{$mbname};
  }

  if (!$isprojpack) {
    # we do not update for disabled/locked packages to be consistent with getprojpack
    my $proj = BSRevision::readproj_local($projid, 1);
    return $mc->{$packid} unless $proj;	# 	local projects only!
    my $pack = BSRevision::readpack_local($projid, $packid, 1);
    $pack ||= {} if $proj->{'link'};
    return $mc->{$packid} unless $pack;
    return $mc->{$packid} if globalenabled($proj->{'lock'}, 0) && !$pack->{'lock'};
    return $mc->{$packid} unless globalenabled($pack->{'build'}, globalenabled($proj->{'build'}, 1));
  }

  # need to update, lock
  mkdir_p("$projectsdir/$projid.pkg") unless -d "$projectsdir/$projid.pkg";
  local *F;
  BSUtil::lockopen(\*F, '>>', "$projectsdir/$projid.pkg/:multibuild");
  $mc = getcache($projid, 1);

  # now update
  my $mb = getmultibuild_fromfiles($projid, $packid, $files);
  delete $mc->{$packid};
  $mc->{$packid} = $mb if $mb;
  putcache($projid, $mc);
  close(F);	# release lock
  return $mc->{$packid};
}

sub prunemultibuild {
  my ($projid, $packages) = @_;
  my $mc = getcache($projid);
  return unless $mc && %$mc;
  my %p = map {$_ => 1} @$packages;
  return unless grep {!$p{$_}} keys %$mc;

  # need to update, lock
  mkdir_p("$projectsdir/$projid.pkg") unless -d "$projectsdir/$projid.pkg";
  local *F;
  BSUtil::lockopen(\*F, '>>', "$projectsdir/$projid.pkg/:multibuild");
  $mc = getcache($projid, 1);
  for my $packid (keys %$mc) {
    delete $mc->{$packid} unless $p{$packid} || -e "$projectsdir/$projid.pkg/$packid.xml";
  }
  putcache($projid, $mc);
  close(F);	# release lock
}

sub getmultibuild {
  my ($projid, $packid) = @_;
  return undef if $packid eq '_product' || $packid =~ /:/;	# master packages only
  my $mc = getcache($projid);
  return $mc->{$packid};
}

sub setmultibuild {
  my ($projid, $packid, $mb) = @_;
  return if $packid eq '_product' || $packid =~ /:/;		# master packages only
  if (!$mb && ! -e "$projectsdir/$projid.pkg/:multibuild") {
    $multibuildcache->{$projid} = {};
    return;
  }
  mkdir_p("$projectsdir/$projid.pkg") unless -d "$projectsdir/$projid.pkg";
  local *F;
  BSUtil::lockopen(\*F, '>>', "$projectsdir/$projid.pkg/:multibuild");
  my $mc = getcache($projid, 1);
  delete $mc->{$packid};
  $mc->{$packid} = $mb if $mb;
  putcache($projid, $mc);
  close(F);	# release lock
}

sub addmultibuildpackages {
  my ($projid, $origins, @packages) = @_;
  my $mc = getcache($projid);
  return @packages if !$mc || !%$mc;
  for my $packid (splice @packages) {
    my $mb = $mc->{$packid};
    if (!$mb || !defined($mb->{'buildemptyflavor'}) || $mb->{'buildemptyflavor'} ne 'false') {
      push @packages, $packid;
    }
    next unless $mb;
    my @mbp = map {"$packid:$_"} @{$mb->{'flavor'} || $mb->{'package'} || []};
    push @packages, @mbp;
    if ($origins) {
      my $origin = defined($origins->{$packid}) ? $origins->{$packid} : $projid;
      for (@mbp) {
	$origins->{$_} = $origin unless defined $origins->{$_};
      }
    }
  }
  return @packages;
}


# Check if any package in @packages matches an entry in $packids, accounting
# for multibuild flavors. A flavor package like 'pkg:flavor' matches if the
# base name 'pkg' is in $packids. This is needed because buildemptyflavor="false"
# excludes the base package from the list, leaving only flavors.
sub packids_match_packages {
  my ($packids, @packages) = @_;
  for my $pkg (@packages) {
    return 1 if $packids->{$pkg};
    next unless $pkg =~ /(?<!^_product)(?<!^_patchinfo):./;
    next unless $pkg =~ /^(.*):[^:]+$/;
    return 1 if $packids->{$1};
  }
  return 0;
}

# Update the multibuild cache during getprojpack processing. Handles both base
# and flavor packages. Returns ($mb, $stale_packages):
#   - Base package: ($mb, undef) where $mb is the multibuild data
#   - Valid flavor: (undef, undef)
#   - Stale flavor: (undef, \@newpackages) with the corrected package list
# For flavor packages, this also refreshes the cache for the base package,
# which is needed when buildemptyflavor="false" excludes the base from
# the getprojpack package list and updatemultibuild would otherwise never
# be called for it.
sub check_flavor_update {
  my ($projid, $packid, $files, $isprojpack) = @_;
  # base package: just call updatemultibuild directly
  if ($packid !~ /(?<!^_product)(?<!^_patchinfo):./) {
    return (updatemultibuild($projid, $packid, $files, $isprojpack), undef);
  }
  # flavor package: update cache for the base and check for stale flavors
  return (undef, undef) unless $packid =~ /^(.*):[^:]+$/;
  my $basepackid = $1;
  my $basemb = updatemultibuild($projid, $basepackid, $files, $isprojpack);
  return (undef, undef) unless $basemb;
  my @newpackages = addmultibuildpackages($projid, undef, $basepackid);
  return (undef, undef) if grep {$_ eq $packid} @newpackages;
  return (undef, \@newpackages);
}

1;

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

sub updatemultibuild {
  my ($projid, $packid, $files, $isprojpack) = @_;
  return undef if $packid eq '_product';	# no multibuilds for those
  return undef if $packid =~ /:/;		# master packages only
  my $mc = getcache($projid);
  if (!$isprojpack) {
    # we do not update for disabled/locked packages to be consistent
    # with getprojpack
    my $proj = BSRevision::readproj_local($projid, 1);
    return $mc->{$packid} unless $proj;	# 	local projects only!
    my $pack = BSRevision::readpack_local($projid, $packid, 1);
    $pack ||= {} if $proj->{'link'};
    return $mc->{$packid} unless $pack;
    return $mc->{$packid} if globalenabled($proj->{'lock'}, 0) && !$pack->{'lock'};
    return $mc->{$packid} unless globalenabled($pack->{'build'}, globalenabled($proj->{'build'}, 1));
  }
  my $mbname = '_multibuild';
  # see findfile
  if ($files->{'_service'}) {
    for (sort keys %$files) {
      next unless /^_service:.*:(.*?)$/s;
      $mbname = $_ if $1 eq '_multibuild';
    }
  }
  if (!$files->{$mbname}) {
    return undef if !$mc->{$packid};
  } else {
    return $mc->{$packid} if $mc->{$packid} && $mc->{$packid}->{'_md5'} eq $files->{$mbname};
  }

  # need to update, lock
  mkdir_p("$projectsdir/$projid.pkg") unless -d "$projectsdir/$projid.pkg";
  local *F;
  BSUtil::lockopen(\*F, '>>', "$projectsdir/$projid.pkg/:multibuild");
  $mc = getcache($projid, 1);

  # now update
  my $mb;
  if ($files->{$mbname}) {
    $mb = BSSrcrep::filereadxml($projid, $packid, $mbname, $files->{$mbname}, $BSXML::multibuild, 1);
    eval {
      BSVerify::verify_multibuild($mb);
    };
    if ($@) {
      warn("$projid/$packid/$mbname: $@");
      $mb = undef;
    }
    $mb->{'_md5'} = $files->{$mbname} if $mb;
  }
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
    delete $mc->{$packid} unless $p{$packid};
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
    push @packages, $packid;
    my $mb = $mc->{$packid};
    next unless $mb;
    my @mbp = map {"$packid:$_"} @{$mb->{'flavor'} || $mb->{'package'} || []};
    push @packages, @mbp;
    if ($origins) {
      for (@mbp) {
	$origins->{$_} = $projid unless defined $origins->{$_};
      }
    }
  }
  return @packages;
}

1;

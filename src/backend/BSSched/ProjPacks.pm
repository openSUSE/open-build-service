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
package BSSched::ProjPacks;

# gctx functions
#   checkbuildrepoid
#   get_projpacks
#   get_projpacks_resume
#   update_projpacks
#   update_project_meta
#   update_project_meta_check
#   update_project_meta_resume
#   update_projpacks_meta
#   clone_projpacks_part
#   postprocess_needed_check
#   get_projpacks_postprocess
#   calc_projpacks_linked
#   find_linked_sources
#   expandsearchpath
#   expandprojlink
#   calc_prps
#   do_delayedprojpackfetches
#   do_fetchprojpacks
#   getconfig
#   update_prpcheckuseforbuild
#
# static functions
#   orderpackids
#
# gctx usage
#   reporoot
#   arch
#   projpacks
#   rctx
#   testmode
#   remoteprojs
#   delayedfetchprojpacks
#   changed_high
#   changed_med
#   changed_low
#   changed_dirty
#   prps
#   channeldata
#   projpacks_linked
#   prpsearchpath
#   prpdeps
#   prpnoleaf
#   asyncmode
#   prpcheckuseforbuild

use strict;
use warnings;


our $usestorableforprojpack = 1;
our $testprojid;

use Build;	# for read_config
use Data::Dumper;

use BSUtil;
use BSSolv;	# for depsort
use Storable;
use BSConfiguration;
use BSSched::Remote;

=head2 checkbuildrepoid - TODO: add summary

 TODO: add description

=cut

sub checkbuildrepoid {
  my ($gctx, $projpacksin) = @_;
  die("ERROR: source server did not report a repoid") unless $projpacksin->{'repoid'};
  my $reporoot = $gctx->{'reporoot'};
  my $buildrepoid = readstr("$reporoot/_repoid", 1);
  if (!$buildrepoid) {
    # set the repoid on first run
    $buildrepoid = $projpacksin->{'repoid'};
    mkdir_p($reporoot) unless -d "$reporoot";
    writestr("$reporoot/._repoid$$", "$reporoot/_repoid", $buildrepoid);
  }
  die("ERROR: My repository id($buildrepoid) has wrong length(".length($buildrepoid).")") unless length($buildrepoid) == 9;
  die("ERROR: source server repository id($projpacksin->{'repoid'}) does not match my repository id($buildrepoid)") unless $buildrepoid eq $projpacksin->{'repoid'};
}

=head2 get_projpacks_all_sync -   get/update project/package information of all packages

 This is used as emergency fallback when we hit some problem.

=cut

sub get_projpacks_all_sync {
  my ($gctx) = @_;
  my $myarch = $gctx->{'arch'};
  my @args = ('withsrcmd5', 'withdeps', 'withrepos', 'withconfig', 'withremotemap', "arch=$myarch");
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
  my $projpacksin;
  while (1) {
    my $param = {
      'uri' => "$BSConfig::srcserver/getprojpack",
    };
    eval {
      if ($usestorableforprojpack) {
        $projpacksin = $gctx->{'rctx'}->xrpc($gctx, undef, $param, \&BSUtil::fromstorable, 'view=storable', @args);
      } else {
        $projpacksin = $gctx->{'rctx'}->xrpc($gctx, undef, $param, $BSXML::projpack, @args);
      }
    };
    last if !$@ && $projpacksin;
    print $@ if $@;
    printf("could not get project/package information, sleeping 1 minute\n");
    sleep(60);
    print "retrying...\n";
  }
  update_projpacks($gctx, $projpacksin);
  get_projpacks_postprocess($gctx);	# just in case
  return 1;
}

=head2 get_projpacks -   get/update project/package information

 input:  $projid: update just this project
         @packids: update just these packages
 output: $projpacks (global)

=cut

sub get_projpacks {
  my ($gctx, $doasync, $projid, @packids) = @_;

  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  undef $projid unless $projpacks;
  @packids = () unless defined $projid;
  @packids = grep {defined $_} @packids;

  $projid ||= $testprojid;

  my @args = ('withsrcmd5', 'withdeps', 'withrepos', 'withconfig', 'withremotemap', "arch=$myarch");
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
  if (!defined($projid)) {
    print "getting data for all projects from $BSConfig::srcserver\n";
  } elsif (!@packids) {
    print "getting data for project '$projid' from $BSConfig::srcserver\n";
    push @args, "project=$projid";
    push @args, 'nopackages' if $testprojid && $projid ne $testprojid;
  } else {
    print "getting data for project '$projid' package '".join("', '", @packids)."' from $BSConfig::srcserver\n";
    push @args, "project=$projid";
    for my $packid (@packids) {
      if ($packid =~ /(?<!^_product)(?<!^_patchinfo):./ && $packid =~ /^(.*):[^:]+$/) {
	push @args, "package=$1" unless grep {$_ eq "package=$1"} @args;
	next;
      }
      push @args, "package=$packid";
    }
  }

  my $projpacksin;
  for my $tries (4, 3, 2, 1, 0) {
    my $param = {
      'uri' => "$BSConfig::srcserver/getprojpack",
    };
    if ($doasync) {
      $param->{'async'} = { %$doasync, '_resume' => \&get_projpacks_resume, '_projid' => $projid, '_changeprp' => $projid };
      $param->{'async'}->{'_packids'} = [ @packids ] if @packids;
    }
    eval {
      if ($usestorableforprojpack) {
	$projpacksin = $gctx->{'rctx'}->xrpc($gctx, $projid, $param, \&BSUtil::fromstorable, 'view=storable', @args);
      } else {
	$projpacksin = $gctx->{'rctx'}->xrpc($gctx, $projid, $param, $BSXML::projpack, @args);
      }
    };
    return 0 if !$@ && $projpacksin && $param->{'async'};	# in progress
    last unless $@ || !$projpacksin;
    print $@ if $@;
    die("could not get project/package information, aborting due to testmode\n") if $gctx->{'testmode'};
    return get_projpacks_all_sync($gctx) unless $tries;		# do it the hard way
    print "retrying after 1 minute...\n";
    sleep(60);
  }
  update_projpacks($gctx, $projpacksin, $projid, \@packids);

  if ($testprojid) {
    my $proj = $projpacks->{$projid} || {};
    for my $repo (@{$proj->{'repository'} || []}) {
      for my $path (@{$repo->{'path'} || []}) {
	next if $path->{'project'} eq $testprojid;
	next if $projid ne $testprojid && $projpacks->{$path->{'project'}};
	get_projpacks($gctx, undef, $path->{'project'});
      }
    }
  }
  return 1;
}

=head2 get_projpacks_resume - async RPC bottom part of get_projpacks

 TODO: add description

=cut

sub get_projpacks_resume {
  my ($gctx, $handle, $error, $projpacksin) = @_;

  # what we asked about
  my $projid = $handle->{'_projid'};
  if ($error) {
    chomp $error;
    warn("$error\n");
    $gctx->{'retryevents'}->addretryevent({'type' => 'package', 'project' => $projid});
    return;
  }
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $wasremote = !$projpacks->{$projid} && $remoteprojs->{$projid} ? 1 : undef;
  my $packids = $handle->{'_packids'};  # we only requested those
  my $oldprojdata = $packids ? clone_projpacks_part($gctx, $projid, $packids) : undef;

  # check if there was a critical meta change
  if ($packids && !update_project_meta_check($gctx, $projid, $projpacksin)) {
    # had a critical change, we have to refetch *all* packages
    print "get_projpacks_resume: fetching all packages\n";
    my $async = {'_changetype' => 'med'};
    $async->{'_lpackids'} = $handle->{'_lpackids'} if $handle->{'_lpackids'};
    get_projpacks($gctx, $async, $projid);
  }

  if ($BSConfig::deep_check_dependent_projects_on_macro_change && !$packids) {
    my $oldproj = $projpacks->{$projid} || $remoteprojs->{$projid} || {};
    my $newproj = $projpacksin->{'project'}->[0];
    $newproj = undef if $newproj && $newproj->{'name'} ne $projid;
    $newproj ||= (grep {$_->{'project'} eq $projid} @{$projpacksin->{'remotemap'} || []})[0] || {};
    my %badprp;
    for my $oldrepo (@{$oldproj->{'repository'} || []}) {
      my $repoid = $oldrepo->{'name'};
      my $newrepo = (grep {$_->{'name'} eq $repoid} @{$oldproj->{'repository'} || []})[0];
      if (!$newrepo || !BSUtil::identical($oldrepo->{'path'}, $newrepo->{'path'})) {
	$badprp{"$projid/$repoid"} = 1;
	next;
      }
      if (($oldproj->{'config'} || '') ne ($newproj->{'config'} || '')) {
        my @mprefix = ("%define _project $projid", "%define _repository $repoid");
        my $cold = Build::read_config($gctx->{'arch'}, [ @mprefix, split("\n", $oldproj->{'config'} || '') ]);
        my $cnew = Build::read_config($gctx->{'arch'}, [ @mprefix, split("\n", $newproj->{'config'} || '') ]);
	$badprp{"$projid/$repoid"} = 1 if !BSUtil::identical($cold->{'macros'}, $cnew->{'macros'});
      }
    }
    if (%badprp) {
      print "had macro change for ".join(', ', sort keys %badprp)."\n";
      my %badprojids = ($projid => 1);
      my $delayedfetchprojpacks = $gctx->{'delayedfetchprojpacks'};
      my $changed_low = $gctx->{'changed_low'};
      my $changed_dirty = $gctx->{'changed_dirty'};
      for my $prp (sort keys %{$gctx->{'prpsearchpath'} || {}}) {
	next unless grep {$badprp{$_}} @{$gctx->{'prpsearchpath'}->{$prp}};
	my $badprojid = (split('/', $prp, 2))[0];
	next if $badprojids{$badprojid};
	next unless $projpacks->{$badprojid};
	# trigger a low fetch of all packages
        print "  triggered deep check of $badprojid\n";
	push @{$delayedfetchprojpacks->{$badprojid}}, '/all';
	$changed_low->{$prp} ||= 1;
	$changed_dirty->{$prp} = 1;
      }
    }
  }

  # commit the update
  update_projpacks($gctx, $projpacksin, $projid, $packids);
  get_projpacks_postprocess($gctx) if !$packids || postprocess_needed_check($gctx, $projid, $oldprojdata);

  # do some upgrades if the project is gone and we fetched all packages
  # (i.e. project event case as someone deleted a project)
  if (!$packids && !$projpacks->{$projid} && !($wasremote && $remoteprojs->{$projid})) {
    print "get_projpacks_resume: upgrading project event\n";
    $handle->{'_dolink'} ||= 2;
    $handle->{'_changetype'} = 'high';
  }
  delete $handle->{'_lpackids'} if $handle->{'_dolink'};        # just in case...
  if (!$handle->{'_dolink'} && !$packids && $handle->{'_lpackids'}) {
    # we had both a project event and changed source events.
    # the changes source packages are in _lpackids
    $handle->{'_dolink'} ||= 2;
  }

  # fetch linked packages with lower prio
  if ($handle->{'_dolink'}) {
    my $delayedfetchprojpacks = $gctx->{'delayedfetchprojpacks'};
    my $xpackids = $packids || $handle->{'_lpackids'};  # just packages linking to those
    my $linked = find_linked_sources($gctx, $projid, $xpackids);
    for my $lprojid (sort keys %$linked) {
      my %lpackids = map {$_ => 1} @{$linked->{$lprojid}};
      # delay package source changes if possible
      if ($handle->{'_dolink'} == 2 && $lprojid ne $projid && $delayedfetchprojpacks && %lpackids) {
        push @{$delayedfetchprojpacks->{$lprojid}}, sort keys %lpackids;
        # we don't use setchanged because it unshifts the prps onto lookat
        my $changed = $gctx->{$xpackids ? 'changed_med' : 'changed_low'};
        my $changed_dirty = $gctx->{'changed_dirty'};
        for my $prp (@{$gctx->{'prps'}}) {
          next unless (split('/', $prp, 2))[0] eq $lprojid;
          $changed->{$prp} ||= 1;
          $changed_dirty->{$prp} = 1;
        }
        next;
      }
      my $async = {'_changetype' => $xpackids ? 'med' : 'low'};
      get_projpacks($gctx, $async, $lprojid, sort keys %lpackids);
    }
  }

  # no need to call setchanged if this is a package source change event
  # and the project does not exist (i.e. lives on another partition)
  return if $packids && !$projpacks->{$projid};
  BSSched::Lookat::setchanged($gctx, $projid, $handle->{'_changetype'}, $handle->{'_changelevel'});
}

=head2 update_projpacks - incorporate all the new data from projpacksin into our projpacks data

 TODO: add description

=cut

# incorporate all the new data from projpacksin into our projpacks data
sub update_projpacks {
  my ($gctx, $projpacksin, $projid, $packids) = @_;

  checkbuildrepoid($gctx, $projpacksin);
  my $isgone;
  my $projpacks = $gctx->{'projpacks'};
  my $channeldata = $gctx->{'channeldata'};
  $gctx->{'projpacks'} = $projpacks = {} unless $projpacks;
  # free old data
  if (!defined($projid)) {
    $gctx->{'projpacks'} = $projpacks = {};
  } elsif (!($packids && @$packids)) {
    delete $projpacks->{$projid};
    $isgone = 1;
  } elsif ($projpacks->{$projid} && $projpacks->{$projid}->{'package'}) {
    my $packs =  $projpacks->{$projid}->{'package'};
    for my $packid (@$packids) {
      delete $packs->{$packid};
    }
    # we always send all multibuild packages in the reply, so delete them as well
    my %packids = map {$_ => 1} @$packids;
    for my $packid (grep {/(?<!^_product)(?<!^_patchinfo):./} keys %$packs) {
      next unless $packid =~ /^(.*):[^:]+$/;
      delete $packs->{$packid} if $packids{$1};
    }
  }
  # incorporate new channel data
  for my $cd (@{$projpacksin->{'channeldata'} || []}) {
    my ($md5, $channel) = ($cd->{'md5'}, $cd->{'channel'});
    next if $channeldata->{$md5};
    $channel->{'_md5'} = $md5;
    $channeldata->{$md5} = $channel;
  }
  for my $proj (@{$projpacksin->{'project'} || []}) {
    if ($packids && @$packids) {
      die("bad projpack answer\n") unless $proj->{'name'} eq $projid;
      if ($projpacks->{$projid}) {
        # do not delete the missingpackages flag if we just update single packages
        $proj->{'missingpackages'} = 1 if $projpacks->{$projid}->{'missingpackages'};
        # use all packages/configs from old projpacks
        my $opackage = $projpacks->{$projid}->{'package'} || {};
        for (keys %$opackage) {
          $opackage->{$_}->{'name'} = $_;
          push @{$proj->{'package'}}, $opackage->{$_};
        }
        if (!$proj->{'patternmd5'} && $projpacks->{$projid}->{'patternmd5'}) {
          $proj->{'patternmd5'} = $projpacks->{$projid}->{'patternmd5'} unless grep {$_ eq '_pattern'} @$packids;
        }
      }
    }
    undef $isgone if defined($projid) && $proj->{'name'} eq $projid;
    update_prpcheckuseforbuild($gctx, $proj->{'name'}, $proj);
    BSSched::DoD::update_doddata($gctx, $proj->{'name'}, $proj) if $BSConfig::enable_download_on_demand;
    $projpacks->{$proj->{'name'}} = $proj;
    delete $proj->{'name'};
    my $packages = {};
    for my $pack (@{$proj->{'package'} || []}) {
      $packages->{$pack->{'name'}} = $pack;
      delete $pack->{'name'};
      my $channelmd5 = delete($pack->{'channelmd5'});
      if ($channelmd5) {
        if ($channeldata->{$channelmd5}) {
          $pack->{'channel'} = $channeldata->{$channelmd5};
        } else {
          $pack->{'error'} = 'missing channeldata in projpack';
        }
      }
    }
    if (%$packages) {
      $proj->{'package'} = $packages;
    } else {
      delete $proj->{'package'};
    }
  }
  my $remoteprojs = $gctx->{'remoteprojs'};
  if (!defined($projid)) {
    %$remoteprojs = ();
  } elsif (!($packids && @$packids)) {
    update_prpcheckuseforbuild($gctx, $projid) if $isgone;
    # delete project from remoteprojs if it is not in the remotemap
    if (!grep {$_->{'project'} eq $projid} @{$projpacksin->{'remotemap'} || []}) {
      delete $remoteprojs->{$projid};
    }
  }
  BSSched::Remote::remotemap2remoteprojs($gctx, $projpacksin->{'remotemap'});
}

=head2 update_project_meta - TODO: add summary

 just update the meta information, do not touch package data unless
 the project was deleted

=cut

sub update_project_meta {
  my ($gctx, $doasync, $projid) = @_;
  print "updating meta for project '$projid' from $BSConfig::srcserver\n";

  my $myarch = $gctx->{'arch'};
  my $projpacksin;
  my $param = {
    'uri' => "$BSConfig::srcserver/getprojpack",
  };
  if ($doasync) {
    $param->{'async'} = { %$doasync, '_resume' => \&update_project_meta_resume, '_projid' => $projid, '_changeprp' => $projid };
  }
  my @args;
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
  push @args, "project=$projid";
  eval {
    # withsrcmd5 is needed for the patterns md5sum
    $projpacksin = $gctx->{'rctx'}->xrpc($gctx, $projid, $param, $BSXML::projpack, 'nopackages', 'withrepos', 'withconfig', 'withsrcmd5', "arch=$myarch", @args);
  };
  if ($@ || !$projpacksin) {
    print $@ if $@;
    return undef;
  }
  return $projpacksin if $projpacksin && $param->{'async'};
  # check if this is a "critical change"
  return 0 unless update_project_meta_check($gctx, $projid, $projpacksin);
  # change is not critical, commit
  update_projpacks_meta($gctx, $projpacksin, $projid);
  return 1;
}

=head2 update_project_meta_check - TODO: add summary

 check if the project meta update changes things so that we need
 to re-fetch all packages

=cut

sub update_project_meta_check {
  my ($gctx, $projid, $projpacksin) = @_;
  return 0 unless $projpacksin;
  my $proj = $projpacksin->{'project'}->[0];
  return 1 unless $proj;        # project is gone?
  return 0 unless $proj->{'name'} eq $projid;   # huh?
  my $projpacks = $gctx->{'projpacks'};
  my $oldproj = $projpacks->{$projid};
  # check if the project meta has critical change
  return 0 unless BSUtil::identical($proj->{'build'}, $oldproj->{'build'});
  return 0 unless BSUtil::identical($proj->{'lock'}, $oldproj->{'lock'});
  return 0 unless BSUtil::identical($proj->{'link'}, $oldproj->{'link'});
  # XXX: could be more clever here
  return 0 unless BSUtil::identical($proj->{'repository'}, $oldproj->{'repository'});
  if (($proj->{'config'} || '') ne ($oldproj->{'config'} || '')) {
    # check macro definitions and build type for all repositories
    my $myarch = $gctx->{'arch'};
    for my $repoid (map {$_->{'name'}} @{$proj->{'repository'} || []}) {
      my @mprefix = ("%define _project $projid", "%define _repository $repoid");
      my $cold = Build::read_config($myarch, [ @mprefix, split("\n", $oldproj->{'config'} || '') ]);
      my $cnew = Build::read_config($myarch, [ @mprefix, split("\n", $proj->{'config'} || '') ]);
      return 0 unless BSUtil::identical($cold->{'macros'}, $cnew->{'macros'});
      return 0 unless BSUtil::identical($cold->{'type'}, $cnew->{'type'});
    }
  }
  # not a critical change
  return 1;
}

=head2 update_project_meta_resume - RPC bottom half of update_project_meta

 TODO: add description

=cut
sub update_project_meta_resume {
  my ($gctx, $handle, $error, $projpacksin) = @_;

  my $projid = $handle->{'_projid'};
  if ($error || !update_project_meta_check($gctx, $projid, $projpacksin)) {
    if ($error) {
      chomp $error;
      warn("$error\n");
    }
    # update meta failed or critical meta change, do it the hard way...
    # XXX: maybe set _dolink = 2?
    my $async = {'_changetype' => $handle->{'_changetype'}, '_changelevel' => $handle->{'_changelevel'}};
    $async->{'_lpackids'} = $handle->{'_lpackids'} if $handle->{'_lpackids'};
    get_projpacks($gctx, $async, $projid);
    return;
  }

  # commit the meta update
  update_projpacks_meta($gctx, $projpacksin, $projid);

  my $projpacks = $gctx->{'projpacks'};
  if ($projpacks->{$projid}) {
    my $packids = $handle->{'_lpackids'};
    if ($packids && @$packids) {
      # now get those packages as well
      my $async = {'_dolink' => 2, '_changetype' => 'high', '_changelevel' => 1};
      get_projpacks($gctx, $async, $projid, @$packids);
    } else {
      BSSched::Lookat::setchanged($gctx, $projid, $handle->{'_changetype'}, $handle->{'_changelevel'});
    }
  } else {
    # project is gone!
    delete $handle->{'_lpackids'};
    get_projpacks_resume($gctx, $handle, $error, $projpacksin);
  }
}


=head2 update_projpacks_meta - like update_projpacks, but leaves the packages untouched

 TODO: add description

=cut

sub update_projpacks_meta {
  my ($gctx, $projpacksin, $projid) = @_;
  my $proj = $projpacksin->{'project'}->[0];
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  if (!$proj) {
    delete $projpacks->{$projid};
    update_prpcheckuseforbuild($gctx, $projid);
  } else {
    delete $proj->{'name'};
    delete $proj->{'package'};
    my $oldproj = $projpacks->{$projid};
    $proj->{'package'} = $oldproj->{'package'} if $oldproj->{'package'};
    $projpacks->{$projid} = $proj;
    update_prpcheckuseforbuild($gctx, $projid, $proj);
  }
  # delete project from remoteprojs if it is not in the remotemap
  if (!grep {$_->{'project'} eq $projid} @{$projpacksin->{'remotemap'} || []}) {
    delete $remoteprojs->{$projid};
  }
  BSSched::Remote::remotemap2remoteprojs($gctx, $projpacksin->{'remotemap'});
}

=head2 clone_projpacks_part - TODO: add summary

 used to remember old data before calling update_projpacks so that
 postprocess_needed_check has something to compare against.

=cut

sub clone_projpacks_part {
  my ($gctx, $projid, $packids) = @_;

  my $projpacks = $gctx->{'projpacks'};
  return undef unless $projpacks->{$projid};
  my $oldprojdata = { %{$projpacks->{$projid} || {}} };
  delete $oldprojdata->{'package'};
  $oldprojdata = Storable::dclone($oldprojdata);
  my $oldpackdata = {};
  my $packs = ($projpacks->{$projid} || {})->{'package'} || {};
  my %packids = map {$_ => 1} @$packids;
  for my $packid (@$packids) {
    $oldpackdata->{$packid} = $packs->{$packid} ? Storable::dclone($packs->{$packid}) : undef;
  }
  # clone multibuild packages as well
  for my $packid (grep {/(?<!^_product)(?<!^_patchinfo):./} keys %$packs) {
    next unless $packid =~ /^(.*):[^:]+$/;
    $oldpackdata->{$packid} = $packs->{$packid} ? Storable::dclone($packs->{$packid}) : undef if $packids{$1};
  }
  $oldprojdata->{'package'} = $oldpackdata;
  return $oldprojdata;
}

=head2 postprocess_needed_check - check if some critical part of a project changed

 TODO: add description

=cut
sub postprocess_needed_check {
  my ($gctx, $projid, $oldprojdata) = @_;

  return 1 if $gctx->{'get_projpacks_postprocess_needed'};
  my $projpacks = $gctx->{'projpacks'};
  return 0 if !defined($oldprojdata) && !$projpacks->{$projid};
  return 1 unless $oldprojdata && $oldprojdata->{'package'};            # sanity
  # if we just had a srcmd5 change in some packages there's no need to postprocess
  if (!BSUtil::identical($projpacks->{$projid}, $oldprojdata, {'package' => 1})) {
    return 1;
  }
  my $packs = ($projpacks->{$projid} || {})->{'package'} || {};
  my %except = map {$_ => 1} qw{rev srcmd5 versrel verifymd5 revtime dep prereq file name error build publish useforbuild};
  my $oldpackdata = $oldprojdata->{'package'};
  for my $packid (keys %$oldpackdata) {
    if (!BSUtil::identical($oldpackdata->{$packid}, $packs->{$packid}, \%except)) {
      return 1;
    }
  }
  # check if we had all multibuild packages before
  for my $packid (grep {/(?<!^_product)(?<!^_patchinfo):./} keys %$packs) {
    next unless $packid =~ /^(.*):[^:]+$/;
    return 1 if $oldpackdata->{$1} && !$oldpackdata->{$packid};
  }
  return 0;
}

=head2 get_projpacks_postprocess - post-process projpack information

  calculate package link information
  calculate ordered prp list
  calculate remote info

=cut

sub get_projpacks_postprocess {
  my ($gctx) = @_;

  delete $gctx->{'get_projpacks_postprocess_needed'};
  BSSched::Remote::beginwatchcollection($gctx);

  #print Dumper($projpacks);
  calc_projpacks_linked($gctx); # modifies watchremote/needremoteproj
  calc_prps($gctx);             # modifies watchremote/needremoteproj

  BSSched::Remote::endwatchcollection($gctx);
}

=head2 calc_projpacks_linked  - generate projpacks_linked helper hash

 TODO: add description

=cut

sub calc_projpacks_linked {
  my ($gctx) = @_;
  delete $gctx->{'projpacks_linked'};
  my %projpacks_linked;
  my $projpacks = $gctx->{'projpacks'};
  my %watched;
  for my $projid (sort keys %$projpacks) {
    my $proj = $projpacks->{$projid};
    my ($mypackid, $pack);
    while (($mypackid, $pack) = each %{$proj->{'package'} || {}}) {
      next unless $pack->{'linked'};
      for my $lil (@{$pack->{'linked'}}) {
	my $li = { %$lil };         # clone so that we don't change projpack
	my $lprojid = delete $li->{'project'};
	if (!$watched{"$lprojid/$li->{'package'}"}) {
	  BSSched::Remote::addwatchremote($gctx, 'package', $lprojid, "/$li->{'package'}");
	  $watched{"$lprojid/$li->{'package'}"} = 1;
	}
	$li->{'myproject'} = $projid;
	$li->{'mypackage'} = $mypackid;
	push @{$projpacks_linked{$lprojid}}, $li;
      }
    }
    if ($proj->{'link'}) {
      for my $li (expandprojlink($gctx, $projid)) {
	my $lprojid = delete $li->{'project'};
	if (!$watched{$lprojid}) {
	  BSSched::Remote::addwatchremote($gctx, 'package', $lprojid, '');        # watch all packages
	  $watched{$lprojid} = 1;
	}
	$li->{'package'} = ':*';
	$li->{'myproject'} = $projid;
	push @{$projpacks_linked{$lprojid}}, $li;
      }
    }
  }
  $gctx->{'projpacks_linked'} = \%projpacks_linked;
  #print Dumper(\%projpacks_linked);
}

=head2 find_linked_sources - find which projects/packages link to the specified project/packages

 output: hash ref project -> package list

=cut

sub find_linked_sources {
  my ($gctx, $projid, $packids) = @_;
  my $projlinked = $gctx->{'projpacks_linked'}->{$projid};
  return {} unless $projlinked;
  my %linked;
  if ($packids) {
    my %packids = map {$_ => 1} @$packids;
    my @packids = sort(keys %packids);
    $packids{':*'} = 1;
    for my $linfo (grep {$packids{$_->{'package'}}} @$projlinked) {
      if (defined($linfo->{'mypackage'})) {
        push @{$linked{$linfo->{'myproject'}}}, $linfo->{'mypackage'};
      } else {
        push @{$linked{$linfo->{'myproject'}}}, @packids;
      }
    }
  } else {
    for my $linfo (@$projlinked) {
      next unless exists $linfo->{'mypackage'};
      push @{$linked{$linfo->{'myproject'}}}, $linfo->{'mypackage'};
    }
  }
  return \%linked;
}

=head2 expandsearchpath  - recursively expand the last component of a repository's path

 input:  $projid     - the project the repository belongs to

         $repository - the repository data

 output: expanded path array

=cut

sub expandsearchpath {
  my ($gctx, $projid, $repository) = @_;

  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  my %done;
  my @ret;
  my @path = @{$repository->{'path'} || []};
  # our own repository is not included in the path,
  # so put it infront of everything
  unshift @path, {'project' => $projid, 'repository' => $repository->{'name'}};
  while (@path) {
    my $t = shift @path;
    my $prp = "$t->{'project'}/$t->{'repository'}";
    push @ret, $t unless $done{$prp};
    $done{$prp} = 1;
    BSSched::Remote::addwatchremote($gctx, 'repository', $t->{'project'}, "/$t->{'repository'}/$myarch") unless $t->{'repository'} eq '_unavailable';
    if (!@path) {
      last if $done{"/$prp"};
      my ($pid, $rid) = ($t->{'project'}, $t->{'repository'});
      my $proj = BSSched::Remote::addwatchremote($gctx, 'project', $pid, '');
      if ($proj) {
        $proj = BSSched::Remote::fetchremoteproj($gctx, $proj, $pid);
      } else {
        $proj = $projpacks->{$pid};
      }
      next unless $proj;
      $done{"/$prp"} = 1;       # mark expanded
      my @repo = grep {$_->{'name'} eq $rid} @{$proj->{'repository'} || []};
      push @path, @{$repo[0]->{'path'}} if @repo && $repo[0]->{'path'};
    }
  }
  return @ret;
}

=head2 expandprojlink - TODO: add summary

 TODO: add description

=cut

sub expandprojlink {
  my ($gctx, $projid) = @_;

  my $projpacks = $gctx->{'projpacks'};
  my @ret;
  my $proj = $projpacks->{$projid};
  my @todo = map {$_->{'project'}} @{$proj->{'link'} || []};
  my %seen = ($projid => 1);
  while (@todo) {
    my $lprojid = shift @todo;
    next if $seen{$lprojid};
    push @ret, {'project' => $lprojid};
    $seen{$lprojid} = 1;
    my $lproj = BSSched::Remote::addwatchremote($gctx, 'project', $lprojid, '');
    if ($lproj) {
      $lproj = BSSched::Remote::fetchremoteproj($gctx, $lproj, $lprojid);
    } else {
      $lproj = $projpacks->{$lprojid};
    }
    unshift @todo, map {$_->{'project'}} @{$lproj->{'link'} || []};
  }
  return @ret;
}

=head2 calc_prps - TODO

 find all prps we have to schedule, expand search path for every prp,
 set up inter-prp dependency graph, sort prps using this graph.

 also gets rid of no longer used channeldata

 input:  $projpacks     (global)

 output: @prps          (global)
         %prpsearchpath (global)
         %prpdeps       (global)
         %prpnoleaf     (global)

=cut

sub calc_prps {
  my ($gctx) = @_;

  print "calculating project dependencies...\n";
  my $myarch = $gctx->{'arch'};
  # calculate prpdeps dependency hash
  delete $gctx->{'prps'};
  delete $gctx->{'prpsearchpath'};
  delete $gctx->{'prpdeps'};
  delete $gctx->{'prpnoleaf'};
  my @prps;
  my %prpsearchpath;
  my %prpdeps;
  my %prpnoleaf;
  my %haveinterrepodep;

  my %newchanneldata;
  my $projpacks = $gctx->{'projpacks'};
  for my $projid (sort keys %$projpacks) {
    my $proj = $projpacks->{$projid};
    my $repos = $proj->{'repository'} || [];
    my @myrepos;        # repos which include my arch
    for my $repo (@$repos) {
      push @myrepos, $repo if grep {$_ eq $myarch} @{$repo->{'arch'} || []};
    }
    next unless @myrepos;       # not for us
    my @pdatas = values(%{$proj->{'package'} || {}});
    my @aggs = grep {$_->{'aggregatelist'}} @pdatas;
    my @channels = grep {$_->{'channel'}} @pdatas;
    my @kiwiinfos = grep {$_->{'path'} || $_->{'containerpath'}} map {@{$_->{'info'} || []}} @pdatas;
    @pdatas = ();               # free mem
    my %channelrepos;
    for my $channel (map {$_->{'channel'}} @channels) {
      $newchanneldata{$channel->{'_md5'} || ''} ||= $channel;
      next unless $channel->{'target'};
      # calculate list targeted tepos
      my %targets;
      for my $rt (@{$channel->{'target'}}) {
	if ($rt->{'project'}) {
	  if ($rt->{'repository'}) {
	    $targets{"$rt->{'project'}/$rt->{'repository'}"} = 1;
	  } else {
	    $targets{$rt->{'project'}} = 1;
	  }
	} elsif ($rt->{'repository'}) {
	  $targets{"$projid/$rt->{'repository'}"} = 1;
	}
      }
      for my $repo (@myrepos) {
	for my $rt (@{$repo->{'releasetarget'} || []}) {
	  $channelrepos{$repo->{'name'}} = 1 if $targets{$rt->{'project'}} || $targets{"$rt->{'project'}/$rt->{'repository'}"};
	}
	$channelrepos{$repo->{'name'}} = 1 if $targets{"$projid/$repo->{'name'}"};
      }
    }
    my %myprps;
    for my $repo (@myrepos) {
      my $repoid = $repo->{'name'};
      my $prp = "$projid/$repoid";
      $myprps{$prp} = 1;
      push @prps, $prp;
      my @searchpath = expandsearchpath($gctx, $projid, $repo);
      # map searchpath to internal prp representation
      my @sp = map {"$_->{'project'}/$_->{'repository'}"} @searchpath;
      $prpsearchpath{$prp} = \@sp;
      $prpdeps{$prp} = \@sp;

      # Find extra dependencies due to aggregate/kiwi description files
      my @xsp;
      if (@aggs) {
	# push source repositories used in this aggregate onto xsp, obey target mapping
	for my $agg (map {@{$_->{'aggregatelist'}->{'aggregate'} || []}} @aggs) {
	  my $aprojid = $agg->{'project'};
	  my @arepoids = grep {!exists($_->{'target'}) || $_->{'target'} eq $repoid} @{$agg->{'repository'} || []};
	  if (@arepoids) {
	    # got some mappings for our target, use source as repoid
	    push @xsp, map {"$aprojid/$_->{'source'}"} grep {exists($_->{'source'})} @arepoids;
	  } else {
	    # no repository mapping, just use own repoid
	    push @xsp, "$aprojid/$repoid";
	  }
	}
      }
      if (@kiwiinfos) {
	# push repositories used in all kiwi files
	for my $info (grep {$_->{'repository'} eq $repoid} @kiwiinfos) {
	  push @xsp, map {"$_->{'project'}/$_->{'repository'}"} grep {$_->{'project'} ne '_obsrepositories'} @{$info->{'path'} || []};
	  push @xsp, map {"$_->{'project'}/$_->{'repository'}"} grep {$_->{'project'} ne '_obsrepositories'} @{$info->{'containerpath'} || []};
        }
      }
      if ($channelrepos{$repoid}) {
	# let a channel repo target all non-channel repos
	my @ncrepos = grep {!$channelrepos{$_}} map {$_->{'name'}} @$repos;
	push @xsp, map {"$projid/$_"} @ncrepos;
      }

      if (@xsp) {
	# found some repos, join extra deps with project deps
	for my $xsp (@xsp) {
	  next if $xsp eq $prp;
	  my ($aprojid, $arepoid) = split('/', $xsp, 2);
	  # we just watch the repository as it costs too much to
	  # watch every single package
	  BSSched::Remote::addwatchremote($gctx, 'repository', $aprojid, "/$arepoid/$myarch");
	}
	my %xsp = map {$_ => 1} (@sp, @xsp);
	delete $xsp{$prp};
	$prpdeps{$prp} = [ sort keys %xsp ];
      }
      # set noleaf info
      for (@{$prpdeps{$prp}}) {
	$prpnoleaf{$_} = 1 if $_ ne $prp;
      }
    }
    # check for inter-repository project dependencies
    for my $prp (keys %myprps) {
      $haveinterrepodep{$projid} = 1 if grep {$myprps{$_} && $_ ne $prp} @{$prpdeps{$prp}};
    }
  }
  # good bye no longer used entries!
  delete $newchanneldata{''};
  %{$gctx->{'channeldata'}} = %newchanneldata;

  # print statistics
  print "have ".scalar(keys %newchanneldata)." unique channel configs\n" if %newchanneldata;
  print "have ".scalar(keys %haveinterrepodep)." inter-repo dependencies\n" if %haveinterrepodep;

  # do the real sorting
  print "sorting projects and repositories...\n";
  if (@prps >= 2) {
    my @cycs;
    @prps = BSSolv::depsort(\%prpdeps, undef, \@cycs, @prps);
    print "cycle: ".join(' -> ', @$_)."\n" for @cycs;
  }

  # create reverse deps to speed up changed2lookat
  my %rprpdeps;
  for my $prp (keys %prpdeps) {
    push @{$rprpdeps{$_}}, $prp for @{$prpdeps{$prp}};
  }
  # free some mem
  for my $prp (keys %rprpdeps) {
    delete $rprpdeps{$prp} if @{$rprpdeps{$prp}} == 1 && $rprpdeps{$prp}->[0] eq $prp;
  }

  $gctx->{'prps'} = \@prps;
  $gctx->{'prpsearchpath'} = \%prpsearchpath;
  $gctx->{'prpdeps'} = \%prpdeps;
  $gctx->{'rprpdeps'} = \%rprpdeps;
  $gctx->{'prpnoleaf'} = \%prpnoleaf;
  $gctx->{'haveinterrepodep'} = \%haveinterrepodep;
}

=head2 do_delayedprojpackfetches - TODO

 Do all the delayed projpack fetches caused by source changes

 See do_fetchprojpacks

 Returns 0 if an async fetch is in progress.

=cut

sub do_delayedprojpackfetches {
  my ($gctx, $doasync, $projid, @packids) = @_;
  my %packids = map {$_ => 1} @packids;
  if ($packids{'/all'}) {
    if ($doasync) {
      get_projpacks($gctx, $doasync, $projid);
      return 0;		# in progress
    }
    get_projpacks($gctx, undef, $projid);
    get_projpacks_postprocess($gctx);
  } elsif (%packids) {
    @packids = sort keys %packids;
    if ($doasync) {
      get_projpacks($gctx, $doasync, $projid, @packids);
      return 0;		# in progress
    }
    my $oldprojdata = clone_projpacks_part($gctx, $projid, \@packids);
    get_projpacks($gctx, undef, $projid, @packids);
    get_projpacks_postprocess($gctx) if BSSched::ProjPacks::postprocess_needed_check($gctx, $projid, $oldprojdata);
  }
  return 1;		# all done
}

=head2 do_fetchprojpacks - TODO

Do all the cummulated projpacks fetching. Done after all events are processed.

=cut

sub do_fetchprojpacks {
  my ($gctx, $fetchprojpacks, $fetchprojpacks_nodelay, $deepcheck, $lowprioproject) = @_;

  my $asyncmode = $gctx->{'asyncmode'};
  my $delayedfetchprojpacks = $gctx->{'delayedfetchprojpacks'};
  my $projpacks = $gctx->{'projpacks'};

  my $changed_low = $gctx->{'changed_low'};
  my $changed_med = $gctx->{'changed_med'};
  my $changed_high = $gctx->{'changed_high'};
  my $changed_dirty = $gctx->{'changed_dirty'};

  return unless %$fetchprojpacks;

  #pass0: delay them if possible
  for my $projid (sort keys %$fetchprojpacks) {
    next if $fetchprojpacks_nodelay->{$projid};
    next if grep {!defined($_) || $_ eq '/all'} @{$fetchprojpacks->{$projid}};
    # only source updates, delay them
    my $foundit;
    for my $prp (@{$gctx->{'prps'}}) {
      if ((split('/', $prp, 2))[0] eq $projid) {
	$changed_high->{$prp} ||= 1;
	$changed_dirty->{$prp} = 1;
	$foundit = 1;
      }
    }
    # don't delay if a getprojpack is in progress (which may create the project)
    next if !$foundit && $gctx->{'rctx'}->xrpc_busy($projid);
    push @{$delayedfetchprojpacks->{$projid}}, @{$fetchprojpacks->{$projid}};
    my $linked = find_linked_sources($gctx, $projid, $fetchprojpacks->{$projid});
    if (%$linked) {
      for my $lprojid (keys %$linked) {
	push @{$delayedfetchprojpacks->{$lprojid}}, @{$linked->{$lprojid}};
      }
      for my $lprp (@{$gctx->{'prps'}}) {
	if ($linked->{(split('/', $lprp, 2))[0]}) {
	  $changed_med->{$lprp} ||= 1;
	  $changed_dirty->{$lprp} = 1;
	}
      }
    }
    delete $fetchprojpacks->{$projid};
    # if we never look at the project
    delete $delayedfetchprojpacks->{$projid} unless $foundit;
  }
  return unless %$fetchprojpacks;

  # pass1: fetch all projpacks
  for my $projid (sort keys %$fetchprojpacks) {
    my $fetchedall;
    if (grep {!defined($_) || $_ eq '/all'} @{$fetchprojpacks->{$projid}}) {
      # project change, this can be
      # a change in _meta
      # a change in _config
      # a change in _pattern
      # deletion of a project
      my %packids = map {$_ => 1} grep {defined($_)} @{$fetchprojpacks->{$projid}};
      my $all = delete $packids{'/all'};
      if ($asyncmode) {
        my $async = { '_changetype' => 'high', '_changelevel' => 2 };
        $async->{'_changetype'} = 'low' if $lowprioproject->{$projid} && !$deepcheck->{$projid};
        $async->{'_lpackids'} = [ sort keys %packids ] if %packids;
        $async->{'_dolink'} = 1 if $deepcheck->{$projid};
	if ($projpacks->{$projid} && !$deepcheck->{$projid} && !$all) {
	  update_project_meta($gctx, $async, $projid);
	} else {
	  get_projpacks($gctx, $async, $projid);
	}
	delete $fetchprojpacks->{$projid};	# backgrounded
	next;
      }
      if ($projpacks->{$projid} && !$deepcheck->{$projid} && !$all) {
	if (!update_project_meta($gctx, 0, $projid)) {
	  # update meta failed or critical change, do it the hard way...
	  get_projpacks($gctx, undef, $projid);
	  $fetchedall = 1;
	}
      } else {
	get_projpacks($gctx, undef, $projid);
	$fetchedall = 1;
      }
    }
    if (!$fetchedall) {
      # single package (source) changes
      my %packids = map {$_ => 1} grep {defined($_)} @{$fetchprojpacks->{$projid}};
      next unless %packids;
      # remove em from the delay queue
      if ($delayedfetchprojpacks->{$projid}) {
	$delayedfetchprojpacks->{$projid} = [ grep {!$packids{$_}} @{$delayedfetchprojpacks->{$projid} || []} ];
	delete $delayedfetchprojpacks->{$projid} unless @{$delayedfetchprojpacks->{$projid}};
      }
      if ($asyncmode) {
	# _dolink = 2: try to delay linked packages fetches
	my $async = { '_dolink' => 2, '_changetype' => 'high', '_changelevel' => 1 };
	get_projpacks($gctx, $async, $projid, sort keys %packids);
	delete $fetchprojpacks->{$projid};	# backgrounded
	next;
      }
      get_projpacks($gctx, undef, $projid, sort keys %packids);
    } else {
      delete $delayedfetchprojpacks->{$projid};
    }
  }

  return unless %$fetchprojpacks;	# still something on the list?

  get_projpacks_postprocess($gctx);

  # pass2: postprocess, set changed_high, calculate link info
  my %fetchlinkedprojpacks;
  my %fetchlinkedprojpacks_srcchange;
  for my $projid (sort keys %$fetchprojpacks) {
    my $changed = $lowprioproject->{$projid} && $projpacks->{$projid} && !$deepcheck->{$projid} ? $changed_low : $changed_high;
    if (grep {!defined($_)} @{$fetchprojpacks->{$projid}}) {
      for my $prp (@{$gctx->{'prps'}}) {
	if ((split('/', $prp, 2))[0] eq $projid) {
	  $changed->{$prp} = 2;
	  $changed_dirty->{$prp} = 1;
	}
      }
      $changed_high->{$projid} = 2;	# $changed only works for prps
      # more work if the project was deleted
      # (if it's just a config change we really do not care about source links)
      if (!$projpacks->{$projid} || $deepcheck->{$projid}) {
	my $linked = find_linked_sources($gctx, $projid, undef);
	push @{$fetchlinkedprojpacks{$_}}, @{$linked->{$_}} for keys %$linked;
      }
    } else {
      for my $prp (@{$gctx->{'prps'}}) {
	if ((split('/', $prp, 2))[0] eq $projid) {
	  $changed_high->{$prp} ||= 1;
	  $changed_dirty->{$prp} = 1;
	}
      }
      $changed_high->{$projid} ||= 1;
    }
    my @packids = grep {defined($_)} @{$fetchprojpacks->{$projid}};
    my $linked = find_linked_sources($gctx, $projid, \@packids);
    for my $lprojid (keys %$linked) {
      push @{$fetchlinkedprojpacks{$lprojid}}, @{$linked->{$lprojid}};
      $fetchlinkedprojpacks_srcchange{$lprojid} = 1;	# mark as source changes
    }
  }

  # pass3: update link information
  if (%fetchlinkedprojpacks) {
    my $projpackchanged;
    for my $projid (sort keys %fetchlinkedprojpacks) {
      my %packids = map {$_ => 1} @{$fetchlinkedprojpacks{$projid}};
      if ($asyncmode) {
	my $async = { '_changelevel' => 1, '_changetype' => 'low' };
	$async->{'_changetype'} = 'med' if $fetchlinkedprojpacks_srcchange{$projid};
	get_projpacks($gctx, $async, $projid, sort keys %packids);
	next;
      }
      get_projpacks($gctx, undef, $projid, sort keys %packids);
      $projpackchanged = 1;
      # we assign source changed through links med prio,
      # everything else is low prio
      if ($fetchlinkedprojpacks_srcchange{$projid}) {
	for my $prp (@{$gctx->{'prps'}}) {
	  if ((split('/', $prp, 2))[0] eq $projid) {
	    $changed_med->{$prp} ||= 1;
	    $changed_dirty->{$prp} = 1;
	  }
	}
	$changed_med->{$projid} ||= 1;
      } else {
	for my $prp (@{$gctx->{'prps'}}) {
	  if ((split('/', $prp, 2))[0] eq $projid) {
	    $changed_low->{$prp} ||= 1;
	    $changed_dirty->{$prp} = 1;
	  }
	}
	$changed_low->{$projid} ||= 1;
      }
    }
    get_projpacks_postprocess($gctx) if $projpackchanged;	# just in case...
  }

  %$fetchprojpacks = ();		# all done
}


=head2 getconfig - concatenate and fixup the build config

 this is basically getconfig from the source server

 we do not need any macros, just the config

=cut

sub getconfig {
  my ($gctx, $projid, $repoid, $arch, $path) = @_;
  my $extraconfig = '';
  my $config = "%define _project $projid\n";
  if ($BSConfig::extraconfig) {
    for (sort keys %{$BSConfig::extraconfig}) {
      $extraconfig .= $BSConfig::extraconfig->{$_} if $projid =~ /$_/;
    }
  }
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  for my $prp (reverse @$path) {
    my ($p, $r) = split('/', $prp, 2);
    my $c;
    my $rproj = $remoteprojs->{$p};
    if ($rproj) {
      return undef if $rproj->{'error'};
      if (exists($rproj->{'config'})) {
        $c = $rproj->{'config'};
      } elsif ($rproj->{'partition'}) {
        $c = '';
      } else {
        $c = BSSched::Remote::fetchremoteconfig($gctx, $p);
        return undef unless defined $c;
      }
    } elsif ($projpacks->{$p}) {
      $c = $projpacks->{$p}->{'config'};
    }
    next unless defined $c;
    $config .= "\n### from $p\n";
    $config .= "%define _repository $r\n";
    # get rid of the Macros sections
    my $s1 = '^\s*macros:\s*$.*?^\s*:macros\s*$';
    my $s2 = '^\s*macros:\s*$.*\Z';
    $c =~ s/$s1//gmsi;
    $c =~ s/$s2//gmsi;
    $config .= $c;
  }
  # it's an error if we have no config at all
  return undef unless $config ne '';
  # now we got the combined config, parse it
  $config .= "\n$extraconfig" if $extraconfig;
  my @c = split("\n", $config);
  my $c = Build::read_config($arch, \@c);
  $c->{'repotype'} = [ 'rpm-md' ] unless @{$c->{'repotype'}};
  $c->{'binarytype'} ||= 'UNDEFINED';
  return $c;
}


=head2 orderpackids - sort package containers

 we simply sort by container name, except that _volatile
 goes to the back and maintenance issues are ordered by
 just their incident number.

=cut

sub orderpackids {
  my ($proj, @packids) = @_;
  $proj ||= {};
  my @s;
  my @back;
  my $kind = $proj->{'kind'} || '';
  for (@packids) {
    if ($_ eq '_volatile') {
      push @back, $_;
    } elsif (/^(.*)\.(\d+)$/) {
      # we ignore the name for maintenance release projects and sort only
      # by the incident number
      if ($kind eq 'maintenance_release') {
        push @s, [ $_, '', $2];
      } else {
        push @s, [ $_, $1, $2];
      }
    } elsif (/^(.*)\.imported_.*?(\d+)$/) {
      # code11 import hack...
      if ($kind eq 'maintenance_release') {
        push @s, [ $_, '', $2 - 1000000];
      } else {
        push @s, [ $_, $1, $2 - 1000000];
      }
    } else {
      push @s, [ $_, $_, 99999999 ];
    }
  }
  @packids = map {$_->[0]} sort { $a->[1] cmp $b->[1] || $b->[2] <=> $a->[2] || $a->[0] cmp $b->[0] } @s;
  push @packids, @back;
  return @packids;
}

=head2 update_prpcheckuseforbuild - update the prpcheckuseforbuild hash if a project is changed

 input: $projid - project name
        $proj   - project data, can be undef if deleted

=cut

sub update_prpcheckuseforbuild {
  my ($gctx, $projid, $proj) = @_;
  my $myarch = $gctx->{'arch'};
  my $prpcheckuseforbuild = $gctx->{'prpcheckuseforbuild'};
  if (!$proj) {
    for my $prp (keys %$prpcheckuseforbuild) {
      delete $prpcheckuseforbuild->{$prp} if (split('/', $prp, 2))[0] eq $projid;
    }
  } else {
    for my $repo (@{$proj->{'repository'}}) {
      next unless grep {$_ eq $myarch} @{$repo->{'arch'} || []};
      $prpcheckuseforbuild->{"$projid/$repo->{'name'}"} = 1;
    }
  }
}

=head2 runningfetchprojpacks - get running projpack requests

 we return them in do_fetchprojpacks format

=cut

sub runningfetchprojpacks {
  my ($gctx) = @_;
  my %running;

  for my $handle ($gctx->{'rctx'}->xrpc_handles()) {
    my $projid = $handle->{'_iswaiting'};
    next if $projid =~ /\//;
    my %packids;
    my $good;
    my $meta;
    my $all;
    for my $async ($handle, map {$_->{'async'}} $gctx->{'rctx'}->xrpc_nextparams($handle)) {
      next if !$async || ($async->{'_projid'} || '') ne $projid;
      $good = 1;
      if ($async->{'_packids'}) {
        $packids{$_} = 1 for @{$async->{'_packids'}};
      } else {
        $packids{$_} = 1 for @{$async->{'_lpackids'} || []};
	$all = 1 if $async->{'_resume'} == \&get_projpacks_resume;
        $meta = 1;
      }   
    }   
    next unless $good;
    my @packids = sort keys %packids;
    push @packids, '/all' if $all;
    push @packids, undef if $meta || !@packids;
    push @{$running{$projid}}, @packids;
  }
  return \%running;
}

sub get_remoteproject_resume {
  my ($gctx, $handle, $error, $projpacksin) = @_;
  my $projid = $handle->{'_projid'};
  delete $gctx->{'remotemissing'}->{$projid};
  if ($error) {
    chomp $error;
    warn("$error\n");
    return;
  }
  BSSched::Remote::remotemap2remoteprojs($gctx, $projpacksin->{'remotemap'});
  $gctx->{'remotemissing'}->{$projid} = 1 if !$gctx->{'projpacks'}->{$projid} && !$gctx->{'remoteprojs'}->{$projid};
  BSSched::Lookat::setchanged($gctx, $handle->{'_changeprp'}, $handle->{'_changetype'}, $handle->{'_changelevel'});
}

sub get_remoteproject {
  my ($gctx, $doasync, $projid) = @_;

  my $myarch = $gctx->{'arch'};
  print "getting data for remote project '$projid' from $BSConfig::srcserver\n";
  my @args;
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
  push @args, "project=$projid";
  my $param = {
    'uri' => "$BSConfig::srcserver/getprojpack",
  };
  if ($doasync) {
    $param->{'async'} = { %$doasync, '_resume' => \&get_remoteproject_resume, '_projid' => $projid};
  }
  my $projpacksin;
  eval {
    if ($usestorableforprojpack) {
      $projpacksin = $gctx->{'rctx'}->xrpc($gctx, $projid, $param, \&BSUtil::fromstorable, 'view=storable', 'withconfig', 'withremotemap', 'remotemaponly', "arch=$myarch", @args);
    } else {
      $projpacksin = $gctx->{'rctx'}->xrpc($gctx, $projid, $param, $BSXML::projpack, 'withconfig', 'withremotemap', 'remotemaponly', "arch=$myarch", @args);
    }
  };
  return 0 if !$@ && $projpacksin && $param->{'async'};
  delete $gctx->{'remotemissing'}->{$projid};
  if ($@) {
    warn($@) if $@;
    return;
  }
  BSSched::Remote::remotemap2remoteprojs($gctx, $projpacksin->{'remotemap'});
  $gctx->{'remotemissing'}->{$projid} = 1 if !$gctx->{'projpacks'}->{$projid} && !$gctx->{'remoteprojs'}->{$projid};
}

1;

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
#   find_linked_sources
#   expandsearchpath
#   expandprojlink
#   setup_projects
#   print_project_stats
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
#   asyncmode
#   prpcheckuseforbuild

use strict;
use warnings;


our $usestorableforprojpack = 1;
our $testprojid;

use Build;	# for read_config
use Data::Dumper;
use Time::HiRes;

use BSUtil;
use BSSolv;	# for depsort and orderpackids
use BSConfiguration;
use BSSched::Remote;
use BSSched::DoD;	# for update_doddata

=head2 checkbuildrepoid - TODO: add summary

 TODO: add description

=cut

sub checkbuildrepoid {
  my ($gctx, $projpacksin) = @_;
  die("ERROR: source server did not report a repoid") unless $projpacksin->{'repoid'};
  my $reporoot = $gctx->{'reporoot'};
  return unless defined $reporoot;
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
  my ($gctx, $startupmode) = @_;
  die("unsupported startup mode $startupmode\n") if $startupmode && $startupmode != 1 && $startupmode != 2;
  my $myarch = $gctx->{'arch'};
  my @args;
  push @args, 'withsrcmd5', 'withdeps' unless $startupmode == 2;
  push @args, 'withrepos', 'withconfig', 'withremotemap';
  push @args, 'noremote=1' if $startupmode;
  push @args, "arch=$myarch";
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
  undef $projid unless $gctx->{'projpacks'};
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
    my $projpacks = $gctx->{'projpacks'};
    my $proj = $projpacks->{$projid} || {};
    for my $repo (@{$proj->{'repository'} || []}) {
      for my $path (@{$repo->{'path'} || []}, @{$repo->{'hostsystem'} || []}) {
	next if $path->{'project'} eq $testprojid;
	next if $projid ne $testprojid && $projpacks->{$path->{'project'}};
	get_projpacks($gctx, undef, $path->{'project'});
      }
    }
  }
  return 1;
}

sub trigger_auto_deep_checks {
  my ($gctx, $projid, $oldproj, $newproj) = @_;
  my %badprp;
  my $oldconfig = $oldproj->{'config'} || '';
  my $newconfig = $newproj->{'config'} || '';
  if ($BSConfig::deep_check_dependent_projects_on_macro_change) {
    for my $oldrepo (@{$oldproj->{'repository'} || []}) {
      my $repoid = $oldrepo->{'name'};
      my $newrepo = (grep {$_->{'name'} eq $repoid} @{$oldproj->{'repository'} || []})[0];
      if (!$newrepo || !BSUtil::identical($oldrepo->{'path'}, $newrepo->{'path'})) {
	$badprp{"$projid/$repoid"} = 1;
      } elsif ($oldconfig ne $newconfig) {
	$badprp{"$projid/$repoid"} = 1 if has_critical_config_change($projid, $repoid, $gctx->{'arch'}, $oldconfig, $newconfig);
      }
    }
  } elsif ($oldconfig ne $newconfig) {
    my @mprefix = ("%define _project $projid");
    my $cold = Build::read_config($gctx->{'arch'}, [ @mprefix, split("\n", $oldproj->{'config'} || '') ]);
    my $cnew = Build::read_config($gctx->{'arch'}, [ @mprefix, split("\n", $newproj->{'config'} || '') ]);
    if (($cold->{'expandflags:macroserial'} || '') ne ($cnew->{'expandflags:macroserial'} || '')) {
      for my $oldrepo (@{$oldproj->{'repository'} || []}) {
	$badprp{"$projid/$oldrepo->{'name'}"} = 1;
      }
    }
  }
  return unless %badprp;
  print "had critical config change for ".join(', ', sort keys %badprp)."\n";
  my %badprojids = ($projid => 1);
  my $projpacks = $gctx->{'projpacks'};
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

  my $oldproj = $projpacks->{$projid} || $remoteprojs->{$projid} || {};
  my $newproj = $projpacksin->{'project'}->[0];
  $newproj = undef if $newproj && $newproj->{'name'} ne $projid;
  $newproj ||= (grep {$_->{'project'} eq $projid} @{$projpacksin->{'remotemap'} || []})[0] || {};
  my $oldconfig = $oldproj->{'config'} || '';
  my $newconfig = $newproj->{'config'} || '';
  trigger_auto_deep_checks($gctx, $projid, $oldproj, $newproj) if !$packids || $oldconfig ne $newconfig;

  # commit the update
  update_projpacks($gctx, $projpacksin, $projid, $packids);
  get_projpacks_postprocess_projects($gctx, $projid) if !$packids || postprocess_needed_check($gctx, $projid, $oldprojdata);

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
    # the changed source packages are in _lpackids
    $handle->{'_dolink'} ||= 2;
  }

  # fetch linked packages with lower prio
  if ($handle->{'_dolink'}) {
    my $alllocked = $gctx->{'alllocked'};
    my $delayedfetchprojpacks = $gctx->{'delayedfetchprojpacks'};
    my $xpackids = $packids || $handle->{'_lpackids'};  # just packages linking to those
    my $linked = find_linked_sources($gctx, $projid, $xpackids);
    for my $lprojid (sort keys %$linked) {
      my %lpackids;
      if ($lprojid eq $projid) {
	next unless $xpackids;	# we just fetched all packages
	# grep out packages we just fetched
	my %xpackids = map {$_ => 1} @$xpackids;
	%lpackids = map {$_ => 1} grep {!$xpackids{$_}} @{$linked->{$lprojid}};
      } else {
	%lpackids = map {$_ => 1} @{$linked->{$lprojid}};
      }
      next unless %lpackids;
      # delay package source changes if possible
      if ($handle->{'_dolink'} == 2 && $lprojid ne $projid && $delayedfetchprojpacks) {
        push @{$delayedfetchprojpacks->{$lprojid}}, sort keys %lpackids;
        # we don't use setchanged because it unshifts the prps onto lookat
        my $changed_med = $gctx->{'changed_med'};
        my $changed_low = $gctx->{'changed_low'};
        my $changed = $xpackids ? $changed_med : $changed_low;
        my $changed_dirty = $gctx->{'changed_dirty'};
        for my $prp (@{$gctx->{'prps'}}) {
          next unless (split('/', $prp, 2))[0] eq $lprojid;
	  if ($alllocked->{$prp}) {
            $changed_low->{$prp} ||= 1;
	  } else {
            $changed->{$prp} ||= 1;
	  }
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
    die("bad projpack answer\n") if defined($projid) && $proj->{'name'} ne $projid;
    if ($packids && @$packids) {
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
  # the src server does not send the project if the packages were deleted
  if (defined($projid) && !@{$projpacksin->{'project'} || []} && $projpacks->{$projid}) {
    update_prpcheckuseforbuild($gctx, $projid, $projpacks->{$projid});
  }
  if (defined($projid) && $isgone) {
    update_prpcheckuseforbuild($gctx, $projid);
    BSSched::DoD::update_doddata($gctx, $projid) if $BSConfig::enable_download_on_demand;
  }

  my $remoteprojs = $gctx->{'remoteprojs'};
  if (!defined($projid)) {
    %$remoteprojs = ();
  } elsif (!($packids && @$packids)) {
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
  # withsrcmd5 is needed for the patterns md5sum
  my @args = ('nopackages', 'withrepos', 'withconfig', 'withsrcmd5', "arch=$myarch");
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
  push @args, "project=$projid";
  eval {
    if ($usestorableforprojpack) {
      $projpacksin = $gctx->{'rctx'}->xrpc($gctx, $projid, $param, \&BSUtil::fromstorable, 'view=storable', @args);

    } else {
      $projpacksin = $gctx->{'rctx'}->xrpc($gctx, $projid, $param, $BSXML::projpack, @args);
    }
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


=head2 has_critical_config_change - TODO: add summary

 check if the project config was changed in a way that needs us
 to re-fetch all packages

=cut

sub has_critical_config_change {
  my ($projid, $repoid, $arch, $oldconfig, $newconfig) = @_;
  my @mprefix = ("%define _project $projid", "%define _repository $repoid", "%define _is_this_project 1", "%define _is_in_project 1");
  my $cold = Build::read_config($arch, [ @mprefix, split("\n", $oldconfig || '') ]);
  my $cnew = Build::read_config($arch, [ @mprefix, split("\n", $newconfig || '') ]);
  return 1 if ($cold->{'expandflags:macroserial'} || '') ne ($cnew->{'expandflags:macroserial'} || '');
  return 1 unless BSUtil::identical($cold->{'macros'}, $cnew->{'macros'});
  return 1 unless BSUtil::identical($cold->{'type'}, $cnew->{'type'});
  # some buildflags change the dependency parsing
  my @bf_old = grep {/^dockerarg:/} @{$cold->{'buildflags'} || []};
  my @bf_new = grep {/^dockerarg:/} @{$cnew->{'buildflags'} || []};
  return 1 unless BSUtil::identical(\@bf_old, \@bf_new);
  return 0;
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
    # check for critical changes in all repositories
    for my $repoid (map {$_->{'name'}} @{$proj->{'repository'} || []}) {
      return 0 if has_critical_config_change($projid, $repoid, $gctx->{'arch'}, $oldproj->{'config'}, $proj->{'config'});
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
  # just clone the specified packages + multibuild packages
  my $oldprojdata = { %{$projpacks->{$projid} || {}} };
  delete $oldprojdata->{'package'};
  $oldprojdata = BSUtil::clone($oldprojdata);
  my $oldpackdata = {};
  my $packs = ($projpacks->{$projid} || {})->{'package'} || {};
  my %packids = map {$_ => 1} @$packids;
  for my $packid (@$packids) {
    $oldpackdata->{$packid} = $packs->{$packid} ? BSUtil::clone($packs->{$packid}) : undef;
  }
  # clone multibuild packages as well
  for my $packid (grep {/(?<!^_product)(?<!^_patchinfo):./} keys %$packs) {
    next unless $packid =~ /^(.*):[^:]+$/;
    $oldpackdata->{$packid} = $packs->{$packid} ? BSUtil::clone($packs->{$packid}) : undef if $packids{$1};
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
  my %except = map {$_ => 1} qw{rev srcmd5 versrel verifymd5 revtime dep prereq file name error build publish useforbuild scmsync};
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

  my $t1 = Time::HiRes::time();
  delete $gctx->{'get_projpacks_postprocess_needed'};
  # clear changed remoteproj list
  BSSched::Remote::getchangedremoteprojs($gctx, 1);
  #print Dumper($projpacks);
  setup_projects($gctx);
  my $t2 = Time::HiRes::time();
  BSSched::Remote::setup_watches($gctx);
  my $t3 = Time::HiRes::time();
  printf "get_projpacks_postprocess done, %.3fs + %.3fs\n", $t2 - $t1, $t3 - $t2;
}

sub get_projpacks_postprocess_projects {
  my ($gctx, @projids) = @_;

  my %todo = map {$_ => 1} @projids;

  # find out which project need an update
  my $projpacks = $gctx->{'projpacks'};
  my %changed = map {$_ => 1} BSSched::Remote::getchangedremoteprojs($gctx, 1);
  $changed{$_} = 1 for @projids;
  return unless %changed;

  # first prp deps
  my $rprpdeps = $gctx->{'rprpdeps'};
  for my $rprp (keys %$rprpdeps) {
    next unless $changed{(split('/', $rprp, 2))[0]};
    for my $prp (@{$rprpdeps->{$rprp}}) {
      my ($aprojid) = split('/', $prp, 2);
      $todo{$aprojid} = 1 if $projpacks->{$aprojid};
    }
  }

  # then project deps
  my $expandedprojlink = $gctx->{'expandedprojlink'};
  for my $aprojid (keys %$expandedprojlink) {
    $todo{$aprojid} = 1 if grep {$changed{$_}} @{$expandedprojlink->{$aprojid}};
  }

  my $nprojids = @projids;
  my $nextra = keys(%todo) - $nprojids;
  print "get_projpacks_postprocess_projects for $nprojids + $nextra projects\n";

  # now update all projects on the todo list
  my $t1 = Time::HiRes::time();
  setup_projects($gctx, [ sort keys %todo ]) if %todo;
  my $t2 = Time::HiRes::time();
  BSSched::Remote::setup_watches($gctx);
  my $t3 = Time::HiRes::time();
  printf "get_projpacks_postprocess_projects done, %.3fs + %.3fs\n", $t2 - $t1, $t3 - $t2;
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

=head2 find_local_linked_sources - find local links of a project

=cut

sub find_local_linked_sources {
  my ($gctx, $projid, $packids) = @_;
  my $projlinked = $gctx->{'projpacks_linked'}->{$projid};
  return () unless $projlinked && $packids;
  my %packids = map {$_ => 1} @$packids;
  $packids{':*'} = 1;
  my @l;
  for my $linfo (grep {$_->{'myproject'} eq $projid && $packids{$_->{'package'}}} @$projlinked) {
    push @l, $linfo->{'mypackage'} if defined $linfo->{'mypackage'};
  }
  return @l;
}

=cut

=head2 expandsearchpath  - recursively expand the last component of a repository's path

 input:  $projid     - the project the repository belongs to

         $repository - the repository data

 output: expanded path array

=cut

sub expandsearchpath {
  my ($gctx, $projid, $repository, $pathelement) = @_;

  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  $pathelement ||= 'path';
  my %done;
  my @ret;
  my @path = @{$repository->{$pathelement} || $repository->{'path'} || []};
  # our own repository is not included in the path,
  # so put it infront of everything
  unshift @path, {'project' => $projid, 'repository' => $repository->{'name'}};
  while (@path) {
    my $t = shift @path;
    my $prp = "$t->{'project'}/$t->{'repository'}";
    push @ret, $t unless $done{$prp};
    $done{$prp} = 1;
    if (!@path) {
      last if $done{"/$prp"};
      my ($pid, $rid) = ($t->{'project'}, $t->{'repository'});
      my $proj = $projpacks->{$pid};
      $proj = $remoteprojs->{$pid} if !$proj || $proj->{'remoteurl'};
      next unless $proj;
      $done{"/$prp"} = 1;       # mark expanded
      my $repo = (grep {$_->{'name'} eq $rid} @{$proj->{'repository'} || []})[0];
      push @path, @{$repo->{$pathelement} || $repo->{'path'} || []} if $repo;
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
  my $remoteprojs = $gctx->{'remoteprojs'};
  my @ret;
  my $proj = $projpacks->{$projid};
  my @todo = map {$_->{'project'}} @{$proj->{'link'} || []};
  my %seen = ($projid => 1);
  while (@todo) {
    my $lprojid = shift @todo;
    next if $seen{$lprojid};
    push @ret, $lprojid;
    $seen{$lprojid} = 1;
    my $lproj = $projpacks->{$lprojid};
    $lproj = $remoteprojs->{$lprojid} if !$lproj || $lproj->{'remoteurl'};
    next unless $lproj;
    unshift @todo, map {$_->{'project'}} @{$lproj->{'link'} || []};
  }
  return @ret;
}

# check if a prp is related to a project
sub is_related {
  my ($projid1, $repoid1, $prp2) = @_;
  #$projid1 =~ s/^([^:]+:[^:]+):.*/$1/;
  my $projid2 = (split('/', $prp2, 2))[0];
  return 1 if $projid1 eq $projid2;
  my $lprojid1 = length($projid1);
  my $lprojid2 = length($projid2);
  return 1 if $lprojid1 > $lprojid2 && substr($projid1, 0, $lprojid2 + 1) eq "$projid2:";
  return 1 if $lprojid2 > $lprojid1 && substr($projid2, 0, $lprojid1 + 1) eq "$projid1:";
  return 1 if $BSConfig::related_projects && ($BSConfig::related_projects->{"$projid1/$projid2"} || $BSConfig::related_projects->{"$projid2/$projid1"});
  return 0;
}

=head2 setup_projects - TODO

 find all prps we have to schedule, expand search path for every prp,
 set up inter-prp dependency graph, sort prps using this graph.

 also gets rid of no longer used channeldata

 input:  %projpacks

 output: @prps
         %prpsearchpath
         %prpdeps
         %rprpdeps
         %relatedprpdeps
         %rrelatedprpdeps
         %channeldata
         %channelids
=cut

sub setup_projects {
  my ($gctx, $projids_todo) = @_;

  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};

  my $t1 = Time::HiRes::time();
  my $projids_todo_cnt = scalar(@{$projids_todo || []});
  undef $projids_todo if $projids_todo_cnt > 1000;	# removing old stuff takes too long

  my @projids_todo;
  if ($projids_todo) {
    BSUtil::printlog("updating project dependencies for $projids_todo_cnt projects...");
    @projids_todo = BSUtil::unify(@$projids_todo);
  } else {
    if ($projids_todo_cnt) {
      my $projids_all_cnt = scalar(keys %$projpacks);
      BSUtil::printlog("calculating project dependencies ($projids_todo_cnt/$projids_all_cnt)...");
    } else {
      BSUtil::printlog("calculating project dependencies...");
    }
    @projids_todo = sort keys %$projpacks;
  }

  # free some mem, we'll recreate those at the end
  $gctx->{'prps'} = [];
  $gctx->{'rprpdeps'} = {};
  $gctx->{'rrelatedprpdeps'} = {};

  my %old_channelids;	# for post-process
  if (!$projids_todo) {
    # going to redo all project dependencies, so start from scratch
    $gctx->{'projpacks_linked'} = {};
    $gctx->{'projpacks_linked_blks'} = {};
    $gctx->{'prpsearchpath'} = {};
    $gctx->{'prpsearchpath_host'} = {};
    $gctx->{'prpdeps'} = {};
    $gctx->{'relatedprpdeps'} = {};
    $gctx->{'expandedprojlink'} = {};
    $gctx->{'linked_projids'} = {};
    $gctx->{'channeldata'} = {};
    $gctx->{'channelids'} = {};
    $gctx->{'project_prps'} = {};
    $gctx->{'alllocked'} = {};
  } else {
    # just updating some projects, delete all the entries we currently have

    # remove project(s) from projpacks_linked
    my $projpacks_linked = $gctx->{'projpacks_linked'};
    my $projpacks_linked_blks = $gctx->{'projpacks_linked_blks'};
    my %projids_todo = map {$_ => 1} @$projids_todo;
    my %lprojids = map {$_ => 1} map { (@{$gctx->{'expandedprojlink'}->{$_} || []}, @{$gctx->{'linked_projids'}->{$_} || []}) } @$projids_todo;
    for my $lprojid (sort keys %lprojids) {
      my $pl = $projpacks_linked->{$lprojid};
      next unless $pl;
      my $off = 0;
      my $blks = $projpacks_linked_blks->{$lprojid};
      for my $blk (@$blks) {
	if (!$projids_todo{$pl->[$off]->{'myproject'}}) {
	  $off += $blk;
	} else {
	  splice(@$pl, $off, $blk);
	  $blk = undef;
	}
      }
      if (@$pl) {
	@$blks = grep {defined($_)} @$blks;
      } else {
	delete $projpacks_linked->{$lprojid};
	delete $projpacks_linked_blks->{$lprojid};
      }
    }
    for my $projid (@$projids_todo) {
      # save old_channelids for post-processing
      $old_channelids{$projid} = $gctx->{'channelids'}->{$projid} if $gctx->{'channelids'}->{$projid};
      # remove project from various prp indexed hashes
      for my $prp (@{$gctx->{'project_prps'}->{$projid} || []}) {
	delete $gctx->{'prpsearchpath'}->{$prp};
	delete $gctx->{'prpsearchpath_host'}->{$prp};
	delete $gctx->{'prpdeps'}->{$prp};
	delete $gctx->{'relatedprpdeps'}->{$prp};
	delete $gctx->{'alllocked'}->{$prp};
      }
      # remove project from various projid indexed hashes
      delete $gctx->{'expandedprojlink'}->{$projid};
      delete $gctx->{'linked_projids'}->{$projid};
      delete $gctx->{'project_prps'}->{$projid};
      delete $gctx->{'channelids'}->{$projid};
    }
  }
  my $t2 = Time::HiRes::time();

  for my $projid (@projids_todo) {
    my $proj = $projpacks->{$projid};
    next if !$proj || $proj->{'remoteurl'};

    # generate package link information
    my %lprojids;
    my $projpacks_linked = $gctx->{'projpacks_linked'};
    my $projpacks_linked_blks = $gctx->{'projpacks_linked_blks'};
    if ($proj->{'package'}) {
      my ($mypackid, $pack);
      while (($mypackid, $pack) = each %{$proj->{'package'} || {}}) {
	next unless $pack->{'linked'};
	for my $lil (@{$pack->{'linked'}}) {
	  my $li = { %$lil, 'myproject' => $projid, 'mypackage' => $mypackid };
	  my $lprojid = delete $li->{'project'};
	  $lprojids{$lprojid}++;
	  push @{$projpacks_linked->{$lprojid}}, $li;
	}
      }
    }
    $gctx->{'linked_projids'}->{$projid} = [ sort keys %lprojids ] if %lprojids;

    # generate project link information
    if ($proj->{'link'}) {
      my $expandedprojlink = $gctx->{'expandedprojlink'};
      $expandedprojlink->{$projid} = [ expandprojlink($gctx, $projid) ];
      for my $lprojid (@{$expandedprojlink->{$projid}}) {
	$lprojids{$lprojid}++;
	push @{$projpacks_linked->{$lprojid}}, { 'package' => ':*', 'myproject' => $projid };
      }
    }

    # save block sizes
    push @{$projpacks_linked_blks->{$_}}, $lprojids{$_} for keys %lprojids;

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
    # filter out disabled/excluded/locked/broken entries
    @aggs = grep {!$_->{'error'}} @aggs;
    @channels = grep {!$_->{'error'}} @channels;
    @kiwiinfos = grep {!$_->{'error'}} @kiwiinfos;
    @pdatas = ();               # free mem
    my %channelrepos;
    if (@channels) {
      my %channelids;
      my $channeldata = $gctx->{'channeldata'};
      my $channelids = $gctx->{'channelids'};
      for my $channel (map {$_->{'channel'}} @channels) {
	if ($channel->{'_md5'}) {
	  $channeldata->{$channel->{'_md5'}} ||= $channel;
	  $channelids{$channel->{'_md5'}} = 1;
	}
	next unless $channel->{'target'};
	# calculate list targeted repos
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
      $gctx->{'channelids'}->{$projid} = [ sort keys %channelids ] if %channelids;
    }
    my %myprps;
    my $prpsearchpath = $gctx->{'prpsearchpath'};
    my $prpdeps = $gctx->{'prpdeps'};
    my $relatedprpdeps = $gctx->{'relatedprpdeps'};
    for my $repo (@myrepos) {
      my $repoid = $repo->{'name'};
      my $prp = "$projid/$repoid";
      $myprps{$prp} = 1;

      # check if all packages are locked
      my $alllocked;
      if ($proj->{'lock'} && BSUtil::enabled($repoid, $proj->{'lock'}, 0, $myarch)) {
	$alllocked = 1;
	for my $pack (grep {$_->{'lock'}} values(%{$proj->{'package'} || {}})) {
	  $alllocked = 0 unless BSUtil::enabled($repoid, $pack->{'lock'}, 1, $myarch);
	}
      }
      if ($alllocked) {
	$gctx->{'alllocked'}->{$prp} = 1;
      } else {
	delete $gctx->{'alllocked'}->{$prp};
      }

      # if all packages are locked we do not have dependencies
      if ($alllocked) {
	my @sp;
	$prpsearchpath->{$prp} = \@sp;
	$prpdeps->{$prp} = \@sp;
	next;
      }

      my $iscrossnative = $repo->{'crosshostarch'} && $repo->{'crosshostarch'} eq $myarch && $myarch ne 'local';
      my @searchpath = expandsearchpath($gctx, $projid, $repo, $iscrossnative ? 'hostsystem' : 'path');
      # map searchpath to internal prp representation
      my @sp = map {"$_->{'project'}/$_->{'repository'}"} @searchpath;
      $prpsearchpath->{$prp} = \@sp;
      $prpdeps->{$prp} = \@sp;

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
	my %xsp = map {$_ => 1} (@sp, @xsp);
	delete $xsp{$prp};
	$prpdeps->{$prp} = [ sort keys %xsp ];
      }
      # get list of related prp
      my @related_prps = grep { $prp ne $_ && is_related($projid, $repoid, $_) } @{$prpdeps->{$prp} || []};
      $relatedprpdeps->{$prp} = \@related_prps if @related_prps;

      # expand hostsystem for cross builds
      if ($repo->{'hostsystem'} && $repo->{'crosshostarch'} && $repo->{'crosshostarch'} ne $myarch && $repo->{'crosshostarch'} ne 'local') {
        my @searchpath_host = expandsearchpath($gctx, $projid, $repo, 'hostsystem');
        @searchpath_host = map {"$_->{'project'}/$_->{'repository'}"} @searchpath_host;
	$gctx->{'prpsearchpath_host'}->{$prp} = [ $repo->{'crosshostarch'}, \@searchpath_host ];
      }
    }
    $gctx->{'project_prps'}->{$projid} = [ sort keys %myprps ] if %myprps;
  }

  # all projects done, now some post processing
  my $t3 = Time::HiRes::time();

  if (%old_channelids) {
    my $channelids = $gctx->{'channelids'};
    # check if they are identical
    for my $projid (keys %old_channelids) {
      next if BSUtil::identical($old_channelids{$projid}, $channelids->{$projid});
      # not identical, delete no longer used entries from channeldata
      my %used;
      for my $projid (keys %{$channelids || {}}) {
        $used{$_} = 1 for @{$channelids->{$projid}};
      }
      for (keys %{$gctx->{'channeldata'} || {}}) {
        delete $gctx->{'channeldata'}->{$_} unless $used{$_};
      }
      last;
    }
  }

  print "have ".scalar(keys %{$gctx->{'channeldata'}})." unique channel configs\n" if %{$gctx->{'channeldata'}};

  # create list of prps and sort them
  print "sorting projects and repositories...\n";
  my @prps = sort keys %{$gctx->{'prpsearchpath'}};
  if (@prps >= 2) {
    my @cycs;
    @prps = BSSolv::depsort($gctx->{'prpdeps'}, undef, \@cycs, @prps);
    print "cycle: ".join(' -> ', @$_)."\n" for @cycs;
  }
  $gctx->{'prps'} = \@prps;

  # create reverse deps to speed up changed2lookat
  my $prpdeps = $gctx->{'prpdeps'};
  my %rprpdeps;
  for my $prp (keys %$prpdeps) {
    push @{$rprpdeps{$_}}, $prp for @{$prpdeps->{$prp}};
  }
  # free some mem
  for my $prp (keys %rprpdeps) {
    delete $rprpdeps{$prp} if @{$rprpdeps{$prp}} == 1 && $rprpdeps{$prp}->[0] eq $prp;
  }
  $gctx->{'rprpdeps'} = \%rprpdeps;

  # create reverse related deps
  my $relatedprpdeps = $gctx->{'relatedprpdeps'};
  my %rrelatedprpdeps;
  for my $prp (keys %$relatedprpdeps) {
    push @{$rrelatedprpdeps{$_}}, $prp for @{$relatedprpdeps->{$prp}};
  }
  $gctx->{'rrelatedprpdeps'} = \%rrelatedprpdeps;
  print "have ".scalar(keys %{$gctx->{'rrelatedprpdeps'}})." related prp dependencies\n" if %{$gctx->{'rrelatedprpdeps'}};

  my $t4 = Time::HiRes::time();
  printf "setup_projects done, %.3fs + %.3fs + %.3fs\n", $t2 - $t1, $t3 - $t2, $t4 - $t3;
}

=head2 print_project_stats - print statistics about our project data

 TODO: add description

=cut

sub verify_projpacks_linked_blks {
  my ($gctx) = @_;
  print "verifying projpacks_linked_blks data\n";
  my $projpacks_linked = $gctx->{'projpacks_linked'};
  my $projpacks_linked_blks = $gctx->{'projpacks_linked_blks'};
  for my $lprojid (sort keys %$projpacks_linked) {
    my $lp = $projpacks_linked->{$lprojid};
    my $blks = $projpacks_linked_blks->{$lprojid};
    my $n = 0;
    $n += $_ for @$blks;
    die("projpacks_linked size mismatch\n") if $n != @$lp;
    $n = 0;
    my $projid;
    my @b = @$blks;
    for (@$lp) {
      if ($n == 0) {
	$projid = $_->{'myproject'};
        $n = shift(@b);
        die("bad blocks entry\n") if $n <= 0;
      } else {
	die("block mismatch\n") if $_->{'myproject'} ne $projid;
      }
      $n--;
    }
    die("excess blocks entry\n") if @b;
  }
}

sub print_project_stats_perproject {
  my ($str, $data, $str2) = @_;
  my @d = sort {$a <=> $b} @$data;
  my $cnt = @d;
  my $sum = 0;
  my $sum2 = 0;
  $sum += $_ for @d;
  $sum2 += $_ * $_ for @d;
  $str .= " cnt:$cnt sum:$sum sum2:$sum2";
  if ($cnt) {
    for my $p (qw{0 0.5 1 5 10 20 30 40 50 60 70 80 90 95 99 99.5 100}) {
      my $i = int($cnt * $p / 100);
      $i = $cnt - 1 if $i >= $cnt; 
      $str .= " $p:$d[$i]";
    }
  }
  $str .= $str2 if $str2;
  print "$str\n";
}

sub print_project_stats_new {
  my ($gctx) = @_;
  my $projpacks = $gctx->{'projpacks'} || {};
  my @pkgperproject;
  my @prpperproject;
  my @ulprpperproject;
  my $alllocked = $gctx->{'alllocked'};
  my $nmissing;
  for my $projid (keys %$projpacks) {
    push @pkgperproject, scalar(keys(%{$projpacks->{$projid}->{'package'} || {}}));
    $nmissing++ if $projpacks->{$projid}->{'missingpackages'};
    my $numprps = scalar(@{$gctx->{'project_prps'}->{$projid} || []});
    push @prpperproject, $numprps if $numprps;
    my $nunlocked = scalar(grep {!$alllocked->{$_}} @{$gctx->{'project_prps'}->{$projid} || []});
    push @ulprpperproject, $nunlocked if $nunlocked;
  }
  $nmissing = $nmissing ? " missing:$nmissing" : undef;
  print_project_stats_perproject("pkg statistics:", \@pkgperproject, $nmissing);
  print_project_stats_perproject("prp statistics:", \@prpperproject);
  print_project_stats_perproject("ulprp statistics:", \@ulprpperproject);
}

sub print_project_stats {
  my ($gctx) = @_;
  print "project data statistics:\n";
  my $projpacks = $gctx->{'projpacks'} || {};
  my $pkg = 0;
  $pkg += keys(%{$projpacks->{$_}->{'package'} || {}}) for keys %$projpacks;
  printf "  projects: %d\n", scalar(keys %$projpacks);
  printf "  packages: %d\n", $pkg;
  printf "  prps: %d\n", scalar(@{$gctx->{'prps'} || []});
  printf "  alllocked: %d\n", scalar(keys %{$gctx->{'alllocked'} || {}});
  for my $what (qw{projpacks_linked projpacks_linked_blks prpsearchpath prpdeps rprpdeps expandedprojlink linked_projids channelids project_prps relatedprpdeps rrelatedprpdeps}) {
    my $w = $gctx->{$what};
    next unless $w;
    my $e = 0;
    $e += @{$w->{$_}} for keys %$w;
    printf "  %s: %d %d\n", $what, scalar(keys %$w), $e;
  }
  # print new statistics data
  print_project_stats_new($gctx);
  # verify data
  verify_projpacks_linked_blks($gctx);
}

=head2 delay_linkedpackages - put linked packages on the delayedfetchprojpacks queue

=cut

sub delay_linkedpackages {
  my ($gctx, $projid, $packids) = @_;
  my %packids = map {$_ => 1} @{$packids || []};
  my $linked = find_linked_sources($gctx, $projid, $packids);
  return unless %$linked;
  my $delayedfetchprojpacks = $gctx->{'delayedfetchprojpacks'};
  my $changed_low = $gctx->{'changed_low'};
  my $changed_med = $gctx->{'changed_med'};
  my $changed_dirty = $gctx->{'changed_dirty'};
  my $alllocked = $gctx->{'alllocked'};
  for my $lprojid (keys %$linked) {
    if ($lprojid eq $projid) {
      next unless $packids;
      my @l = grep {!$packids{$_}} @{$linked->{$lprojid}};
      next unless @l;
      push @{$delayedfetchprojpacks->{$lprojid}}, @l;
    } else {
      push @{$delayedfetchprojpacks->{$lprojid}}, @{$linked->{$lprojid}};
    }
    for my $prp (@{$gctx->{'prps'}}) {
      next unless (split('/', $prp, 2))[0] eq $lprojid;
      if ($alllocked->{$prp}) {
	$changed_low->{$prp} ||= 1;
      } else {
	$changed_med->{$prp} ||= 1;
      }
      $changed_dirty->{$prp} = 1;
    }
  }
}

=head2 do_delayedprojpackfetches - do delayed projpack fetches caused by source changes

 Do all the delayed projpack fetches caused by source changes

 See do_fetchprojpacks

 Returns 0 if an async fetch is in progress.

=cut

sub do_delayedprojpackfetches {
  my ($gctx, $doasync, $projid, @packids) = @_;
  my %packids = map {$_ => 1} @packids;
  my $dolink = delete $packids{'/dolink'};
  return 1 unless %packids;
  $doasync = { %$doasync, '_dolink' => 2 } if $doasync && $dolink;
  if ($packids{'/all'}) {
    if ($doasync) {
      get_projpacks($gctx, $doasync, $projid);
      return 0;		# in progress
    }
    get_projpacks($gctx, undef, $projid);
    get_projpacks_postprocess_projects($gctx, $projid);
  } else {
    @packids = sort keys %packids;
    if ($dolink) {
      # extend with local linked packages
      push @packids, find_local_linked_sources($gctx, $projid, \@packids);
      %packids = map {$_ => 1} @packids;
      @packids = sort keys %packids;
    }
    if ($doasync) {
      get_projpacks($gctx, $doasync, $projid, @packids);
      return 0;		# in progress
    }
    my $oldprojdata = clone_projpacks_part($gctx, $projid, \@packids);
    get_projpacks($gctx, undef, $projid, @packids);
    get_projpacks_postprocess_projects($gctx, $projid) if BSSched::ProjPacks::postprocess_needed_check($gctx, $projid, $oldprojdata);
  }
  delay_linkedpackages($gctx, $projid, $packids{'/all'} ? undef : \@packids) if $dolink;
  return 1;		# all done
}

=head2 do_fetchprojpacks - process cummulated projpacks fetches

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
    push @{$delayedfetchprojpacks->{$projid}}, '/dolink', @{$fetchprojpacks->{$projid}};
    delay_linkedpackages($gctx, $projid, $fetchprojpacks->{$projid}) unless $foundit;
    delete $delayedfetchprojpacks->{$projid} unless $foundit; # if we never look at the project
    delete $fetchprojpacks->{$projid};
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
      my @packids = grep {defined($_)} @{$fetchprojpacks->{$projid}};
      next unless @packids;
      # extend with local links we know in async mode
      push @packids, find_local_linked_sources($gctx, $projid, \@packids) if $asyncmode;
      my %packids = map {$_ => 1} @packids;
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
    my $alllocked = $gctx->{'alllocked'};
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
	    if ($alllocked->{$prp}) {
	      $changed_low->{$prp} ||= 1;
	    } else {
	      $changed_med->{$prp} ||= 1;
	    }
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

 this is basically getconfig from the source server, but
 with all the macro code stripped as we do not need any
 macros in the scheduler.

=cut

sub getconfig {
  my ($gctx, $projid, $repoid, $arch, $path) = @_;
  my $config = "%define _project $projid\n";
  $config .= "%define _obs_feature_exclude_cpu_constraints 1\n";
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my ($old_is_this_project, $old_is_in_project) = (-1, -1);
  for my $prp (reverse @$path) {
    my ($p, $r) = split('/', $prp, 2);
    my $c;
    my $proj = $projpacks->{$p};
    if (!$proj || $proj->{'remoteurl'}) {
      $proj = $remoteprojs->{$p};
      next unless $proj;
      return undef if $proj->{'error'};
    }
    $c = $proj->{'config'};
    next unless defined $c;
    $config .= "\n### from $p\n";
    $config .= "%define _repository $r\n";
    my $new_is_this_project = $p eq $projid ? 1 : 0; 
    my $new_is_in_project = $new_is_this_project || substr($projid, 0, length($p) + 1) eq "$p:" ? 1 : 0;
    $config .= "%define _is_this_project $new_is_this_project\n" if $new_is_this_project ne $old_is_this_project;
    $config .= "%define _is_in_project $new_is_in_project\n" if $new_is_in_project ne $old_is_in_project;
    ($old_is_this_project, $old_is_in_project) = ($new_is_this_project, $new_is_in_project);

    # get rid of the Macros sections
    my $s1 = '^\s*macros:\s*$.*?^\s*:macros\s*$';
    my $s2 = '^\s*macros:\s*$.*\Z';
    $c =~ s/$s1//gmsi;
    $c =~ s/$s2//gmsi;
    $config .= $c;
  }
  # now we got the combined config, parse it
  if ($BSConfig::extraconfig) {
    my $extraconfig = '';
    for (sort keys %{$BSConfig::extraconfig}) {
      $extraconfig .= $BSConfig::extraconfig->{$_} if $projid =~ /$_/;
    }
    $config .= "\n$extraconfig" if $extraconfig;
  }
  my @c = split("\n", $config);
  my $c = Build::read_config($arch, \@c);
  $c->{'repotype'} = [ 'rpm-md' ] unless @{$c->{'repotype'}};
  $c->{'binarytype'} ||= 'UNDEFINED';
  return $c;
}

=head2 getdodrepotype - get the repotype of a dod prp

=cut

sub getdodrepotype {
  my ($gctx, $prp) = @_;
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $myarch = $gctx->{'arch'};

  my ($projid, $repoid) = split('/', $prp, 2);
  my $proj = $projpacks->{$projid};
  $proj = $remoteprojs->{$projid} if !$proj || $proj->{'remoteurl'};
  return undef unless $proj;
  my $repo = (grep {$_->{'name'} eq $repoid} @{$proj->{'repository'} || []})[0];
  return undef unless $repo && $repo->{'download'};
  my $doddata = (grep {($_->{'arch'} || '') eq $myarch} @{$repo->{'download'} || []})[0];
  return $doddata ? $doddata->{'repotype'} || 'unset' : undef;
}

=head2 neededdodresources - get all requested dod resources for a dod repo

=cut

sub neededdodresources {
  my ($gctx, $prp) = @_;
  my $dodrepotype = getdodrepotype($gctx, $prp);
  return [] unless $dodrepotype eq 'registry';
  my $projpacks = $gctx->{'projpacks'};
  my $rprpdeps = $gctx->{'rprpdeps'}->{$prp};
  return [] unless $rprpdeps;
  my %needed;
  for my $aprp (@$rprpdeps) {
    my ($aprojid, $arepoid) = split('/', $aprp, 2);
    my $aproj = $projpacks->{$aprojid};
    next unless $aproj;
    my $pdatas = $aproj->{'package'} || {};
    for my $pdata (values %$pdatas) {
      my $info = (grep {$_->{'repository'} eq $arepoid} @{$pdata->{'info'} || []})[0];
      next unless $info;
      $needed{$_} = 1 for grep {/^container:/} @{$info->{'dep'} || []};
    }      
  }
  return [ sort keys %needed ];
}

=head2 orderpackids - sort package containers

 we simply sort by container name, except that _volatile
 goes to the back and maintenance issues are ordered by
 just their incident number.

=cut

sub orderpackids {
  my ($proj, @packids) = @_;
  my $kind = ($proj || {})->{'kind'} || '';
  if (defined &BSSolv::orderpackids) {
    # use fast C implementation if available
    return BSSolv::orderpackids($kind eq 'maintenance_release' ? 1 : 0, @packids);
  }
  my @s;
  my @back;
  for (@packids) {
    if ($_ eq '_volatile') {
      push @back, $_;
      next;
    }
    my $mbflavor = '';
    if (/(?<!^_product)(?<!^_patchinfo):./) {
      /^(.*):(.*?)$/;	# split into base name and flavor
      $_ = $1;
      $mbflavor = ":$2";
    }
    if (!/\d$/) {
      push @s, [ "$_$mbflavor", "$_\0$mbflavor", 99999999999999 ];
    } elsif (/^(.*)\.(\d+)$/) {
      push @s, [ "$_$mbflavor", "$1\0$mbflavor", $2];
    } elsif (/^(.*)\.imported_.*?(\d+)$/) {
      # code11 import hack...
      push @s, [ "$_$mbflavor", "$1\0$mbflavor", $2 - 1000000];
    } else {
      push @s, [ "$_$mbflavor", "$_\0$mbflavor", 99999999999999 ];
    }
  }
  if ($kind eq 'maintenance_release') {
    # in maintenance release projects the incident number comes first
    @packids = map {$_->[0]} sort { $b->[2] <=> $a->[2] || $a->[1] cmp $b->[1] || $a->[0] cmp $b->[0] } @s;
  } else {
    @packids = map {$_->[0]} sort { $a->[1] cmp $b->[1] || $b->[2] <=> $a->[2] || $a->[0] cmp $b->[0] } @s;
  }
  return @packids, @back;
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
  get_projpacks_postprocess_projects($gctx);
  $gctx->{'remotemissing'}->{$projid} = 1 if !$gctx->{'projpacks'}->{$projid} && !$gctx->{'remoteprojs'}->{$projid};
  BSSched::Lookat::setchanged($gctx, $handle->{'_changeprp'}, $handle->{'_changetype'}, $handle->{'_changelevel'});
}

sub get_remoteproject {
  my ($gctx, $doasync, $projid) = @_;

  my $myarch = $gctx->{'arch'};
  print "getting data for missing project '$projid' from $BSConfig::srcserver\n";
  my @args = ('withconfig', 'withremotemap', 'remotemaponly', "arch=$myarch");
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
      $projpacksin = $gctx->{'rctx'}->xrpc($gctx, $projid, $param, \&BSUtil::fromstorable, 'view=storable', @args);
    } else {
      $projpacksin = $gctx->{'rctx'}->xrpc($gctx, $projid, $param, $BSXML::projpack, @args);
    }
  };
  return 0 if !$@ && $projpacksin && $param->{'async'};
  delete $gctx->{'remotemissing'}->{$projid};
  if ($@) {
    warn($@) if $@;
    return;
  }
  BSSched::Remote::remotemap2remoteprojs($gctx, $projpacksin->{'remotemap'});
  get_projpacks_postprocess_projects($gctx);
  $gctx->{'remotemissing'}->{$projid} = 1 if !$gctx->{'projpacks'}->{$projid} && !$gctx->{'remoteprojs'}->{$projid};
}

# schedule deep checks for all packages excluded on startup:
#   startupmode 1: noremote option, all remote packages have an error
#   startupmode 2: no package recipe parsed
sub do_delayed_startup {
  my ($gctx, $startupmode) = @_;

  return unless $startupmode && ($startupmode == 1 || $startupmode == 2);
  my $projpacks = $gctx->{'projpacks'};
  my $delayedfetchprojpacks = $gctx->{'delayedfetchprojpacks'};
  for my $projid (sort keys %$projpacks) {
    my $packs = $projpacks->{$projid}->{'package'} || {};
    next unless %$packs;
    if ($startupmode == 1) {
      my @delayed;
      my $ok;
      for my $packid (sort keys %$packs) {
	my $pdata = $packs->{$packid};
	if ($pdata->{'error'}) {
	  if ($pdata->{'error'} =~ /noremote option/) {
	    $pdata->{'error'} = 'delayed startup';
	    push @delayed, $packid;
	  } else {
	    $ok++;
	  }
	} else {
	  if (grep {$_->{'error'} && $_->{'error'} =~ /noremote option/} @{$pdata->{'info'} || []}) {
	    $pdata->{'error'} = 'delayed startup';
	    push @delayed, $packid;
	  } else {
	    $ok++;
	  }
	}
      }
      if (!$ok) {
	$delayedfetchprojpacks->{$projid} = [ '/all' ]; # hack
      } else {
	$delayedfetchprojpacks->{$projid} = [ @delayed ];
      }
    } else {
      $delayedfetchprojpacks->{$projid} = [ '/all' ];   # hack
      for my $packid (sort keys %$packs) {
	$packs->{$packid}->{'error'} = 'delayed startup';
      }
    }
  }
}

1;

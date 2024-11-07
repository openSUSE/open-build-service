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

package BSSched::BuildJob::KiwiProduct;

use strict;
use warnings;

use BSUtil;
use Build;
use BSSolv;
use BSConfiguration;
use BSSched::BuildResult;
use BSSched::BuildJob;			# for expandkiwipath
use BSSched::ProjPacks;			# for orderpackids
use BSSched::DoD;			# for dodcheck
my %bininfo_oldok_cache;

=head1 NAME

BSSched::BuildJob::KiwiProduct - A Class to handle KiwiProduct builds

=head1 SYNOPSIS

my $h = BSSched::BuildJob::KiwiProduct->new()

$h->check();

$h->expand();

$h->rebuild();

=cut


=head2 new - TODO: add summary

 TODO: add description

=cut

sub new {
  return bless({}, $_[0]);
}


=head2 expand - TODO: add summary

 TODO: add description

=cut

sub expand {
  return 1, splice(@_, 3);
}


=head2 check - TODO: add summary

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $repo = $ctx->{'repo'};
  my $prp = "$projid/$repoid";
  my $reporoot = $gctx->{'reporoot'};

  # hmm, should get the arch from the kiwi info
  # but how can we map it to the buildarchs?

  # calculate all involved architectures
  my $buildarch = ($repo->{'arch'} || [])->[0] || '';
  # compat to old OBS versions, prefer local...
  $buildarch = 'local' if $BSConfig::localarch && grep {$_ eq 'local'} @{$repo->{'arch'} || []};
  # reposerver buildinfo is always the right build arch
  $buildarch = $myarch if $ctx->{'isreposerver'};
  # localbuildarch is where we take the buildenv from
  my $localbuildarch = $buildarch eq 'local' && $BSConfig::localarch ? $BSConfig::localarch : $buildarch;
  my $markerdir;
  $markerdir = "$reporoot/$projid/$repoid/$buildarch/$packid" unless $ctx->{'isreposerver'};

  my %imagearch = map {$_ => 1} @{$info->{'imagearch'} || []};
  return ('excluded', 'no architectures for packages') unless grep {$imagearch{$_}} @{$repo->{'arch'} || []};
  my @archs = grep {$imagearch{$_}} @{$repo->{'arch'} || []};

  # sort archs like in bs_worker
  @archs = sort(@archs);
  if ($packid =~ /-([^-]+)$/) {
    if (grep {$_ eq $1} @archs) {
      @archs = grep {$_ ne $1} @archs;
      push @archs, $1;
    }
  }

  if ($myarch ne $buildarch && $myarch ne $localbuildarch) {
    if (!grep {$_ eq $myarch} @archs) {
      if ($ctx->{'verbose'}) {
        print "      - $packid (kiwi-product)\n";
        print "        not mine\n";
      }
      return ('excluded');
    }
  }

  my @deps = @{$info->{'dep'} || []};   # expanded?
  my %deps = map {$_ => 1} @deps;
  delete $deps{''};
  $deps{'empty-modulemd-hack'} = 1 unless $deps{'-empty-modulemd-hack'};
  delete $deps{"-$_"} for grep {!/^-/} keys %deps;

  my @aprps = BSSched::BuildJob::expandkiwipath($ctx, $info);
  my @bprps = @{$ctx->{'prpsearchpath'}};
  my $bconf = $ctx->{'conf'};

  if (!@{$repo->{'path'} || []}) {
    # have no configured path, use repos from kiwi file instead
    @bprps = @aprps;
    my @configpath = @aprps;
    # always put ourselfs in front
    unshift @configpath, "$projid/$repoid" unless @configpath && $configpath[0] eq "$projid/$repoid";
    $bconf = $ctx->getconfig($projid, $repoid, $myarch, \@configpath);
    if (!$bconf) {
      if ($ctx->{'verbose'}) {
        print "      - $packid (kiwi-product)\n";
        print "        no config\n";
      }
      return ('broken', 'no config');
    }
    $bconf->{'type'} = 'kiwi';
  }
  # remove our own prp from aprps (there can't be packages in it)
  @aprps = grep {$_ ne $prp} @aprps;

  my @blocked;
  my @rpms;
  my %rpms_meta;
  my %rpms_hdrmd5;
  my $neverblock = $ctx->{'isreposerver'};
  my $remoteprojs = $gctx->{'remoteprojs'};

#print "prps: @aprps\n";
#print "archs: @archs\n";
#print "deps: @deps\n";
  my $pool;
  my %dep2pkg;
  if ($myarch eq $buildarch || $myarch eq $localbuildarch) {
    my $is_identical = BSUtil::identical(\@bprps, $ctx->{'prpsearchpath'});
    # calculate packages needed for building
    if ($myarch eq $localbuildarch && $ctx->{'pool'} && $is_identical) {
      $pool = $ctx->{'pool'};	# we can reuse the ctx pool, nice!
    } elsif ($myarch eq $buildarch && $ctx->{'pool_local'} && $is_identical) {
      $pool = $ctx->{'pool_local'};	# we can reuse the cached local pool, nice!
    } else {
      my ($error, $delayed);
      ($pool, $error, $delayed) = BSSched::BuildJob::createextrapool($ctx, $bconf, \@bprps, undef, undef, $localbuildarch);
      if ($error && $ctx->{'verbose'}) {
        print "      - $packid (kiwi-product)\n";
        print $delayed ? "        $error (delayed)\n" : "        $error\n";
      }
      return (($delayed ? 'delayed' : 'broken'), $error) if $error;
      $ctx->{'pool_local'} = $pool if $is_identical && $myarch eq $buildarch && $buildarch ne $localbuildarch;
    }
    my $xp = BSSolv::expander->new($pool, $bconf);
    no warnings 'redefine';
    local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
    use warnings 'redefine';
    my ($eok, @kdeps) = Build::get_sysbuild($bconf, 'kiwi-product', [ grep {/^kiwi-.*:/} @{$info->{'dep'} || []} ]);
    if (!$eok) {
      BSSched::BuildJob::add_expanddebug($ctx, 'kiwi sysdeps expansion', $xp) if $ctx->{'expanddebug'};
      if ($ctx->{'verbose'}) {
        print "      - $packid (kiwi-product)\n";
        print "        unresolvable for sysbuild:\n";
        print "          $_\n" for @kdeps;
      }
      return ('unresolvable', join(', ', @kdeps));
    }
    for my $p ($pool->consideredpackages()) {
      $dep2pkg{$pool->pkg2name($p)} = $p;
    }
    # check access
    for my $aprp (@aprps) {
      if (!$ctx->checkprpaccess($aprp)) {
	if ($ctx->{'verbose'}) {
	  print "      - $packid (kiwi-product)\n";
	  print "        repository '$aprp' is unavailable\n";
	}
	return ('broken', "repository '$aprp' is unavailable");
      }
    }
    # check if we are blocked
    if ($myarch ne $localbuildarch) {
      my %used;
      for my $bin (@kdeps) {
	my $p = $dep2pkg{$bin};
	my $aprp = $pool->pkg2reponame($p);
	my $pname = $pool->pkg2srcname($p);
	push @{$used{$aprp}}, $pname;
      }
      for my $aprp (@aprps) {
	my ($aprojid, $arepoid) = split('/', $aprp, 2);
	next if $remoteprojs->{$aprojid};	# FIXME: should do something here
	my %pnames = map {$_ => 1} @{$used{$aprp}};
	next unless %pnames;
	next if $neverblock;
	my $ps = $ctx->read_packstatus($aprp, $localbuildarch);
	# FIXME: this assumes packid == pname
	push @blocked, grep {$ps->{$_} && ($ps->{$_} eq 'scheduled' || $ps->{$_} eq 'blocked' || $ps->{$_} eq 'finished')} sort keys %pnames;
      }
      if ($markerdir) {
        if (@blocked) {
	  if (! -e "$markerdir/.waiting_for_$localbuildarch") {
	    mkdir_p($markerdir);
	    BSUtil::touch("$markerdir/.waiting_for_$localbuildarch");
	  }
        } else {
	  unlink("$markerdir/.waiting_for_$localbuildarch");
	}
      }
    } else {
      my $notready = $ctx->{'notready'};
      my $prpnotready = $gctx->{'prpnotready'};
      for my $bin (@kdeps) {
	my $p = $dep2pkg{$bin};
	my $aprp = $pool->pkg2reponame($p);
	my $pname = $pool->pkg2srcname($p);
	my $nr = ($prp eq $aprp ? $notready : $prpnotready->{$aprp}) || {};
	push @blocked, $bin if $nr->{$pname};
      }
    }
    @blocked = () if $neverblock;
    if (@blocked) {
      splice(@blocked, 10, scalar(@blocked), '...') if @blocked > 10;
      if ($ctx->{'verbose'}) {
        print "      - $packid (kiwi-product)\n";
        print "        blocked for sysbuild (@blocked)\n";
      }
      return ('blocked', join(', ', @blocked));
    }
    push @rpms, @kdeps;
    if ($myarch eq $buildarch) {
      my $dods = BSSched::DoD::dodcheck($ctx, $pool, $localbuildarch, @kdeps);
      return ('blocked', $dods) if $dods;
    }
  }

  # check right away if some gbininfo fetch is in progress
  my $delayed_errors = '';
  if (!$ctx->{'isreposerver'}) {
    for my $aprp (@aprps) {
      my ($aprojid, $arepoid) = split('/', $aprp, 2);
      next unless $remoteprojs->{$aprojid};
      for my $arch (reverse @archs) {
        next if $myarch ne $buildarch && $myarch ne $arch;
	$delayed_errors .= ", project binary state of $aprp/$arch is unavailable" if $ctx->gbininfo_is_delayed($aprp, $arch);
      }
    }
    if ($delayed_errors) {
      substr($delayed_errors, 0, 2, '');
      if ($ctx->{'verbose'}) {
        print "      - $packid (kiwi-product)\n";
        print "        $delayed_errors (delayed)\n";
      }
      return ('delayed', $delayed_errors);
    }
  }

  my $allpacks = $deps{'*'} ? 1 : 0;
  my $nodbgpkgs = $info->{'nodbgpkgs'};
  my $nosrcpkgs = $info->{'nosrcpkgs'};

  my $pkgs_checked = 0;
  my $pkgs_taken = 0;
  my $mode = 0;
  $mode |= 1 if $nodbgpkgs;
  $mode |= 2 if $nosrcpkgs;
  $mode |= 4 if $allpacks;

  my $maxblocked = 20;
  my %blockedarch;
  my $projpacks = $gctx->{'projpacks'};
  my %unneeded_na;
  my %archs = map {$_ => 1} @archs;
  my $dobuildinfo = $ctx->{'dobuildinfo'};

  for my $aprp (@aprps) {
    my %seen_fn;	# resolve file conflicts in this prp
    my %known;
    my ($aprojid, $arepoid) = split('/', $aprp, 2);
    my $aproj = $projpacks->{$aprojid} || {};
    $aproj = $remoteprojs->{$aprojid} if $remoteprojs->{$aprojid};
    my $pdatas = $aproj->{'package'} || {};
    my @apackids = sort keys %$pdatas;
    my $is_maintenance_release = ($aproj->{'kind'} || '') eq 'maintenance_release' ? 1 : 0;
    my @next_unneeded_na;
    for my $arch (reverse @archs) {
      next if $myarch ne $buildarch && $myarch ne $arch;
      my $ps = {};
      $ps = $ctx->read_packstatus($aprp, $arch) unless $neverblock || $remoteprojs->{$aprojid};
      my $gbininfo = $ctx->read_gbininfo($aprp, $arch, $ps);
      if (!$gbininfo && $remoteprojs->{$aprojid}) {
	my $error = "project binary state of $aprp/$arch is unavailable";
	if (defined $gbininfo) {
	  $delayed_errors .= ", $error";
	  next;
	}
	if ($ctx->{'verbose'}) {
	  print "      - $packid (kiwi-product)\n";
	  print "        $error\n";
	}
	return ('broken', $error);
      }
      next if $delayed_errors;
      if (!$gbininfo && $arch ne $myarch && $gctx->{'eventdir'} && -d "$gctx->{'eventdir'}/$arch") {
	# mis-use unblocked to tell other scheduler that it is missing
	print "    requesting :repoinfo for $aprp/$arch\n" if $ctx->{'verbose'};
	$ctx->{'sendunblockedevents'}->{"$aprp/$arch"} = 2;
      }

      # XXX: move into checker
      my $blocked_cache = {};
      if (!$neverblock) {
	$blocked_cache = $ctx->{'blocked_cache'}->{"$aprp/$arch"};
	if (!$blocked_cache) {
	  $blocked_cache = {};
	  for (keys %$ps) {
	    my $code = $ps->{$_} || '';
	    $blocked_cache->{$_} = 1 if $code eq 'scheduled' || $code eq 'blocked' || $code eq 'finished';
	  }
	  $ctx->{'blocked_cache'}->{"$aprp/$arch"} = $blocked_cache;
	}
      }

      if ($gbininfo) {
	# we only take rpms when we have entries in the bininfo, so just check the blocked state for
	# all packages not yet in gbininfo
	# this is a bit of code duplication, but can't be helped (perl function calls are slow)
	for my $apackid (grep {$blocked_cache->{$_} && !exists($gbininfo->{$_})} @apackids) {
	  next if ($pdatas->{$apackid} || {})->{'patchinfo'};
	  if (!exists($known{$apackid})) {
	    my $info = (grep {$_->{'repository'} eq $arepoid} @{$pdatas->{$apackid}->{'info'} || []})[0];
	    $known{$apackid} = ($info || {})->{'name'} || $apackid;
	  }
	  my $apackid2 = $known{$apackid} || $apackid;
	  # crude check if the "main" binary is needed
	  if (($allpacks && !$deps{"-$apackid"} && !$deps{"-$apackid2"}) || $deps{$apackid} || $deps{$apackid2}) {
	    # hey, we probably need this package! wait till it's finished
	    push @blocked, "$aprp/$arch/$apackid";
	    $blockedarch{$arch} = 1;
	    last if @blocked > $maxblocked;
	    next;
	  }
	}
	last if @blocked > $maxblocked;
	# now check just the gbininfo entries
	@apackids = keys %$gbininfo;
      }

      # just for maintenance_release project handling, in that case we
      # use the binary from the container with the highest number if
      # some containers contain the same binary.
      my $seen_binary = $is_maintenance_release ? {} : undef;
      my @unneeded_na_revert;

      for my $apackid (BSSched::ProjPacks::orderpackids($aproj, @apackids)) {
	next if $apackid eq '_volatile';
	next if ($pdatas->{$apackid} || {})->{'patchinfo'};

	# fast blocked check
	if ($blocked_cache->{$apackid}) {
	  if (!exists($known{$apackid})) {
	    my $info = (grep {$_->{'repository'} eq $arepoid} @{($pdatas->{$apackid} || {})->{'info'} || []})[0];
	    $known{$apackid} = ($info || {})->{'name'} || $apackid;
	  }
	  my $apackid2 = $known{$apackid} || $apackid;
	  # crude check if the "main" binary is needed
	  if (($allpacks && !$deps{"-$apackid"} && !$deps{"-$apackid2"}) || $deps{$apackid} || $deps{$apackid2}) {
	    # hey, we probably need this package! wait till it's finished
	    push @blocked, "$aprp/$arch/$apackid";
	    $blockedarch{$arch} = 1;
	    last if @blocked > $maxblocked;
	    next;
	  }
	}

	# go through all the rpms in this package
	my $bininfo = $gbininfo ? $gbininfo->{$apackid} : read_bininfo_oldok("$reporoot/$aprp/$arch/$apackid");
	next if !$bininfo || $bininfo->{'.nouseforbuild'};	# skip channels/patchinfos

	$pkgs_checked++;

	# first find out if we need any rpm from this package
	if (defined &BSSolv::kiwiproductcheck) {
	  # use fast C version from perl-BSSolv if available
	  next unless BSSolv::kiwiproductcheck($bininfo, $mode, \%unneeded_na, \%deps, \%seen_fn, \%archs);
	} else {
	  # slow pure-perl version
	  my $needit;
	  for my $fn (keys %$bininfo) {
	    next unless $fn =~ /^(?:::import::.*::)?(.+)-(?:[^-]+)-(?:[^-]+)\.([a-zA-Z][^\.\-]*)\.rpm$/;
	    my ($bn, $ba) = ($1, $2);
	    next if $ba eq 'src' || $ba eq 'nosrc';	# always unneeded
	    my $na = "$bn.$ba";
	    next if $unneeded_na{$na};
	    if ($fn =~ /-(?:debuginfo|debugsource)-/) {
	      if ($nodbgpkgs || !$deps{$bn}) {
		$unneeded_na{$na} = 1;
		next;
	      }
	    }
	    next if $seen_fn{$fn};
	    if ($fn =~ /^::import::(.*?)::(.*)$/) {
	      next if $archs{$1};		# we pick it up from the real arch
	      next if $seen_fn{$2};
	    }
	    if (!($deps{$bn} || ($allpacks && !$deps{"-$bn"}))) {
	      $unneeded_na{$na} = 1;	# cache unneeded
	      next;
	    }
	    $needit = 1;
	    last;
	  }
	  next unless $needit;
	}

	$pkgs_taken++;

	# sort file names, but put imports last
	my @bi = sort(keys %$bininfo);
	my @ibi = grep {/^::import::/} @bi;
	if (@ibi) {
	  @bi = grep {!/^::import::/} @bi;
	  push @bi, @ibi;
	}

	# we need the package, add all rpms
	for my $fn (@bi) {
	  next unless $fn =~ /^(?:::import::.*::)?(.+)-(?:[^-]+)-(?:[^-]+)\.([a-zA-Z][^\.\-]*)\.rpm$/;
	  my ($bn, $ba) = ($1, $2);
	  next if $nosrcpkgs && ($ba eq 'src' || $ba eq 'nosrc');
	  next if $nodbgpkgs && $fn =~ /-(?:debuginfo|debugsource)-/;
	  next if $fn =~ /^::import::(.*?):/ && $archs{$1};	# we pick it up from the real arch
	  my $na = "$bn.$ba";

	  if ($seen_binary && ($ba ne 'src' && $ba ne 'nosrc')) {
	    next if $seen_binary->{$na}++;
	    # we also add the na to the unneeded_na hash so that we do
	    # not have to check the seen_binary hash when testing if we
	    # need this package. This also means that we need to revert
	    # this when we are done with the architecture
	    push @unneeded_na_revert, $na unless $unneeded_na{$na}++;
	  }

	  # ignore if we already have this file (maybe from a different scheduler arch)
	  # we need to do this after the seen_binary test above
	  next if $seen_fn{$fn};
	  next if $fn =~ /^::import::(.*?)::(.*)$/ && $seen_fn{$2};

	  my $b = $bininfo->{$fn};
	  my $rpm = "$aprp/$arch/$apackid/$fn";
	  push @rpms, $rpm;
	  $rpms_hdrmd5{$rpm} = $b->{'hdrmd5'} if $b->{'hdrmd5'};
	  $rpms_meta{$rpm} = "$aprp/$arch/$apackid/$na";
	  $seen_fn{$fn} = 1;
	  push @next_unneeded_na, $na unless $ba eq 'src' || $ba eq 'nosrc';
	}

	# our buildinfo data also includes special files like appdata
	if ($dobuildinfo) {
	  for my $fn (@bi) {
            next unless $fn =~ (/[-.]appdata\.xml$/) || $fn eq '_modulemd.yaml';
	    next if $seen_fn{$fn};
	    push @rpms, "$aprp/$arch/$apackid/$fn";
	    $seen_fn{$fn} = 1 unless $fn eq '_modulemd.yaml';	# we expect the modulemd file to be renamed
	  }
	}

	# check if we are blocked
	if ($blocked_cache->{$apackid}) {
	  push @blocked, "$aprp/$arch/$apackid";
	  $blockedarch{$arch} = 1;
	  last if @blocked > $maxblocked;
	}
      }
      last if @blocked > $maxblocked;
      if (@unneeded_na_revert) {
	delete $unneeded_na{$_} for @unneeded_na_revert;
      }
    }
    @next_unneeded_na = () if $deps{'--use-newest-package'};
    # now commit all name.arch entries to the unneeded_na hash
    $unneeded_na{$_} = 1 for @next_unneeded_na;
    last if @blocked > $maxblocked;
  }

  if ($delayed_errors) {
    substr($delayed_errors, 0, 2, '');
    if ($ctx->{'verbose'}) {
      print "      - $packid (kiwi-product)\n";
      print "        $delayed_errors (delayed)\n";
    }
    return ('delayed', $delayed_errors);
  }

  if ($markerdir && $myarch eq $buildarch) {
    # update waiting_for markers
    for my $arch (grep {$_ ne $buildarch} @archs) {
      if ($blockedarch{$arch}) {
	next if -e "$markerdir/.waiting_for_$arch";
	mkdir_p($markerdir);
	BSUtil::touch("$markerdir/.waiting_for_$arch");
      } else {
	unlink("$markerdir/.waiting_for_$arch");
      }
    }
  }
  if (@blocked) {
    push @blocked, '...' if @blocked > $maxblocked;
    if ($ctx->{'verbose'}) {
      print "      - $packid (kiwi-product)\n";
      print "        blocked (@blocked)\n";
    }
    return ('blocked', join(', ', @blocked));
  }

  if (1) {
    my $naprps = scalar(@aprps);
    my $narchs = scalar(@archs);
    print "      - stats for $packid: $pkgs_taken/$pkgs_checked, $naprps aprps, $narchs archs\n";
  }

  if ($myarch ne $buildarch) {
    # looks good from our side. tell master arch to check it
    if ($markerdir && -e "$markerdir/.waiting_for_$myarch") {
      unlink("$markerdir/.waiting_for_$myarch");
      $ctx->{'sendunblockedevents'}->{"$prp/$buildarch"} = 2;
      if ($ctx->{'verbose'}) {
        print "      - $packid (kiwi-product)\n";
        print "        unblocked\n";
      }
    }
    $ctx->{'sendunblockedevents'}->{"$prp/$buildarch"} ||= 1 unless $ctx->{'isreposerver'};
    return ('excluded', "is built in architecture '$buildarch'");
  }

  # now create meta info
  my @new_meta;
  push @new_meta, map {"$_->{'srcmd5'}  $_->{'project'}/$_->{'package'}"} @{$info->{'extrasource'} || []};
  for my $rpm (sort {$rpms_meta{$a} cmp $rpms_meta{$b} || $a cmp $b} grep {$rpms_meta{$_}} @rpms) {
    my $id = $rpms_hdrmd5{$rpm};
    if (!$id) {
      eval { $id = Build::queryhdrmd5("$reporoot/$rpm") };
      $rpms_hdrmd5{$rpm} = $id if $id;
      $id ||= "deaddeaddeaddeaddeaddeaddeaddead";
    }
    push @new_meta, "$id  $rpms_meta{$rpm}";
  }
  return BSSched::BuildJob::metacheck($ctx, $packid, $pdata, 'kiwi-product', \@new_meta, [ $bconf, \@rpms, $pool, \%dep2pkg, \%rpms_hdrmd5 ]);
}


=head2 build - TODO: add summary

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my ($bconf, $rpms, $pool, $dep2pkg, $rpms_hdrmd5, $reason) = @$data;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $repo = $ctx->{'repo'};
  my $relsyncmax = $ctx->{'relsyncmax'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $gdst = $ctx->{'gdst'};
  my $prp = "$projid/$repoid";

  my $dobuildinfo = $ctx->{'dobuildinfo'};
  my @bdeps;
  for my $rpm (BSUtil::unify(@{$rpms || []})) {
    my @b = split('/', $rpm);
    next unless @b == 5;
    my $b;
    if ($b[4] =~ /^(?:::import::.*::)?(.+)-([^-]+)-([^-]+)\.([a-zA-Z][^\.\-]*)\.rpm$/) {
      $b = {
        'name' => $1,
        'version' => $2,
        'release' => $3,
        'arch' => $4,
        'project' => $b[0],
        'repository' => $b[1],
        'repoarch' => $b[2],
        'package' => $b[3],
        'binary' => $b[4],
      };
    } elsif ($dobuildinfo && (($b[4] =~ /[-.]appdata\.xml$/) || $b[4] eq '_modulemd.yaml')) {
      $b = {
        'project' => $b[0],
        'repository' => $b[1],
        'repoarch' => $b[2],
        'package' => $b[3],
        'binary' => $b[4],
      };
    } else {
      next;
    }
    if ($dobuildinfo) {
      $b->{'hdrmd5'} = $rpms_hdrmd5->{$rpm} if $rpms_hdrmd5->{$rpm};
      $b->{'noinstall'} = 1;
      delete $b->{'repoarch'} if $b->{'repoarch'} eq $myarch;
    }
    push @bdeps, $b;
  }
  my $prpsearchpath = $ctx->{'prpsearchpath'};
  $prpsearchpath = [] if !@{$repo->{'path'} || []};

  # setup expander again for now, to be removed
  my $xp = BSSolv::expander->new($pool, $bconf);
  no warnings 'redefine';
  local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
  use warnings 'redefine';

  my $nctx = bless { %$ctx, 'prpsearchpath' => $prpsearchpath, 'conf' => $bconf, 'pool' => $pool, 'dep2pkg' => $dep2pkg, 'extrabdeps' => \@bdeps, 'realctx' => $ctx, 'expander' => $xp}, ref($ctx);
  return BSSched::BuildJob::create($nctx, $packid, $pdata, $info, [], [], $reason, 0);
}

sub read_bininfo_oldok {
  my ($dir) = @_;
  my @s = stat("$dir/.bininfo");
  if (@s) {
    my $bininfo = BSUtil::retrieve("$dir/.bininfo", 1);
    if ($bininfo) {
      $bininfo->{'.bininfo'} = {'id' => "$s[9]/$s[7]/$s[1]"};
      return $bininfo;
    }
    # check the old format cache
    $bininfo = $bininfo_oldok_cache{$dir};
    return $bininfo if $bininfo && $bininfo->{'.bininfo'}->{'id'} eq "$s[9]/$s[7]/$s[1]";
    local *F;
    if (open(F, '<', "$dir/.bininfo")) {
      $bininfo = {};
      while (<F>) {
        chomp;
        if (length($_) <= 34 || substr($_, 32, 2) ne '  ') {
          # seems to be a corrupt file
          undef $bininfo;
          last;
        }
        my $file = substr($_, 34);
        next unless $file =~ /^(?:::import::.*::)?(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/;
        $bininfo->{$file} = {'filename' => $file, 'hdrmd5' => substr($_, 0, 32), 'name' => $1, 'arch' => $2};
      }
      close(F);
      if ($bininfo) {
        $bininfo->{'.bininfo'} = {'id' => "$s[9]/$s[7]/$s[1]"};
        $bininfo_oldok_cache{$dir} = $bininfo;
        return $bininfo;
      }
    }
  }
  my $bininfo = {};
  for my $file (ls($dir)) {
    next unless $file =~ /^(?:::import::.*::)?(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/;
    $bininfo->{$file} = {'filename' => $file, 'name' => $1, 'arch' => $2};
  }
  return $bininfo;
}

1;

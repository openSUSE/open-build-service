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

package BSSched::BuildJob::KiwiImage;

use strict;
use warnings;

use Data::Dumper;
use Build;
use BSSolv;
use BSConfiguration;
use BSSched::BuildJob;  	# for expandkiwipath
use BSSched::DoD;       	# for dodcheck


=head1 NAME

BSSched::BuildJob::KiwiImage - A Class to handle KiwiImage products

=head1 SYNOPSIS

my $h = BSSched::BuildJob::KiwiImage->new()

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

# try to expand container dependencies. This is just for sorting
# purposes, as we re-expand in check() with the correct pool setup.
sub expand {
  my ($self, $bconf, $subpacks, @deps) = @_;
  my @containerdeps = grep {/^container:/} @deps;
  return 1 unless @containerdeps;
  my ($cok, @cdeps) = Build::expand($bconf, @containerdeps);
  return 1 unless $cok;		# continue anyway if the expansion fails as we're not using the correct pool
  return (0, 'weird result of container expansion') unless @cdeps > 0 && @cdeps <= @containerdeps && !grep {!/^container:/} @cdeps;
  return $cok, @cdeps;
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
  my $prp = $ctx->{'prp'};
  my $repo = $ctx->{'repo'};

  my $notready = $ctx->{'notready'};
  my $prpnotready = $gctx->{'prpnotready'};
  my $neverblock = $ctx->{'isreposerver'} || ($repo->{'block'} || '' eq 'never');

  my %aprpprios;
  my @aprps = BSSched::BuildJob::expandkiwipath($ctx, $info, \%aprpprios);
  # get config from kiwi path
  my @configpath = @aprps;
  # always put ourselfs in front
  unshift @configpath, "$projid/$repoid" unless @configpath && $configpath[0] eq "$projid/$repoid";
  my $bconf = $ctx->getconfig($projid, $repoid, $myarch, \@configpath);
  if (!$bconf) {
    if ($ctx->{'verbose'}) {
      print "      - $packid (kiwi-image)\n";
      print "        no config\n";
    }
    return ('broken', 'no config');
  }
  $bconf->{'type'} = 'kiwi';
  $bconf->{'no_vminstall_expand'} = 1 if @{$repo->{'path'} || []};
  my $unorderedrepos = 0;
  if (!grep {$_->{'project'} eq '_obsrepositories'} @{$info->{'path'} || []}) {
    if ($bconf->{"expandflags:unorderedimagerepos"} || grep {$_ eq '--unorderedimagerepos'} @{$info->{'dep'} || []}) {
      $unorderedrepos = 1;
    }
  }

  my $pool;
  if ($ctx->{'pool'} && !$unorderedrepos && BSUtil::identical(\@aprps, $ctx->{'prpsearchpath'})) {
    $pool = $ctx->{'pool'};	# we can reuse the ctx pool, nice!
  } else {
    my ($error, $delayed);
    ($pool, $error, $delayed) = BSSched::BuildJob::createextrapool($ctx, $bconf, \@aprps, $unorderedrepos, \%aprpprios);
    if ($error && $ctx->{'verbose'}) {
      print "      - $packid (kiwi-image)\n";
      print $delayed ? "        $error (delayed)\n" : "        $error\n";
    }
    return (($delayed ? 'delayed' : 'broken'), $error) if $error;
  }

  my $bconfignore = $bconf->{'ignore'};
  my $bconfignoreh = $bconf->{'ignoreh'};
  delete $bconf->{'ignore'};
  delete $bconf->{'ignoreh'};

  my @deps = @{$info->{'dep'} || []};

  my $cpool;	# pool used for container expansion
  my @cbdep;    # container bdep for job
  my @cmeta;    # container meta entry
  my $expanddebug = $ctx->{'expanddebug'};

  my @containerdeps = grep {/^container:/} @deps;
  if (@containerdeps) {
    @deps = grep {!/^container:/} @deps;

    # setup container pool
    $cpool = $ctx->{'pool'};
    if (@{$info->{'containerpath'} || []}) {
      my @cprps = map {"$_->{'project'}/$_->{'repository'}"} @{$info->{'containerpath'}};
      my ($error, $delayed);
      ($cpool, $error, $delayed) = BSSched::BuildJob::createextrapool($ctx, undef, \@cprps);
      return (($delayed ? 'delayed' : 'broken'), $error) if $error;
    }

    # expand the container dependency
    my $xp = BSSolv::expander->new($cpool, $bconf);
    my ($cok, @cdeps) = $xp->expand(@containerdeps);
    BSSched::BuildJob::add_expanddebug($ctx, 'container expansion', $xp, $cpool) if $expanddebug;
    return ('unresolvable', join(', ', @cdeps)) unless $cok;
    return ('unresolvable', 'weird result of container expansion') unless @cdeps > 0 && @cdeps <= @containerdeps && !grep {!/^container:/} @cdeps;

    my $basecontainer = $containerdeps[-1];
    my %basep;
    %basep = map {$_ => 1} $cpool->whatprovides($basecontainer) if $basecontainer;
    my $basecbdep;
    for my $cdep (@cdeps) {
      # find container package
      my $p;
      for ($cpool->whatprovides($cdep)) {
	$p = $_ if $cpool->pkg2name($_) eq $cdep;
      }
      return ('unresolvable', 'weird result of container expansion') unless $p;

      # generate bdep entry
      my $cbdep = {'name' => $cdep, 'noinstall' => 1, 'p' => $p};
      my $cprp = $cpool->pkg2reponame($p);
      push @cmeta, $cpool->pkg2pkgid($p) . "  $cprp/$cdep";
      ($cbdep->{'project'}, $cbdep->{'repository'}) = split('/', $cprp, 2) if $cprp;
      if ($ctx->{'dobuildinfo'}) {
	my $d = $cpool->pkg2data($p);
	$cbdep->{'epoch'} = $d->{'epoch'} if $d->{'epoch'};
	$cbdep->{'version'} = $d->{'version'};
	$cbdep->{'release'} = $d->{'release'} if defined $d->{'release'};
	$cbdep->{'arch'} = $d->{'arch'} if $d->{'arch'};
	$cbdep->{'hdrmd5'} = $d->{'hdrmd5'} if $d->{'hdrmd5'};
      }
      if (!$basecbdep && $basep{$p}) {
	$basecbdep = $cbdep;
      } else {
	push @cbdep, $cbdep;
      }
    }
    push @cbdep, $basecbdep if $basecbdep;	# always put base container last

    # put annotation in dep
    my $annotationbdep = $basecbdep || $cbdep[-1];
    BSSched::BuildJob::getcontainerannotation($cpool, $annotationbdep->{'p'}, $annotationbdep) if $annotationbdep;
  }

  local $Build::expand_dbg = 1 if $expanddebug;
  my $xp = BSSolv::expander->new($pool, $bconf);
  no warnings 'redefine';
  local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
  use warnings 'redefine';
  my ($eok, @edeps) = Build::get_build($bconf, [], @deps, '--ignoreignore--');
  BSSched::BuildJob::add_expanddebug($ctx, 'kiwi image expansion', $xp, $pool) if $expanddebug;
  if (!$eok) {
    if ($ctx->{'verbose'}) {
      print "      - $packid (kiwi-image)\n";
      print "        unresolvable:\n";
      print "            $_\n" for @edeps;
    }
    return ('unresolvable', join(', ', @edeps));
  }
  $bconf->{'ignore'} = $bconfignore if $bconfignore;
  $bconf->{'ignoreh'} = $bconfignoreh if $bconfignoreh;

  my @new_meta;

  my %dep2pkg;
  for my $p ($pool->consideredpackages()) {
    my $n = $pool->pkg2name($p);
    $dep2pkg{$n} = $p;
  }

  my %nrs;
  for my $arepo ($pool->repos()) {
    my $aprp = $arepo->name();
    if ($neverblock) {
      $nrs{$aprp} = {};
    } else {
      $nrs{$aprp} = ($prp eq $aprp ? $notready : $prpnotready->{$aprp}) || {};
    }
  }

  my @blocked;
  if ($cpool && @cbdep && !$neverblock) {
    for my $cbdep (@cbdep) {
      my $p = $cbdep->{'p'};
      my $aprp = $cpool->pkg2reponame($p);
      my $n = $cbdep->{'name'};
      $n =~ s/^container://;
      if ($prp eq $aprp) {
        push @blocked, $n if $notready->{$n};
      } else {
        push @blocked, "$aprp/$n" if $prpnotready->{$aprp}->{$n};
      }
    }
  }
  for my $n (sort @edeps) {
    my $p = $dep2pkg{$n};
    my $aprp = $pool->pkg2reponame($p);
    my $pname = $pool->pkg2srcname($p);
    push @blocked, $prp ne $aprp ? "$aprp/$n" : $n if $nrs{$aprp}->{$pname};
    push @new_meta, $pool->pkg2pkgid($p)."  $aprp/$n" unless @blocked;
  }
  if (@blocked) {
    splice(@blocked, 10, scalar(@blocked), '...') if @blocked > 10;
    if ($ctx->{'verbose'}) {
      print "      - $packid (kiwi-image)\n";
      print "        blocked (@blocked)\n";
    }
    return ('blocked', join(', ', @blocked));
  }
  push @new_meta, @cmeta;
  @new_meta = sort {substr($a, 34) cmp substr($b, 34) || $a cmp $b} @new_meta;
  unshift @new_meta, map {"$_->{'srcmd5'}  $_->{'project'}/$_->{'package'}"} @{$info->{'extrasource'} || []};
  my ($state, $data) = BSSched::BuildJob::metacheck($ctx, $packid, $pdata, 'kiwi-image', \@new_meta, [ $bconf, \@edeps, $pool, \%dep2pkg, \@cbdep, $unorderedrepos ]);
  if ($state eq 'scheduled') {
    my $dods = BSSched::DoD::dodcheck($ctx, $pool, $myarch, @edeps);
    return ('blocked', $dods) if $dods;
    $dods = BSSched::DoD::dodcheck($ctx, $cpool, $myarch, map {$_->{'name'}} @cbdep) if $cpool && @cbdep;
    return ('blocked', $dods) if $dods;
  }
  return ($state, $data);
}


=head2 build - TODO: add summary

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  # bconf is the config used to expand the image packages
  my ($bconf, $edeps, $epool, $edep2pkg, $cbdep, $unorderedrepos, $reason) = @$data;
  my $gctx = $ctx->{'gctx'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $repo = $ctx->{'repo'};

  if (!$ctx->{'conf_host'} && !@{$repo->{'path'} || []}) {
    # repo has no path and not cross building, use kiwi repositories also for kiwi system setup
    my $xp = BSSolv::expander->new($epool, $bconf);
    no warnings 'redefine';
    local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
    use warnings 'redefine';
    $ctx = bless { %$ctx, 'conf' => $bconf, 'prpsearchpath' => [], 'pool' => $epool, 'dep2pkg' => $edep2pkg, 'realctx' => $ctx, 'expander' => $xp, 'unorderedrepos' => $unorderedrepos}, ref($ctx);
    BSSched::BuildJob::add_container_deps($ctx, $cbdep) if @{$cbdep || []};
    return BSSched::BuildJob::create($ctx, $packid, $pdata, $info, [], $edeps, $reason, 0);
  }

  my $extrabdeps;
  if ($ctx->{'dobuildinfo'} || $unorderedrepos) {
    # need to dump the image packages first...
    my @bdeps;
    for my $n (@$edeps) {
      my $b = {'name' => $n};
      my $p = $edep2pkg->{$n};
      my $d = $epool->pkg2data($p);
      my $prp = $epool->pkg2reponame($p);
      ($b->{'project'}, $b->{'repository'}) = split('/', $prp, 2) if $prp;
      if ($ctx->{'dobuildinfo'}) {
        $b->{'epoch'} = $d->{'epoch'} if $d->{'epoch'};
        $b->{'version'} = $d->{'version'};
        $b->{'release'} = $d->{'release'} if defined $d->{'release'};
        $b->{'arch'} = $d->{'arch'} if $d->{'arch'};
        $b->{'hdrmd5'} = $d->{'hdrmd5'} if $d->{'hdrmd5'};
      }
      $b->{'noinstall'} = 1;
      push @bdeps, $b;
    }
    $extrabdeps = \@bdeps;
    $edeps = [];
  }

  if ($ctx->{'conf_host'}) {
    my $xp = BSSolv::expander->new($ctx->{'pool_host'}, $ctx->{'conf_host'});
    no warnings 'redefine';
    local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
    use warnings 'redefine';
    $ctx = bless { %$ctx, 'conf' => $ctx->{'conf_host'}, 'pool' => $ctx->{'pool_host'}, 'dep2pkg' => $ctx->{'dep2pkg_host'}, 'realctx' => $ctx, 'expander' => $xp, 'prpsearchpath' => $ctx->{'prpsearchpath_host'} }, ref($ctx);
    $ctx->{'extrabdeps'} = $extrabdeps if $extrabdeps;
    BSSched::BuildJob::add_container_deps($ctx, $cbdep) if @{$cbdep || []};
    return BSSched::BuildJob::create($ctx, $packid, $pdata, $info, [], $edeps, $reason, 0);
  }

  # clone the ctx so we can change it
  $ctx = bless { %$ctx, 'realctx' => $ctx}, ref($ctx);
  $ctx->{'extrabdeps'} = $extrabdeps if $extrabdeps;

  BSSched::BuildJob::add_container_deps($ctx, $cbdep) if @{$cbdep || []};

  # repo has a configured path, expand kiwi build system with it
  return BSSched::BuildJob::create($ctx, $packid, $pdata, $info, [], $edeps, $reason, 0);
}

1;

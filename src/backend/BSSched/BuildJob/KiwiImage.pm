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
  my $prp = $ctx->{'prp'};
  my $repo = $ctx->{'repo'};

  my $notready = $ctx->{'notready'};
  my $prpnotready = $gctx->{'prpnotready'};
  my $neverblock = $ctx->{'isreposerver'} || ($repo->{'block'} || '' eq 'never');

  my @aprps = BSSched::BuildJob::expandkiwipath($info, $ctx->{'prpsearchpath'});
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

  my $pool = BSSolv::pool->new();
  $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';

  my $delayed_errors = '';
  for my $aprp (@aprps) {
    if (!$ctx->checkprpaccess($aprp)) {
      if ($ctx->{'verbose'}) {
        print "      - $packid (kiwi-image)\n";
        print "        repository $aprp is unavailable";
      }
      return ('broken', "repository $aprp is unavailable");
    }
    my $r = $ctx->addrepo($pool, $aprp);
    if (!$r) {
      my $error = "repository '$aprp' is unavailable";
      if (defined $r) {
	$error .= " (delayed)";
	$delayed_errors .= ", $error";
	next;
      }
      if ($ctx->{'verbose'}) {
        print "      - $packid (kiwi-image)\n";
        print "        $error\n";
      }
      return ('broken', $error);
    }
  }
  return ('delayed', substr($delayed_errors, 2)) if $delayed_errors;
  $pool->createwhatprovides();
  my $bconfignore = $bconf->{'ignore'};
  my $bconfignoreh = $bconf->{'ignoreh'};
  delete $bconf->{'ignore'};
  delete $bconf->{'ignoreh'};

  my $cbdep;
  my @deps = @{$info->{'dep'} || []};
  my $cprp;
  my $cdep;
  my $cmeta;
  if (grep {/^container:/} @deps) {
    for my $dep (splice @deps) {
      if ($dep =~ /^container:([^\/]*\/[^\/]*)\/(.+)$/) {
	return ('broken', 'multiple containers') if $cprp;
	$cprp = $1;
	$cdep = "container:$2";
      } else {
	push @deps, $dep;
      }
    }
  }
  if ($cprp) {
    my $cpool;
    if ($cprp eq '_obsrepositories/') {
      $cpool = $ctx->{'pool'};
    } else {
      return ('broken', "repository $cprp is unavailable") if !$ctx->checkprpaccess($cprp);
      $cpool = BSSolv::pool->new();
      my $r = $ctx->addrepo($cpool, $cprp);
      if (!$r) {
	return ('delayed', "repository '$cprp' is unavailable (delayed)") if defined $r;
	return ('broken', "repository '$cprp' is unavailable");
      }
      $cpool->createwhatprovides();
    }
    my $xp = BSSolv::expander->new($cpool, $bconf);
    my ($cok, @cdeps) = $xp->expand($cdep);
    if (!$cok) {
      return ('unresolvable', join(', ', @cdeps));
    }
    return ('unresolvable', 'weird result of container expansion') if @cdeps != 1;
    my $p;
    for ($cpool->whatprovides($cdeps[0])) {
      $p = $_ if $cpool->pkg2name($_) eq $cdeps[0];
    }
    return ('unresolvable', 'weird result of container expansion') unless $p;
    $cbdep = {'name' => $cdeps[0], 'noinstall' => 1};
    ($cbdep->{'project'}, $cbdep->{'repository'}) = split('/', $cprp, 2);
    $cprp = $cpool->pkg2reponame($p);
    $cmeta = $cpool->pkg2pkgid($p) . "  $cprp/$cdeps[0]";
    if ($ctx->{'dobuildinfo'}) {
      ($cbdep->{'project'}, $cbdep->{'repository'}) = split('/', $cprp, 2) if $cprp;
      my $d = $cpool->pkg2data($p);
      $cbdep->{'epoch'} = $d->{'epoch'} if $d->{'epoch'};
      $cbdep->{'version'} = $d->{'version'};
      $cbdep->{'release'} = $d->{'release'} if defined $d->{'release'};
      $cbdep->{'arch'} = $d->{'arch'} if $d->{'arch'};
    }
  }

  my $expanddebug = $ctx->{'expanddebug'};
  local $Build::expand_dbg = 1 if $expanddebug;
  my $xp = BSSolv::expander->new($pool, $bconf);
  no warnings 'redefine';
  local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
  use warnings 'redefine';
  my ($eok, @edeps) = Build::get_build($bconf, [], @deps, '--ignoreignore--');
  BSSched::BuildJob::add_expanddebug($ctx, 'kiwi image expansion', $xp) if $expanddebug;
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
  for my $n (sort @edeps) {
    my $p = $dep2pkg{$n};
    my $aprp = $pool->pkg2reponame($p);
    push @blocked, $prp ne $aprp ? "$aprp/$n" : $n if $nrs{$aprp}->{$n};
    push @new_meta, $pool->pkg2pkgid($p)."  $aprp/$n" unless @blocked;
  }
  if (@blocked) {
    if ($ctx->{'verbose'}) {
      print "      - $packid (kiwi-image)\n";
      if (@blocked < 11) {
	print "        blocked (@blocked)\n";
      } else {
	print "        blocked (@blocked[0..9] ...)\n";
      }
    }
    return ('blocked', join(', ', @blocked));
  }
  push @new_meta, $cmeta if $cmeta;
  @new_meta = sort {substr($a, 34) cmp substr($b, 34)} @new_meta;
  unshift @new_meta, map {"$_->{'srcmd5'}  $_->{'project'}/$_->{'package'}"} @{$info->{'extrasource'} || []};
  my ($state, $data) = BSSched::BuildJob::metacheck($ctx, $packid, $pdata, 'kiwi-image', \@new_meta, [ $bconf, \@edeps, $pool, \%dep2pkg, $cbdep, $cprp ]);
  if ($BSConfig::enable_download_on_demand && $state eq 'scheduled') {
    my $dods = BSSched::DoD::dodcheck($ctx, $pool, $myarch, @edeps);
    return ('blocked', $dods) if $dods;
  }
  return ($state, $data);
}


=head2 build - TODO: add summary

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my $bconf = $data->[0];	# this is the config used to expand the image packages
  my $edeps = $data->[1];
  my $epool = $data->[2];
  my $edep2pkg = $data->[3];
  my $cbdep = $data->[4];
  my $cprp = $data->[5];
  my $reason = $data->[6];

  my $gctx = $ctx->{'gctx'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $repo = $ctx->{'repo'};

  if (!@{$repo->{'path'} || []}) {
    # repo has no path, use kiwi repositories also for kiwi system setup
    my $xp = BSSolv::expander->new($epool, $bconf);
    no warnings 'redefine';
    local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
    use warnings 'redefine';
    $ctx = bless { %$ctx, 'conf' => $bconf, 'prpsearchpath' => [], 'pool' => $epool, 'dep2pkg' => $edep2pkg, 'realctx' => $ctx, 'expander' => $xp}, ref($ctx);
    $ctx->{'extrabdeps'} = [ $cbdep ] if $cbdep;
    $ctx->{'containerpath'} = [ $cprp ] if $cbdep && $cprp;
    return BSSched::BuildJob::create($ctx, $packid, $pdata, $info, [], $edeps, $reason, 0);
  }
  if ($ctx->{'dobuildinfo'}) {
    # need to dump the image packages first...
    my @bdeps;
    for my $n (@$edeps) {
      my $b = {'name' => $n};
      my $p = $edep2pkg->{$n};
      my $d = $epool->pkg2data($p);
      my $prp = $epool->pkg2reponame($p);
      ($b->{'project'}, $b->{'repository'}) = split('/', $prp, 2) if $prp;
      $b->{'epoch'} = $d->{'epoch'} if $d->{'epoch'};
      $b->{'version'} = $d->{'version'};
      $b->{'release'} = $d->{'release'} if defined $d->{'release'};
      $b->{'arch'} = $d->{'arch'} if $d->{'arch'};
      $b->{'noinstall'} = 1;
      push @bdeps, $b;
    }
    $edeps = [];
    push @bdeps, $cbdep if $cbdep;
    $ctx = bless { %$ctx, 'extrabdeps' => \@bdeps, 'realctx' => $ctx}, ref($ctx);
    $ctx->{'containerpath'} = [ $cprp ] if $cbdep && $cprp;
  } elsif ($cbdep) {
    $ctx = bless { %$ctx, 'extrabdeps' => [ $cbdep ], 'realctx' => $ctx}, ref($ctx);
    $ctx->{'containerpath'} = [ $cprp ] if $cbdep && $cprp;
  }
  # repo has a configured path, expand kiwi build system with it
  return BSSched::BuildJob::create($ctx, $packid, $pdata, $info, [], $edeps, $reason, 0);
}

1;

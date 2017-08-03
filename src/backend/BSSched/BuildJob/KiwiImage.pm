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

use Build;
use BSSolv;
use BSConfiguration;
use BSSched::BuildJob;  	# for expandkiwipath
use BSSched::DoD;       	# for dodcheck
use BSSched::ProjPacks;         # for getconfig


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

  my @aprps = BSSched::BuildJob::expandkiwipath($info, $ctx->{'prpsearchpath'});
  # get config from kiwi path
  my $bconf = BSSched::ProjPacks::getconfig($gctx, $projid, $repoid, $myarch, \@aprps);
  if (!$bconf) {
    print "      - $packid (kiwi-image)\n";
    print "        no config\n";
    return ('broken', 'no config');
  }

  my $pool = BSSolv::pool->new();
  $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';

  my $delayed_errors = '';
  for my $aprp (@aprps) {
    if (!$ctx->checkprpaccess($aprp)) {
      print "      - $packid (kiwi-image)\n";
      print "        repository $aprp is unavailable";
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
      print "      - $packid (kiwi-image)\n";
      print "        $error\n";
      return ('broken', $error);
    }
  }
  return ('delayed', substr($delayed_errors, 2)) if $delayed_errors;
  $pool->createwhatprovides();
  my $bconfignore = $bconf->{'ignore'};
  my $bconfignoreh = $bconf->{'ignoreh'};
  delete $bconf->{'ignore'};
  delete $bconf->{'ignoreh'};

  my @deps = @{$info->{'dep'} || []};
  my $xp = BSSolv::expander->new($pool, $bconf);
  no warnings 'redefine';
  local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
  use warnings 'redefine';
  my ($eok, @edeps) = Build::get_build($bconf, [], @deps, '--ignoreignore--');
  if (!$eok) {
    print "      - $packid (kiwi-image)\n";
    print "        unresolvable:\n";
    print "            $_\n" for @edeps;
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

  my $notready = $ctx->{'notready'};
  my $prpnotready = $gctx->{'prpnotready'};
  my %nrs;
  for my $arepo ($pool->repos()) {
    my $aprp = $arepo->name();
    if (!$repo->{'block'} || $repo->{'block'} ne 'never') {
      $nrs{$aprp} = ($prp eq $aprp ? $notready : $prpnotready->{$aprp}) || {};
    } else {
      $nrs{$aprp} = {};
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
    print "      - $packid (kiwi-image)\n";
    if (@blocked < 11) {
      print "        blocked (@blocked)\n";
    } else {
      print "        blocked (@blocked[0..9] ...)\n";
    }
    return ('blocked', join(', ', @blocked));
  }
  @new_meta = sort {substr($a, 34) cmp substr($b, 34)} @new_meta;
  unshift @new_meta, map {"$_->{'srcmd5'}  $_->{'project'}/$_->{'package'}"} @{$info->{'extrasource'} || []};
  unshift @new_meta, ($pdata->{'verifymd5'} || $pdata->{'srcmd5'})."  $packid";
  my ($state, $data) = BSSched::BuildJob::metacheck($ctx, $packid, 'kiwi-image', \@new_meta, [ $bconf, \@edeps ]);
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
  my $bconf = $data->[0];
  my $edeps = $data->[1];
  my $reason = $data->[2];

  my $gctx = $ctx->{'gctx'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $repo = $ctx->{'repo'};

  if (!@{$repo->{'path'} || []}) {
    # repo has no path, use kiwi repositories also for kiwi system setup
    my $prp = "$projid/$repoid";
    my @aprps = BSSched::BuildJob::expandkiwipath($info, $ctx->{'prpsearchpath'});
    # setup pool again for kiwi system expansion
    my $pool = BSSolv::pool->new();
    $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';
    for my $aprp (@aprps) {
      if (!$ctx->checkprpaccess($aprp)) {
        print "      - $packid (kiwi-image)\n";
        print "        repository $aprp is unavailable";
        return ('broken', "repository $aprp is unavailable");
      }
      my $r = $ctx->addrepo($pool, $aprp);
      if (!$r) {
        my $error = "repository '$aprp' is unavailable";
        $error .= " (delayed)" if defined $r;
        print "      - $packid (kiwi-image)\n";
        print "        $error\n";
        return ('delayed', $error) if defined $r;
        return ('broken', $error);
      }
    }
    $pool->createwhatprovides();
    my $xp = BSSolv::expander->new($pool, $bconf);
    no warnings 'redefine';
    local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
    use warnings 'redefine';
    return BSSched::BuildJob::create({ %$ctx, 'conf' => $bconf, 'prpsearchpath' => [], 'pool' => $pool, 'realctx' => $ctx }, $packid, $pdata, $info, [], $edeps, $reason, 0);
  } else {
    # repo has a configured path, expand kiwi system with it
    my $prp = "$projid/$repoid";
    return ('broken', 'no config') unless $bconf;       # should not happen
    return BSSched::BuildJob::create($ctx, $packid, $pdata, $info, [], $edeps, $reason, 0);
  }
}

1;

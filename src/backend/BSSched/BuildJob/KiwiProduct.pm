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

  my @aprps = BSSched::BuildJob::expandkiwipath($info, $ctx->{'prpsearchpath'});
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
  }

  my @blocked;
  my @rpms;
  my %rpms_meta;
  my %rpms_hdrmd5;
  my $neverblock = $ctx->{'isreposerver'};

#print "prps: @aprps\n";
#print "archs: @archs\n";
#print "deps: @deps\n";
  my $pool;
  my %dep2pkg;
  if ($myarch eq $buildarch || $myarch eq $localbuildarch) {
    # calculate packages needed for building
    $pool = BSSolv::pool->new();
    $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';
    my $delayed_errors = '';
    for my $aprp (@bprps) {
      if (!$ctx->checkprpaccess($aprp)) {
	if ($ctx->{'verbose'}) {
	  print "      - $packid (kiwi-product)\n";
	  print "        repository $aprp is unavailable";
	}
	return ('broken', "repository $aprp is unavailable");
      }
      my $r = $ctx->addrepo($pool, $aprp, $localbuildarch);
      if (!$r) {
	my $error = "repository '$aprp' is unavailable";
	$error .= " (delayed)" if defined $r;
	if ($ctx->{'verbose'}) {
	  print "      - $packid (kiwi-product)\n";
	  print "        $error\n";
	}
	if (defined $r) {
	  $delayed_errors .= ", $error";
	  next;
	}
	return ('broken', $error);
      }
    }
    return ('delayed', substr($delayed_errors, 2)) if $delayed_errors;
    $pool->createwhatprovides();
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
	  print "        repository $aprp is unavailable for sysbuild";
	}
	return ('broken', "repository $aprp is unavailable");
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
	my %pnames = map {$_ => 1} @{$used{$aprp}};
	next unless %pnames;
	# FIXME: does not work for remote repos
	my $ps = BSUtil::retrieve("$reporoot/$aprp/$localbuildarch/:packstatus", 1);
	if (!$ps) {
	  $ps = (readxml("$reporoot/$aprp/$localbuildarch/:packstatus", $BSXML::packstatuslist, 1) || {})->{'packstatus'} || [];
	  $ps = { 'packstatus' => { map {$_->{'name'} => $_->{'status'}} @$ps } };
	}
	$ps = ($ps || {})->{'packstatus'} || {};
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
      if ($ctx->{'verbose'}) {
        print "      - $packid (kiwi-product)\n";
        if (@blocked < 10) {
          print "        blocked for sysbuild (@blocked)\n";
        } else {
          print "        blocked for sysbuild (@blocked[0..9] ...)\n";
        }
      }
      return ('blocked', join(', ', @blocked));
    }
    push @rpms, @kdeps;
    if ($BSConfig::enable_download_on_demand && $myarch eq $buildarch) {
      my $dods = BSSched::DoD::dodcheck($ctx, $pool, $localbuildarch, @kdeps);
      return ('blocked', $dods) if $dods;
    }
  }

  my $allpacks = $deps{'*'} ? 1 : 0;
  my $nodbgpkgs = $info->{'nodbgpkgs'};
  my $nosrcpkgs = $info->{'nosrcpkgs'};

  my $maxblocked = 20;
  my %blockedarch;
  my $delayed_errors = '';
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  for my $aprp (@aprps) {
    my %known;
    my ($aprojid, $arepoid) = split('/', $aprp, 2);
    my $aproj = $projpacks->{$aprojid} || {};
    $aproj = $remoteprojs->{$aprojid} if $remoteprojs->{$aprojid};
    my $pdatas = $aproj->{'package'} || {};
    my @apackids = sort keys %$pdatas;
    for my $apackid (@apackids) {
      next if $pdatas->{$apackid}->{'patchinfo'};
      my $info = (grep {$_->{'repository'} eq $arepoid} @{$pdatas->{$apackid}->{'info'} || []})[0];
      $known{$apackid} = $info->{'name'} if $info && $info->{'name'};
    }
    for my $arch (@archs) {
      next if $myarch ne $buildarch && $myarch ne $arch;
      my $ps = BSUtil::retrieve("$reporoot/$aprp/$arch/:packstatus", 1);
      if (!$ps) {
	$ps = (readxml("$reporoot/$aprp/$arch/:packstatus", $BSXML::packstatuslist, 1) || {})->{'packstatus'} || [];
	$ps = { 'packstatus' => { map {$_->{'name'} => $_->{'status'}} @$ps } };
      }
      $ps = ($ps || {})->{'packstatus'} || {};

      my $gbininfo = $ctx->read_gbininfo($aprp, $arch, $ps);
      if (!$gbininfo && $remoteprojs->{$aprojid}) {
	my $error = "project binary state of $aprp/$arch is unavailable";
	$error .= " (delayed)" if defined $gbininfo;
	if ($ctx->{'verbose'}) {
	  print "      - $packid (kiwi-product)\n";
	  print "        $error\n";
	}
	if (defined $gbininfo) {
	  $delayed_errors .= ", $error";
	  next;
	}
	return ('broken', $error);
      }
      next if $delayed_errors;
      if (!$gbininfo && $arch ne $myarch && $gctx->{'eventdir'} && -d "$gctx->{'eventdir'}/$arch") {
	# mis-use unblocked to tell other scheduler that it is missing
	print "    requesting :repoinfo for $aprp/$arch\n" if $ctx->{'verbose'};
	$ctx->{'sendunblockedevents'}->{"$aprp/$arch"} = 2;
      }
      @apackids = BSUtil::unify(@apackids, sort keys %$gbininfo) if $gbininfo;

      # just for maintenance_release project handling, in that case we
      # use the binary from the container with the highest number if
      # some containers contain the same binary.
      my $seen_binary;
      $seen_binary = {} if ($aproj->{'kind'} || '') eq 'maintenance_release';

      for my $apackid (BSSched::ProjPacks::orderpackids($aproj, @apackids)) {
	next if $apackid eq '_volatile';
	next if ($pdatas->{$apackid} || {})->{'patchinfo'};

	if (($allpacks && !$deps{"-$apackid"} && !$deps{'-'.($known{$apackid} || '')}) || $deps{$apackid} || $deps{$known{$apackid} || ''}) {
	  # hey, we probably need this package! wait till it's finished
	  my $code = $ps->{$apackid} || 'unknown';
	  if (!$neverblock && ($code eq 'scheduled' || $code eq 'blocked' || $code eq 'finished')) {
	    push @blocked, "$aprp/$arch/$apackid";
	    $blockedarch{$arch} = 1;
	    last if @blocked > $maxblocked;
	    next;
	  }
	}

	# hmm, we don't know if we really need it. check bininfo.
	my $bininfo;
	if ($gbininfo) {
	  $bininfo = $gbininfo->{$apackid} || {};
	} else {
	  $bininfo = read_bininfo_oldok("$reporoot/$aprp/$arch/$apackid");
	}

	# skip channels/patchinfos
	next if $bininfo->{'.nouseforbuild'};

	my @got;
	my $needit;
	my @bi = sort(keys %$bininfo);
	# put imports last
	my @ibi = grep {/^::import::/} @bi;
	if (@ibi) {
	  @bi = grep {!/^::import::/} @bi;
	  push @bi, @ibi;
	}
	for my $fn (@bi) {
	  next unless $fn =~ /\.rpm$/;
	  next if $nodbgpkgs && $fn =~ /-(?:debuginfo|debugsource)-/;
	  next if $nosrcpkgs && $fn =~ /\.(?:nosrc|src)\.rpm$/;
	  if ($fn =~ /^::import::.*?::(.*)$/) {
	    # ignore import if we already got the package (can happen with aggregates)
	    next if $rpms_meta{"$aprp/$arch/$apackid/$1"};
	  }
	  my $b = $bininfo->{$fn};
	  if ($seen_binary) {
	    next if $seen_binary->{"$b->{'name'}.$b->{'arch'}"};
	    $seen_binary->{"$b->{'name'}.$b->{'arch'}"} = 1;
	  }
	  $needit = 1 if $deps{$b->{'name'}} || ($allpacks && !$deps{"-$b->{'name'}"});
	  push @got, "$aprp/$arch/$apackid/$fn";
	  $rpms_hdrmd5{$got[-1]} = $b->{'hdrmd5'} if $b->{'hdrmd5'};
	  $rpms_meta{$got[-1]} = "$aprp/$arch/$apackid/$b->{'name'}.$b->{'arch'}";
	}
	next unless $needit;
	# ok we need it. check if the package is built.
	my $code = $ps->{$apackid} || 'unknown';
	if (!$neverblock && ($code eq 'scheduled' || $code eq 'blocked' || $code eq 'finished')) {
	  push @blocked, "$aprp/$arch/$apackid";
	  $blockedarch{$arch} = 1;
	  last if @blocked > $maxblocked;
	  next;
	}
	push @rpms, @got;
      }
      last if @blocked > $maxblocked;
    }
    last if @blocked > $maxblocked;
  }
  return ('delayed', substr($delayed_errors, 2)) if $delayed_errors;
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
    eval { $id ||= Build::queryhdrmd5("$reporoot/$rpm"); };
    $id ||= "deaddeaddeaddeaddeaddeaddeaddead";
    push @new_meta, "$id  $rpms_meta{$rpm}";
  }
  return BSSched::BuildJob::metacheck($ctx, $packid, $pdata, 'kiwi-product', \@new_meta, [ $bconf, \@rpms, $pool, \%dep2pkg ]);
}


=head2 build - TODO: add summary

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $repo = $ctx->{'repo'};
  my $relsyncmax = $ctx->{'relsyncmax'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $gdst = $ctx->{'gdst'};

  my ($bconf, $rpms, $pool, $dep2pkg, $reason) = @$data;
  my $prp = "$projid/$repoid";

  my $dobuildinfo = $ctx->{'dobuildinfo'};
  my @bdeps;
  for my $rpm (BSUtil::unify(@{$rpms || []})) {
    my @b = split('/', $rpm);
    next if @b == 1;
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
      };
    } elsif ($dobuildinfo && ($b[4] =~  /^(.*)[-.]appdata\.xml$/)) {
      $b = {
        'project' => $b[0],
        'repository' => $b[1],
        'repoarch' => $b[2],
        'package' => $b[3],
      };
    } else {
      next;
    }
    if ($dobuildinfo) {
      $b->{'noinstall'} = 1;
      $b->{'binary'} = $b[4];
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

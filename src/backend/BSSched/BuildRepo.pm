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
package BSSched::BuildRepo;

# fctx functions
#   fctx_set_metaidmd5
#   fctx_check_linkedmeta
#   fctx_add_binary_to_full
#   fctx_del_binary_from_full
#   fctx_gbininfo2full
#   fctx_rebuild_full
#   fctx_migrate_full
#   fctx_integrate_package_into_full
#   fctx_move_into_full
#
# gctx functions
#   sync_fullcache
#   checkuseforbuild
#   forcefullrebuild
#   calculate_useforbuild
#
# ctx functions
#   addrepo
#   addrepo_scan
#
# static functions
#   writesolv
#   volatile_cmp
#
# fctx usage
#   metaid
#   metamd5
#   lastmeta
#   linkedmeta
#   gdst
#   packid
#   meta
#   dst
#   oldids
#   metacache
#   metacache_ismerge
#   dep2meta
#   gctx
#   prp
#   filter
#   olduseforbuild
#   newuseforbuild
#   dstcache
#
# gctx usage
#   arch
#   projpacks
#   repodatas
#   reporoot
#   remoteprojs
#
# ctx usage
#   gctx


=head1 NAME

BSSched::BuildRepo - create repository which is used for build

=head1 DESCRIPTION

This package contains functions which are used to generate a "useforbuild" or
formerly in autobuild ':full' repository

=cut

use strict;
use warnings;

use BSConfiguration;
use BSOBS;
use BSUtil;
use BSSched::ProjPacks;		# for orderpackids
use BSSched::DoD;
#use BSSched::BuildResult;	# circular dep

use Build::Rpm;			# for verscmp

my $exportcnt = 0;
my @binsufs = @BSOBS::binsufs;
my @binsufs_lnk = (@binsufs, 'obsbinlnk');
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);
my $binsufsre_lnk = join('|', map {"\Q$_\E"} @binsufs_lnk);

=head1 FUNCTIONS / METHODS

=head2 fctx_set_metaidmd5 - calculate id/md5 of the meta file and cache it

=cut

sub fctx_set_metaidmd5 {
  my ($fctx) = @_;
  local *F;
  my $metamd5 = '0' x 32;
  my $metaid = '0/0/0';
  if (open(F, '<', $fctx->{'lastmeta'})) {
    my @s = stat(F);
    $metaid = "$s[9]/$s[7]/$s[1]" if @s;
    my $ctx = Digest::MD5->new;
    $ctx->addfile(*F);
    close F;
    $metamd5 = $ctx->hexdigest();
  }
  $fctx->{'metaid'} = $metaid;
  $fctx->{'metamd5'} = $metamd5;
}

=head2 fctx_check_linkedmeta - workaround for btrfs hardlink limitation. sigh.

=cut

sub fctx_check_linkedmeta {
  my ($fctx) = @_;
  my $meta = $fctx->{'lastmeta'};
  if (!defined($fctx->{'linkedmeta'})) {
    my @s = stat($meta);
    $fctx->{'linkedmeta'} = $s[3] - 1;  # nlink
  }
  return unless ++$fctx->{'linkedmeta'} >= $BSConfig::maxmetahardlink;
  writestr("$meta.linkedmetadup", $meta, readstr($meta));
  $fctx->{'linkedmeta'} = 1;
  if ($fctx->{'metaid'}) {
    my @s = stat($meta);
    $fctx->{'metaid'} = "$s[9]/$s[7]/$s[1]" if @s;
  }
}

=head2 fctx_add_binary_to_full - add a single binary to the full tree

(packid/meta overrides the fctx data)

=cut

sub fctx_add_binary_to_full {
  my ($fctx, $fn, $r, $packid, $meta) = @_;
  my $n = $r->{'name'};
  my $suf = $r->{'suf'};
  my $gdst = $fctx->{'gdst'};
  if (!defined($packid)) {
    print "      + :full/$n.$suf ($fn)\n";
    $packid = $fctx->{'packid'};
    $meta = $fctx->{'meta'};
  } else {
    print "      + :full/$n.$suf ($packid/$fn)\n";
  }
  my $dir = $fctx->{'dst'} || "$gdst/$packid";
  # link gives an error if the dest exists, so we dup
  # and rename instead.
  # when the dest is the same file, rename doesn't do
  # anything, so we need the unlink after the rename
  unlink("$dir/$fn.dup");
  link("$dir/$fn", "$dir/$fn.dup");
  rename("$dir/$fn.dup", "$gdst/:full/$n.$suf") || die("rename $dir/$fn.dup $gdst/:full/$n.$suf: $!\n");
  unlink("$dir/$fn.dup");
  $fctx->{'oldids'}->{"$n.$suf"} = $r->{'id'};
  for my $osuf (@binsufs_lnk) {
    next if $suf eq $osuf;
    unlink("$gdst/:full/$n.$osuf");
    delete $fctx->{'oldids'}->{"$n.$osuf"};
  }
  if ($meta) {
    if (!$fctx->{'lastmeta'} || $fctx->{'lastmeta'} ne $meta) {
      delete $fctx->{'metamd5'};
      delete $fctx->{'metaid'};
      delete $fctx->{'linkedmeta'};
      $fctx->{'lastmeta'} = $meta;
    }
    fctx_check_linkedmeta($fctx) if $BSConfig::maxmetahardlink;
    link($meta, "$meta.dup");
    rename("$meta.dup", "$gdst/:full/$n.meta") || die("rename $meta.dup $gdst/:full/$n.meta: $!\n");
    unlink("$meta.dup");
    fctx_set_metaidmd5($fctx) if $fctx->{'metacache'} && !$fctx->{'metamd5'};
    $fctx->{'metacache'}->{$n} = [$fctx->{'metaid'}, $fctx->{'metamd5'}] if $fctx->{'metacache'};
  } else {
    unlink("$gdst/:full/$n.meta");
    if ($fctx->{'metacache'}) {
      delete $fctx->{'metacache'}->{$n};
      $fctx->{'metacache'}->{$n} = undef if $fctx->{'metacache_ismerge'};
    }
  }
  my $dep2meta = $fctx->{'dep2meta'};
  if ($dep2meta) {
    my $m = delete $dep2meta->{$n};
    delete $dep2meta->{$m->[1]} if $m && $m->[1];
  }
}

=head2 fctx_del_binary_from_full - remove a single binary from the full tree

=cut

sub fctx_del_binary_from_full {
  my ($fctx, $r) = @_;
  my $n = $r->{'name'};
  my $suf = $r->{'suf'};
  print "      - :full/$n.$suf\n";
  my $gdst = $fctx->{'gdst'};
  for my $osuf (@binsufs_lnk) {
    unlink("$gdst/:full/$n.$osuf");
    delete $fctx->{'oldids'}->{"$n.$osuf"};
  }
  unlink("$gdst/:full/$n.meta");
  unlink("$gdst/:full/$n-MD5SUMS.meta");       # obsolete
  if ($fctx->{'metacache'}) {
    delete $fctx->{'metacache'}->{$n};
    $fctx->{'metacache'}->{$n} = undef if $fctx->{'metacache_ismerge'};
  }
  my $dep2meta = $fctx->{'dep2meta'};
  if ($dep2meta) {
    my $m = delete $dep2meta->{$n};
    delete $dep2meta->{$m->[1]} if $m && $m->[1];
  }
}

=head2 volatile_cmp - compare evr of two volatile packages

=cut

sub volatile_cmp {
  my ($r, $or) = @_;
  return 0 if $r->{'imported'} && !$or->{'imported'};
  return 1 if $or->{'imported'} && !$r->{'imported'};
  # XXX: the following should be package type dependent...
  if ($r->{'arch'} ne $or->{'arch'}) {
    return 0 if $r->{'arch'} eq 'noarch' || $r->{'arch'} eq 'all' || $r->{'arch'} eq 'any';
    return 1 if $or->{'arch'} eq 'noarch' || $or->{'arch'} eq 'all' || $or->{'arch'} eq 'any';
    return $r->{'arch'} gt $or->{'arch'} ? 1 : 0;
  }
  my $x = Build::Rpm::verscmp($r->{'epoch'} || '0', $or->{'epoch'} || '0');
  return $x > 0 ? 1 : 0 if $x;
  $x = Build::Rpm::verscmp($r->{'version'} || '', $or->{'version'} || '');
  return $x > 0 ? 1 : 0 if $x;
  $x = Build::Rpm::verscmp($r->{'release'} || '', $or->{'release'} || '');
  return $x > 0 ? 1 : 0 if $x;
  return 0;
}


=head2 calculate_useforbuild - calculate the packages that may go into the :full tree

=cut

sub calculate_useforbuild {
  my ($gctx, $prp, $bconf, $dstcache) = @_;
  my $projpacks = $gctx->{'projpacks'};
  my $myarch = $gctx->{'arch'};

  $bconf ||= BSSched::BuildResult::getconfig($gctx, $prp, $dstcache);  # hopefully taken from the cache

  my ($projid, $repoid) = split('/', $prp, 2);
  my $proj = $projpacks->{$projid} || {};
  my $pdatas = $proj->{'package'} || {};
  my $prjuseforbuildenabled = 1;
  $prjuseforbuildenabled = BSUtil::enabled($repoid, $proj->{'useforbuild'}, $prjuseforbuildenabled, $myarch);
  my $buildflags;
  $buildflags = { map {$_ => 1} @{$bconf->{'buildflags'} || []} } if $bconf && exists $bconf->{"buildflags:nouseforbuild"};
  my %useforbuild;
  for my $packid (sort keys %$pdatas) {
    my $useforbuildflags = ($pdatas->{$packid} || {})->{'useforbuild'};
    my $useforbuildenabled = $prjuseforbuildenabled;
    $useforbuildenabled = BSUtil::enabled($repoid, $useforbuildflags, $useforbuildenabled, $myarch) if $useforbuildflags;
    $useforbuildenabled = 0 if $buildflags && $buildflags->{"nouseforbuild:$packid"};
    $useforbuild{$packid} = 1 if $useforbuildenabled;
  }
  if ($proj->{'missingpackages'}) {
    # packages missing from pdatas, use old data for them
    my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
    for my $packid (@{BSUtil::retrieve("$gdst/:full.useforbuild", 1) || []}) {
      $useforbuild{$packid} = 1 unless $pdatas->{$packid};
    }
  }
  return \%useforbuild;
}

=head2 fctx_gbininfo2full - create full tree hash from gbininfo

maps name -> binobj

sets packid and filename as side effect

=cut

sub fctx_gbininfo2full {
  my ($fctx, $gbininfo, $oldpackid, $old, $useforbuild) = @_;
  my $hadoldpackid;
  if (defined($oldpackid)) {
    $hadoldpackid = $gbininfo->{$oldpackid};
    $gbininfo->{$oldpackid} ||= {};     # make sure oldpackid is included
  }
  my $gctx = $fctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projpacks = $gctx->{'projpacks'};
  my ($projid, $repoid) = split('/', $fctx->{'prp'}, 2);
  my $proj = $projpacks->{$projid} || {};
  my @packids = BSSched::ProjPacks::orderpackids($proj, keys %$gbininfo);

  # generate useforbuild from package data if not specified
  $useforbuild ||= calculate_useforbuild($gctx, $fctx->{'prp'}, $fctx->{'bconf'}, $fctx->{'dstcache'});

  # construct new full
  my %full;
  for my $packid (@packids) {
    next unless $packid eq '_volatile' || $useforbuild->{$packid};
    my $bininfo = $gbininfo->{$packid};
    $bininfo = $old if defined($oldpackid) && $oldpackid eq $packid;
    next if $bininfo->{'.nouseforbuild'};               # channels/patchinfos don't go into the full tree
    my %f = BSSched::BuildResult::set_suf_and_filter_exports($gctx, $bininfo, $fctx->{'filter'});
    for my $fn (sort { ($f{$a}->{'imported'} || 0) <=> ($f{$b}->{'imported'} || 0) || $a cmp $b} keys %f) {
      my $r = $f{$fn};
      $r->{'packid'} = $packid;
      $r->{'filename'} = $fn;
      my $or = $full{$r->{'name'}};
      $full{$r->{'name'}} = $r if $or && $or->{'packid'} eq $packid && volatile_cmp($r, $or);
      $full{$r->{'name'}} ||= $r;		# first one wins
    }
  }
  delete $gbininfo->{$oldpackid} if defined($oldpackid) && !$hadoldpackid;
  return %full;
}

=head2 fctx_rebuild_full - completely rebuild the full tree.

Expensive, as it has to stat() all of the old files.

Called when an inconsistency is found.

=cut

sub fctx_rebuild_full {
  my ($fctx, $newfull, $gbininfo) = @_;
  my $prp = $fctx->{'prp'};
  my $gdst = $fctx->{'gdst'};

  if (-d "$gdst/:full" && ! -e "$gdst/:full.useforbuild") {
    fctx_migrate_full($fctx, $gbininfo);
    return;
  }
  print "rebuilding full tree for $prp\n";

  # create newfullsuf
  my %newfullsuf = map {("$_->{'name'}.$_->{'suf'}" => $_)} values %$newfull;
  my %kept;
  for my $bin (sort(ls("$gdst/:full"))) {
    next unless $bin =~ /\.($binsufsre_lnk)$/;      # hmm?
    my $suf = $1;
    my $r = $newfullsuf{$bin};
    if ($r) {
      my @s = stat("$gdst/:full/$bin");
      if (@s && $r->{'id'} eq "$s[9]/$s[7]/$s[1]") {
        # keep it
        $kept{$bin} = 1;
        next;
      }
    }
    # kill it
    $r = { 'name' => substr($bin, 0, length($bin) - length($suf) - 1), 'suf' => $suf };
    fctx_del_binary_from_full($fctx, $r);
  }
  mkdir_p("$gdst/:full") if %newfullsuf;

  # now the full tree contains only entries we want. put the missing ones in.
  my $out_of_sync;
  for my $bin (sort {$newfullsuf{$a}->{'packid'} cmp $newfullsuf{$b}->{'packid'} || $a cmp $b} grep {!$kept{$_}} keys(%newfullsuf)) {
    my $r = $newfullsuf{$bin};
    my $packid = $r->{'packid'};

    # check if we're out of sync
    my @s = stat("$gdst/$packid/$r->{'filename'}");
    if (!@s || "$s[9]/$s[7]/$s[1]" ne $r->{'id'}) {
      unlink("$gdst/$packid/.bininfo");         # ohhh, we're out of sync! rebuild that bininfo...
      $out_of_sync = "$packid/$r->{'filename'}";
      next;
    }

    if (defined($fctx->{'packid'}) && $packid eq $fctx->{'packid'}) {
      fctx_add_binary_to_full($fctx, $r->{'filename'}, $r);
    } else {
      my $meta = BSSched::BuildResult::findmeta($gdst, $packid, $r);
      fctx_add_binary_to_full($fctx, $r->{'filename'}, $r, $packid, $meta);
    }
  }

  if ($out_of_sync) {
    print "detected out-of-sync condition for $out_of_sync, rebuilding bad bininfos\n";
    $gbininfo = BSSched::BuildResult::rebuild_gbininfo($gdst);
    my %newfull = fctx_gbininfo2full($fctx, $gbininfo, undef, undef, $fctx->{'newuseforbuild'});
    fctx_rebuild_full($fctx, \%newfull, $gbininfo);
    return;
  }

  if ($gbininfo->{'_volatile'}) {
    # try to clean up _volatile
    my $bininfo = $gbininfo->{'_volatile'};
    my @del;
    for (sort(keys %$bininfo)) {
      my $r = $bininfo->{$_};
      push @del, $r if $r->{'name'} && $newfull->{$r->{'name'}} != $r;
    }
    BSSched::BuildResult::remove_from_volatile($fctx->{'gdst'}, \@del, $fctx->{'dstcache'}) if @del;
  }
}

=head2 fctx_migrate_full - used to switch to the new full handling.

currently only puts unknown stuff into _volatile.

=cut

sub fctx_migrate_full {
  my ($fctx, $gbininfo) = @_;

  my $gctx = $fctx->{'gctx'};
  my $prp = $fctx->{'prp'};
  my $gdst = $fctx->{'gdst'};
  print "migrating full tree for $prp\n";
  my %knownids;
  for my $packid (keys %$gbininfo) {
    for (values %{$gbininfo->{$packid}}) {
      push @{$knownids{$_->{'id'}}}, $packid if $_->{'id'};
    }
  }
  my $dirty;
  my %packidschecked;
  for my $bin (sort(ls("$gdst/:full"))) {
    next unless $bin =~ /\.($binsufsre_lnk)$/;      # hmm?
    my $suf = $1;
    my @s = stat("$gdst/:full/$bin");
    next unless @s;
    my $id = "$s[9]/$s[7]/$s[1]";
    my $name = substr($bin, 0, length($bin) - length($suf) - 1);
    my $meta = $name;
    if (-e "$gdst/:full/$meta.meta") {
      $meta = "$gdst/:full/$meta.meta";
    } elsif (-e "$gdst/:full/$meta-MD5SUMS.meta") {
      $meta = "$gdst/:full/$meta-MD5SUMS.meta";
    } else {
      undef $meta;
    }
    if ($knownids{$id}) {
      next unless $meta;
      my $isbad;
      for my $packid (@{$knownids{$id}}) {
        next if $packidschecked{$packid};
        if (-e "$gdst/$packid/.meta.success") {
          $packidschecked{$packid} = 1;
          next;
        }
        $isbad = 1;
      }
      if ($isbad) {
        local *F;
        my $m;
        if (open(F, '<', $meta)) {
          $m = <F>;
          chomp $m;
          close F;
        }
        next unless $m && $m =~ s/^.*?  //;;
        next if $packidschecked{$m};
        next unless grep {$_ eq $m} @{$knownids{$id}};
        link($meta, "$gdst/$m/.meta.success");
        $packidschecked{$m} = 1;
      }
      next;
    }
    mkdir_p("$gdst/_volatile");
    unlink("$gdst/_volatile/$bin");
    unlink("$gdst/_volatile/$name.meta");
    link("$gdst/:full/$bin", "$gdst/_volatile/$bin") || die("link $gdst/:full/$bin $gdst/_volatile/$bin: $!\n");
    if ($meta) {
      link($meta, "$gdst/_volatile/$name.meta") || die("link $meta $gdst/_volatile/$name.meta: $!\n");
    }
    $dirty = 1;
  }
  if ($dirty) {
    unlink("$gdst/_volatile/.bininfo");
    my $bininfo = BSSched::BuildResult::read_bininfo("$gdst/_volatile", 1);
    BSSched::BuildResult::update_bininfo_merge($gdst, '_volatile', $bininfo, $fctx->{'dstcache'});
    delete $bininfo->{'.bininfo'};
    $gbininfo->{'_volatile'} = $bininfo;
  }

  # create newuseforbuild
  my $newuseforbuild = calculate_useforbuild($gctx, $prp, $fctx->{'bconf'}, $fctx->{'dstcache'});
  my $newuseforbuild_arr = [ sort keys %$newuseforbuild ];
  BSUtil::store("$gdst/.:full.useforbuild", "$gdst/:full.useforbuild", $newuseforbuild_arr);

  # rebuild the full tree
  my %newfull = fctx_gbininfo2full($fctx, $gbininfo, undef, undef, $newuseforbuild);
  fctx_rebuild_full($fctx, \%newfull, $gbininfo);
}

=head2 fctx_integrate_package_into_full - put files from a package into the full tree.

knows how to deal with overlapping packages.

both $old and $new need to contain all the imports as well.

=cut

sub fctx_integrate_package_into_full {
  my ($fctx, $old, $new) = @_;
  my $packid = $fctx->{'packid'};
  my $gdst = $fctx->{'gdst'};

  my %oldfull;
  my %newfull;
  my $bad;
  if (defined($packid)) {
    # sort by file name, but put imported stuff last
    for my $fn (sort { ($old->{$a}->{'imported'} || 0) <=> ($old->{$b}->{'imported'} || 0) || $a cmp $b} keys %$old) {
      my $r = $old->{$fn};
      my $ofn = $oldfull{$r->{'name'}};
      $oldfull{$r->{'name'}} = $fn if $ofn && $old->{$ofn} && volatile_cmp($r, $old->{$ofn});
      $oldfull{$r->{'name'}} ||= $fn;
    }
    for my $fn (sort { ($new->{$a}->{'imported'} || 0) <=> ($new->{$b}->{'imported'} || 0) || $a cmp $b} keys %$new) {
      my $r = $new->{$fn};
      my $ofn = $newfull{$r->{'name'}};
      $newfull{$r->{'name'}} = $fn if $ofn && $new->{$ofn} && volatile_cmp($r, $new->{$ofn});
      $newfull{$r->{'name'}} ||= $fn;
    }

    # check if just the versions changed
    $bad = 1 if grep {!$newfull{$_}} keys %oldfull;
    $bad = 1 if grep {!$oldfull{$_}} keys %newfull;
    if (!$bad) {
      # just same names with new versions. see if all of the old files are there.
      for my $n (keys %oldfull) {
        my $r = $old->{$oldfull{$n}};
        my @s = stat("$gdst/:full/$r->{'name'}.$r->{'suf'}");
        next if @s && $r->{'id'} eq "$s[9]/$s[7]/$s[1]";
        $bad = 1;
        last;
      }
    }
    if (!$bad) {
      # nice! just new versions and all old files seen. move em over.
      # this should be the common case
      for my $n (sort keys %newfull) {
        my $or = $old->{$oldfull{$n}};
        my $nr = $new->{$newfull{$n}};
        fctx_add_binary_to_full($fctx, $newfull{$n}, $nr) if $or != $nr;
      }
      return;
    }
  }

  # could not do easy integration, read gbininfo
  my $gbininfo = BSSched::BuildResult::read_gbininfo($gdst, undef, 1, $fctx->{'dstcache'});
  my $olduseforbuild = $fctx->{'olduseforbuild'};
  my $newuseforbuild = $fctx->{'newuseforbuild'};
  %oldfull = fctx_gbininfo2full($fctx, $gbininfo, $packid, $old, $olduseforbuild);
  %newfull = fctx_gbininfo2full($fctx, $gbininfo, $packid, $new, $newuseforbuild);

  # check if all interesting packages are correct
  undef $bad;
  my %interesting;
  if (defined($packid)) {
    %interesting = map {$_->{'name'} => 1} (values(%$old), values(%$new));
  } elsif (defined($olduseforbuild)) {
    for my $p (keys %$gbininfo) {
      next if $olduseforbuild->{$p} && $newuseforbuild->{$p};
      next if !$olduseforbuild->{$p} && !$newuseforbuild->{$p};
      $interesting{$_->{'name'}} = 1 for grep {exists($_->{'name'})} values %{$gbininfo->{$p}};
    }
    mkdir_p("$gdst/:full") if %interesting;
  } else {
    # bad. do full integration.
    fctx_rebuild_full($fctx, \%newfull, $gbininfo);
    return;
  }
  for my $n (sort keys %interesting) {
    my $or = $oldfull{$n};
    my $nr = $newfull{$n};
    if ($or) {
      my @s = stat("$gdst/:full/$or->{'name'}.$or->{'suf'}");
      if (!@s || $or->{'id'} ne "$s[9]/$s[7]/$s[1]") {
        $bad = 1;       # missing interesting old package
        last;
      }
      next if $nr && $or == $nr;        # already in full tree
    }
    if ($nr && $nr->{'packid'} ne ($packid || '')) {
      my @s = stat("$gdst/$nr->{'packid'}/$nr->{'filename'}");
      if (!@s || $nr->{'id'} ne "$s[9]/$s[7]/$s[1]") {
        $bad = 1;               # replaced with binary from different packid
        last;
      }
      # check if we have the meta
      my $meta = BSSched::BuildResult::findmeta($gdst, $nr->{'packid'}, $nr, 1);
      if (!$meta) {
        $bad = 1;               # too bad, no meta available. probably not migrated. better rebuild...
        last;
      }
    }
  }
  if (!$bad) {
    # put new stuff in
    for my $n (sort keys %interesting) {
      my $or = $oldfull{$n};
      my $nr = $newfull{$n};
      next unless $nr;
      next if $or && $or == $nr;
      if ($nr->{'packid'} ne ($packid || '')) {
        my $meta = BSSched::BuildResult::findmeta($gdst, $nr->{'packid'}, $nr);
        fctx_add_binary_to_full($fctx, $nr->{'filename'}, $nr, $nr->{'packid'}, $meta);
      } else {
        fctx_add_binary_to_full($fctx, $nr->{'filename'}, $nr);
      }
    }
    # delete old stuff
    my @volrm;
    for my $n (sort keys %interesting) {
      my $or = $oldfull{$n};
      my $nr = $newfull{$n};
      next unless $or;
      fctx_del_binary_from_full($fctx, $or) unless $nr;
      push @volrm, $or if $or->{'packid'} eq '_volatile' && !($nr && $nr == $or);
    }
    BSSched::BuildResult::remove_from_volatile($fctx->{'gdst'}, \@volrm, $fctx->{'dstcache'}) if @volrm;
    return;
  }

  # too bad. rebuild all. slow as we need to stat the complete full tree...
  fctx_rebuild_full($fctx, \%newfull, $gbininfo);
}

=head2 fctx_move_into_full - TODO

=cut

sub fctx_move_into_full {
  my ($fctx, $old, $new) = @_;

  my $prp = $fctx->{'prp'};
  my $gdst = $fctx->{'gdst'};
  my $gctx = $fctx->{'gctx'};
  my $fullcache = ($fctx->{'dstcache'} || {})->{'fullcache'};
  my $prpa = "$prp/$gctx->{'arch'}";
  my $repodatas = $gctx->{'repodatas'};
  my $pool;
  my $satrepo;
  my %oldids;   # maps path => id
  my $metacache;
  my $metacache_ismerge;

  if ($fullcache && $fullcache->{'old'}) {
    my $move_into_full_cnt = $fullcache->{'move_into_full_cnt'} || 0;
    if ($move_into_full_cnt > 20) {
      # a lot of integration work, go into "rebuild full tree later" mode
      if (!$fullcache->{'rebuild_full_tree'}) {
	print "too much integration work, switching into 'rebuild full tree' mode...\n";
	# write a "rebuild full tree" event in case we crash
	my ($projid, $repoid) = split('/', $prp, 2);
	my $ev = {'type' => 'useforbuild', 'project' => $projid, 'repository' => $repoid};
	my $myeventdir = $gctx->{'myeventdir'};
	my $evname = "rebuild_full_tree:$projid:$repoid";
	writexml("$myeventdir/.$evname$$", "$myeventdir/$evname", $ev, $BSXML::event);
	$fullcache->{'rebuild_full_tree'} = "$myeventdir/$evname";
      }
      delete $repodatas->{$prpa}->{'solv'};
      return;
    }
    $fullcache->{'move_into_full_cnt'} = $move_into_full_cnt + 1;
  }

  if ($fullcache && $fullcache->{'old'}) {
    $pool = $fullcache->{'pool'};
    $satrepo = $fullcache->{'satrepo'};
    %oldids = %{$fullcache->{'old'}};
    $metacache = $fullcache->{'metacache'} || {};
    $metacache_ismerge = $fullcache->{'metacache_ismerge'};
  } else {
    $pool = BSSolv::pool->new();
    eval { $satrepo = $pool->repofromfile($prp, "$gdst/:full.solv"); };
    %oldids = $satrepo->getpathid() if $satrepo;
    if (((-s "$gdst/:full.metacache") || 0) < 16384 && ! -e "$gdst/:full.metacache.merge") {
      $metacache = BSUtil::retrieve("$gdst/:full.metacache", 1) || {};
    } else {
      $metacache = BSUtil::retrieve("$gdst/:full.metacache.merge", 1) || {};
      $metacache_ismerge = 1;
    }
  }
  # move em over into :full
  $fctx->{'oldids'} = \%oldids;
  $fctx->{'metacache'} = $metacache;
  $fctx->{'metacache_ismerge'} = $metacache_ismerge;
  $fctx->{'dep2meta'} = $repodatas->{$prpa}->{'meta'} if $repodatas->{$prpa} && $repodatas->{$prpa}->{'meta'};
  mkdir_p("$gdst/:full") if $new && %$new && ! -d "$gdst/:full";
  fctx_integrate_package_into_full($fctx, $old, $new);

  mkdir_p($gdst) unless -d $gdst;
  if ($fullcache) {
    # delayed writing of the solv file, just update the fullcache
    $fullcache->{'prp'} = $prp;
    $fullcache->{'pool'} = $pool;
    $fullcache->{'satrepo'} = $satrepo if $satrepo;
    $fullcache->{'old'} = \%oldids;
    $fullcache->{'metacache'} = $metacache;
    $fullcache->{'metacache_ismerge'} = $metacache_ismerge;
  } else {
    if ($satrepo) {
      $satrepo->updatefrombins("$gdst/:full", %oldids);
    } else {
      $satrepo = $pool->repofrombins($prp, "$gdst/:full", %oldids);
    }
    writesolv("$gdst/:full.solv.new", "$gdst/:full.solv", $satrepo);
    if ($metacache_ismerge) {
      BSUtil::store("$gdst/.:full.metacache.merge", "$gdst/:full.metacache.merge", $metacache);
    } else {
      BSUtil::store("$gdst/.:full.metacache", "$gdst/:full.metacache", $metacache);
    }
  }
  delete $repodatas->{$prpa}->{'solv'};
}

=head2 sync_fullcache - TODO

=cut

sub sync_fullcache {
  my ($gctx, $fullcache) = @_;

  return unless $fullcache;
  if (!$fullcache->{'old'}) {
    %$fullcache = ();
    return;
  }
  my $myarch = $gctx->{'arch'};
  my $prp = $fullcache->{'prp'};
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  mkdir_p($gdst) unless -d $gdst;
  my $pool = $fullcache->{'pool'};
  my $satrepo = $fullcache->{'satrepo'};
  my %oldids = %{$fullcache->{'old'}};
  if ($satrepo) {
    $satrepo->updatefrombins("$gdst/:full", %oldids);
  } else {
    $satrepo = $pool->repofrombins($prp, "$gdst/:full", %oldids);
  }
  writesolv("$gdst/:full.solv.new", "$gdst/:full.solv", $satrepo);
  delete $gctx->{'repodatas'}->{"$prp/$myarch"}->{'solv'};
  if ($fullcache->{'metacache'}) {
    if ($fullcache->{'metacache_ismerge'}) {
      BSUtil::store("$gdst/.:full.metacache.merge", "$gdst/:full.metacache.merge", $fullcache->{'metacache'});
    } else {
      BSUtil::store("$gdst/.:full.metacache", "$gdst/:full.metacache", $fullcache->{'metacache'});
    }
  }
  if ($fullcache->{'rebuild_full_tree'}) {
    unlink($fullcache->{'rebuild_full_tree'});	# delete dummy event
    %$fullcache = (); 
    forcefullrebuild($gctx, $prp);
  }
  %$fullcache = ();
}

=head2 writesolv - write full tree repo as solv file

 TODO: add description

=cut

sub writesolv {
  my ($fn, $fnf, $repo) = @_;
  if (defined($fnf) && $BSUtil::fdatasync_before_rename) {
    local *F;
    open(F, '>', $fn) || die("$fn: $!\n");
    $repo->tofile_fd(fileno(F));
    BSUtil::do_fdatasync(fileno(F));
    close(F) || die("$fn close: $!\n");
  } else {
    $repo->tofile($fn);
  }
  return unless defined $fnf;
  $! = 0;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n");
}

=head2 checkuseforbuild - TODO: add summary

 check if the useforbuild settings have changed. If yes, update the :full tree
 Returns true if the :full tree was updated

=cut

sub checkuseforbuild {
  my ($gctx, $prp, $dstcache, $forcerebuild) = @_;
  my $myarch = $gctx->{'arch'};
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  my $projpacks = $gctx->{'projpacks'};
  my ($projid, $repoid) = split('/', $prp, 2);
  my $proj = $projpacks->{$projid};
  return 0 unless $proj;

  # do not mess with completely locked projects
  if (BSUtil::enabled($repoid, $proj->{'lock'}, 0, $myarch)) {
    my $alllocked = 1;
    for my $pack (grep {$_->{'lock'}} values %{$proj->{'package'} || {}}) {
      $alllocked = 0 unless BSUtil::enabled($repoid, $pack->{'lock'}, 1, $myarch);
    }
    return 0 if $alllocked;
  }

  my $bconf = BSSched::BuildResult::getconfig($gctx, $prp, $dstcache);  # hopefully taken from the cache

  my $olduseforbuild_arr = BSUtil::retrieve("$gdst/:full.useforbuild", 1);
  $olduseforbuild_arr = [] if !$olduseforbuild_arr && ! -d "$gdst/:full";
  $olduseforbuild_arr = undef if $forcerebuild;
  my $newuseforbuild = calculate_useforbuild($gctx, $prp, $bconf, $dstcache);
  my $newuseforbuild_arr = [ sort keys %$newuseforbuild ];

  # return if there was no change
  return 0 if $olduseforbuild_arr && join('/', @$olduseforbuild_arr) eq join('/', @$newuseforbuild_arr);

  my $filter = BSSched::BuildResult::calculate_exportfilter($gctx, $bconf);
  my $fctx = {
    'gctx' => $gctx,
    'gdst' => $gdst,
    'prp' => $prp,
    'filter' => $filter,
    'dstcache' => $dstcache,
    'bconf' => $bconf,
  };

  if ($olduseforbuild_arr) {
    # diff it. only care about current packages.
    my %olduseforbuild = map {$_ => 1} @$olduseforbuild_arr;
    # work around added/removed packages
    for (grep {!$olduseforbuild{$_}} keys %$newuseforbuild) {
      $olduseforbuild{$_} = 1 unless -d "$gdst/$_";       # did not exist before
    }
    $fctx->{'olduseforbuild'} = \%olduseforbuild;
    $fctx->{'newuseforbuild'} = $newuseforbuild;
  }

  # setup metacache
  if (((-s "$gdst/:full.metacache") || 0) < 16384 && ! -e "$gdst/:full.metacache.merge") {
    $fctx->{'metacache'} = BSUtil::retrieve("$gdst/:full.metacache", 1) || {};
  } else {
    $fctx->{'metacache'} = BSUtil::retrieve("$gdst/:full.metacache.merge", 1) || {};
    $fctx->{'metacache_ismerge'} = 1;
  }

  # this will also remove no longer existing packages from the :full tree
  fctx_move_into_full($fctx, undef, undef);

  # update the full.useforbuild file
  BSUtil::store("$gdst/.:full.useforbuild", "$gdst/:full.useforbuild", $newuseforbuild_arr);

  # flush updated metacache
  if ($fctx->{'metacache_ismerge'}) {
    BSUtil::store("$gdst/.:full.metacache.merge", "$gdst/:full.metacache.merge", $fctx->{'metacache'});
  } else {
    BSUtil::store("$gdst/.:full.metacache", "$gdst/:full.metacache", $fctx->{'metacache'});
  }

  return 1;
}

=head2 forcefullrebuild - force the rebuild of the full repo

 TODO: add description

=cut

sub forcefullrebuild {
  my ($gctx, $prp) = @_;
  checkuseforbuild($gctx, $prp, undef, 1); 
}

=head2 addrepo_scan - add :full repo to pool, make sure repo is up-to-data by scanning the directory

 TODO: add description

=cut

sub addrepo_scan {
  my ($gctx, $pool, $prp, $arch) = @_;

  if ($arch eq $gctx->{'arch'}) {
    print "    scanning repo $prp...\n";
  } else {
    print "    scanning repo $prp/$arch...\n";
  }
  my $repocache = $gctx->{'repodatas'};
  my $dir = "$gctx->{'reporoot'}/$prp/$arch/:full";
  my $r;
  my $dirty;

  if (-s "$dir.solv") {
    eval {$r = $pool->repofromfile($prp, "$dir.solv");};
    warn($@) if $@;
    if ($r && $r->isexternal()) {
      $repocache->setcache($prp, $arch) if $repocache;
      return $r;
    }
  }

  # update the doddata
  my $doddata;
  if ($BSConfig::enable_download_on_demand) {
    $doddata = BSSched::DoD::get_doddata($gctx, $prp, $arch);
    ($dirty, $r) = BSSched::DoD::put_doddata_in_cache($gctx, $doddata, $pool, $prp, $r, $dir);
  }

  my @bins;
  local *D;
  if (opendir(D, $dir)) {
    @bins = grep {/\.(?:$binsufsre_lnk)$/s && !/^\.dod\./s} readdir(D);
    closedir D;
    if (!@bins && -s "$dir.subdirs") {
      for my $subdir (split(' ', readstr("$dir.subdirs"))) {
        push @bins, map {"$subdir/$_"} grep {/\.(?:$binsufsre)$/} ls("$dir/$subdir");
      }
    }
  } else {
    if (!$r) {
      # return in-core empty repo
      my $r = $pool->repofrombins($prp, $dir);
      $repocache->setcache($prp, $arch, 'solv' => $r->tostr()) if $repocache;
      return $r;
    }
  }
  for (splice @bins) {
    my @s = stat("$dir/$_");
    next unless @s;
    push @bins, $_, "$s[9]/$s[7]/$s[1]";
  }
  if ($r) {
    my $updated = $r->updatefrombins($dir, @bins);
    print "    (dirty: $updated)\n" if $updated;
    $dirty = 1 if $updated;
  } else {
    $r = $pool->repofrombins($prp, $dir, @bins);
    $dirty = 1;
  }
  return undef unless $r;
  # write solv file (unless alien arch)
  if ($dirty && $arch eq $gctx->{'arch'}) {
    @bins = BSSched::DoD::clean_obsolete_dodpackages($gctx, $doddata, $pool, $prp, $r, $dir, @bins) if $doddata;
    writesolv("$dir.solv.new", "$dir.solv", $r);
  }
  $repocache->setcache($prp, $arch) if $repocache;
  return $r;
}

1;

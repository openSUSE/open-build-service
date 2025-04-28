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
package BSSched::BuildResult;

# gctx functions
#   calculate_exportfilter
#   getconfig
#   set_suf_and_filter_exports
#   update_dst_full
#   set_dstcache_prp
#   wipe
#   wipeobsolete
#   wipeobsoleterepo
#
# static functions
#   compile_exportfilter
#   update_bininfo_merge
#   repofromfiles
#   read_bininfo
#   read_gbininfo
#   rebuild_gbininfo
#   findmeta
#   remove_from_volatile
#
# gctx usage
#   arch
#   reporoot
#   projpacks
#   prpcheckuseforbuild		[rw]
#   prpsearchpath
#   repounchanged		[rw]
#
# fctx usage
#   dst				[rw]

use strict;
use warnings;

use BSOBS;
use BSUtil;
use BSXML;
use BSVerify;
use BSConfiguration;
use BSRedisnotify;
use BSSched::BuildRepo;
use BSSched::Blobstore;
use BSSched::BuildJob::Import;		# for createexportjob
use BSSched::BuildJob::PreInstallImage;	# for update_preinstallimage
use BSSched::Access;			# for checkaccess
use BSSched::ProjPacks;			# for getconfig

use Build;


my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);
my $binsufsre_binlnk = join('|', map {"\Q$_\E"} (@binsufs, 'obsbinlnk'));

my %default_exportfilters = (
  'i586' => {
    '\.x86_64\.rpm$'   => [ 'x86_64' ],
    '\.ia64\.rpm$'     => [ 'ia64' ],
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
  'x86_64' => {
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
  'ppc' => {
    '\.ppc64\.rpm$'   => [ 'ppc64' ],
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
  'ppc64' => {
    '\.ppc\.rpm$'   => [ 'ppc' ],
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
  'sparc' => {
    # discard is intended - sparcv9 target is better suited for 64-bit baselibs
    '\.sparc64\.rpm$' => [],
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
  'sparcv8' => {
    # discard is intended - sparcv9 target is better suited for 64-bit baselibs
    '\.sparc64\.rpm$' => [],
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
  'sparcv9' => {
    '\.sparc64\.rpm$' => [ 'sparc64' ],
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
  'sparcv9v' => {
    '\.sparc64v\.rpm$' => [ 'sparc64v' ],
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
  'sparc64' => {
    '\.sparcv9\.rpm$' => [ 'sparcv9' ],
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
  'sparc64v' => {
    '\.sparcv9v\.rpm$' => [ 'sparcv9v' ],
    '-debuginfo-.*\.rpm$' => [],
    '-debugsource-.*\.rpm$' => [],
  },
);


=head2 compile_exportfilter - compile the regexpes of the exportfilter

TODO

=cut

sub compile_exportfilter {
  my ($filter) = @_;
  return undef unless $filter;
  my @res;
  for my $f (@$filter) {
    eval {
      $_ eq '.' || BSVerify::verify_arch($_) for @{$f->[1] || []};
      push @res, [ qr/$f->[0]/, $f->[1] ];
    };
  }
  return \@res;
}

=head2 getconfig - return the build config for a prp

TODO

=cut

sub getconfig {
  my ($gctx, $prp, $dstcache) = @_;
  my $prpsearchpath = $gctx->{'prpsearchpath'}->{$prp};
  return undef unless $prpsearchpath;
  set_dstcache_prp($gctx, $dstcache, $prp) if $dstcache;
  my $fullcache = $dstcache ? $dstcache->{'fullcache'} : undef;
  return $fullcache->{'config'} if $fullcache && $fullcache->{'config'};
  my ($projid, $repoid) = split('/', $prp, 2);
  my $bconf = BSSched::ProjPacks::getconfig($gctx, $projid, $repoid, $gctx->{'arch'}, $prpsearchpath);
  $fullcache->{'config'} = $bconf if $fullcache;
  return $bconf
}

=head2 calculate_exportfilter - return exportfilter for a prp

TODO

=cut

sub calculate_exportfilter {
  my ($gctx, $bconf) = @_;
  my $filter = $bconf ? $bconf->{'exportfilter'} : undef;
  undef $filter if $filter && !%$filter;
  $filter ||= $default_exportfilters{$gctx->{'arch'}};
  $filter = [ map {[$_, $filter->{$_}]} reverse sort keys %$filter ] if $filter;
  return compile_exportfilter($filter);
}


=head2 set_suf_and_filter_exports - apply the export filter to a job repo

sets suf and imported for all repo entries, collect entries to export

=cut

sub set_suf_and_filter_exports {
  my ($gctx, $repo, $filter, $exports) = @_;
  my %n;
  my $myarch = $gctx->{'arch'};

  for my $rp (sort keys %$repo) {
    my $r = $repo->{$rp};
    delete $r->{'suf'};
    next unless $r->{'source'};         # no src in full tree
    next unless $r->{'name'};           # need binary name
    my $suf;
    $suf = $1 if $rp =~ /\.($binsufsre_binlnk)$/;
    next unless $suf;                   # need a valid suffix
    $r->{'suf'} = $suf;
    my $nn = $rp;
    $nn =~ s/.*\///;
    if ($nn =~ /^::import::/) {
      # do not re-export. Also set imported so that local binaries come first
      $r->{'imported'} = 1;
      $n{$nn} = $r;
      next;
    }
    if ($filter) {
      my $skip;
      for (@$filter) {
        if ($nn =~ /$_->[0]/) {
          $skip = $_->[1];
          last;
        }
      }
      if ($skip) {
        my $myself;
        for my $exportarch (@$skip) {
          if ($exportarch eq '.' || $exportarch eq $myarch) {
            $myself = 1;
            next;
          }
          push @{$exports->{$exportarch}}, $nn, $r if $exports;
        }
        next unless $myself;
      }
    }
    $n{$nn} = $r;
  }
  return %n;
}

=head2 update_bininfo_merge - TODO: add summary

 TODO: add description

=cut

sub update_bininfo_merge {
  my ($gdst, $packid, $bininfo, $dstcache) = @_;

  # delete currently not needed values from bininfo, maybe later
  if ($bininfo) {
    for (values %$bininfo) {
      delete $_->{'provides'};
      delete $_->{'requires'};
    }
  }

  my $bininfocache = $dstcache ? $dstcache->{'bininfocache'} : undef;

  if ($bininfocache && $bininfocache->{'gdst'}) {
    # sync to disk if from another gdst
    sync_bininfocache($gdst, $bininfocache) if $bininfocache->{'gdst'} ne $gdst;

    my $merge = $bininfocache->{'merge'};
    if ($merge) {
      $merge->{$packid} = $bininfo;	# update cache
      if (!$bininfocache->{'outdated'}) {
        # start caching 
	$bininfocache->{'outdated'} = 1;
        # write a "not-up-to-date marker" so that we rebuild when there is a crash
        $merge->{'/outdated'} = 1;
        BSUtil::store("$gdst/.:bininfo.merge", "$gdst/:bininfo.merge", $merge);
        delete $merge->{'/outdated'};
      }
      return;
    }
  }

  my $merge = {};
  if (-e "$gdst/:bininfo.merge") {
    if (-s _ > 100000) {
      # quite big. better merge now.
      print "merging bininfo for $gdst because of the size\n";
      read_gbininfo($gdst);	# this will also merge
      $merge = BSUtil::retrieve("$gdst/:bininfo.merge", 1) if -e "$gdst/:bininfo.merge";
    } else {
      $merge = BSUtil::retrieve("$gdst/:bininfo.merge", 1);
    }
    if ($merge && $merge->{'/outdated'}) {
      # hey! need to rebuild gbininfo!
      read_gbininfo($gdst);	# this will also merge
      $merge = {};
      $merge = BSUtil::retrieve("$gdst/:bininfo.merge", 1) if -e "$gdst/:bininfo.merge";
    }
    undef $merge if $merge && $merge->{'/outdated'};
  } elsif (! -e "$gdst/:bininfo") {
    # hmm, no bininfo yet? better create it.
    read_gbininfo($gdst);
  }

  if (!$merge) {
    writestr("$gdst/.:bininfo.merge", "$gdst/:bininfo.merge", '');      # corrupt file, mark
    return;
  }

  $merge->{$packid} = $bininfo;
  BSUtil::store("$gdst/.:bininfo.merge", "$gdst/:bininfo.merge", $merge);

  if ($bininfocache) {
    # just cache the merge file for now
    $bininfocache->{'gdst'} = $gdst;
    $bininfocache->{'merge'} = $merge;
  }
}

sub sync_bininfocache {
  my ($gctx, $bininfocache) = @_;
  my $gdst = $bininfocache->{'gdst'};
  return unless $gdst;
  if ($bininfocache->{'outdated'}) {
    if (! -e "$gdst/:bininfo.merge") {
      # wait, something is wrong! There should be the .merge file with the /outdated marker.
      delete $bininfocache->{'merge'};
      delete $bininfocache->{'base'};
      delete $bininfocache->{'outdated'};
      delete $bininfocache->{'gdst'};
      rebuild_gbininfo($gdst);
      return;
    }
    BSUtil::store("$gdst/.:bininfo.merge", "$gdst/:bininfo.merge", $bininfocache->{'merge'});
  }
  delete $bininfocache->{'merge'};
  delete $bininfocache->{'base'};
  delete $bininfocache->{'outdated'};
  delete $bininfocache->{'gdst'};
}

=head2 repofromfiles - create repo from a file list

 TODO

=cut

sub repofromfiles {
  my ($dir, $files, $cache) = @_;
  my $repobins = {};
  for my $bin (@$files) {
    next unless $bin =~ /\.(?:$binsufsre_binlnk)$/;
    next if $bin =~ /\.delta\.rpm$/;	# those go not into the full tree
    my @s = stat("$dir/$bin");
    next unless @s;
    my $id = "$s[9]/$s[7]/$s[1]";
    my $data;
    if ($cache && $cache->{$id}) {
      $data = { %{$cache->{$id}} };
    } else {
      if ($bin =~ /\.obsbinlnk$/) {
	$data = BSUtil::retrieve("$dir/$bin", 1);
	delete $data->{'path'} if $data;
      } else {
        $data = Build::query("$dir/$bin", 'evra' => 1);  # need arch
      }
      next unless $data;
    }
    eval {
      BSVerify::verify_nevraquery($data);
    };
    next if $@;
    delete $data->{'disttag'};
    $data->{'id'} = $id;
    $repobins->{"$dir/$bin"} = $data;
  }
  return $repobins;
}

=head2 update_dst_full - move binary packages from jobrepo to dst and update the full repository

Move the job result into the package's artifact directory and update the :full tree
accordingly. Returns true if the :full tree was changed.

=cut

sub update_dst_full {
  my ($gctx, $prp, $packid, $jobdir, $meta, $dstcache, $importarch, $obsolete_pkg) = @_;

  my $myarch = $gctx->{'arch'};
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  my $dst = "$gdst/$packid";

  my ($projid, $repoid) = split('/', $prp, 2);

  # do extra preinstallimage processing if this is/was a preinstall image
  if ((-e "$dst/.preinstallimage") || (defined($jobdir) && -e "$jobdir/.preinstallimage")) {
    BSSched::BuildJob::PreInstallImage::update_preinstallimage($gctx, $prp, $packid, $dst, $jobdir);
  }

  # check for lock
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid} || {};
  my $pdata = ($proj->{'package'} || {})->{$packid} || {};
  my $locked = 0;
  $locked = BSUtil::enabled($repoid, $proj->{'lock'}, $locked, $myarch) if $proj->{'lock'};
  $locked = BSUtil::enabled($repoid, $pdata->{'lock'}, $locked, $myarch) if $pdata->{'lock'};
  if ($locked) {
    print "    package is locked\n";
    return 0;
  }

  # calculate the config (this slows us down a bit)
  my $bconf = getconfig($gctx, $prp, $dstcache);

  # calculate useforbuild status
  my $useforbuildenabled = 1;
  $useforbuildenabled = BSUtil::enabled($repoid, $proj->{'useforbuild'}, $useforbuildenabled, $myarch) if $proj->{'useforbuild'};
  $useforbuildenabled = BSUtil::enabled($repoid, $pdata->{'useforbuild'}, $useforbuildenabled, $myarch) if $pdata->{'useforbuild'};
  if (exists $bconf->{'buildflags:nouseforbuild'}) {
    if (!$dstcache || ($dstcache->{'nouseforbuild_checked'} || '') ne $prp) {
      $gctx->{'prpcheckuseforbuild'}->{$prp} = 1;	# always force a recheck for now
      $dstcache->{'nouseforbuild_checked'} = $prp if $dstcache;
    }
    $useforbuildenabled = 0 if grep {$_ eq "nouseforbuild:$packid"} @{$bconf->{'buildflags'} || []};
  }
  $useforbuildenabled = 1 if !defined($jobdir) && $obsolete_pkg;	# called from wipeobsolete

  my $changed_full = 0;
  # further down we assume that the useforbuild setting of the full tree
  # matches the current setting, so make sure they are in sync.
  my $prpcheckuseforbuild = $gctx->{'prpcheckuseforbuild'};
  if ($prpcheckuseforbuild->{$prp}) {
    $changed_full = BSSched::BuildRepo::checkuseforbuild($gctx, $prp, $dstcache);
    delete $prpcheckuseforbuild->{$prp};
  }

  my $jobrepo;
  my @jobfiles;
  my $jobbininfo;
  if (defined($jobdir)) {
    @jobfiles = sort(ls($jobdir));
    @jobfiles = grep {$_ ne 'history' && $_ ne 'logfile' && $_ ne 'meta' && $_ ne 'status' && $_ ne 'reason' && $_ ne '.bininfo' && $_ ne '.meta.success' && $_ ne '.logfile.success' && $_ ne '.logfile.fail'} @jobfiles;
    $jobbininfo = BSUtil::retrieve("$jobdir/.bininfo", 1);
    if ($jobbininfo && !($jobdir eq $dst) && !$jobbininfo->{'.bininfo'}) {
      # old style jobdir bininfo, ignore
      unlink("$jobdir/.bininfo");
      undef $jobbininfo;
    }
    $jobbininfo ||= read_bininfo($jobdir);
    delete $jobbininfo->{'.bininfo'};   # delete new version marker
    my $cache = { map {$_->{'id'} => $_} grep {$_->{'id'}} values %$jobbininfo };
    $jobrepo = repofromfiles($jobdir, \@jobfiles, $cache);
  } else {
    $jobrepo = {};
  }

  ##################################################################
  # part 1: move files into package directory ($dst)

  my $oldrepo;
  my $old_nouseforbuild;
  my $bininfo;

  if (!$importarch && $jobdir && $dst eq $jobdir) {
    # a "refresh" operation triggered by a useforbuild event, nothing to do here
    $oldrepo = $jobrepo;
    $bininfo = $jobbininfo;
    $bininfo->{'.nosourceaccess'} = {} if -e "$dst/.nosourceaccess";
    $bininfo->{'.nouseforbuild'} = {} if -e "$dst/.channelinfo" || -e "$dst/updateinfo.xml" || -e "$dst/.updateinfodata" || -e "$dst/.nouseforbuild";
    $old_nouseforbuild = 1 if $bininfo->{'.nouseforbuild'};
  } else {
    # get old state: oldfiles, oldbininfo, oldrepo
    my @oldfiles = sort(ls($dst));
    @oldfiles = grep {$_ ne '.stats' && $_ ne 'history' && $_ ne 'logfile' && $_ ne 'meta' && $_ ne 'status' && $_ ne 'reason' && $_ ne '.bininfo' && $_ ne '.meta.success'} @oldfiles;
    mkdir_p($dst);
    my $oldbininfo = read_bininfo($dst);
    delete $oldbininfo->{'.bininfo'};   # delete new version marker
    $old_nouseforbuild = 1 if $oldbininfo->{'.nouseforbuild'};
    my $oldcache = { map {$_->{'id'} => $_} grep {$_->{'id'}} values %$oldbininfo };
    $oldrepo = repofromfiles($dst, \@oldfiles, $oldcache);

    # move files over (and rename in import case)
    my %new;
    for my $f (@jobfiles) {
      next if $importarch && $f eq 'replaced.xml';      # not needed
      if (! -l "$dst/$f" && -d _) {
        BSUtil::cleandir("$dst/$f");
        rmdir("$dst/$f");
      }
      my $df = $importarch ? "::import::${importarch}::$f" : $f;
      rename("$jobdir/$f", "$dst/$df") || die("rename $jobdir/$f $dst/$df: $!\n");
      $new{$df} = 1;
      BSSched::Blobstore::blobstore_lnk($gctx, $df, $dst) if $df =~ /^_blob\./;
      if ($jobbininfo->{$f}) {
        $bininfo->{$df} = $jobbininfo->{$f};
        $bininfo->{$df}->{'filename'} = $df if $importarch;
      }
      $bininfo->{'.nouseforbuild'} = {} if $f eq '.channelinfo' || $f eq 'updateinfo.xml' || $f eq '.updateinfodata' || $f eq '.nouseforbuild';
      $jobrepo->{"$jobdir/$df"} = delete $jobrepo->{"$jobdir/$f"} if $df ne $f;
    }
    for my $f (grep {!$new{$_}} @oldfiles) {
      if (!$importarch) {
	if ($f =~ /^\.meta\.success\.import\./) {
	  next if defined($jobdir) || defined($importarch);
	}
        if (defined($importarch) && !defined($jobdir) && $f =~ /^::import::/) {
          # a wipe, keep the imports
          $bininfo->{$f} = $oldbininfo->{$f} if $oldbininfo->{$f};
          $jobrepo->{"$dst/$f"} = $oldrepo->{"$dst/$f"} if $oldrepo->{"$dst/$f"};
          next;
        }
        if (defined($jobdir) && $f =~ /^::import::/) {
          $bininfo->{$f} = $oldbininfo->{$f} if $oldbininfo->{$f};
          $jobrepo->{"$jobdir/$f"} = $oldrepo->{"$dst/$f"} if $oldrepo->{"$dst/$f"};
          next;
        }
      } else {
        if ($f !~ /^::import::\Q$importarch\E::/) {
          $bininfo->{$f} = $oldbininfo->{$f} if $oldbininfo->{$f};
          $jobrepo->{"$jobdir/$f"} = $oldrepo->{"$dst/$f"} if $oldrepo->{"$dst/$f"};
          next;
        }
      }
      if (! -l "$dst/$f" && -d _) {
        BSUtil::cleandir("$dst/$f");
        rmdir("$dst/$f");
      } else {
	unlink("$dst/$f");
	BSSched::Blobstore::blobstore_chk($gctx, $f) if $f =~ /^_blob\./;
      }
    }
    # save meta into .meta.success file
    my $dmeta = $importarch ? ".meta.success.import.$importarch" : '.meta.success';
    unlink("$dst/$dmeta");
    if ($meta) {
      link($meta, "$dst/$dmeta") || die("link $meta $dst/$dmeta: $!\n");
    }
    # we only check 'sourceaccess', not 'access' here. 'access' has
    # to be handled anyway, so we don't gain anything by limiting
    # source access.
    if (!BSSched::Access::checkaccess($gctx, 'sourceaccess', $projid, $packid, $repoid)) {
      BSUtil::touch("$dst/.nosourceaccess");
      $bininfo->{'.nosourceaccess'} = {};
    }
    # now jobrepo + bininfo contain all the files of dst
  }

  # write .bininfo file and update :bininfo.merge (jobdir is undef for package deletion)
  my @bininfo_s;
  if (defined($jobdir) && defined($bininfo)) {
    BSUtil::store("$dst/.bininfo.new", "$dst/.bininfo", $bininfo);
    @bininfo_s = stat("$dst/.bininfo");
    $bininfo->{'.bininfo'} = {'id' => "$bininfo_s[9]/$bininfo_s[7]/$bininfo_s[1]"} if @bininfo_s;
  } else {
    unlink("$dst/.bininfo");
  }
  update_bininfo_merge($gdst, $packid, defined($jobdir) ? $bininfo : undef, $dstcache);
  delete $bininfo->{'.bininfo'} if $bininfo;

  ##################################################################
  # part 2: link needed binaries into :full tree

  my $filter = calculate_exportfilter($gctx, $bconf);
  my %oldexports;
  my %newexports;
  my %old = set_suf_and_filter_exports($gctx, $oldrepo, $filter, \%oldexports);
  my %new = set_suf_and_filter_exports($gctx, $jobrepo, $filter, \%newexports);

  # make sure the old export archs are known
  $newexports{$_} ||= [] for keys %oldexports;

  if ($old_nouseforbuild) {
    %old = ();
  }

  if ($bininfo && $bininfo->{'.nouseforbuild'}) {
    %new = ();			# do not put channels or patchinfos in the :full tree
    %newexports = (); 		# do not export channels or patchinfos
  }

  if ($filter && !$importarch && %newexports) {
    # we always export, the other schedulers are free to reject the job
    # if move to full is also disabled for them
    for my $exportarch (sort keys %newexports) {
      # check if this prp supports the arch
      next unless $projpacks->{$projid};
      my $repo = (grep {$_->{'name'} eq $repoid} @{$projpacks->{$projid}->{'repository'} || []})[0];
      if ($repo && grep {$_ eq $exportarch} @{$repo->{'arch'} || []}) {
        print "    sending filtered packages to $exportarch\n";
        BSSched::BuildJob::Import::createexportjob($gctx, $prp, $exportarch, $packid, $jobrepo, $dst, $oldrepo, $meta, @{$newexports{$exportarch}});
      }
    }
  }

  if (!$useforbuildenabled) {
    print "    move to :full is disabled\n";
    return $changed_full;
  }

  my $fctx = {
    'gctx' => $gctx,
    'gdst' => $gdst,
    'prp' => $prp,
    'packid' => $packid,
    'meta' => $meta,
    'filter' => $filter,
    'importarch' => $importarch,
    'dstcache' => $dstcache,
    'bconf' => $bconf,
  };
  BSSched::BuildRepo::fctx_move_into_full($fctx, \%old, \%new);
  return 1;
}

sub helminfo2bininfo {
  my ($dir, $helminfo) = @_;
  return undef unless -e "$dir/$helminfo";
  return undef unless (-s _) < 100000;
  my $m = readstr("$dir/$helminfo");
  my $d; 
  eval { $d = JSON::XS::decode_json($m); };
  return undef unless $d && ref($d) eq 'HASH';
  return undef unless $d->{'name'} && ref($d->{'name'}) eq ''; 
  return undef unless $d->{'version'} && ref($d->{'version'}) eq ''; 
  return undef unless !$d->{'tags'} || ref($d->{'tags'}) eq 'ARRAY';
  return undef unless $d->{'chart'} && ref($d->{'chart'}) eq ''; 
  my $info = { 'name' => "helm:$d->{'name'}",
               'version' => (defined($d->{'version'}) ? $d->{'version'} : '0'),
               'release' => (defined($d->{'release'}) ? $d->{'release'} : '0'),
               'arch' => (defined($d->{'arch'}) ? $d->{'arch'} : 'noarch') };
  eval { BSVerify::verify_nevraquery($info) };
  if ($@) {
    warn($@);
    return undef;
  }
  return $info;
}

=head2 read_bininfo - TODO: add summary

 TODO: add description

=cut

sub read_bininfo {
  my ($dir, $withid) = @_;
  my $bininfo;
  my @bininfo_s;
  local *BI;
  if (open(BI, '<', "$dir/.bininfo")) {
    @bininfo_s = stat(BI);
    $bininfo = BSUtil::retrieve(\*BI, 1) if @bininfo_s && $bininfo_s[7];
    close BI;
    if ($bininfo) {
      $bininfo->{'.bininfo'} = {'id' => "$bininfo_s[9]/$bininfo_s[7]/$bininfo_s[1]"} if $withid;
      return $bininfo;
    }
  }
  # old style bininfo or no bininfo, create it
  $bininfo = {};
  @bininfo_s = ();
  for my $file (ls($dir)) {
    $bininfo->{'.nosourceaccess'} = {} if $file eq '.nosourceaccess';
    if ($file !~ /\.(?:$binsufsre)$/) {
      $bininfo->{'.nouseforbuild'} = {} if $file eq '.channelinfo' || $file eq 'updateinfo.xml' || $file eq '.updateinfodata' || $file eq '.nouseforbuild';
      if ($file =~ /\.obsbinlnk$/) {
	my @s = stat("$dir/$file");
	my $d = BSUtil::retrieve("$dir/$file", 1);
	next unless @s && $d;
	my $r = {%$d, 'filename' => $file, 'id' => "$s[9]/$s[7]/$s[1]"};
	delete $r->{'path'};
	$bininfo->{$file} = $r;
      } elsif ($file =~ /[-.]appdata\.xml$/ || $file eq '_modulemd.yaml' || $file =~ /slsa_provenance\.json$/ || $file eq 'updateinfo.xml') {
        local *F;
        open(F, '<', "$dir/$file") || next;
        my @s = stat(F);
        next unless @s;
        my $ctx = Digest::MD5->new;
        $ctx->addfile(*F);
        close F;
        $bininfo->{$file} = {'md5sum' => $ctx->hexdigest(), 'filename' => $file, 'id' => "$s[9]/$s[7]/$s[1]"};
      } elsif ($file =~ /\.helminfo$/) {
	my @s = stat("$dir/$file");
	my $r = helminfo2bininfo($dir, $file);
	next unless $r;
	$r->{'filename'} = $file;
	$r->{'id'} = "$s[9]/$s[7]/$s[1]";
	$bininfo->{$file} = $r;
      }
      next;
    }
    my @s = stat("$dir/$file");
    next unless @s;
    my $id = "$s[9]/$s[7]/$s[1]";
    my $data;
    eval {
      my $leadsigmd5;
      die("$dir/$file: no hdrmd5\n") unless Build::queryhdrmd5("$dir/$file", \$leadsigmd5);
      $data = Build::query("$dir/$file", 'evra' => 1);
      die("$dir/$file: queury failed\n") unless $data;
      BSVerify::verify_nevraquery($data);
      $data->{'leadsigmd5'} = $leadsigmd5 if $leadsigmd5;
    };
    if ($@) {
      warn($@);
      next;
    }
    $data->{'filename'} = $file;
    $data->{'id'} = $id;
    $bininfo->{$file} = $data;
  }
  eval {
    BSUtil::store("$dir/.bininfo.new", "$dir/.bininfo", $bininfo);
    @bininfo_s = stat("$dir/.bininfo");
    $bininfo->{'.bininfo'} = {'id' => "$bininfo_s[9]/$bininfo_s[7]/$bininfo_s[1]"} if @bininfo_s && $withid;
  };
  warn($@) if $@;
  return $bininfo;
}


=head2 read_gbininfo - get "global" bininfo data for all packages

 alien: gbininfo is from another scheduler, do not modify
 dontmerge: no not write merged gbininfo back
 dstcache: cache for bininfo and full data

=cut

sub read_gbininfo {
  my ($gdst, $alien, $dontmerge, $dstcache) = @_;

  my $bininfocache = $dstcache ? $dstcache->{'bininfocache'} : undef;
  $bininfocache = undef if $bininfocache && ($bininfocache->{'gdst'} || '') ne $gdst;

  my $gbininfo;
  if ($bininfocache && $bininfocache->{'base'}) {
    $gbininfo = BSUtil::clone($bininfocache->{'base'});
  } else {
    return {} unless -d $gdst;
    $gbininfo = BSUtil::retrieve("$gdst/:bininfo", 1);
  }

  my $gbininfo_m;
  if ($gbininfo) {
    if ($bininfocache && $bininfocache->{'merge'}) {
      $gbininfo_m = BSUtil::clone($bininfocache->{'merge'});
      $bininfocache->{'base'} ||= BSUtil::clone($gbininfo);
    } else {
      return $gbininfo unless -e "$gdst/:bininfo.merge";
      $gbininfo_m = BSUtil::retrieve("$gdst/:bininfo.merge", 1);
      $gbininfo_m = undef if $gbininfo_m && $gbininfo_m->{'/outdated'};
    }
  }

  if ($gbininfo && $gbininfo_m) {
    for (keys %$gbininfo_m) {
      if ($gbininfo_m->{$_}) {
        $gbininfo->{$_} = $gbininfo_m->{$_};
      } else {
        delete $gbininfo->{$_};
      }
    }
    return $gbininfo if $dontmerge;
  } else {
    return undef if $alien;
    $gbininfo = {};
    my @gdst = split('/', $gdst);
    print "    rebuilding project repoinfo for $gdst[-3]/$gdst[-2]...\n";
    for my $packid (grep {!/^[:\.]/} ls($gdst)) {
      next if $packid eq '_deltas';
      next unless -d "$gdst/$packid";
      my $bininfo = read_bininfo("$gdst/$packid", 1);
      if ($bininfo) {
        for (values %$bininfo) {
          delete $_->{'provides'};
          delete $_->{'requires'};
        }
        $gbininfo->{$packid} = $bininfo;
      }
    }
  }
  return $gbininfo if $alien;
  eval {
    BSUtil::store("$gdst/.:bininfo", "$gdst/:bininfo", $gbininfo);
    unlink("$gdst/:bininfo.merge");
  };
  warn($@) if $@;
  return $gbininfo;
}

=head2 rebuild_gbininfo - force a rebuild of the bininfo data

=cut

sub rebuild_gbininfo {
  my ($gdst) = @_;
  unlink("$gdst/:bininfo");
  unlink("$gdst/:bininfo.merge");
  return read_gbininfo($gdst);
}

=head2 findmeta - find the correct meta for a binary in a package directory

=cut

sub findmeta {
  my ($gdst, $packid, $r, $zerook) = @_;
  if ($r->{'imported'}) {
    my $fn = $r->{'filename'};
    if ($fn =~ s/^::import::/.meta.success.import./s) {
      $fn =~ s/::.*//;
      return "$gdst/$packid/$fn" if -s "$gdst/$packid/$fn";
    }
  } else {
    return "$gdst/$packid/.meta.success" if -s "$gdst/$packid/.meta.success";
  }
  my $fn = $r->{'filename'};
  $fn = substr($fn, 0, length($fn) - length($r->{'suf'}) - 1) . '.meta';
  if ($zerook) {
    return "$gdst/$packid/$fn" if -e "$gdst/$packid/$fn";
  } else {
    return "$gdst/$packid/$fn" if -s "$gdst/$packid/$fn";
  }
  return undef;
}

=head2 remove_from_volatile - remove binaries from the _volatile package

=cut

sub remove_from_volatile {
  my ($gdst, $del, $dstcache) = @_;
  for my $r (@$del) {
    my $bin = $r->{'filename'};
    next unless $bin =~ /^(.*)\.($binsufsre_binlnk)$/; # hmm?
    print "      - _volatile/$bin\n";
    unlink("$gdst/_volatile/$1.meta");
    unlink("$gdst/_volatile/$bin");
  }
  unlink("$gdst/_volatile/.bininfo");
  my $bininfo = read_bininfo("$gdst/_volatile", 1);
  update_bininfo_merge($gdst, '_volatile', $bininfo, $dstcache);
}

=head2 wipe - remove a built result

=cut

sub wipe {
  my ($gctx, $prp, $packid, $dstcache, $allarch) = @_;

  my ($projid, $repoid) = split('/', $prp, 2);
  my $myarch = $gctx->{'arch'};
  my $reporoot = $gctx->{'reporoot'};
  my $gdst = "$reporoot/$prp/$myarch";
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid} || {};
  my $pdata = ($proj->{'package'} || {})->{$packid} || {};

  my $locked = 0;
  $locked = BSUtil::enabled($repoid, $proj->{'lock'}, $locked, $myarch) if $proj->{'lock'};
  $locked = BSUtil::enabled($repoid, $pdata->{'lock'}, $locked, $myarch) if $pdata->{'lock'};
  if ($locked) {
    print "ignoring wipe, package $projid/$packid is locked!\n";
    return;
  }
  undef $allarch if $allarch && $proj->{'lock'} || $pdata->{'lock'};	# too dangerous

  # delete repository done flag
  unlink("$gdst/:repodone");
  # delete full entries
  my $importarch = !$allarch ? '' : undef;					# keep those imports
  update_dst_full($gctx, $prp, $packid, undef, undef, $dstcache, $importarch);
  delete $gctx->{'repounchanged'}->{$prp};
  # delete other files
  unlink("$gdst/:logfiles.success/$packid");
  unlink("$gdst/:logfiles.fail/$packid");
  unlink("$gdst/:meta/$packid");
  my $dst = "$gdst/$packid";
  for my $f (ls($dst)) {
    next if $f eq 'history' || $f eq '.bininfo' || $f eq '.stats';
    next if !$allarch && ($f =~ /^::import::/ || $f =~ /^\.meta\.success\.import\./);	# keep those imports
    if (-d "$dst/$f") {
      BSUtil::cleandir("$dst/$f");
      rmdir("$dst/$f");
    } else {
      unlink("$dst/$f");
    }
  }
  rmdir($dst);       # in case there is no history
}

sub set_dstcache_prp {
  my ($gctx, $dstcache, $prp) = @_;
  # sync the bininfocache before the fullcache so that we have the correct
  # data in case we need to rebuild the full tree in sync_fullcache
  my $bininfocache = $dstcache->{'bininfocache'};
  if ($bininfocache) {
    if ($prp) {
      my $gdst = "$gctx->{'reporoot'}/$prp/$gctx->{'arch'}";
      sync_bininfocache($gctx, $bininfocache) if $bininfocache->{'gdst'} && $bininfocache->{'gdst'} ne $gdst;
    } else {
      sync_bininfocache($gctx, $bininfocache) if $bininfocache->{'gdst'};
    }
  }
  my $fullcache = $dstcache->{'fullcache'};
  if ($fullcache) {
    if ($prp) {
      BSSched::BuildRepo::sync_fullcache($gctx, $fullcache) if $fullcache->{'prp'} && $fullcache->{'prp'} ne $prp;
      $fullcache->{'prp'} = $prp;
    } else {
      BSSched::BuildRepo::sync_fullcache($gctx, $fullcache) if %$fullcache;
    }
  }
}

=head2 wipeobsolete - remove an obsolete package from the repo

This is similar to wipe(), but also removes the .history file and ignores the
useforbuild flag.

=cut

sub wipeobsolete {
  my ($gctx, $prp, $packid, $dstcache, $reason, $allarch) = @_;

  my $projpacks = $gctx->{'projpacks'};
  my $myarch = $gctx->{'arch'};
  my $reporoot = $gctx->{'reporoot'};
  my $gdst = "$reporoot/$prp/$myarch";
  my $dst = "$gdst/$packid";
  my @files = ls($dst);
  return 0 unless @files;
  # find imported files we have to keep
  my @ifiles = grep {/^::import::/ || /^\.meta\.success\.import\./} @files;
  @ifiles = () if $allarch;
  if (@ifiles) {
    # only imported stuff?
    return 0 unless grep {$_ ne '.bininfo' && !(/^::import::/ || /^\.meta\.success\.import\./)} @files;
  }
  print "      - $packid: $reason\n" if $reason;
  my ($projid, $repoid) = split('/', $prp, 2);
  # delete repository done flag
  unlink("$gdst/:repodone");
  # don't wipe imports if we're obsoleting just one arch
  my $importarch = !$allarch && @ifiles ? '' : undef;
  # delete full entries
  update_dst_full($gctx, $prp, $packid, undef, undef, $dstcache, $importarch, 1);
  delete $gctx->{'repounchanged'}->{$prp};
  # delete other files
  unlink("$gdst/:logfiles.success/$packid");
  unlink("$gdst/:logfiles.fail/$packid");
  unlink("$gdst/:meta/$packid");
  if (@ifiles) {
    # keep those imports
    for my $f (@files) {
      next if $f eq '.bininfo';
      next if $f =~ /^::import::/ || $f =~ /^\.meta\.success\.import\./;	# keep those imports
      if (-d "$dst/$f") {
        BSUtil::cleandir("$dst/$f");
        rmdir("$dst/$f");
      } else {
        unlink("$dst/$f");
      }
    }
  } else {
    BSUtil::cleandir($dst);
  }
  rmdir($dst);
  return 1;
}

=head2 wipeobsoleterepo - remove an obsolete repo

Note that :repo and :repoinfo must be already gone

=cut

sub wipeobsoleterepo {
  my ($gctx, $prp) = @_;
  my $myarch = $gctx->{'arch'};
  my $reporoot = $gctx->{'reporoot'};
  my $gdst = "$reporoot/$prp/$myarch";
  return unless -d $gdst;
  for my $dir (ls($gdst)) {
    if (-d "$gdst/$dir") {
      BSUtil::cleandir("$gdst/$dir");
      rmdir("$gdst/$dir") || die("rmdir $gdst/$dir: $!\n");
    } else {
      unlink("$gdst/$dir") || die("unlink $gdst/$dir: $!\n");
    }
  }
  BSRedisnotify::deleteresult("$prp/$myarch") if $BSConfig::redisserver;
  # we unfortunately have a race: the reposerver may touch the :schedulerstate.dirty file
  while (!rmdir($gdst)) {
    die("$gdst: $!\n") unless -e "$gdst/:schedulerstate.dirty";
    print "rep server created dirty file $gdst/:schedulerstate.dirty, retry ...\n";
    unlink("$gdst/:schedulerstate.dirty");
  }
}

1;

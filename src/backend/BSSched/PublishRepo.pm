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
package BSSched::PublishRepo;

# ctx functions
#   prpfinished
#   publishdelta
#
# static functions
#   compile_publishfilter
#   mkdeltaname
#
# ctx usage
#   gctx
#   gdst
#   prp
#   conf
#   prpsearchpath
#
# gctx usage
#   arch
#   reporoot
#   projpacks
#   myjobsdir

use strict;
use warnings;

use Fcntl qw(:DEFAULT :flock);
use POSIX;
use Digest::MD5 ();

use BSConfiguration;
use BSOBS;
use BSUtil;
use BSUrlmapper;
use Build::Rpm;			# for verscmp

use BSSched::ProjPacks;		# for orderpackids
use BSSched::BuildJob::DeltaRpm;
use BSSched::EventSource::Directory;  # sendpublishevent
use BSSched::Blobstore;

my $default_publishfilter;
my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);


=head1 NAME

BSSched::PublishRepo - functions for publishing repositories

=head1 FUNCTIONS / METHODS

=head2 compile_publishfilter - TODO

TODO

=cut

sub compile_publishfilter {
  my ($filter) = @_;
  return undef unless $filter;
  my @res;
  for (@$filter) {
    eval {
      push @res, qr/$_/;
    };
  }
  return \@res;
}

sub wait_for_lock {
  my ($fd, $timeout) = @_;

  while (1) {
    return 1 if flock($fd, defined($timeout) ? LOCK_EX | LOCK_NB : LOCK_EX);
    die("flock: $!\n") unless $! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK;
    next unless defined $timeout;
    return 0 if $timeout <= 0;
    sleep(3);
    $timeout -= 3;
  }
}

=head2 prpfinished  - publish a prp

 updates :repo and sends an event to the publisher

 input:  $prp        - the finished prp
         $packs      - packages in project
                       undef -> arch no longer builds this repository
         $pubenabled - only publish those packages
=cut

sub prpfinished {
  my ($ctx, $packs, $pubenabled, $nodelayed, $keepobsolete) = @_;

  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $myarch = $gctx->{'arch'};
  my $reporoot = $gctx->{'reporoot'};
  my $projpacks = $gctx->{'projpacks'};
  my $prp = $ctx->{'prp'};
  my $rdir = "$gdst/:repo";
  print "    publishing $prp...\n";

  my ($projid, $repoid) = split('/', $prp, 2);

  local *F;
  open(F, '>', "$reporoot/$prp/.finishedlock") || die("$reporoot/$prp/.finishedlock: $!\n");
  if (!flock(F, LOCK_EX | LOCK_NB)) {
    print "    waiting for lock...\n";
    if (!wait_for_lock(\*F, $packs && !$nodelayed ? 300 : undef)) {
      print "    could not get lock...\n";
      close F;
      return 'delayed:lock timeout';
    }
    print "    got the lock...\n";
  }

  if (!$packs) {
    # delete all in :repo
    unlink("${rdir}info");
    if (-d $rdir) {
      my @blobs = grep {/^_blob\./} ls($rdir);
      BSUtil::cleandir($rdir);
      rmdir($rdir) || die("rmdir $rdir: $!\n");
      for my $blob (sort @blobs) {
	BSSched::Blobstore::blobstore_chk($gctx, $blob);
      }
    } elsif (! -e "$reporoot/$prp/:repoinfo") {
      print "    nothing to delete...\n";
      close(F);
      return '';
    }
    # release lock and ping publisher
    close(F);
    BSSched::EventSource::Directory::sendpublishevent($gctx, $prp);
    return '';
  }

  my $bconf = $ctx->{'conf'};

  # to produce a failure for the test suite
  if (grep {"$_:" =~ /:(?:publisherror):/} @{$bconf->{'repotype'} || []}) {
      return "Testcase publish error";
  }

  die unless $pubenabled;

  my $rinfo;
  my $rinfo_packid2bins;

  # read old repoinfo if we have packages that have publishing disabled
  if ($keepobsolete || grep {!$pubenabled->{$_}} @$packs) {
    $rinfo = {};
    $rinfo = BSUtil::retrieve("${rdir}info") if -s "${rdir}info";
    # create package->binaries helper hash
    $rinfo_packid2bins = {};
    my $rb = $rinfo->{'binaryorigins'} || {};
    for (keys %$rb) {
      push @{$rinfo_packid2bins->{$rb->{$_}}}, $_;
    }
    my $rc = $rinfo->{'conflicts'} || {};
    for my $rbin (keys %$rc) {
      for my $packid (@{$rc->{$rbin} || []}) {
        push @{$rinfo_packid2bins->{$packid}}, $rbin unless ($rb->{$rbin} || '') eq $packid;
      }
    }
  }

  # honor keepobsolete flag
  if ($keepobsolete) {
    $packs = [ @$packs ];	# so we can add packages
    my %known = map {$_ => 1} @$packs;
    my @obsolete = grep {!$known{$_}} sort keys %$rinfo_packid2bins;
    push @$packs, @obsolete;
    $keepobsolete = { map {$_ => 1} @obsolete };
  }

  # make all the deltas we need
  my $needdeltas;
  $needdeltas = 1 if grep {"$_:" =~ /:(?:deltainfo|prestodelta):/} @{$bconf->{'repotype'} || []};
  my ($deltas, $err) = makedeltas($ctx, $needdeltas ? $packs : undef, $pubenabled);
  if (!$deltas) {
      close(F);
      $err ||= 'internal error';
      $err = "delta generation: $err";
      return $err;
  }


  # link all packages into :repo, put origin data into :repoinfo
  my %origin;
  my $changed;
  my $filter;
  my %conflicts;
  $filter = $bconf->{'publishfilter'} if $bconf;
  undef $filter if $filter && !@$filter;
  $filter ||= $default_publishfilter;
  eval { $filter = compile_publishfilter($filter) };
  if ($@) {
    my $err = $@;
    chomp $err;
    return "invalid publish filter: $err";
  }

  my $seen_binary;
  my $singleexport;
  $singleexport = $bconf->{'singleexport'} if $bconf;						# obsolete
  $singleexport = 1 if $bconf && grep {$_ eq 'singleexport'} @{$bconf->{'repotype'} || []};	# obsolete
  $singleexport = 1 if $bconf && $bconf->{'publishflags:singleexport'};
  if ($singleexport) {
    print "    prp $prp is singleexport\n";
    $seen_binary = {};
  }

  # let the publisher decide about empty repositories
  $changed = 1 if $bconf && ($bconf->{'publishflags:createempty'} || $bconf->{'publishflags:create_empty'}) && ! -e "$reporoot/$prp/:repoinfo";

  my %newchecksums;
  # sort like in the full tree
  for my $packid (BSSched::ProjPacks::orderpackids($projpacks->{$projid}, @$packs)) {
    if (!$pubenabled->{$packid}) {
      # publishing of this package is disabled, copy binary list from old info
      die unless $rinfo_packid2bins;
      if ($keepobsolete && $keepobsolete->{$packid}) {
        print "        $packid: keeping obsolete\n";
      } else {
        print "        $packid: publishing disabled\n";
      }
      my $rb = $rinfo->{'binaryorigins'} || {};
      for my $rbin (@{$rinfo_packid2bins->{$packid} || []}) {
	if (exists $origin{$rbin}) {
	  push @{$conflicts{$rbin}}, $origin{$rbin} unless $conflicts{$rbin};
	  push @{$conflicts{$rbin}}, $packid;
	  next;		# first one wins
	}
	next unless ($rb->{$rbin} || '') eq $packid;	# ignore if this is from a conflict
	$origin{$rbin} = $packid;
      }
      next;
    }
    my $pdir = "$gdst/$packid";
    my @all = sort(ls($pdir));
    my %all = map {$_ => 1} @all;
    next if $all{'.preinstallimage'};
    my $debian = grep {/\.dsc$/} @all;
    my $nosourceaccess = $all{'.nosourceaccess'};
    @all = grep {$_ ne '_ccache.tar' && $_ ne 'history' && $_ ne 'logfile' && $_ ne 'rpmlint.log' && $_ ne '_statistics' && $_ ne '_buildenv' && $_ ne '_channel' && $_ ne '_slsa_provenance.json' && $_ ne '_slsa_provenance.config' && $_ ne 'meta' && $_ ne 'status' && $_ ne 'reason' && !/^\./} @all;
    @all = grep {!/slsa_provenance\.json$/} @all;
    my $taken;
    for my $bin (@all) {
      next if $bin =~ /^::import::/;
      next if $bin =~ /\.obsbinlnk$/;
      my $rbin = $bin;
      # XXX: should be source name instead?
      $rbin = "${packid}::$bin" if $debian || $bin eq 'updateinfo.xml' || $bin eq '_modulemd.yaml';
      if (exists $origin{$rbin}) {
	  push @{$conflicts{$rbin}}, $origin{$rbin} unless $conflicts{$rbin};
	  push @{$conflicts{$rbin}}, $packid;
	  next;		# first one wins
      }
      if ($nosourceaccess) {
        next if $bin =~ /\.(?:no)?src\.rpm$/;
        next if $bin =~ /-debug(:?info|source).*\.rpm$/;
        next if $debian && ($bin !~ /\.deb$/);
      }
      if ($seen_binary) {
        if ($bin =~ /(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/) {
          next if $seen_binary->{"$1.$2"};
          $seen_binary->{"$1.$2"} = 1;
        }
      }
      if ($filter) {
        my $bad;
        for (@$filter) {
          next unless $bin =~ /$_/;
          $bad = 1;
          last;
        }
        next if $bad;
      }
      $origin{$rbin} = $packid;

      # find out if we have a corresponding provenance file
      my $provenance;
      my $rprovenance;
      if ($bin =~ /^(.*)\.(?:$binsufsre|containerinfo)$/) {
        $provenance = "$pdir/$1.slsa_provenance.json" if $all{"$1.slsa_provenance.json"};
        $provenance = "$pdir/_slsa_provenance.json" if !$provenance && $all{'_slsa_provenance.json'};
	if ($provenance) {
	  if ($rbin =~ /^(.*)\.(?:$binsufsre|containerinfo)$/) {
            $rprovenance = "$1.slsa_provenance.json";
	  } else {
            $rprovenance = "$rbin.slsa_provenance.json";
	  }
	}
      }

      # link from package dir (pdir) to repo dir (rdir)
      my @sr = lstat("$rdir/$rbin");
      if (@sr) {
        my $risdir = -d _ ? 1 : 0;
        my @s = lstat("$pdir/$bin");
        my $pisdir = -d _ ? 1 : 0;
        next unless @s;
        if ("$s[9]/$s[7]/$s[1]" eq "$sr[9]/$sr[7]/$sr[1]") {
          # unchanged file, check deltas
          if ($deltas->{"$packid/$bin"}) {
            for my $delta (@{$deltas->{"$packid/$bin"}}) {
              $changed = 1 if publishdelta($ctx, $delta, $bin, $rdir, $rbin, \%origin, $packid);
            }
          }
          $changed = 1 if $provenance && publishprovenance($ctx, $provenance, $rdir, $rprovenance, \%origin, $packid);
          next;
        }
        if ($risdir && $pisdir) {
          my $rdirinfo = BSUtil::treeinfo("$rdir/$rbin");
          my $pdirinfo = BSUtil::treeinfo("$pdir/$bin");
          next if join(',', @$rdirinfo) eq join(',', @$pdirinfo);
        }
        print "      ! :repo/$rbin ($packid)\n";
        if ($risdir) {
          BSUtil::cleandir("$rdir/$rbin");
          rmdir("$rdir/$rbin");
        } else {
	  unlink("$rdir/$rbin");
	  BSSched::Blobstore::blobstore_chk($gctx, $rbin) if $rbin =~ /^_blob\./;
        }
      } else {
        print "      + :repo/$rbin ($packid)\n";
        mkdir_p($rdir) unless -d $rdir;
      }
      # new or changed, link
      $taken = 1;
      if (! -l "$pdir/$bin" && -d _) {
        BSUtil::linktree("$pdir/$bin", "$rdir/$rbin");
      } else {
        link("$pdir/$bin", "$rdir/$rbin") || die("link $pdir/$bin $rdir/$rbin: $!\n");
        if ($deltas->{"$packid/$bin"}) {
          for my $delta (@{$deltas->{"$packid/$bin"}}) {
            publishdelta($ctx, $delta, $bin, $rdir, $rbin, \%origin, $packid);
          }
        }
        publishprovenance($ctx, $provenance, $rdir, $rprovenance, \%origin, $packid) if $provenance;
      }
      $changed = 1;
    }

    # merge checksums if we took at least one binary
    if ($taken && $all{'.checksums'}) {
      my $nc = readstr("$pdir/.checksums", 1);
      $newchecksums{$packid} = $nc if defined $nc;
    }
  }
  undef $rinfo_packid2bins;     # no longer needed

  # delete obsolete files
  for my $rbin (sort(ls($rdir))) {
    next if exists $origin{$rbin};
    next if $rbin eq '.newchecksums' || $rbin eq '.newchecksums.new' || $rbin eq '.checksums' || $rbin eq '.checksums.new';
    next if ($rbin eq '.archsync' || $rbin eq '.archsync.new') && $bconf->{'publishflags:archsync'};
    if ($conflicts{$rbin}) {
      # we lost the original origin. Reassign for blobs as we know the content is identical
      if ($rbin =~ /^_blob\./) {
	$origin{$rbin} = $conflicts{$rbin}->[0];
	next;
      }
    }
    print "      - :repo/$rbin\n";
    if (! -l "$rdir/$rbin" && -d _) {
      BSUtil::cleandir("$rdir/$rbin");
      rmdir("$rdir/$rbin") || die("rmdir $rdir/$rbin: $!\n");
    } else {
      if (-f "$rdir/$rbin") {
        unlink("$rdir/$rbin") || die("unlink $rdir/$rbin: $!\n");
        BSSched::Blobstore::blobstore_chk($gctx, $rbin) if $rbin =~ /^_blob\./;
      }
    }
    $changed = 1;
  }

  # write new rpminfo
  $rinfo = {'binaryorigins' => \%origin};
  $rinfo->{'conflicts'} = \%conflicts if %conflicts;
  BSUtil::store("${rdir}info.new", "${rdir}info", $rinfo);

  # update checksums
  if (%newchecksums) {
    if (-e "$rdir/.newchecksums") {
      print "    merging new checksums...\n";
      my $oldchecksums = BSUtil::retrieve("$rdir/.newchecksums", 1) || {};
      my %knownpackids = map {$_ => 1} @$packs;
      for my $packid (keys %$oldchecksums) {
	$newchecksums{$packid} = $oldchecksums->{$packid} if !exists($newchecksums{$packid}) && $knownpackids{$packid};
      }
    }
    BSUtil::store("$rdir/.newchecksums.new", "$rdir/.newchecksums", \%newchecksums);
  }

  # update archsync information
  if ($bconf->{'publishflags:archsync'}) {
    my $oldas = BSUtil::retrieve("$rdir/.archsync", 1) || {};
    my $as = { 'lastcheck' => time(), 'lastchange' => $oldas->{'lastchange'} };
    $as->{'lastchange'} = $as->{'lastcheck'} if $changed || !$as->{'lastchange'};
    $changed = 1 if -e "$rdir/.archsync.new";	# hack, see bs_publish
    mkdir_p($rdir) unless -d $rdir;
    BSUtil::store("$rdir/.archsync.new", "$rdir/.archsync", $as);
  }

  # release lock and ping publisher
  close(F);
  BSSched::EventSource::Directory::sendpublishevent($ctx->{'gctx'}, $prp) if $changed;
  return '';
}

=head2 makedeltas - calculate list of needed delta rpms and create build jobs

make sure that we have all of the deltas we need
create a deltajob if some are missing
note that we must have the repo lock so that $extrep does not change!

=cut

sub makedeltas {
  my ($ctx, $packs, $pubenabled) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $prp = $ctx->{'prp'};
  my $gdst = $ctx->{'gdst'};
  my ($projid, $repoid) = split('/', $prp, 2);
  my $rdir = "$gdst/:repo";
  my $ddir = "$gdst/_deltas";

  my %oldbins;

  my %havedelta;
  my @needdelta;
  my %deltaids;

  my $partial_job;
  my $unfinished;
  my $jobsize = 0;

  my $suffix;
  my $running_jobs = 0;
  my $maxjobs = 100;

  my $deltabuilder = BSSched::BuildJob::DeltaRpm->new();

  my %running_ids;
  if ($maxjobs > 1) {
    $suffix = 0;
    my $jobprefix = BSSched::BuildJob::jobname($prp, '_deltas');
    my $myjobsdir = $gctx->{'myjobsdir'};
    for my $job (grep {$_ eq $jobprefix || /^\Q$jobprefix-\E\d+$/} ls($myjobsdir)) {
      $running_jobs++;
      if ($job =~ /(\d+)$/) {
        $suffix = $1 if $1 > $suffix;
      }
      $running_ids{$_} = 1 for grep {s/\.info$//} ls("$myjobsdir/$job:dir");
    }
  }

  my %ddir = map {$_ => 1} ls($ddir);

  # first collect all binary names
  my %binarchnames;
  for my $packid (@{$packs || []}) {
    next if $pubenabled && !$pubenabled->{$packid};
    my $pdir = "$gdst/$packid";
    my @all = sort(ls($pdir));
    my $nosourceaccess = grep {$_ eq '.nosourceaccess'} @all;
    @all = grep {/\.rpm$/} @all;
    next unless @all;
    for my $bin (@all) {
      next if $bin =~ /^::import::/;    # no deltas for imports, they don't get published
      next if $bin =~ /\.(?:no)?src\.rpm$/;     # no source deltas
      next if $bin =~ /-debug(:?info|source).*\.rpm$/;  # no debug deltas
      next unless $bin =~ /^(.+)-[^-]+-[^-]+\.([a-zA-Z][^\/\.\-]*)\.rpm$/;
      my $binname = $1;
      my $binarch = $2;
      push @{$binarchnames{"$binarch/$binname"}}, [ $bin, $packid ];
    }
  }

  # check for a subdir definition
  my $subdir;
  for (@{($ctx->{'conf'} || {})->{'repotype'} || []}) {
    $subdir = $1 if /^packagesubdir:([^\.\/][^\/:]+)$/;
  }

  for my $binarchname (sort keys %binarchnames) {
    # we only want deltas against the highest version
    my @binxs = sort {Build::Rpm::verscmp($b->[0], $a->[0])} @{$binarchnames{$binarchname}};
    my $didbin;
    for my $binx (@binxs) {
      my ($bin, $packid) = @$binx;
      last if $didbin && Build::Rpm::verscmp($didbin, $bin) > 0;
      my $pdir = "$gdst/$packid";
      my @binstat = stat("$pdir/$bin");
      next unless @binstat;
      $didbin = $bin;
      my ($binarch, $binname) = split('/', $binarchname, 2);

      # find all delta candidates for this package. we currently just
      # use the searchpath, this may be configurable in a later version
      my @aprp = @{$ctx->{'prpsearchpath'} || []};
      for my $aprp (@aprp) {
        # look in the *published* repos. We allow a special
        # extradeltarepos override in the config.
	if (!$oldbins{"$aprp/$binarch"}) {
	  $oldbins{"$aprp/$binarch"} = {};
	  if (!exists($oldbins{$aprp})) {
	    my $aextrep = BSUrlmapper::get_extrep($aprp);
	    $aextrep = "$aextrep/$subdir" if $subdir && $aextrep && -d "$aextrep/$subdir";
	    $aextrep = $BSConfig::extradeltarepos->{$aprp} if $BSConfig::extradeltarepos && defined($BSConfig::extradeltarepos->{$aprp});
	    $oldbins{$aprp} = $aextrep;
	  }
	  my $aextrep = $oldbins{$aprp};
	  next unless $aextrep;
	  for my $obin (sort(ls("$aextrep/$binarch"))) {
	    next unless $obin =~ /^(.+)-[^-]+-[^-]+\.(?:[a-zA-Z][^\/\.\-]*)\.rpm$/;
	    push @{$oldbins{"$aprp/$binarch"}->{$1}}, $obin;
	  }
	}
        my @cand = grep {$_ ne $bin} @{$oldbins{"$aprp/$binarch"}->{$binname}};
        next unless @cand;

        # sort and delete everything newer than bin
        # FIXME: what about the epoch? use file mtime instead?
        push @cand, $bin;
        @cand = sort { Build::Rpm::verscmp($b, $a) || ($a eq $bin ? 1 : $b eq $bin ? -1 : 0) } @cand;
        shift @cand while $cand[0] ne $bin;
        shift @cand;
        next unless @cand;

        # make this configurable
        @cand = splice(@cand, 0, 1);
        for my $obin (@cand) {
          my $aextrep = $oldbins{$aprp};
	  next unless $aextrep;
          my @s = stat("$aextrep/$binarch/$obin");
          next unless @s;
          # 2013-09-05 mls: dropped $s[1]
          my $deltaid = Digest::MD5::md5_hex("$packid/$bin/$aprp/$obin/$s[9]/$s[7]");
          if (!$ddir{$deltaid}) {
            # see if we know it under the old id
            my $olddeltaid = Digest::MD5::md5_hex("$packid/$bin/$aprp/$obin/$s[9]/$s[7]/$s[1]");
            if ($ddir{$olddeltaid}) {
              # yes, link it over
              unlink("$ddir/$deltaid");
              unlink("$ddir/$deltaid.dseq");
              $ddir{$deltaid} = 1 if link("$ddir/$olddeltaid", "$ddir/$deltaid");
              $ddir{"$deltaid.dseq"} = 1 if link("$ddir/$olddeltaid.dseq", "$ddir/$deltaid.dseq");
            }
          }
          $deltaids{$deltaid} = 1;
          if ($ddir{$deltaid}) {
            next unless $ddir{"$deltaid.dseq"};         # delta was too big
            # make sure we don't already have this one
            if (!grep {$_->[1] eq $obin} @{$havedelta{"$packid/$bin"} || []}) {
              push @{$havedelta{"$packid/$bin"}}, [ $deltaid, $obin ];
            }
            next;
          }
          $unfinished = 1;
          next if $running_ids{$deltaid};
          push @needdelta, [ "$aextrep/$binarch/$obin", "$pdir/$bin", $deltaid ];
          $jobsize += $s[7] + $binstat[7];
          if ($jobsize > 500000000) {
            # flush the job
            if ($running_jobs >= $maxjobs) {
              print "    too many delta jobs running\n";
              $partial_job = 1;
              last;
            }
            $suffix++ if defined $suffix;
            my ($job, $joberror) = $deltabuilder->build($ctx, '_deltas', undef, undef, [ $suffix, \@needdelta ]);
            return (undef, $joberror) if $joberror;
            $running_jobs++ if $job;
            @needdelta = ();
            $jobsize = 0;
          }
        }
        last if $partial_job;
      }
      last if $partial_job;
    }
    last if $partial_job;
  }

  if (@needdelta && $running_jobs < $maxjobs) {
    $suffix++ if defined $suffix;
    my ($job, $joberror) = $deltabuilder->build($ctx, '_deltas', undef, undef, [ $suffix, \@needdelta ]);
    return (undef, $joberror) if $joberror;
  }

  if ($unfinished) {
    print "    waiting for deltajobs to finish\n";
    return (undef, 'building');
  }

  # ddir maintenance
  my @ddir = sort(ls($ddir));
  for my $deltaid (grep {!$deltaids{$_} && !/\.dseq$/} @ddir) {
    next if $deltaid eq 'logfile';
    unlink("$ddir/$deltaid");           # no longer need this one
    unlink("$ddir/$deltaid.dseq");      # no longer need this one
  }
  return \%havedelta;
}

=head2 mkdeltaname - convert normal rpm name to delta rpm

=cut

sub mkdeltaname {
  my ($old, $new) = @_;
  # name-version-release.arch.rpm
  my $newtail = '';
  if ($old =~ /^(.*)(\.[^\.]+\.rpm$)/) {
    $old = $1;
  }
  if ($new =~ /^(.*)(\.[^\.]+\.rpm$)/) {
    $new = $1;
    $newtail = $2;
  }
  my @old = split('-', $old);
  my @new = split('-', $new);
  my @out;
  while (@old || @new) {
    $old = shift @old;
    $new = shift @new;
    $old = '' unless defined $old;
    $new = '' unless defined $new;
    if ($old eq $new) {
      push @out, $old;
    } else {
      push @out, "${old}_${new}";
    }
  }
  my $ret = join('-', @out).$newtail;
  $ret =~ s/\.rpm$//;
  return "$ret.drpm";
}


=head2 publishdelta - put a built deltarpm in :repo

Returns true if a delta was published (i.e. if :repo was changed)

=cut
sub publishdelta {
  my ($ctx, $delta, $bin, $rdir, $rbin, $origin, $packid) = @_;

  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $myarch = $gctx->{'arch'};
  my $prp = $ctx->{'prp'};
  my $dst = "$gdst/_deltas";
  my @s = stat("$dst/$delta->[0]");
  return 0 unless @s && $s[7];          # zero size means skip it
  return 0 unless -s "$dst/$delta->[0].dseq";   # need dseq file
  my $deltaname = mkdeltaname($delta->[1], $bin);
  return 0 if length("${rbin}::$deltaname") > 240;	# limit file name size
  my $deltaseqname = $deltaname;
  $deltaseqname =~ s/\.drpm$//;
  $deltaseqname .= '.dseq';
  my @sr = stat("$rdir/${rbin}::$deltaname");
  my $changed;
  if (!@sr || "$s[9]/$s[7]/$s[1]" ne "$sr[9]/$sr[7]/$sr[1]") {
    print @sr ? "      ! :repo/${rbin}::$deltaname\n" : "      + :repo/${rbin}::$deltaname\n";
    unlink("$rdir/${rbin}::$deltaname");
    unlink("$rdir/${rbin}::$deltaseqname");
    link("$dst/$delta->[0]", "$rdir/${rbin}::$deltaname") || die("link $dst/$delta->[0] $rdir/${rbin}::$deltaname: $!");
    link("$dst/$delta->[0].dseq", "$rdir/${rbin}::$deltaseqname") || die("link $dst/$delta->[0].dseq $rdir/${rbin}::$deltaseqname: $!");
    $changed = 1;
  }
  $origin->{"${rbin}::$deltaname"} = $packid;
  $origin->{"${rbin}::$deltaseqname"} = $packid;
  return $changed;
}

sub publishprovenance {
  my ($ctx, $provenance, $rdir, $rprovenance, $origin, $packid) = @_;
  my @s = stat($provenance);
  my @sr = stat("$rdir/$rprovenance");
  my $changed;
  if (!@sr || "$s[9]/$s[7]/$s[1]" ne "$sr[9]/$sr[7]/$sr[1]") {
    print @sr ? "      ! :repo/$rprovenance\n" : "      + :repo/$rprovenance\n";
    unlink("$rdir/$rprovenance");
    link($provenance, "$rdir/$rprovenance") || die("link $provenance $rdir/$rprovenance: $!");
    $changed = 1;
  }
  $origin->{$rprovenance} = $packid;
  return $changed;
}

1;

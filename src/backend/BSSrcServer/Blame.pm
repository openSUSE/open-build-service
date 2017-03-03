# Copyright (c) 2016 SUSE LLC
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

# Source blame implementation
# 
# algorithm:
#   - get file from next commit
#     (get_commit)
#   - call diff to find identical chunks of lines
#     (propblame, chunker)
#   - call blame algorithm recursivly for next commit
#     to blame those identical chunks
#   - assign the current commit to the remaining lines
#
# algorithm, with expand set to true:
#   - expand next commit (at the time of the commit)
#     (this will also return the expanded link target)
#     (get_commit)
#   - call diff to find identical chunks of lines
#     (propblame, chunker)
#   - call blame algorithm recursivly for next commit
#   - call diff with expanded link target to find
#     identical chunks of lines
#     (doblame_link)
#   - find local commit for the link target
#     (getlocalrev)
#   - call blame algorithm recursivly for link target
#
# the code in doblame was changed from recursion to iteration
# so that perl does not warn about "deep recursion"


package BSSrcServer::Blame;

use strict;
use warnings;

use Data::Dumper;

use BSConfiguration;
use BSFileDB;
use BSRevision;
use BSSrcrep;
use BSXML;

use BSSrcServer::Local;
use BSSrcServer::Link;

my $srcrevlay = [qw{rev vrev srcmd5 version time user comment requestid}];
my $projectsdir = "$BSConfig::bsdir/projects";

our $getrev = \&BSSrcServer::Local::getrev;
our $lsrev_expanded = \&BSRevision::lsrev;
our $lsrev_service = \&BSRevision::lsrev;

# find common chunks in two files
sub chunker {
  my ($file1, $file2) = @_;
  my @chunks;
  open(F, '-|', 'diff', '-U0', $file1, $file2) || die("diff: $!");
  my $in_pre;
  my $num_post = 0;
  while(<F>) {
    if (/^@@ -(\d+)(?:,(\d+))? +\+(\d+)(?:,(\d+))? @@/) {
      my ($ob, $on, $nb, $nn) = ($1, $2, $3, $4);
      if (@chunks && $num_post) {
	$chunks[-1]->[0] -= $num_post;
	$chunks[-1]->[1] -= $num_post;
      }   
      $on = 1 unless defined $on;
      $nn = 1 unless defined $nn;
      $ob-- if $ob && $on;
      $nb-- if $nb && $nn;
      push @chunks, [$ob + $on, $nb + $nn, $ob, $nb];
      $in_pre = 1;
      $num_post = 0;
      next;
    }
    if ($in_pre && /^ /) {
      $chunks[-1]->[2]++;
      $chunks[-1]->[3]++;
    } else {
      $in_pre = 0;
      if (/^ /) {
	$num_post++;
      } else {
	$num_post = 0;
      }   
    }
  }
  close(F);
  if (@chunks && $num_post) {
    $chunks[-1]->[0] -= $num_post;
    $chunks[-1]->[1] -= $num_post;
  }
  return \@chunks;
}

# propagate blame pointers from $rev, $files to $nvrev, $nfiles
sub propblame {
  my ($bc, $blame, $rev, $files, $nrev, $nfiles) = @_;

  my $filename = $bc->{'filename'};
  return [] if !$nfiles->{$filename} || $files->{$filename} eq $BSSrcrep::emptysrcmd5 || $nfiles->{$filename} eq $BSSrcrep::emptysrcmd5;
  if ($files->{$filename} eq $nfiles->{$filename}) {
    return [] unless grep {defined($_) && !$$_} @$blame;
    return [ @$blame ];
  }
  my $cc = "$files->{$filename}-$nfiles->{$filename}";
  my $chunks = $bc->{'chunkcache'}->{$cc};
  if (!$chunks) {
    my $file = BSRevision::revfilename($rev, $filename, $files->{$filename});
    my $nfile = BSRevision::revfilename($nrev, $filename, $nfiles->{$filename});
    $chunks = chunker($file, $nfile);
    $bc->{'chunkcache'}->{$cc} = $chunks;
  }
  my @nblame;
  my $i = 0;
  for my $c (@$chunks) {
    push @nblame, $blame->[$i++] while @nblame < $c->[3];
    push @nblame, undef while @nblame < $c->[1];
    $i = $c->[0];
  }
  push @nblame, $blame->[$i++] while $i < @$blame;
  return [] unless grep {defined($_) && !$$_} @nblame;
  return \@nblame;
}

# find a commit that is older than $ti and  has srcmd5 $srcmd5
sub findcommit {
  my ($bc, $projid, $packid, $ti, $srcmd5, $revid) = @_;
  my $revs = $bc->{'historycache'}->{"$projid/$packid"};
  if (!$revs) {
    $revs = [ BSFileDB::fdb_getall("$projectsdir/$projid.pkg/$packid.rev", $srcrevlay) ];
    $bc->{'historycache'}->{"$projid/$packid"} = $revs;
  }
  if ($revid && length($revid) < 16) {
    # check if this revision matches
    my $rev = (grep {$_->{'rev'} == $revid && $ti >= $_->{'time'}} reverse @$revs)[0];
    return $rev if $rev && (!defined($srcmd5) || $rev->{'srcmd5'} eq $srcmd5);
  }
  for my $rev (reverse @$revs) {
    next if defined($srcmd5) && $rev->{'srcmd5'} ne $srcmd5;
    if ($ti >= $rev->{'time'}) {
      return { %$rev, 'project' => $projid, 'package' => $packid };
    }
  }
  return undef;
}

# find the local commit for an expanded revision
sub getlocalrev {
  my ($bc, $rev, $ti, $files, $linkinfo, $nofallback) = @_;
  # get the local commit from the linkinfo
  my $srcmd5 = $linkinfo->{'lservicemd5'} || $rev->{'srcmd5'};
  if ($linkinfo->{'lsrcmd5'}) {
    my $orev = $getrev->($rev->{'project'}, $rev->{'package'},  $linkinfo->{'lsrcmd5'});
    my $olinkinfo = {};
    my $ofiles = BSRevision::lsrev($orev, $olinkinfo);
    $srcmd5 = $olinkinfo->{'lservicemd5'} || $linkinfo->{'lsrcmd5'};
  }
  return findcommit($bc, $rev->{'project'}, $rev->{'package'}, $ti, $srcmd5, $linkinfo->{'rev'});
}

# find the baserev of a link $l for a specific time $ti
sub find_baserev {
  my ($bc, $rev, $l, $ti, $recu) = @_;
  my $lproject = $l->{'project'} || $rev->{'project'};
  my $lpackage = $l->{'package'} || $rev->{'package'};
  # print "find_baserev $rev->{'project'}/$rev->{'package'} -> $lproject/$lpackage $ti\n";
  my $lrev;
  if ($l->{'rev'}) {
    $lrev = $getrev->($lproject, $lpackage, $l->{'rev'});
  } else {
    $lrev = findcommit($bc, $lproject, $lpackage, $ti);
    die("could not find commit in $lproject/$lpackage at time $ti\n") unless $lrev;
  }
  die("circular link\n") if $recu->{"$lproject/$lpackage/$lrev->{'rev'}"};
  $recu->{"$lproject/$lpackage/$lrev->{'rev'}"} = 1;
  my $lfiles = $lsrev_service->($lrev);
  return $lrev->{'srcmd5'} unless $lfiles->{'_link'};
  $l = BSRevision::revreadxml($rev, '_link', $lfiles->{'_link'}, $BSXML::link);
  my $baserev = find_baserev($bc, $lrev, $l, $ti);
  my %rev = (%$rev, 'linkrev' => $baserev);
  $lsrev_expanded->(\%rev);
  return $rev->{'srcmd5'};
}

# return the expaned filelist at the commit time
# this is easy when we have a baserev in the link
sub lsrev_expanded_committime {
  my ($bc, $rev, $linkinfo) = @_;
  my $files = $lsrev_service->($rev);
  return $files unless $files->{'_link'};
  my $l = BSRevision::revreadxml($rev, '_link', $files->{'_link'}, $BSXML::link);
  return $files unless $l;
  local $rev->{'linkrev'};
  if ($l->{'baserev'}) {
    # we have a baserev. good. expand link with it.
    $rev->{'linkrev'} = 'base';
  } else {
    $rev->{'linkrev'} = find_baserev($bc, $rev, $l, $rev->{'time'}, {});
    # print "lsrev_expanded_committime: expanded baserev of $rev->{'project'}/$rev->{'package'}/$rev->{'rev'} to $rev->{'linkrev'}\n";
  }
  return $lsrev_expanded->($rev, $linkinfo);
}

# get (and expand) a commit, cache result
sub get_commit {
  my ($bc, $projid, $packid, $revno) = @_;
  my $rc = $bc->{'revcache'}->{"$projid/$packid/$revno"};
  return @$rc if $rc;
  eval {
    my $rev;
    if ($bc->{'meta'}) {
      $rev = BSRevision::getrev_meta($projid, $packid, $revno);
    } else {
      $rev = $getrev->($projid, $packid, $revno);
    }
    my $linkinfo = {};
    my $files;
    if ($bc->{'expand'}) {
      $files = lsrev_expanded_committime($bc, $rev, $linkinfo);
    } elsif ($bc->{'service'}) {
      $files = $lsrev_service->($rev);
    } else {
      $files = BSRevision::lsrev($rev);
    }
    $rc = [ $rev, $files, $linkinfo ];
  };
  warn("get_commit $projid/$packid/$revno: $@") if $@;
  $rc ||= [];
  $bc->{'revcache'}->{"$projid/$packid/$revno"} = $rc;
  return @$rc;
}

# assign blame by following a link
sub doblame_link {
  my ($bc, $rev, $ti, $files, $linkinfo, $blame) = @_;

  # get (expanded) filelist
  BSSrcServer::Link::linkinfo_addtarget($rev, $linkinfo);
  my $orev = $getrev->($linkinfo->{'project'}, $linkinfo->{'package'}, $linkinfo->{'srcmd5'});
  my $olinkinfo = {};
  my $ofiles = BSRevision::lsrev($orev, $olinkinfo);

  my $oblame = propblame($bc, $blame, $rev, $files, $orev, $ofiles);
  return unless @$oblame;

  # get the local commit from the linkinfo
  my $lrev = getlocalrev($bc, $orev, $ti, $ofiles, $olinkinfo);
  if (!$lrev) {
    print "could not find local commit for $orev->{'project'}/$orev->{'package'}/$orev->{'srcmd5'}\n";
    return;
  }
  # recursive call to assign the blame.
  doblame($bc, $lrev, $ti, $ofiles, $olinkinfo, $oblame);
}

sub doblame {
  my ($bc, $rev, $ti, $files, $linkinfo, $blame) = @_;

  my @todo = ( [ $rev, $ti, $files, $linkinfo, $blame ] );

  my $revno = $rev->{'rev'};
  # do last commit twice in case of a link (both with time $ti and commit time)
  $revno++ if $bc->{'expand'};

  # go through local commits
  while ($revno > 1) {
    $revno--;
    my ($orev, $ofiles, $olinkinfo) = get_commit($bc, $rev->{'project'}, $rev->{'package'}, $revno);
    next unless $orev;
    my $oblame = propblame($bc, $blame, $rev, $files, $orev, $ofiles);
    last unless @$oblame;	# stop if nothing left to blame
    ($rev, $ti, $files, $linkinfo, $blame) = ($orev, $orev->{'time'}, $ofiles, $olinkinfo, $oblame);
    unshift @todo, [ $rev, $ti, $files, $linkinfo, $blame ];
  }

  for my $todo (@todo) {
    ($rev, $ti, $files, $linkinfo, $blame) = @$todo;

    # blame those links as well
    if ($bc->{'expand'} && $linkinfo && $linkinfo->{'srcmd5'}) {
      doblame_link($bc, $rev, $ti, $files, $linkinfo, $blame);
    }

    # assign remaining blame
    if (grep {defined($_) && !$$_} @$blame) {
      $bc->{'revs'}->{"$rev->{'project'}/$rev->{'package'}/$rev->{'rev'}"} ||= $rev;
      $rev = $bc->{'revs'}->{"$rev->{'project'}/$rev->{'package'}/$rev->{'rev'}"};
      $$_ ||= $rev for grep {defined($_)} @$blame;
    }
  }
}

sub blame {
  my ($rev, $filename, $expand, $meta) = @_;

  my $service;
  $expand = undef if $meta;
  $service = 1 if !$expand && !$meta && $filename =~ /^_service:/;

  my $bc = {
    'filename' => $filename,
    'expand' => $expand,
    'service' => $service,
    'meta' => $meta,
    'revs' => {},
    'chunkcache' => {},
    'historycache' => {},
    'revcache' => {},
  };
  my $now = time();

  # get local commit
  my $lrev = $rev;
  if (length($rev->{'rev'}) >= 16) {
    my $olinkinfo = {};
    my $ofiles = BSRevision::lsrev($rev, $olinkinfo);
    $lrev = getlocalrev($bc, $rev, $now, $ofiles, $olinkinfo);
    die("could not get local commit for $rev->{'rev'}\n") unless $lrev;
  }

  # get (expanded) files
  my $files;
  my $linkinfo = {};
  if ($expand) {
    $files = $lsrev_expanded->($rev, $linkinfo);
  } elsif ($service) {
    $files = $lsrev_service->($rev);
  } else {
    $files = BSRevision::lsrev($rev);
  }
  die("$filename does not exist\n") unless $files->{$filename};

  # setup blame scoreboard
  local *F;
  BSRevision::revopen($rev, $filename, $files->{$filename}, \*F) || die("$filename: $!\n");
  my @c;
  my @blame;
  for (split("\n", BSRevision::revreadstr($rev, $filename, $files->{$filename}))) {
    push @c, '', $_;
    push @blame, \$c[-2];
  }

  # run blame algorithm
  doblame($bc, $lrev, $now, $files, $linkinfo, \@blame);
  return \@c;
}

1;

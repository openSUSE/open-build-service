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
package BSSrcServer::Blame;

use strict;
use warnings;

use Data::Dumper;

use BSConfiguration;
use BSFileDB;
use BSRevision;
use BSSrcrep;

use BSSrcServer::Local;
use BSSrcServer::Link;

my $srcrevlay = [qw{rev vrev srcmd5 version time user comment requestid}];
my $projectsdir = "$BSConfig::bsdir/projects";

our $getrev = \&BSSrcServer::Local::getrev;
our $lsrev_expanded = \&BSRevision::lsrev;

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
      $ob-- if $ob;
      $nb-- if $nb;
      push @chunks, [$ob + ($on ? $on : 1), $nb + ($nn ? $nn : 1), $on ? $ob : $ob + 1, $nn ? $nb : $nb + 1]; 
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

# find a commit that is older than $ti and  has srcmd5 $srcmd5
sub findcommit {
  my ($bc, $projid, $packid, $ti, $srcmd5) = @_;
  my $revs = $bc->{'historycache'}->{"$projid/$packid"};
  if (!$revs) {
    $revs = [ BSFileDB::fdb_getall("$projectsdir/$projid.pkg/$packid.rev", $srcrevlay) ];
    $bc->{'historycache'}->{"$projid/$packid"} = $revs;
  }
  for my $rev (reverse @$revs) {
    next if defined($srcmd5) && $rev->{'srcmd5'} ne $srcmd5;
    if ($ti >= $rev->{'time'}) {
      return { %$rev, 'project' => $projid, 'package' => $packid };
    }
  }
  return undef;
}

sub propblame {
  my ($bc, $rev, $files, $nrev, $nfiles, $filename, $blame) = @_;

  return [] if !$nfiles->{$filename} || $files->{$filename} eq $BSSrcrep::emptysrcmd5 || $nfiles->{$filename} eq $BSSrcrep::emptysrcmd5;
  if ($files->{$filename} eq $nfiles->{$filename}) {
    return [] unless grep {defined($_) && !$$_} @$blame;
    return [ @$blame ];
  }
  return [ @$blame ] if $files->{$filename} eq $nfiles->{$filename};
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

sub doblame {
  my ($bc, $rev, $revno, $ti, $files, $filename, $linkinfo, $blame) = @_;

  my $nextrevno = $revno - 1;
  while ($nextrevno > 0) {
    my $rc = $bc->{'revcache'}->{"$rev->{'project'}/$rev->{'package'}/$nextrevno"};
    if (!$rc) {
      eval {
        my $orev;
        if ($bc->{'meta'}) {
          $orev = BSRevision::getrev_meta($rev->{'project'}, $rev->{'package'}, $nextrevno);
        } else {
          $orev = $getrev->($rev->{'project'}, $rev->{'package'}, $nextrevno);
        }
        $orev->{'linkrev'} = 'base';
        my $olinkinfo = {};
        my $ofiles;
        if ($bc->{'expand'} && !$bc->{'meta'}) {
          $ofiles = $lsrev_expanded->($orev, $olinkinfo);
        } else {
          $ofiles = BSRevision::lsrev($orev);
        }
	$rc = [ $orev, $ofiles, $olinkinfo ];
        $bc->{'revcache'}->{"$rev->{'project'}/$rev->{'package'}/$nextrevno"} = $rc;
      };
      if ($@) {
	warn($@);
        $nextrevno--;
	next;
      }
    }
    my ($orev, $ofiles, $olinkinfo) = @$rc;
    my $nblame = propblame($bc, $rev, $files, $orev, $ofiles, $filename, $blame);
    doblame($bc, $orev, $orev->{'rev'}, $orev->{'time'}, $ofiles, $filename, $olinkinfo, $nblame) if @$nblame;
    last;
  }
  if ($linkinfo && $linkinfo->{'srcmd5'} && !$bc->{'meta'}) {
    BSSrcServer::Link::linkinfo_addtarget($rev, $linkinfo);
    my $orev = $getrev->($linkinfo->{'project'}, $linkinfo->{'package'}, $linkinfo->{'srcmd5'});
    my $olinkinfo = {};
    my $ofiles = BSRevision::lsrev($orev, $olinkinfo);
    my $osrcmd5 = $olinkinfo->{'lsrcmd5'} || $linkinfo->{'srcmd5'};
    my $lorev = findcommit($bc, $orev->{'project'}, $orev->{'package'}, $ti, $osrcmd5);
    if (!$lorev) {
      $lorev = findcommit($bc, $orev->{'project'}, $orev->{'package'}, $ti);
    }
    if ($lorev) {
      $orev = $lorev;
      # ok, got the commit and the expanded files. now blame.
      my $nblame = propblame($bc, $rev, $files, $orev, $ofiles, $filename, $blame);
      doblame($bc, $orev, $orev->{'rev'}, $ti, $ofiles, $filename, $olinkinfo, $nblame) if @$nblame;
    }
  }
  # blame the rest on this commit
  if (grep {defined($_) && !$$_} @$blame) {
    $bc->{'revs'}->{"$rev->{'project'}/$rev->{'package'}/$revno"} ||= { %$rev, 'rev' => $revno };
    my $r = $bc->{'revs'}->{"$rev->{'project'}/$rev->{'package'}/$revno"};
    $$_ ||= $r for grep {defined($_)} @$blame;
  }
}

sub blame {
  my ($rev, $filename, $expand, $meta) = @_;
  my $bc = {
    'expand' => $expand,
    'meta' => $meta,
    'revs' => {},
    'chunkcache' => {},
    'historycache' => {},
    'revcache' => {},
  };
  my $files;
  my $revno = $rev->{'rev'};
  my $now = time();
  if (length($revno) >= 16) {
    my $lrev = findcommit($bc, $rev->{'project'}, $rev->{'package'}, $now, $revno);
    die("$rev->{'project'}/$rev->{'package'}: could not find commit $revno\n") unless $lrev;
    $rev = $lrev;
  }
  my $linkinfo = {};
  if ($expand && !$meta) {
    $files = $lsrev_expanded->($rev, $linkinfo);
  } else {
    $files = BSRevision::lsrev($rev);
  }
  die("$filename does not exist\n") unless $files->{$filename};
  local *F;
  BSRevision::revopen($rev, $filename, $files->{$filename}, \*F) || die("$filename: $!\n");
  my @c = split("\n", BSRevision::revreadstr($rev, $filename, $files->{$filename}));
  my @blame = map {my $x = ''; \$x} @c;
  doblame($bc, $rev, $revno, $now, $files, $filename, $linkinfo, \@blame);
  for (splice @c) {
    push @c, ${shift @blame}, $_;
  }
  return \@c;
}

1;

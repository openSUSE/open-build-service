#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
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
#######################################################
#
# Tiny file-based relational database based on perl's Storage module.

package BSDBIndex;

use strict;
use Fcntl qw(:DEFAULT :flock);
use POSIX;
use Digest::MD5 ();
use Storable ();
use Data::Dumper;

sub opendb {
  my ($path) = @_;
  return bless {'dir' => $path};
}

sub _getdata {
  my ($db, $file) = @_;

  my $fn = Digest::MD5::md5_hex($file);
  my $dn = substr($fn, 0, 2);
  $fn = substr($fn, 2);
  my $dbdir = $db->{'dir'};
  local *F;
  open(F, '<', "$dbdir/$dn/$fn") || return ();
  if (! -s F) {
    close F;
    return ();
  }
  my $data = Storable::fd_retrieve(\*F);
  die("retrieve $dbdir/$dn/$fn failed\n") unless $data;
  close F;
  return @$data;
}

sub gettables {
  my ($db) = @_;
  return _getdata($db, '');
}

sub getkeys {
  my ($db, $table) = @_;
  return _getdata($db, $table);
}

sub getvalues {
  my ($db, $table, $key) = @_;
  return _getdata($db, "$table\0$key");
}

# reladd: relations to add to db
# relrem: relations to remove from db
# relations are triplets:
#   rel[0] - key
#   rel[1] - value
#   rel[2] - data
#
sub modify {
  my ($db, $relrem, $reladd) = @_;
  my %usedfiles;
  my %addbyfile;
  my %rembyfile;

  for my $rel (@{$relrem || []}) {
    my $file;
    if (defined($rel->[1])) {
      $file = "$rel->[0]\0$rel->[1]";
    } elsif (defined($rel->[0])) {
      $file = "$rel->[0]";
    } else {
      $file = "";
    }
    $usedfiles{$file} = undef;
    push @{$rembyfile{$file}}, $rel;
  }
  for my $rel (@{$reladd || []}) {
    my $file;
    if (defined($rel->[1])) {
      $file = "$rel->[0]\0$rel->[1]";
    } elsif (defined($rel->[0])) {
      $file = "$rel->[0]";
    } else {
      $file = "";
    }
    $usedfiles{$file} = undef;
    push @{$addbyfile{$file}}, $rel;
  }
  delete $usedfiles{$_} for @{$db->{'blocked'} || []};

  # sort so we do not run into deadlocks
  my @usedfiles = sort keys %usedfiles;
  my $dbdir = $db->{'dir'};

  # lock our files
  for my $file (@usedfiles) {
    my $fn = Digest::MD5::md5_hex($file);
    my $dn = substr($fn, 0, 2);
    $fn = substr($fn, 2);
    while (1) {
      if (!sysopen($usedfiles{$file}, "$dbdir/$dn/$fn", POSIX::O_RDWR|POSIX::O_CREAT, 0666)) {
	die("$dbdir/$dn/$fn: $!\n") if $! != POSIX::ENOENT;
        next if mkdir("$dbdir/$dn") || $! == POSIX::EEXIST;
	die("mkdir $dbdir/$dn: $!\n");
      }
      die("flock $dbdir/$dn/$fn: $!\n") unless flock($usedfiles{$file}, LOCK_EX);
      last if (stat($usedfiles{$file}))[3];
    }
  }

  # read-modify-write
  for my $file (@usedfiles) {

    my $fn = Digest::MD5::md5_hex($file);
    my $dn = substr($fn, 0, 2);
    $fn = substr($fn, 2);

    my @data;
    if (-s $usedfiles{$file}) {
      my $data;
      eval {
        $data = Storable::fd_retrieve($usedfiles{$file});
      };
      if (!$data) {
	my $fn = Digest::MD5::md5_hex($file);
	my $dn = substr($fn, 0, 2);
	$fn = substr($fn, 2);
	die("retrieve file $dn/$fn failed: $@");
      }
      @data = @$data;
    }
    my $oldcnt = @data;
    my $changes = 0;
    my %data = map {$_ => $_} @data;
    for my $rel (@{$rembyfile{$file} || []}) {
      if (ref($rel->[2]) eq 'CODE') {
        @data = sort keys %data if $changes;
	$changes += $rel->[2]->($db, $rel, \@data);
	%data = map {$_ => $_} @data;
	next;
      }
      next unless exists $data{$rel->[2]};
      delete $data{$rel->[2]};
      $changes++;
    }
    for my $rel (@{$addbyfile{$file} || []}) {
      next if exists $data{$rel->[2]};
      $data{$rel->[2]} = $rel->[2];
      $changes++;
    }
    if (!$changes) {
      if (!@data) {
        unlink("$dbdir/$dn/$fn") || die("unlink $dbdir/$dn/$fn: $!\n");
      }
      close($usedfiles{$file});
      delete $usedfiles{$file};
      next;
    }
    @data = sort values %data;
    if (@data) {
      if (!$oldcnt) {
        # add to next level
	my $rel;
        $rel ||= $addbyfile{$file}->[0] if $addbyfile{$file};
        $rel ||= $rembyfile{$file}->[0] if $rembyfile{$file};
        if ($rel) {
          if (defined($rel->[1])) {
	    modify($db, undef, [[ $rel->[0], undef, $rel->[1]]]);
	  } elsif (defined($rel->[0])) {
	    modify($db, undef, [[ undef, undef, $rel->[0]]]);
	  }
        }
      }
      local *F;
      sysopen(F, "$dbdir/$dn/$fn.new", POSIX::O_RDWR|POSIX::O_CREAT, 0666) || die("$dbdir/$dn/$fn.new: $!\n");
      Storable::nstore_fd(\@data, \*F) || die("store file failed\n");
      close(F) || die("close $dbdir/$dn/$fn.new: $!\n");
      # this will free the lock
      rename("$dbdir/$dn/$fn.new", "$dbdir/$dn/$fn") || die("rename $dbdir/$dn/$fn.new $dbdir/$dn/$fn");
    } else {
      truncate $usedfiles{$file}, 0;

      # remove from next level
      my $rel;
      $rel ||= $addbyfile{$file}->[0] if $addbyfile{$file};
      $rel ||= $rembyfile{$file}->[0] if $rembyfile{$file};
      if ($rel) {
	if (defined($rel->[1])) {
	  modify($db, [[ $rel->[0], undef, $rel->[1]]], undef);
	} elsif (defined($rel->[0])) {
	  modify($db, [[ undef, undef, $rel->[0]]], undef);
	}
      }
      
      # this will free the lock
      unlink("$dbdir/$dn/$fn") || die("unlink $dbdir/$dn/$fn: $!\n");
      rmdir("$dbdir/$dn");
    }
    close($usedfiles{$file});
    delete $usedfiles{$file};
  }
}

1;

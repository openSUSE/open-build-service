#
# Copyright (c) 2018 SUSE Inc.
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
################################################################
#
# Tar file accessing
#

package BSTar;

use strict;

my @headnames = qw{name mode uid gid size mtime chksum type linkname magic version uname gname major minor prefix};

sub list {
  my ($handle) = @_;

  my $offset = 0;
  my $ispax;
  my $nameoverride;
  my @tar;

  while (1) {
    my $head = '';
    last unless (read($handle, $head, 512) || 0) == 512;
    $offset += 512;
    last if $head eq "\0" x 512;
    next if substr($head, 500, 12) ne "\0" x 12;
    my @head = unpack('A100A8A8A8A12A12A8A1A100A6A2A32A32A8A8A155x12', $head);
    /^([^\0]*)/ && ($_ = $1) for @head;
    $head[$_] = oct($head[$_]) for (1, 2, 3, 5, 6, 13, 14);
    my $bsize;
    if (substr($head, 124, 1) eq "\x80") {
      # not octal, but binary!
      my @s = unpack('aCSNN', substr($head, 124, 12));
      $head[4] = $s[4] + (2 ** 32) * $s[3] + (2 ** 64) * $s[2];
      $bsize = $s[4] & 511;
      $bsize = $head[4] + ($bsize ? 512 - $bsize : 0);
    } else {
      $head[4] = oct($head[4]);
      $bsize = ($head[4] + 511) & ~511;
    }
    $head[7] = '0' if $head[7] eq '' || $head[7] =~ /\W/;
    $head[7] = '5' if $head[7] eq '0' && $head[0] =~ /\/$/s;	# dir
    my $ent = { map {$headnames[$_] => $head[$_]} (0..$#headnames) };
    next if $ent->{'type'} eq 'V';	# ignore volume lables
    if ($ent->{'type'} eq 'L' || $ent->{'type'} eq 'x' || $ent->{'type'} eq 'X') {
      # read longlink/pax extension
      die if $bsize < 1 || $bsize > 2 ** 16;
      my $data = '';
      last unless (read($handle, $data, $bsize) || 0) == $bsize;
      $offset += $bsize;
      substr($data, $ent->{'size'}) = '';
      if ($ent->{'type'} eq 'L') {
        $nameoverride = $data;
      } else {
	$ispax = 1;
        while ($data =~ /^(\d+) /) {
          my $entry = substr($data, length($1) + 1, $1);
          $data = substr($data, length($1) + 1 + $1);
	  $nameoverride = substr($entry, 5) if substr($entry, 0, 5) eq 'path=';
        }
      }
      next;
    }
    if (defined($nameoverride)) {
      $ent->{'name'} = $nameoverride;
      undef $nameoverride;
    } elsif (defined($ent->{'prefix'})) {
      $ent->{'prefix'} =~ s/\/$//;
      $ent->{'name'} = "$ent->{'prefix'}/$ent->{'name'}" if $ent->{'prefix'} ne '';
    }
    delete $ent->{'prefix'};
    $bsize = 0 if $ent->{'type'} == '2' || $ent->{'type'} == '3' || $ent->{'type'} == '4' || $ent->{'type'} == '6';
    $bsize = 0 if $ent->{'type'} == '1' && !$ispax;	# hard link magic
    $ent->{'offset'} = $offset if $ent->{'type'} == '0';
    if ($bsize) {
      last unless seek($handle, $bsize, 1);	# skip if seek fails?
      $offset += $bsize;
    }
    push @tar, $ent;
  }
  return \@tar;
}

sub extract {
  my ($handle, $ent, $offset, $length) = @_;
  die("cannot extract this type of entry\n") unless $ent->{'type'} eq '0';
  my $size = $ent->{'size'};
  $offset = 0 unless defined($offset) && $offset >= 0;
  return '' if $offset >= $size || (defined($length) && $length <= 0);
  $length = $size - $offset if !defined($length) || $length > $size - $offset;
  die("cannot seek to $ent->{name} entry\n") unless seek($handle, $ent->{'offset'} + $offset, 0);
  my $data = '';
  die("cannot read $ent->{name} entry\n") unless (read($handle, $data, $length) || 0) == $length;
  return $data;
}

1;

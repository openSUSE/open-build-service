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
  return substr($ent->{'data'}, $offset, $length) if exists $ent->{'data'};
  die("cannot seek to $ent->{name} entry\n") unless seek($handle, $ent->{'offset'} + $offset, 0);
  my $data = '';
  die("cannot read $ent->{name} entry\n") unless (read($handle, $data, $length) || 0) == $length;
  return $data;
}

sub maketarhead {
  my ($file, $s) = @_; 

  my $h = "\0\0\0\0\0\0\0\0" x 64;
  my $pad = '';
  return ("$h$h", $pad) unless $file;
  my $name = $file->{'name'};
  my $type = '0';
  $type = '5' if (($file->{'mode'} || 0) | 0xfff) == 0x4fff;
  $name =~ s/\/?$/\// if $type eq '5';
  my $mode = sprintf("%07o", $file->{'mode'} || 0x81a4);
  my $size = sprintf("%011o", $s->[7]);
  my $mtime = sprintf("%011o", defined($file->{'mtime'}) ? $file->{'mtime'} : $s->[9]);
  substr($h, 0, length($name), $name);
  substr($h, 100, length($mode), $mode);
  substr($h, 108, 15, "0000000\0000000000");
  substr($h, 124, length($size), $size);
  substr($h, 136, length($mtime), $mtime);
  substr($h, 148, 8, '        ');
  substr($h, 156, 1, $type);
  substr($h, 257, 8, "ustar\00000");
  substr($h, 329, 15, "0000000\0000000000");
  substr($h, 148, 7, sprintf("%06o\0", unpack("%16C*", $h)));
  $pad = "\0" x (512 - $s->[7] % 512) if $s->[7] % 512;
  return ($h, $pad);
}

sub writetar {
  my ($fd, $entries) = @_;

  my $writer;
  $writer = $fd if ref($fd) eq 'CODE';
  for my $ent (@{$entries || []}) {
    my (@s);
    local *F;
    if (exists $ent->{'filename'}) {
      my $filename = $ent->{'filename'};
      if (ref($filename)) {
        *F = $filename;
      } else {
        @s = lstat($filename);
        die("$filename: $!\n") unless @s;
        if (-l _) {
          die("$filename: is a symlink\n");
        } elsif (! -f _) {
          die("$filename: not a plain file\n");
        }
        if (!open(F, '<', $filename)) {
          die("$filename: $!\n") unless @s;
        }
      }
      @s = stat(F);
      my $l = $s[7];
      if (defined($ent->{'offset'})) {
        die("$filename: seek error: $!\n") unless seek(F, $ent->{'offset'}, 0);
        $l -= $ent->{'offset'};
      }
      if (defined($ent->{'size'})) {
        die("$filename: size too small for request\n") if $ent->{'size'} > $l;
        $l = $ent->{'size'};
      }
      $s[7] = $l;
      my $r = 0;
      my ($data, $pad) = maketarhead($ent, \@s);
      while(1) {
        $r = sysread(F, $data, $l > 8192 ? 8192 : $l, length($data)) if $l;
        die("$filename: read error: $!\n") unless defined $r;
        die("$filename: unexpected EOF\n") if $l && !$r;
        $data .= $pad if $r == $l;
        if ($writer) {
          $writer->($data);
        } else {
          print $fd $data or die("write error: $!\n");
        }
        $data = '';
        $l -= $r;
        last unless $l;
      }
      close F unless ref $filename;
    } else {
      $s[7] = length($ent->{'data'});
      $s[9] = $ent->{'mtime'} || time;
      my ($data, $pad) = maketarhead($ent, \@s);
      $data .= "$ent->{'data'}$pad";
      if ($writer) {
        $writer->($data);
      } else {
        print $fd $data or die("write error: $!\n");
      }
    }
  }
  my ($data) = maketarhead();
  if ($writer) {
    $writer->($data);
  } else {
    print $fd $data or die("write error: $!\n");
  }
}

1;

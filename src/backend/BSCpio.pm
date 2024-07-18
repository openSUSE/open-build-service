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
# Cpio file parsing/writing
#

package BSCpio;

use strict;

# cpiotype: 1=pipe 2=char 4=dir 6=block 8=file 10=symlink 12=socket

sub makecpiohead {
  my ($ent, $s) = @_;
  return ("07070100000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000b00000000TRAILER!!!\0\0\0\0") if !$ent;
  my $name = $ent->{'name'};
  my $mode = $ent->{'mode'} || 0x81a4;
  if (defined($ent->{'cpiotype'})) {
    $mode = ($mode & ~0xf000) | ($ent->{'cpiotype'} << 12);
  } else {
    $mode |= 0x8000 unless $mode & 0xf000;
  }
  my $mtime = defined($ent->{'mtime'}) ? $ent->{'mtime'} : $s->[9];
  my $h = sprintf("07070100000000%08x000000000000000000000001%08x", $mode, $mtime);
  my $size = $s->[7];
  if ($size >= 0xffffffff) {
    # build service extension, size is in rmajor/rminor
    my $top = int($s->[7] / 4294967296);
    $size -= $top * 4294967296;
    $h .= sprintf("ffffffff0000000000000000%08x%08x", $top, $size);
  } else {
    $h .= sprintf("%08x00000000000000000000000000000000", $size);
  }
  $h .= sprintf("%08x", length($name) + 1);
  $h .= "00000000$name\0";
  $h .= substr("\0\0\0\0", (length($h) & 3)) if length($h) & 3;
  my $pad = $size % 4 ? substr("\0\0\0\0", $size % 4) : '';
  return ($h, $pad);
}

sub parsecpiohead {
  my ($cpiohead) = @_;
  return undef unless substr($cpiohead, 0, 6) eq '070701';
  my $mode = hex(substr($cpiohead, 14, 8));
  my $mtime = hex(substr($cpiohead, 46, 8));
  my $size  = hex(substr($cpiohead, 54, 8));
  my $pad = (4 - ($size % 4)) % 4;
  my $namesize = hex(substr($cpiohead, 94, 8));
  my $namepad = (6 - ($namesize % 4)) % 4;
  if ($size == 0xffffffff) {
    # build service extension, size is in rmajor/rminor
    $size = hex(substr($cpiohead, 86, 8));
    $pad = (4 - ($size % 4)) % 4;
    $size += hex(substr($cpiohead, 78, 8)) * 4294967296;
    return undef if $size < 0xffffffff;
  }
  return undef if $namesize > 8192;
  my $ent = { 'namesize' => $namesize , 'size' => $size, 'mtime' => $mtime, 'mode' => $mode, 'cpiotype' => ($mode >> 12 & 0xf) };
  return ($ent, $namesize, $namepad, $size, $pad);
}

sub openentfile {
  my ($ent, $file, $s, $follow) = @_;
  my $name = $ent->{'name'};
  my $fd;
  my $type = ref($file);
  if ($type) {
    if ($type eq 'CODE') {
      $fd = $file->($ent);
      die("$name: open: $!\n") unless $fd;
    } else {
      $fd = $file;
    }
  } else {
    @$s = lstat($file);
    return (undef, "$name: $file: $!\n") unless @$s;
    if (-l _) {
      return (undef, "$name: $file: is a symlink\n") if !$ent->{'follow'} && !$follow;
    } elsif (! -f _) {
      return (undef, "$name: $file: not a plain file\n");
    }
    return (undef, "$name: $file: $!\n") unless open($fd, '<', $file);
  }
  @$s = stat($fd);
  return ($fd, "$name: fstat: $!\n") unless @$s;
  if (defined($ent->{'offset'})) {
    return ($fd, "$name: seek error: $!\n") unless defined(sysseek($fd, $ent->{'offset'}, 0));
    $s->[7] -= $ent->{'offset'};
  }
  if (defined($ent->{'size'})) {
    return ($fd, "$name: size too small for request\n") if $ent->{'size'} > $s->[7];
    $s->[7] = $ent->{'size'};
  }
  return ($fd, undef);
}

sub writecpio {
  my ($fd, $entries, %opts) = @_;
  my $writer;
  $writer = $fd if ref($fd) eq 'CODE';
  my $collecterrors = $opts{'collecterrors'};
  my $errors = {'name' => $collecterrors, '__errors' => 1, 'data' => ''};
  for my $ent (@{$entries || []}, $errors) {
    my @s;
    my $name = $ent->{'name'};
    if ($ent->{'error'}) {
      die("$name: $ent->{'error'}\n") unless $collecterrors;
      $errors->{'data'} .= "$name: $ent->{'error'}\n";
    } elsif (exists($ent->{'file'}) || exists($ent->{'filename'}) || (!exists($ent->{'data'}) && defined($opts{'file'}) && defined($ent->{'offset'}))) {
      my $file = exists($ent->{'file'}) ? $ent->{'file'} : $ent->{'filename'};
      $file = $opts{'file'} if !defined($file) && defined($ent->{'offset'});
      my ($efd, $error) = openentfile($ent, $file, \@s, $opts{'follow'});
      if ($error) {
	close($efd) if $efd && !ref($file);
        die($error) unless $collecterrors;
        $errors->{'data'} .= $error;
	next;
      }
      my ($data, $pad) = makecpiohead($ent, \@s);
      my $l = $s[7];
      my $r = 0;
      while (1) {
	$r = sysread($efd, $data, $l > 8192 ? 8192 : $l, length($data)) if $l;
	die("$name: $file: read error: $!\n") unless defined $r;
	die("$name: $file: unexpected EOF\n") if $l && !$r;
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
      close($efd) unless ref $file;
    } else {
      next if $ent->{'__errors'} && $ent->{'data'} eq '';
      $s[7] = length($ent->{'data'});
      $s[9] = $ent->{'mtime'} || time;
      my ($data, $pad) = makecpiohead($ent, \@s);
      $data .= "$ent->{'data'}$pad";
      while (length($data) > 8192) {
        if ($writer) {
          $writer->(substr($data, 0, 8192, ''));
        } else {
          print $fd substr($data, 0, 8192, '') or die("write error: $!\n");
        }
      }
      if ($writer) {
        $writer->($data);
      } else {
        print $fd $data or die("write error: $!\n");
      }
    }
  }
  my ($data) = makecpiohead();
  if ($writer) {
    $writer->($data);
  } else {
    print $fd $data or die("write error: $!\n");
  }
}

sub writecpiofile {
  my ($fn, $fnf, $cpio, %opts) = @_;
  my $cpiofd;
  open($cpiofd, '>', $fn) || die("$fn: $!\n");
  writecpio($cpiofd, $cpio, %opts);
  close($cpiofd) || die("$fn close: $!\n");
  my $mtime = $opts{'mtime'};
  utime($mtime, $mtime, $fn) if defined $mtime;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n") if defined $fnf;
}

sub readchunk {
  my ($fd, $l) = @_;
  my $r = '';
  die("bad cpio file\n") unless !$l || (read($fd, $r, $l) || 0) == $l;
  return $r;
}

sub list {
  my ($fd) = @_;
  my $offset = 0;
  my @cpio;
  while (1) {
    my $cpiohead = readchunk($fd, 110);
    my ($ent, $namesize, $namepad, $size, $pad) = parsecpiohead($cpiohead);
    last unless $ent;
    my $name = substr(readchunk($fd, $namesize + $namepad), 0, $namesize);
    $offset += 110 + $namesize + $namepad;
    $name =~ s/\0.*//s;
    last if !$size && $name eq 'TRAILER!!!';
    $ent->{'name'} = $name;
    if ($ent->{'cpiotype'} == 8 || $ent->{'cpiotype'} == 10) {
      $ent->{'offset'} = $offset;
      $size += $pad;
      while ($size > 0) {
        my $l = $size > 65536 ? 65536 : $size;
        readchunk($fd, $l);
	$offset += $l;
	$size -= $l;
      }
    }
    push @cpio, $ent;
  }
  return \@cpio;
}

sub extract {
  my ($handle, $ent, $offset, $length) = @_;
  die("cannot extract this type of entry\n") if defined($ent->{'cpiotype'}) && ($ent->{'cpiotype'} != 8 && $ent->{'cpiotype'} != 10);
  return '' if defined($length) && $length <= 0;
  $offset = 0 unless defined($offset) && $offset >= 0;
  if (exists $ent->{'data'}) {
    return substr($ent->{'data'}, $offset) unless defined $length;
    return substr($ent->{'data'}, $offset, $length);
  }
  my $size = $ent->{'size'};
  return '' if $offset >= $size;
  $length = $size - $offset if !defined($length) || $length > $size - $offset;
  die("cannot seek to $ent->{name} entry\n") unless seek($handle, $ent->{'offset'} + $offset, 0);
  my $data = '';
  die("cannot read $ent->{name} entry\n") unless (read($handle, $data, $length) || 0) == $length;
  return $data;
}

1;

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
################################################################
#
# HTTP protocol functions. Also contains file/cpio sender/receiver.
#

package BSHTTP;

use Digest::MD5 ();

use strict;

sub gethead {
  my ($h, $t) = @_;

  my ($field, $data);
  for (split(/[\r\n]+/, $t)) {
    next if $_ eq '';
    if (/^[ \t]/) {
      next unless defined $field;
      s/^\s*/ /;
      $h->{$field} .= $_;
    } else {
      ($field, $data) = split(/\s*:\s*/, $_, 2);
      $field =~ tr/A-Z/a-z/;
      if ($h->{$field} && $h->{$field} ne '') {
        $h->{$field} = $h->{$field}.','.$data;
      } else {
        $h->{$field} = $data;
      }
    }
  }
}

#
# read data from socket, do chunk decoding
# hdr: header data
# maxl = undef: read as much as you can
# exact = 1: read maxl data, maxl==undef -> read to eof;
#
sub read_data {
  my ($hdr, $maxl, $exact) = @_;

  my $ret = '';
  local *S = $hdr->{'__socket'};
  if ($hdr->{'transfer-encoding'} && lc($hdr->{'transfer-encoding'}) eq 'chunked') {
    my $cl = $hdr->{'__cl'} || 0;
    if ($cl < 0) {
      die("unexpected EOF\n") if $exact && defined($maxl) && length($ret) < $maxl;
      return $ret;
    }
    my $qu = $hdr->{'__data'};
    while(1) {
      if (defined($maxl) && $maxl <= $cl) {
	while(length($qu) < $maxl) {
          my $r = sysread(S, $qu, 8192, length($qu));
          die("unexpected EOF\n") unless $r;
	}
	$ret .= substr($qu, 0, $maxl);
        $hdr->{'__cl'} = $cl - $maxl;
        $hdr->{'__data'} = substr($qu, $maxl);
	return $ret;
      }
      if ($cl) {
	# no maxl or maxl > cl, read full cl
	while(length($qu) < $cl) {
          my $r = sysread(S, $qu, 8192, length($qu));
          die("unexpected EOF\n") unless $r;
	}
	$ret .= substr($qu, 0, $cl);
	$qu = substr($qu, $cl);
	$maxl -= $cl if defined $maxl;
        $cl = 0;
	if (!defined($maxl) && !$exact) { # no maxl, return every chunk
	  $hdr->{'__cl'} = $cl;
	  $hdr->{'__data'} = $qu;
	  return $ret;
	}
      }
      while ($qu !~ /\r?\n/s) {
        my $r = sysread(S, $qu, 8192, length($qu));
        die("unexpected EOF\n") unless $r;
      }
      if (substr($qu, 0, 1) eq "\n") {
        $qu = substr($qu, 1);
	next;
      }
      if (substr($qu, 0, 2) eq "\r\n") {
        $qu = substr($qu, 2);
	next;
      }
      die("bad CHUNK data: $qu\n") unless $qu =~ /^([0-9a-fA-F]+)/;
      $cl = hex($1);
      die if $cl < 0;
      $qu =~ s/^.*?\r?\n//s;
      if ($cl == 0) {
        $hdr->{'__cl'} = -1;	# mark EOF
        die("unexpected EOF\n") if $exact && defined($maxl) && length($ret) < $maxl;
	# read trailer
	$qu = "\r\n$qu";
	while ($qu !~ /\n\r?\n/s) {
          my $r = sysread(S, $qu, 8192, length($qu));
          die("unexpected EOF\n") unless $r;
	}
	$qu =~ /^(.*?)\n\r?\n/;
	gethead($hdr, length($1) >= 2 ? substr($1, 2) : '');
	return $ret;
      }
    }
  } else {
    my $qu = $hdr->{'__data'};
    my $cl = $hdr->{'__cl'};
    $cl = $hdr->{'content-length'} unless defined $cl;
    if (defined($cl) && (!defined($maxl) || $maxl > $cl)) {
      die("unexpected EOF\n") if $exact && defined($maxl);
      $maxl = $cl >= 0 ? $cl : 0;
    }
    while (!defined($maxl) || length($qu) < $maxl) {
      my $m = ($maxl || 0) - length($qu);
      $m = 8192 if $m < 8192;
      my $r = sysread(S, $qu, $m, length($qu));
      if (!$r) {
        die("unexpected EOF\n") if defined($cl) || ($exact && defined($maxl));
        $cl = $maxl = length($qu);
      }
    }
    $cl -= $maxl if defined($cl);
    $ret = substr($qu, 0, $maxl);
    $hdr->{'__cl'} = $cl;
    $hdr->{'__data'} = substr($qu, $maxl);
    return $ret;
  }
}

sub str2hdr {
  my ($str) = @_;
  my $hdr = {
    '__data' => $str,
    '__cl' => length($str),
  };
  return $hdr;
}

sub fd2hdr {
  my ($fd) = @_;
  my $hdr = {
    '__data' => '',
    '__socket' => $fd,
    '__cl' => -s *$fd,
  };
  return $hdr;
}

sub file_receiver {
  my ($hdr, $param) = @_;

  die("file_receiver: no filename\n") unless defined $param->{'filename'};
  my $fn = $param->{'filename'};
  my $withmd5 = $param->{'withmd5'};
  local *F;
  my $ctx;
  $ctx = Digest::MD5->new if $withmd5;
  open(F, '>', $fn) || die("$fn: $!\n");
  my $size = 0;
  while(1) {
    my $s = read_data($hdr, 8192);
    last if $s eq '';
    (syswrite(F, $s) || 0) == length($s) || die("syswrite: $!\n");
    $size += length($s);
    $ctx->add($s) if $ctx;
  }
  close(F) || die("close: $!\n");
  my $res = {size => $size};
  $res->{'md5'} = $ctx->hexdigest if $ctx;
  return $res;
}

sub cpio_receiver {
  my ($hdr, $param) = @_;
  my @res;
  my $dn = $param->{'directory'};
  my $withmd5 = $param->{'withmd5'};
  local *F;
  while(1) {
    my $cpiohead = read_data($hdr, 110, 1);
    die("cpio: not a 'SVR4 no CRC ascii' cpio\n") unless substr($cpiohead, 0, 6) eq '070701';
    my $mode = hex(substr($cpiohead, 14, 8));
    my $mtime = hex(substr($cpiohead, 46, 8));
    my $size  = hex(substr($cpiohead, 54, 8));
    if ($size == 0xffffffff) {
      # build service length extension
      $cpiohead .= read_data($hdr, 16, 1);
      $size = hex(substr($cpiohead, 62, 8)) * 4294967296. + hex(substr($cpiohead, 70, 8));
      substr($cpiohead, 62, 16) = '';
    }
    my $nsize = hex(substr($cpiohead, 94, 8));
    die("ridiculous long filename\n") if $nsize > 8192;
    my $nsizepad = $nsize;
    $nsizepad += 4 - ($nsize + 2 & 3) if $nsize + 2 & 3;
    my $name = read_data($hdr, $nsizepad, 1);
    $name =~ s/\0.*//s;
    $name =~ s/^\.\///s;
    my $sizepad = $size;
    $sizepad += 4 - ($size % 4) if $size % 4;
    last if !$size && $name eq 'TRAILER!!!';
    if ($param->{'acceptsubdirs'} || $param->{'createsubdirs'}) {
      die("cpio filename is illegal: $name\n") if "/$name/" =~ /\/\.{0,2}\//s;
    } else {
      die("cpio filename contains a '/': $name\n") if $name =~ /\//s;
    }
    die("cpio filename is '.' or '..'\n") if $name eq '.' || $name eq '..';
    my $ent = {'name' => $name, 'size' => $size, 'mtime' => $mtime, 'mode' => $mode};
    if ($param->{'accept'}) {
      if (ref($param->{'accept'})) {
	die("illegal file in cpio archive: $name\n") unless $param->{'accept'}->($param, $name, $ent);
      } else {
	die("illegal file in cpio archive: $name\n") unless $name =~ /$param->{'accept'}/;
      }
    }
    if ($param->{'map'}) {
      $ent->{'unmappedname'} = $name;
      if (ref($param->{'map'})) {
	$ent->{'name'} = $name = $param->{'map'}->($param, $name);
      } else {
	$ent->{'name'} = $name = "$param->{'map'}$name";
      }
    }
    if (!defined($name)) {
      # skip entry
      while ($sizepad) {
        my $m = $sizepad > 8192 ? 8192 : $sizepad;
        read_data($hdr, $m, 1);
        $sizepad -= $m;
      }
      next;
    }
    push @res, $ent;
    my $ctx;
    $ctx = Digest::MD5->new if $withmd5;
    if (defined($dn)) {
      my $filename = "$dn/$name";
      if (($mode & 0xf000) == 0x4000 && $param->{'createsubdirs'}) {
	die("directory has non-zero size\n") if $sizepad;
	if (! -d $filename) {
	  unlink($filename) unless $param->{'no_unlink'};
	  mkdir($filename) || die("mkdir $filename: $!\n");
	}
      } else {
	die("can only unpack plain files from cpio archive, file $name, mode was $mode\n") unless ($mode & 0xf000) == 0x8000;
	unlink($filename) unless $param->{'no_unlink'};
	open(F, '>', $filename) || die("$filename: $!\n");
      }
    } else {
      $ent->{'data'} = '';
    }
    while ($sizepad) {
      my $m = $sizepad > 8192 ? 8192 : $sizepad;
      my $data = read_data($hdr, $m, 1);
      $sizepad -= $m;
      $size -= $m;
      $m += $size if $size < 0;
      if (defined($dn)) {
        (syswrite(F, $data, $m) || 0) == $m || die("syswrite: $!\n");
      } else {
        $ent->{'data'} .= substr($data, 0, $m);
      }
      $ctx->add($size >= 0 ? $data : substr($data, 0, $m)) if $ctx;
    }
    if (defined($dn) && ($mode & 0xf000) != 0x4000) {
      close(F) || die("close: $!\n");
      utime($mtime, $mtime, "$dn/$name");
    }
    $ent->{'md5'} = $ctx->hexdigest if $ctx && ($mode & 0xf000) != 0x4000;
    $param->{'cpiopostfile'}->($param, $ent) if $param->{'cpiopostfile'};
  }
  return \@res;
}

sub swrite {
  my ($sock, $data) = @_;
  local *S = $sock;
  while (length($data)) {
    my $l = syswrite(S, $data, length($data));
    die("socket write: $!\n") unless $l;
    $data = substr($data, $l);
  }
}

sub cpio_sender {
  my ($param, $sock) = @_;

  my $errors = '';
  local *F;
  my $data;
  for my $file (@{$param->{'cpiofiles'} || []}, {'__errors' => 1}) {
    my @s;
    if ($file->{'error'}) {
	$errors .= "$file->{'name'}: $file->{'error'}\n";
	next;
    }
    if (exists $file->{'filename'}) {
      if (ref($file->{'filename'})) {
	*F = $file->{'filename'};
      } elsif (!open(F, '<', $file->{'filename'})) {
	$errors .= "$file->{'name'}: $file->{'filename'}: $!\n";
	next;
      }
      @s = stat(F);
    } else {
      if ($file->{'__errors'}) {
	next if $errors eq '';
        $file->{'data'} = $errors;
        $file->{'name'} = ".errors";
      }
      $s[7] = length($file->{'data'});
      $s[9] = time;
    }
    my $mode = $file->{'mode'} || 0x81a4;
    $data = sprintf("07070100000000%08x000000000000000000000001", $mode);
    if ($s[7] > 0xffffffff) {
      # build service length extension
      my $top = int($s[7] / 4294967296.);
      $data .= sprintf("%08xffffffff%08x%08x", $s[9], $top, $s[7] - $top * 4294967296.);
    } else {
      $data .= sprintf("%08x%08x", $s[9], $s[7]);
    }
    $data .= "00000000000000000000000000000000";
    $data .= sprintf("%08x", length($file->{'name'}) + 1);
    $data .= "00000000";
    $data .= "$file->{'name'}\0";
    $data .= substr("\0\0\0\0", (length($data) & 3)) if length($data) & 3;
    if (exists $file->{'filename'}) {
      my $l = $s[7];
      my $r = 0;
      while(1) {
        $r = sysread(F, $data, $l > 8192 ? 8192 : $l, length($data)) if $l;
        $data .= substr("\0\0\0\0", ($s[7] % 4)) if $r == $l && ($s[7] % 4) != 0;
	$data = sprintf("%X\r\n", length($data)).$data."\r\n" if $param->{'chunked'};
	swrite($sock, $data);
        $data = '';
        $l -= $r;
        last unless $l;
      }
      die("internal error\n") if $l;
      close F unless ref $file->{'filename'};
    } else {
      $data .= $file->{'data'};
      $data .= substr("\0\0\0\0", (length($data) & 3)) if length($data) & 3;
      $data = sprintf("%X\r\n", length($data)).$data."\r\n" if $param->{'chunked'};
      swrite($sock, $data);
    }
  }
  $data = "07070100000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000b00000000TRAILER!!!\0\0\0\0";
  $data = sprintf("%X\r\n", length($data)).$data."\r\n" if $param->{'chunked'};
  swrite($sock, $data);
  return '';
}

sub file_sender {
  my ($param, $sock) = @_;
  local *F;

  my $bytes = $param->{'bytes'};
  my $data;
  if (ref($param->{'filename'})) {
    *F = $param->{'filename'};
  } else {
    open(F, '<', $param->{'filename'}) || die("$param->{'filename'}: $!\n")
  }
  while(1) {
    last if defined($bytes) && !$bytes;
    my $r = sysread(F, $data, 8192);
    last unless $r;
    if ($bytes) {
      $data = substr($data, 0, $bytes) if length($data) > $bytes;
      $bytes -= length($data);
    }
    $data = sprintf("%X\r\n", length($data)).$data."\r\n" if $param->{'chunked'};
    swrite($sock, $data);
  }
  close F unless ref $param->{'filename'};
  return '';
}

1;

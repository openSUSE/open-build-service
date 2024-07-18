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

my @headnames = qw{name mode uid gid size mtime chksum tartype linkname magic version uname gname major minor};

# tartype: 0=file 1=hardlink 2=symlink 3=char 4=block 5=dir 6=fifo

sub parsetarhead {
  my ($tarhead) = @_;
  my @head = unpack('A100A8A8A8A12A12A8a1A100a6a2A32A32A8A8A155x12', $tarhead);
  /^([^\0]*)/s && ($_ = $1) for @head;
  $head[7] = '0' if $head[7] eq '';	# map old \0 type to 0
  $head[$_] = oct($head[$_]) for (1, 2, 3, 5, 6, 13, 14);
  my $pad;
  if (substr($tarhead, 124, 1) eq "\x80") {
    # not octal, but binary!
    my @s = unpack('aCSNN', substr($tarhead, 124, 12));
    $head[4] = $s[4] + (2 ** 32) * $s[3] + (2 ** 64) * $s[2];
    $pad = (512 - ($s[4] & 511)) & 511;
  } else {
    $head[4] = oct($head[4]);
    $pad = (512 - ($head[4] & 511)) & 511;
  }
  $head[7] = '0' if $head[7] eq '' || $head[7] =~ /\W/;
  $head[7] = '5' if $head[7] eq '0' && $head[0] =~ /\/$/s;	# dir
  if ($head[9] eq 'ustar' && $head[15] ne '') {		# ustar prefix handling
    $head[15] =~ s/\/$//s;
    $head[0] = "$head[15]/$head[0]";
  }
  my $ent = { map {$headnames[$_] => $head[$_]} (0..$#headnames) };
  return ($ent, $head[4], $pad);
}

sub read_gnusparse_data {
  my ($handle, $ent, $bsize) = @_;
  die("unsupported GNU.sparse version\n") unless delete($ent->{'gnusparse_pending'}) eq '1.0';
  my $nent;
  my $lastline = '';
  my $offset;
  while (1) {
    my $blk = '';
    die("EOF while reading gnusparse data\n") unless $bsize >= 512 && (read($handle, $blk, 512) || 0) == 512;
    $bsize -= 512;
    $ent->{'offset'} += 512;
    $blk = "$lastline$blk";
    $lastline = ($blk =~ s/([^\n]+)\z//s) ? $1 : '';
    for (split("\n", $blk)) {
      next unless $_ =~ /^[0-9]+$/;
      if (!defined($nent)) {
	$nent = $_;
	return $bsize unless $nent;
      } elsif (!defined($offset)) {
	$offset = $_;
      } else {
	push @{$ent->{'sparsemap'}}, [ $offset, $_ ];
	undef $offset;
	return $bsize if --$nent <= 0;
      }
    }
  }
}

sub parse_gnusparse {
  my ($override, $n, $entry) = @_;
  $override->{'gnusparse_size'} = $entry if $n eq 'GNU.sparse.size' || $n eq 'GNU.sparse.realsize';
  $override->{'gnusparse_name'} = $entry if $n eq 'GNU.sparse.name';
  $override->{'gnusparse_offset'} = $entry if $n eq 'GNU.sparse.offset';
  $override->{'gnusparse_numbytes'} = $entry if $n eq 'GNU.sparse.numbytes';
  $override->{'gnusparse_major'} = $entry if $n eq 'GNU.sparse.major';
  $override->{'gnusparse_minor'} = $entry if $n eq 'GNU.sparse.minor';
  if (defined($override->{'gnusparse_offset'}) && defined($override->{'gnusparse_numbytes'})) {
    push @{$override->{'sparsemap'}}, [ delete($override->{'gnusparse_offset'}), delete($override->{'gnusparse_numbytes'}) ];
  }
  if (defined($override->{'gnusparse_map'})) {
    my @m = split(',', delete $override->{'gnusparse_map'});
    push @{$override->{'sparsemap'}}, [ splice(@m, 0, 2) ] while @m >= 2;
  }
  if (defined($override->{'gnusparse_major'}) && defined($override->{'gnusparse_minor'})) {
    $override->{'gnusparse_pending'} = delete($override->{'gnusparse_major'}).'.'.delete($override->{'gnusparse_minor'});
  }
}

sub parseoverride {
  my ($override, $tartype, $data) = @_;
  $override ||= {};
  if ($tartype eq 'L') {
    $override->{'name'} = $data;
  } elsif ($tartype eq 'K') {
    $override->{'linkname'} = $data;
  } elsif ($tartype eq 'x' || $tartype eq 'X') {
    $override->{'ispax'} = 1;
    while ($data =~ /^(\d+) / && $1 > 3) {
      my $entry = substr($data, length($1) + 1, $1 - length($1) - 2);	# -2 because of space and newline
      $data = substr($data, $1);
      $override->{'name'} = substr($entry, 5) if substr($entry, 0, 5) eq 'path=';
      $override->{'linkname'} = substr($entry, 9) if substr($entry, 0, 9) eq 'linkpath=';
      $override->{'size'} = 0 + substr($entry, 5) if substr($entry, 0, 5) eq 'size=';
      parse_gnusparse($override, $1, substr($entry, length($1) + 1)) if substr($entry, 0, 11) eq 'GNU.sparse.' && $entry =~ /^(.*?)=/;
    }
  }
  $override->{'name'} = delete $override->{'gnusparse_name'} if defined $override->{'gnusparse_name'};
  return $override;
}

sub list {
  my ($handle) = @_;

  my $offset = 0;
  my $override;
  my @tar;

  while (1) {
    my $head = '';
    last unless (read($handle, $head, 512) || 0) == 512;
    $offset += 512;
    last if $head eq "\0" x 512;
    next if substr($head, 500, 12) ne "\0" x 12;
    my ($ent, $size, $pad) = parsetarhead($head);
    my $bsize = $size + $pad;
    my $tartype = $ent->{'tartype'};
    next if $tartype eq 'V';	# ignore volume lables
    if ($tartype eq 'L' || $tartype eq 'K' || $tartype eq 'x' || $tartype eq 'X') {
      # read longname/longlink/pax extension
      last if $bsize < 1 || $bsize >= 1024 * 1024;
      my $data = '';
      last unless (read($handle, $data, $bsize) || 0) == $bsize;
      $offset += $bsize;
      substr($data, $size) = '';
      $override = parseoverride($override, $tartype, $data);
      next;
    }
    if ($override) {
      $ent->{$_} = $override->{$_} for keys %$override;
      if (exists $override->{'size'}) {
	$size = $ent->{'size'};
	$pad = (512 - ($size % 512)) & 511;
	$bsize = $size + $pad;
      }
      undef $override;
    }
    $bsize = 0 if $tartype eq '2' || $tartype eq '3' || $tartype eq '4' || $tartype eq '6';
    $bsize = 0 if $tartype eq '1' && !$ent->{'ispax'};	# hard link magic
    $ent->{'offset'} = $offset if $tartype eq '0';
    if ($tartype eq '0' && $ent->{'gnusparse_size'}) {
      ($ent->{'sparsesize'}, $ent->{'size'}) = ($ent->{'size'}, delete($ent->{'gnusparse_size'}));
      $bsize = read_gnusparse_data($handle, $ent, $bsize) if $ent->{'gnusparse_pending'};
    }
    if ($bsize) {
      last unless seek($handle, $bsize, 1);	# try to skip if seek fails?
      $offset += $bsize;
    }
    push @tar, $ent;
  }
  return \@tar;
}

sub extract_sparse {
  my ($handle, $ent, $offset, $length) = @_;
  die("no sparsemap in entry\n") unless $ent->{'sparsemap'};
  my $data = "\0" x $length;
  my $o = 0;
  my $ssize = $ent->{'sparsesize'};
  for (@{$ent->{'sparsemap'}}) {
    die("bad sparsemap\n") if $_->[0] < 0 || $_->[1] < 0 || $o + $_->[1] > $ssize;
    if ($offset < $_->[0] + $_->[1] &&  $offset + $length > $_->[0]) {
      my $ol = $offset > $_->[0] ? $offset : $_->[0];
      my $or = $offset + $length > $_->[0] + $_->[1] ? $_->[0] + $_->[1] : $offset + $length;
      die("cannot seek to $ent->{name} entry\n") unless seek($handle, $ent->{'offset'} + $o + $ol - $_->[0], 0);
      my $d = '';
      die("cannot read $ent->{name} entry\n") unless (read($handle, $d, $or - $ol) || 0) == $or - $ol;
      substr($data, $ol - $offset, $or - $ol, $d);
    }
    $o += $_->[1];
  }
  return $data;
}

sub extract {
  my ($handle, $ent, $offset, $length) = @_;
  die("cannot extract this type of entry\n") if defined($ent->{'tartype'}) && $ent->{'tartype'} ne '0';
  return '' if defined($length) && $length <= 0;
  $offset = 0 unless defined($offset) && $offset >= 0;
  if (exists $ent->{'data'}) {
    return substr($ent->{'data'}, $offset) unless defined $length;
    return substr($ent->{'data'}, $offset, $length);
  }
  my $size = $ent->{'size'};
  return '' if $offset >= $size;
  $length = $size - $offset if !defined($length) || $length > $size - $offset;
  return extract_sparse($handle, $ent, $offset, $length) if $ent->{'sparsemap'};
  die("cannot seek to $ent->{name} entry\n") unless seek($handle, $ent->{'offset'} + $offset, 0);
  my $data = '';
  die("cannot read $ent->{name} entry\n") unless (read($handle, $data, $length) || 0) == $length;
  return $data;
}

sub makepaxhead {
  my ($file, $s, $paxentries) = @_;
  return '' if ($file->{'tartype'} || '') eq 'x';	# no pax header for pax headers
  my $paxdata = '';
  for my $pe (@$paxentries) {
    my $t;
    my $l = length($pe) + 3;
    $l++ while length($t = sprintf("%d %s\n", $l, $pe)) > $l;
    $paxdata .= $t;
  }
  my $filepath = $file->{'name'};
  $filepath =~ s/\/+\z//s;
  if ($filepath =~ /\A(.*)\/(.*?)\z/s) {
    $filepath = "$1/PaxHeaders.0/$2";
  } else {
    $filepath = "PaxHeaders.0/$filepath";
  }
  my @paxs = @$s;
  $paxs[7] = length($paxdata);
  my $paxfile = { 'name' => $filepath, 'tartype' => 'x', 'mtime' => $file->{'mtime'}, 'mode' => $file->{'mode'} };
  $paxfile->{'mode'} = 0x8000 | ($paxfile->{'mode'} & 0777) if $paxfile->{'mode'};
  my ($h, $pad) = maketarhead($paxfile, \@paxs);
  return "$h$paxdata$pad";
}

sub maketarhead {
  my ($file, $s) = @_; 

  my $h = "\0\0\0\0\0\0\0\0" x 64;
  my $pad = '';
  return ("$h$h") unless $file;
  my $name = $file->{'name'};
  my $linkname = $file->{'linkname'};
  my $tartype = $file->{'tartype'};
  if (!defined($tartype)) {
    $tartype = '0';
    $tartype = '5' if (($file->{'mode'} || 0) | 0xfff) == 0x4fff;
  }
  $name =~ s/\/?$/\// if $tartype eq '5';
  my $size = $s->[7];
  my @pax;
  if (defined($linkname) && length($linkname) > 100) {
    push @pax, "linkpath=$linkname";
    $linkname = substr($linkname, 0, 100);
  }
  if (length($name) > 100) {
    push @pax, "path=$name";
    $name = substr($name, 0, 100);
  }
  if ($size >= 8589934592) {
    push @pax, "size=$size";
    $size = 0;
  }
  my $mode = sprintf("%07o", $file->{'mode'} || 0x81a4);
  my $sizestr = sprintf("%011o", $size);
  my $mtime = sprintf("%011o", defined($file->{'mtime'}) ? $file->{'mtime'} : $s->[9]);
  substr($h, 0, length($name), $name);
  substr($h, 100, length($mode), $mode);
  substr($h, 108, 15, "0000000\0000000000");	# uid/gid
  substr($h, 124, length($sizestr), $sizestr);
  substr($h, 136, length($mtime), $mtime);
  substr($h, 148, 8, '        ');
  substr($h, 156, 1, $tartype);
  substr($h, 157, length($linkname), $linkname) if defined($linkname);
  substr($h, 257, 8, "ustar\00000");		# magic/version
  substr($h, 329, 15, "0000000\0000000000");	# major/minor
  substr($h, 148, 7, sprintf("%06o\0", unpack("%16C*", $h)));
  $pad = "\0" x (512 - $size % 512) if $size % 512;
  $h = makepaxhead($file, $s, \@pax) . $h if @pax;
  return ($h, $pad);
}

sub writetar {
  my ($fd, $entries, %opts) = @_;

  my $writer;
  $writer = $fd if ref($fd) eq 'CODE';
  for my $ent (@{$entries || []}) {
    my (@s);
    my $f;
    if (exists($ent->{'file'}) || (!exists($ent->{'data'}) && defined($opts{'file'}) && defined($ent->{'offset'}))) {
      my $file = $ent->{'file'};
      $file = $opts{'file'} if !defined($file) && defined($ent->{'offset'});
      my $type = ref($file);
      if ($type) {
        if ($type eq 'CODE') {
	  $f = $file->($ent);
	  die("$file: open: $!\n") unless $f;
	} else {
          $f = $file;
	}
      } else {
        @s = lstat($file);
        die("$file: $!\n") unless @s;
        if (-l _) {
          die("$file: is a symlink\n");
        } elsif (! -f _) {
          die("$file: not a plain file\n");
        }
        open($f, '<', $file) || die("$file: $!\n");
      }
      @s = stat($f);
      my $l = $s[7];
      if (defined($ent->{'offset'})) {
        die("$file: seek error: $!\n") unless defined(sysseek($f, $ent->{'offset'}, 0));
        $l -= $ent->{'offset'};
      }
      if (defined($ent->{'size'})) {
        die("$file: size too small for request\n") if $ent->{'size'} > $l;
        $l = $ent->{'size'};
      }
      $s[7] = $l;
      my $r = 0;
      my ($data, $pad) = maketarhead($ent, \@s);
      while(1) {
        $r = sysread($f, $data, $l > 8192 ? 8192 : $l, length($data)) if $l;
        die("$file: read error: $!\n") unless defined $r;
        die("$file: unexpected EOF\n") if $l && !$r;
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
      close $f unless ref $file;
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

sub writetarfile {
  my ($fn, $fnf, $tar, %opts) = @_;
  my $tarfd;
  open($tarfd, '>', $fn) || die("$fn: $!\n");
  writetar($tarfd, $tar);
  close($tarfd) || die("$fn close: $!\n");
  my $mtime = $opts{'mtime'};
  utime($mtime, $mtime, $fn) if defined $mtime;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n") if defined $fnf;
}

1;

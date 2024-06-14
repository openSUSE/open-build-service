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
# create a diff between two source trees
#

package BSSrcServer::Srcdiff;

use Digest::MD5;
use Digest::SHA;
use Fcntl;
eval { require Diff::LibXDiff };

use strict;

use BSUtil;
use BSZip;

my $havelibxdiff;
$havelibxdiff = 1 if defined(&Diff::LibXDiff::diff);

#
# batcher support: if we need to do lots of diffs for a bif tar archive,
# we call the diff program from an extra process. While this sounds like
# something that makes no sense at all, it actually speeds up diffing
# by a factor of 20. The reason is that fork/exec is much slower if the
# process has a big memory size.
#
# A better approach would be a perl module that does the diffing with
# no exec at all but alas, there seems to be no such thing (execpt a
# pure perl version that is too slow).
#
my $batcherpid;

sub batcher {
  $| = 1;
  open(OUT, ">&3") || die("open fd 3: $!\n");
  my $r = 0;
  while (1) {
    my $in = '';
    my $inl = sysread(STDIN, $in, 4);
    last if defined($inl) && $inl == 0;
    die("read error length\n") unless $inl && $inl == 4;
    $inl = unpack('N', $in);
    if ($inl == 0) {	# ping
      syswrite(OUT, $in, 4);
      next;
    }
    $in = '';
    while ($inl > 0) {
      my $l = $inl > 8192 ? 8192 : $inl;
      $l = sysread(STDIN, $in, $l, length($in));
      die("read error body\n") unless $l && $l > 0;
      $inl -= $l;
    }
    $in = BSUtil::fromstorable($in);
    $in = BSSrcServer::Srcdiff::filediff(@$in);
    $in = BSUtil::tostorable($in);
    $in = pack('N', length($in)).$in;
    while (length($in)) {
      my $l = syswrite(OUT, $in, length($in));
      die("write error: $!\n") unless $l;
      $in = substr($in, $l);
    }
    eval {
      exec("/usr/bin/perl", '-I', $INC[0], '-MBSSrcServer::Srcdiff', '-e', 'BSSrcServer::Srcdiff::batcher()') if $r++ == 1000;
    };
    warn($@) if $@;
  }
}

sub startbatcher {
  die("batcher is already running\n") if $batcherpid;
  pipe(BATCHERIN, TOBATCHER);
  pipe(FROMBATCHER, BATCHEROUT);
  if (($batcherpid = xfork()) == 0) {
    close(TOBATCHER);
    close(FROMBATCHER);
    POSIX::dup2(fileno(BATCHERIN), 0);
    POSIX::dup2(fileno(BATCHEROUT), 3);
    my $dir = __FILE__;
    $dir =~ s/[^\/]+$/./;
    $dir =~ s/BSSrcServer\/\.$/./;
    exec("/usr/bin/perl", '-I', $dir, '-MBSSrcServer::Srcdiff', '-e', 'BSSrcServer::Srcdiff::batcher()');
    die("/usr/bin/perl: $!\n");
  }
  my $p = '';
  close(BATCHEROUT);
  syswrite(TOBATCHER, "\000\000\000\000", 4);
  if (sysread(FROMBATCHER, $p, 4) != 4 || $p ne "\000\000\000\000") {
    warn("batcher did not start\n");
    close(BATCHEROUT);
    close(TOBATCHER);
    close(FROMBATCHER);
    waitpid($batcherpid, 0);
    undef($batcherpid);
    return;
  }
  close(BATCHERIN);
}

sub endbatcher {
  return unless $batcherpid;
  close(TOBATCHER);
  close(FROMBATCHER);
  waitpid($batcherpid, 0);
  undef($batcherpid);
}

sub filediff_batcher {
  die("batcher is not running\n") unless $batcherpid;
  my $p = BSUtil::tostorable(\@_);
  $p = pack('N', length($p)).$p;
  while (length($p)) {
    my $l = syswrite(TOBATCHER, $p, length($p));
    die("batcher write: $!\n") unless $l;
    $p = substr($p, $l);
  }
  $p = '';
  sysread(FROMBATCHER, $p, 4) == 4 || die;
  my $pl = unpack('N', $p);
  $p = '';
  while ($pl > 0) {
    my $l = $pl > 8192 ? 8192 : $pl;
    $l = sysread(FROMBATCHER, $p, $l, length($p));
    die unless $l > 0;
    $pl -= $l;
  }
  return BSUtil::fromstorable($p);
}

#
# fmax: maximum number of lines in a diff
# tmax: maximum number of lines in a tardiff
#

sub opentar {
  my ($fp, $tar, $gemdata, @taropts) = @_;
  if (!$gemdata) {
     open($fp, '-|', 'tar', @taropts, $tar) || die("tar: $!\n");
     return;
  }
  if (!open($fp, '-|')) {
    if (!open(STDIN, '-|')) {
      exec('tar', '-xOf', $tar, $gemdata);
      die("tar $gemdata");
    }
    if ($gemdata =~ /\.gz$/) {
      exec('tar', '-z', @taropts, '-');
    } elsif ($gemdata =~ /\.xz$/) {
      exec('tar', '--xz', @taropts, '-');
    } elsif ($gemdata =~ /\.zstd?$/) {
      exec('tar', '--zstd', @taropts, '-');
    } else {
      exec('tar', @taropts, '-');
    }
    die('tar');
  }
}

#
# entries have the following attributes:
#
#   name: name in tar file
#   type: [-dlbcp] type of file
#   size: size in bytes
#   mode: mode as rwx... string
#   info: sha256sum for plain files, link target for symlinks
#   md5: md5sum for plain files

sub listtar {
  my ($tar, $gemdata) = @_;
  local *F;
  
  opentar(\*F, $tar, $gemdata, '--numeric-owner', '-tvf');
  my @c;
  my $fc = 0;
  while(<F>) {
    next unless /^([-dlbcp])(.........)\s+\d+\/\d+\s+(\S+) \d\d\d\d-\d\d-\d\d \d\d:\d\d(?::\d\d)? (.*)$/;
    my $type = $1;
    my $mode = $2;
    my $size = $3;
    my $name = $4;
    my $info = '';
    my $md5;
    if ($type eq 'l') {
      next unless $name =~ /^(.*) -> (.*)$/;
      $name = $1;
      $info = $2;
    } elsif ($type eq 'b' || $type eq 'c') {
      $info = $size;
      $size = 0;
    } elsif ($type eq 'd') {
      $name =~ s/\/$//;
    } elsif ($type eq '-') {
      if ($size == 0) {
	$md5 = 'd41d8cd98f00b204e9800998ecf8427e';
	$info = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      } else {
	$fc++;		# need 2nd pass
      }
    }
    push @c, {'type' => $type, 'name' => $name, 'size' => $size, 'mode' => $mode, 'info' => $info};
    $c[-1]->{'md5'} = $md5 if defined $md5;
  }
  close(F) || die($! ? "tar: $!\n" : "tar: exit status $?\n");
  if ($fc) {
    opentar(\*F, $tar, $gemdata, '-xOf');
    for my $c (@c) {
      next unless $c->{'type'} eq '-' && $c->{'size'};
      my $ctx = Digest::MD5->new;
      my $ctx256 = Digest::SHA->new(256);
      my $s = $c->{'size'};
      while ($s > 0) {
	my $b;
	my $l = $s > 16384 ? 16384 : $s;
	$l = sysread(F, $b, $l);
	die("tar read error\n") unless $l;
	$ctx->add($b);
	$ctx256->add($b);
	$s -= $l;
      }
      $c->{'md5'} = $ctx->hexdigest();
      $c->{'info'} = $ctx256->hexdigest();
    }
    close(F) || die($! ? "tar: $!\n" : "tar: exit status $?\n");
  }
  return @c;
}

sub extracttar {
  my ($tar, $cp, $gemdata) = @_;

  local *F;
  local *G;
  opentar(\*F, $tar, $gemdata, '-xOf');
  my $skipgemdata;
  for my $c (@$cp) {
    next unless $c->{'type'} eq '-' || $c->{'type'} eq 'gemdata';
    if ($c->{'type'} eq 'gemdata') {
      my @data = grep {$_->{'name'} =~ /^data\// && $_->{'type'} ne 'gemdata'} @$cp;
      extracttar($tar, \@data, $c->{'name'});
      delete $c->{'extract'};	# just in case...
      $skipgemdata = 1;
    }
    next if $skipgemdata && $c->{'type'} ne 'gemdata' && $c->{'name'} =~ /^data\//;
    if (exists $c->{'content'}) {
      my $s = $c->{'size'};
      while ($s > 0) {
	my $l = $s > 16384 ? 16384 : $s;
	$l = sysread(F, $c->{'content'}, $l, length($c->{'content'}));
	die("tar read error\n") unless $l;
	$s -= $l;
      }
    } elsif (exists $c->{'extract'}) {
      open(G, '>', $c->{'extract'}) || die("$c->{'extract'}: $!\n");
      my $s = $c->{'size'};
      while ($s > 0) {
	my $b;
	my $l = $s > 16384 ? 16384 : $s;
	$l = sysread(F, $b, $l);
	die("tar read error\n") unless $l;
	(syswrite(G, $b) || 0) == $l || die("syswrite: $!\n");
	$s -= $l;
      }
      close(G);
    } elsif ($c->{'size'}) {
      my $s = $c->{'size'};
      while ($s > 0) {
	my $b;
	my $l = $s > 16384 ? 16384 : $s;
	$l = sysread(F, $b, $l);
	die("tar read error\n") unless $l;
	$s -= $l;
      }
    }
  }
  close(F) || die($! ? "tar: $!\n" : "tar: exit status $?\n");
}

sub listgem {
  my ($gem) = @_;

  my @gem;
  my @tar = listtar($gem);
  my $founddata = 0;
  for my $t (@tar) {
    if ($t->{'name'} =~ /^data\.tar\.[xg]z$/) {
      die("multiple data sections in gem\n") if $founddata++;
      $t->{'type'} = 'gemdata';
      push @gem, $t;
      my @data = listtar($gem, $t->{'name'});
      $_->{'name'} = "data/".$_->{'name'} for @data;
      push @gem, @data;
    } elsif ($t->{'name'} =~ /^data\//) {
      die("gemfile contains data directory\n");
    } else {
      push @gem, $t;
    }
  }
  return @gem;
}

sub cpiomode {
  my ($m) = @_;
  my $mm = '';
  my $b = 0x100;
  for (qw{r w x r w x r w x}) {
    $mm .= $m & $b ? $_ : '-';
    $b >>= 1;
  }
  substr($mm, 2, 1) = substr($mm, 2, 1) eq 'x' ? 's' : 'S' if $m & 0x800;
  substr($mm, 5, 1) = substr($mm, 5, 1) eq 'x' ? 's' : 'S' if $m & 0x400;
  substr($mm, 8, 1) = substr($mm, 8, 1) eq 'x' ? 't' : 'T' if $m & 0x200;
  return $mm;
}

sub listextractcpio {
  my ($cpio, $cp) = @_;
  
  my @c;
  local *F;
  local *G;
  open(F, '<', $cpio) || die("$cpio: $!\n");
  while (1) {
    my $cpiohead;
    die("cpio read error head\n") unless (read(F, $cpiohead, 110) || 0) == 110;
    die("cpio: not a newc cpio\n") unless substr($cpiohead, 0, 6) eq '070701';
    my $mode = hex(substr($cpiohead, 14, 8));
    my $mtime = hex(substr($cpiohead, 46, 8));
    my $fsize  = hex(substr($cpiohead, 54, 8));
    my $nsize = hex(substr($cpiohead, 94, 8));
    die("ridiculous long filename\n") if $nsize > 8192;
    my $nsizepad = 0;
    $nsizepad = 4 - ($nsize + 2 & 3) if $nsize + 2 & 3;
    my $name;
    die("cpio read error name\n") unless (read(F, $name, $nsize + $nsizepad) || 0) == $nsize + $nsizepad;
    $name = substr($name, 0, $nsize);
    $name =~ s/\0.*//s;
    my $type = $mode & 0xf000;
    if ($type == 0x1000) {
      $type = 'p';
    } elsif ($type == 0x2000) {
      $type = 'c';
    } elsif ($type == 0x4000) {
      $type = 'd';
    } elsif ($type == 0x6000) {
      $type = 'b';
    } elsif ($type == 0x8000) {
      $type = '-';
    } elsif ($type == 0xa000) {
      $type = 'l';
    } elsif ($type == 0xc000) {
      $type = 's';
    } else {
      $type = '?';
    }
    last if (!$fsize || $fsize == 4) && $name eq 'TRAILER!!!';
    push @c, {'type' => $type, 'name' => $name, 'size' => $fsize, 'mode' => cpiomode($mode)};
    my $x;
    if ($cp) {
      $x = shift @$cp;
      die unless $x;
      undef $x if !$x->{'extract'};
    }
    die("bad extract file type\n") if $x && $type ne '-';
    my $fsizepad = 0;
    $fsizepad = 4 - ($fsize & 3) if $fsize & 3;
    my $md5 = $type eq '-' ? 'd41d8cd98f00b204e9800998ecf8427e' : undef;
    my $info = $type eq '-' ? 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' : '';
    my $tomem = $x && exists($x->{'content'});
    if ($x && !$tomem) {
      open(G, '>', $x->{'extract'}) || die("$x->{'extract'}: $!\n");
    }
    if ($fsize > 0) {
      if ($type eq 'l') {
        die("ridiculous long symlink\n") if $fsize > 8192;
        die("cpio read error symlink body\n") unless (read(F, $info, $fsize) || 0) == $fsize;
      } else {
        my $ctx = Digest::MD5->new;
        my $ctx256 = Digest::SHA->new(256);
        while ($fsize > 0) {
	  my $chunk = $fsize > 16384 ? 16384 : $fsize;
	  my $data;
	  die("cpio read error body\n") unless (read(F, $data, $chunk) || 0) == $chunk;
	  $ctx->add($data);
	  $ctx256->add($data);
	  if ($tomem) {
	    $x->{'content'} .= $data;
	  } elsif ($x) {
	    print G $data;
	  }
	  $fsize -= $chunk;
	}
        $info = $ctx256->hexdigest() if $type eq '-';
        $md5 = $ctx->hexdigest() if $type eq '-';
      }
    }
    close(G) if $x && !$tomem;
    $c[-1]->{'info'} = $info;
    $c[-1]->{'md5'} = $md5 if $type eq '-';
    die("cpio read error bodypad\n") unless (read(F, $name, $fsizepad) || 0) == $fsizepad;
  }
  close(F);
  return @c;
}

my %ziptypes = (1 => 'p', 2 => 'c', 4 => 'd', 8 => '-', 10 => 'l', 12 => 's');

sub listzip {
  my ($zipfile) = @_;
  local *F;
  open(F, '<', $zipfile) || die("$zipfile: $!\n");
  my $entries;
  eval { $entries = BSZip::list(\*F) };
  die("$zipfile: $@") if $@;
  my @c;
  for my $e (@$entries) {
    die("$zipfile: name contains \\0\n") if $e->{'name'} =~ /\0/;
    my $type = $ziptypes{$e->{'ziptype'}} || '?';
    my $fsize = $e->{'size'};
    push @c, {'type' => $type, 'name' => $e->{'name'}, 'size' => $fsize, 'mode' => cpiomode($e->{'mode'})};
    my $md5 = $type eq '-' ? 'd41d8cd98f00b204e9800998ecf8427e' : undef;
    my $info = $type eq '-' ? 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' : '';
    if ($fsize > 0) {
      if ($type eq 'l') {
	die("ridiculous long symlink $e->{'name'}\n") if $fsize > 8192;
	$info = BSZip::extract(\*F, $e);
      } elsif ($type eq '-') {
        my $ctx = Digest::MD5->new;
        my $ctx256 = Digest::SHA->new(256);
        my $writer = sub { $ctx->add($_[0]); $ctx256->add($_[0]) };
	eval { BSZip::extract(\*F, $e, 'writer' => $writer) };
	die("$zipfile: $@") if $@;
	$info = $ctx256->hexdigest();
	$md5 = $ctx->hexdigest();
      }
    }
    $c[-1]->{'info'} = $info;
    $c[-1]->{'md5'} = $md5 if $type eq '-';
  }
  close(F);
  return @c;
}

sub extractzip {
  my ($zipfile, $cp) = @_;
  local *F;
  open(F, '<', $zipfile) || die("$zipfile: $!\n");
  my $entries = BSZip::list(\*F);
  for my $e (@$entries) {
    my $x = shift @$cp;
    die unless $x;
    next unless $x->{'extract'};
    die("bad extract file type $e->{'ziptype'}\n") unless $e->{'ziptype'} == 8;
    if (exists($x->{'content'})) {
      $x->{'content'} .= BSZip::extract(\*F, $e);
    } else {
      local *G;
      open(G, '>', $x->{'extract'}) || die("$x->{'extract'}: $!\n");
      my $writer = sub { print G $_[0] or die("write: $!\n") };
      eval { BSZip::extract(\*F, $e, 'writer' => $writer) };
      die("$zipfile: $@") if $@;
      close(G) || die("close: $!\n");
    }
  }
}

sub filediff_libxdiff_check {
  my ($f, $content) = @_;
  return '' unless defined($f);
  return $f if ref($f);
  return undef if $f =~ /\.(?:gz|bz2|xz|zstd?)$/;
  if (!defined($content)) {
    return undef unless -e $f;
    return undef if -s _ > 65536;
    $content = readstr($f, 1);
    return undef unless defined $content;
  }
  return undef if $content =~ /\0/s;	# can't handle
  my $ff = substr($content, 0, 4096);
  my $bcnt = $ff =~ tr/\000-\007\016-\037/\000-\007\016-\037/;
  return undef if $bcnt * 40 > length($ff);
  return $content;
}

#
# diff file f1 against file f2 using libxdiff
#
sub filediff_libxdiff {
  my ($f1, $f2, %opts) = @_;

  my $max = $opts{'fmax'};
  my $maxc = defined($max) ? $max * 80 : undef;
  $maxc = $opts{'fmaxc'} if exists $opts{'fmaxc'};

  my $d = Diff::LibXDiff->diff(!defined($f1) || ref($f1) ? '' : $f1, !defined($f2) || ref($f2) ? '' : $f2);
  my $lcnt = $d =~ tr/\n/\n/;
  my $ccnt = 0;
  if (defined($max)) {
    if ($max <= 0) {
      $d = '';
    } elsif ($max < $lcnt) {
      my @tmp = split("\n", $d, $max + 1);
      pop(@tmp);
      $d = join("\n", @tmp)."\n";
    }
  }
  if (defined($maxc)) {
    if ($maxc <= 0) {
      $ccnt = $d =~ tr/\n/\n/;
    } elsif (length($d) > $maxc) {
      my $out = substr($d, $maxc);
      $d = substr($d, 0, $maxc);
      $d =~ s/[^\n]*\Z//s;
      $ccnt = $out =~ tr/\n/\n/;
    }
  }
  if (defined($f1) && ref($f1) && @$f1) {
    $d = "-".join("\n-", @$f1)."\n$d";
    $lcnt += @$f1;
  }
  if (defined($f2) && ref($f2) && @$f2) {
    $d .= "+".join("\n+", @$f2)."\n";
    $lcnt += @$f2;
  }
  my $ret = {};
  if (!defined($f1)) {
    $ret->{'state'} = 'added';
  } elsif (!defined($f2)) {
    $ret->{'state'} = 'deleted';
  } else {
    $ret->{'state'} = 'changed';
  }
  $ret->{'lines'} = $lcnt;
  $ret->{'shown'} = $max if defined($max) && $lcnt > $max;
  $ret->{'shown'} = ($ret->{'shown'} || $ret->{'lines'}) - $ccnt if $ccnt;
  $ret->{'_content'} = $d;
  return $ret;
}

#
# diff file f1 against file f2
#
sub filediff {
  my ($f1, $f2, %opts) = @_;

  return undef if $opts{'nodiff'};
  if (!defined($f1) && !defined($f2)) {
    return { 'lines' => 0 , '_content' => ''};
  }

  my $diffarg = $opts{'diffarg'} || '-u';

  if ($havelibxdiff && $diffarg eq '-u') {
    my ($c1, $c2);
    if (!defined($f1) || defined($c1 = filediff_libxdiff_check($f1))) {
      if (!defined($f2) || defined($c2 = filediff_libxdiff_check($f2))) {
        return filediff_libxdiff($c1, $c2, %opts);
      }
    }
  }

  return filediff_batcher(@_) if $batcherpid;

  my $nodecomp = $opts{'nodecomp'};
  my $max = $opts{'fmax'};
  my $maxc = defined($max) ? $max * 80 : undef;
  $maxc = $opts{'fmaxc'} if exists $opts{'fmaxc'};


  local *D;
  my $pid = open(D, '-|');
  if (!$pid) {
    local *F1;
    local *F2;
    if (!defined($f1) || ref($f1)) {
      open(F1, "<", '/dev/null') || die("open /dev/null: $!\n");
    } elsif (!$nodecomp && $f1 =~ /\.gz$/i) {
      open(F1, "-|", 'gunzip', '-dc', $f1) || die("open $f1: $!\n");
    } elsif (!$nodecomp && $f1 =~ /\.bz2$/i) {
      open(F1, "-|", 'bzip2', '-dc', $f1) || die("open $f1: $!\n");
    } elsif (!$nodecomp && $f1 =~ /\.xz$/i) {
      open(F1, "-|", 'xz', '-dc', $f1) || die("open $f1: $!\n");
    } elsif (!$nodecomp && $f1 =~ /\.zstd?$/i) {
      open(F1, "-|", 'zstd', '-dc', $f1) || die("open $f1: $!\n");
    } else {
      open(F1, '<', $f1) || die("open $f1: $!\n");
    }
    if (!defined($f2) || ref($f2)) {
      open(F2, "<", '/dev/null') || die("open /dev/null: $!\n");
    } elsif (!$nodecomp && $f2 =~ /\.gz$/i) {
      open(F2, "-|", 'gunzip', '-dc', $f2) || die("open $f2: $!\n");
    } elsif (!$nodecomp && $f2 =~ /\.bz2$/i) {
      open(F2, "-|", 'bzip2', '-dc', $f2) || die("open $f2: $!\n");
    } elsif (!$nodecomp && $f2 =~ /\.xz$/i) {
      open(F2, "-|", 'xz', '-dc', $f2) || die("open $f2: $!\n");
    } elsif (!$nodecomp && $f2 =~ /\.zstd?$/i) {
      open(F2, "-|", 'zstd', '-dc', $f2) || die("open $f2: $!\n");
    } else {
      open(F2, '<', $f2) || die("open $f2: $!\n");
    }
    fcntl(F1, F_SETFD, 0);
    fcntl(F2, F_SETFD, 0);
    exec '/usr/bin/diff', $diffarg, '/dev/fd/'.fileno(F1), '/dev/fd/'.fileno(F2);
    die("diff: $!\n");
  }
  my $lcnt = $opts{'linestart'} || 0;
  my $ccnt = 0;
  my $d = '';
  my $havediff;
  my $binary;
  while (<D>) {
    if (!$havediff) {
      next if /^diff/;
      next if /^--- \/dev\/fd\/\d+/;
      if (/^\+\+\+ \/dev\/fd\/\d+/) {
	if (defined($f1) && ref($f1)) {
	  $d .= "-$_\n" for @$f1;
	  $lcnt += @$f1;
	}
	$havediff = 1;
	next;
      }
      if (/^(?:Binary )?[fF]iles \/dev\/fd\/\d+ and \/dev\/fd\/\d+ differ/) {
	$binary = 1;
	last;
      }
    }
    $lcnt++;
    if (!defined($max) || $lcnt <= $max) {
      if (defined($maxc) && length($d) + length($_) > $maxc) {
	$ccnt++;
      } else {
        $d .= $_;
      }
    }
  }
  close(D);
  if ($havediff && !$binary && length($d) >= 1024) {
    # the diff binary detection is a bit "lacking". Do some extra heuristics
    # by counting 26 chars common in binaries
    my $bcnt = $d =~ tr/\000-\007\016-\037/\000-\007\016-\037/;
    if ($bcnt * 40 > length($d)) {
      $d = '';
      $havediff = 0;
      $binary = 1;
      $lcnt = $opts{'linestart'} || 0;
      $ccnt = 0;
    }
  }
  if (!$havediff && ((defined($f1) && ref($f1)) || defined($f2) && ref($f2))) {
    $havediff = 1;
    if (defined($f1) && ref($f1)) {
      $d .= "-$_\n" for @$f1;
      $lcnt += @$f1;
    }
  }
  if ($havediff && defined($f2) && ref($f2)) {
    $d .= "+$_\n" for @$f2;
    $lcnt += @$f2;
  }
  my $ret = {};
  if (!defined($f1)) {
    $ret->{'state'} = 'added';
  } elsif (!defined($f2)) {
    $ret->{'state'} = 'deleted';
  } else {
    $ret->{'state'} = 'changed';
  }
  $ret->{'binary'} = 1 if $binary;
  $ret->{'lines'} = $lcnt;
  $ret->{'shown'} = $max if defined($max) && $lcnt > $max;
  $ret->{'shown'} = ($ret->{'shown'} || $ret->{'lines'}) - $ccnt if $ccnt;
  $ret->{'_content'} = $d;
  return $ret;
}

sub fixup {
  my ($e, $nowrite) = @_;
  return undef unless defined $e;
  if ($e->{'type'} eq 'd') {
    return [ '(directory)' ];
  } elsif ($e->{'type'} eq 'b') {
    return [ "(block device $e->{info})" ];
  } elsif ($e->{'type'} eq 'c') {
    return [ "(character device $e->{info})" ];
  } elsif ($e->{'type'} eq 'l') {
    return [ "(symlink to $e->{info})" ];
  } elsif ($e->{'type'} eq '-') {
    writestr($e->{'extract'}, undef, $e->{'content'}) if !$nowrite && exists $e->{'content'};
    return $e->{'size'} ? $e->{'extract'} : undef;
  } else {
    return [ "(unknown type $e->{type})" ];
  }
}

sub filediff_fixup {
  my ($f1, $f2, %opts) = @_;
  if ($havelibxdiff && ($opts{'diffarg'} || '-u') eq '-u') {
    my ($c1, $c2);
    if (!$f1 || defined($c1 = filediff_libxdiff_check(fixup($f1, 1), $f1->{'content'}))) {
      if (!$f2 || defined($c2 = filediff_libxdiff_check(fixup($f2, 1), $f2->{'content'}))) {
        return filediff_libxdiff($c1, $c2, %opts);
      }
    }
  }
  return filediff(fixup($f1), fixup($f2), %opts);
}

sub adddiffheader {
  my ($r, $p1, $p2) = @_;
  my ($h, $hl);
  my $state = $r->{'state'} || 'changed';
  $r->{'_content'} = '' unless defined $r->{'_content'};
  if ($r->{'binary'}) {
    if (defined($p1) && defined($p2) && $state eq 'changed') {
      if ($p1 eq $p2) {
        $h = "Binary file $p1 differs\n";
      } else {
        $h = "Binary files $p1 and $p2 differ\n";
      }
    } elsif (defined($p1) && $state ne 'added') {
      $h = "Binary file $p1 deleted\n";
    } elsif (defined($p2) && $state ne 'deleted') {
      $h = "Binary file $p2 added\n";
    }
    $hl = 1;
  } else {
    if (defined($p1) && defined($p2) && $state eq 'changed') {
      $h = "--- $p1\n+++ $p2\n";
    } elsif (defined($p1) && $state ne 'added') {
      $p2 = $p1 unless defined $p2;
      $h = "--- $p1\n+++ $p2\n";
    } elsif (defined($p2) && $state ne 'deleted') {
      $p1 = $p2 unless defined $p1;
      $h = "--- $p1\n+++ $p2\n";
    }
    $hl = 2;
  }
  if ($h) {
    $r->{'_content'} = $h . $r->{'_content'};
    $r->{'lines'} += $hl;
    $r->{'shown'} += $hl if defined $r->{'shown'};
  }
  if (defined($r->{'shown'})) {
    if ($r->{'shown'}) {
      $r->{'_content'} .= "(".($r->{'lines'} - $r->{'shown'})." more lines skipped)\n";
    } else {
      $r->{'_content'} .= "(".($r->{'lines'})." lines skipped)\n";
    }
  }
  return $r->{'_content'};
}

sub listit {
  my ($f) = @_;
  return listgem($f) if $f =~ /\.gem$/;
  return listextractcpio($f) if $f =~ /\.obscpio$/;
  return listzip($f) if $f =~ /\.zip$/;
  return listtar($f);
}

sub extractit {
  my ($f, $cp) = @_;
  return listextractcpio($f, $cp || []) if $f =~ /\.obscpio$/;
  return extractzip($f, $cp) if $f =~ /\.zip$/;
  return extracttar($f, $cp);
}

# find renamed files. currently only looks for same content
sub findren {
  my ($old, $new) = @_;

  my %l1info;
  for my $f (grep {!$new->{$_}} sort keys %$old) {
    my $l = $old->{$f};
    next unless $l->{'type'} eq '-' && $l->{'size'};
    $l1info{$l->{'info'}} = $f;
  }
  my %ren;
  for my $f (grep {!$old->{$_}} sort keys %$new) {
    my $l = $new->{$f};
    next unless $l->{'type'} eq '-' && $l->{'size'};
    next unless exists $l1info{$l->{'info'}};
    my $of = $l1info{$l->{'info'}};
    $ren{$of} = $f;
    $ren{$f} = $of;
    delete $l1info{$l->{'info'}};	# used up
  }
  return \%ren;
}

sub findtarfiles {
  my ($files) = @_;

  my @names = map {$_->{'name'}} @$files;
  # strip ./ prefix
  s/^\.\/// for @names;
  if (@names) {
    # strip first dir if it is the same for all files
    my $l1 = $names[0];
    if ($l1 =~ s/\/.*//s || $files->[0]->{'type'} eq 'd') {
      if (!grep {!($_ eq $l1 || $_ =~ /^\Q$l1\E\//)} @names) {
	for (@names) {
          s/^[^\/]*\/?//;
	  $_ = '.' if $_ eq '';
	}
      }
    }
  }
  # exclude some files
  for (@names) {
    $_ = '' if "/$_/" =~ /\/(?:CVS|\.cvsignore|\.svn|\.svnignore)\//;
  }
  my %l;
  $l{shift @names} = $_ for @$files;
  delete $l{''};
  return \%l;
}

sub tardiff {
  my ($f1, $f2, %opts) = @_;

  my $max = $opts{'tmax'};
  my $maxc = defined($max) ? $max * 80 : undef;
  $maxc = $opts{'tmaxc'} if exists $opts{'tmaxc'};
  my $tfmax = $opts{'tfmax'};
  my $tfmaxc = $opts{'tfmaxc'};
  my $edir = $opts{'edir'};
  die("doarchive needs the edir option\n") unless $edir;

  my @l1 = listit($f1);
  my @l2 = listit($f2);

  # find the files we want to diff
  my $t1 = findtarfiles(\@l1);
  my $t2 = findtarfiles(\@l2);

  # find renamed files
  my $ren = findren($t1, $t2);

  my @f = sort keys %{ { %$t1, %$t2 } };

  my $e1cnt = 0;
  my $e2cnt = 0;
  my @efiles;
  my $memsize = 50000000;
  for my $f (@f) {
    my $l1 = $t1->{$f};
    my $l2 = $t2->{$f};
    if (exists $ren->{$f}) {
      next unless $l2;
      $l1 = $t1->{$ren->{$f}};
    }
    next if $l1 && $l2 && $l1->{'type'} eq $l2->{'type'} && $l1->{'info'} eq $l2->{'info'};
    if ($l1 && $l1->{'size'} && $l1->{'type'} eq '-') {
      my $suf1 = '';
      $suf1 = ".$1" if $l1->{'name'} =~ /\.(gz|xz|bz2|zstd?)$/;
      my $exfile = "$edir/a$e1cnt$suf1";
      $l1->{'extract'} = $exfile;
      push @efiles, $exfile;
      $e1cnt++;
    }
    if ($l2 && $l2->{'size'} && $l2->{'type'} eq '-') {
      my $suf2 = '';
      $suf2 = ".$1" if $l2->{'name'} =~ /\.(gz|xz|bz2|zstd?)$/;
      my $exfile = "$edir/b$e2cnt$suf2";
      $l2->{'extract'} = $exfile;
      push @efiles, $exfile;
      $e2cnt++;
    }
    if ($havelibxdiff) {
      # extract small files to memory
      if ($l1 && $l1->{'extract'} && $l1->{'size'} < 100000 && $memsize > 0) {
	$l1->{'content'} = '';
	$memsize -= $l1->{'size'};
      }
      if ($l2 && $l2->{'extract'} && $l2->{'size'} < 100000 && $memsize > 0) {
	$l2->{'content'} = '';
	$memsize -= $l2->{'size'};
      }
    }
  }

  if ($e1cnt || $e2cnt) {
    # need to extract some files
    if (! -d $edir) {
      mkdir($edir) || die("mkdir $edir: $!\n");
    }
    extractit($f1, \@l1) if $e1cnt;
    extractit($f2, \@l2) if $e2cnt;
  }

  startbatcher() if $e1cnt + $e2cnt > 100 || ($e1cnt + $e2cnt > 10 && @f > 20000);

  my $lcnt = 0;
  my $d = '';
  my @ret;
  my $ccnt = 0;
  for my $f (@f) {
    my $l1 = $t1->{$f};
    my $l2 = $t2->{$f};
    next unless $l1 || $l2;
    if ($ren->{$f}) {
      if (!$l1) {
	my $r = {'name' => $f, 'lines' => 1, '_content' => "(renamed from $ren->{$f})\n"};
	$r->{'new'} = {'name' => $f, 'md5' => $l2->{'md5'}, 'size' => $l2->{'size'}};
	push @ret, $r;
	$lcnt += $r->{'lines'};
	next;
      }
      $l2 = $t2->{$ren->{$f}};
      # no need to diff if identical
      if ($l1->{'type'} eq $l2->{'type'} && $l1->{'info'} eq $l2->{'info'}) {
	my $r = {'name' => $f, 'lines' => 1, '_content' => "(renamed to $ren->{$f})\n"};
	$r->{'old'} = {'name' => $f, 'md5' => $l1->{'md5'}, 'size' => $l1->{'size'}};
	$r->{'new'} = {'name' => $ren->{$f}, 'md5' => $l2->{'md5'}, 'size' => $l2->{'size'}};
	$lcnt += $r->{'lines'};
	next;
      }
    }
    if ($l1 && $l2) {
      next if $l1->{'type'} eq $l2->{'type'} && (!defined($l1->{'info'}) || $l1->{'info'} eq $l2->{'info'});
      next if $l1->{'type'} eq 'gemdata' && $l2->{'type'} eq 'gemdata';
    }
    my $fmax;
    $fmax = $max > $lcnt ? $max - $lcnt : 0 if defined $max;
    $fmax = $tfmax if defined($tfmax) && (!defined($fmax) || $fmax > $tfmax);
    my $r = filediff_fixup($l1, $l2, %opts, 'fmax' => $fmax, 'fmaxc' => $tfmaxc);
    $r->{'name'} = $f;
    $r->{'old'} = {'name' => $f, 'md5' => $l1->{'md5'}, 'size' => $l1->{'size'}} if $l1;
    $r->{'new'} = {'name' => $f, 'md5' => $l2->{'md5'}, 'size' => $l2->{'size'}} if $l2;
    if ($ren->{$f}) {
      $r->{'new'}->{'name'} = $ren->{$f};
      $r->{'_content'} = "(renamed to $ren->{$f})\n" . ($r->{'content'} || '');
      $r->{'lines'} = ($r->{'lines'} || 0) + 1;
    }
    push @ret, $r;
    $lcnt += $r->{'shown'} || $r->{'lines'};
    $ccnt += length($r->{'_content'}) if exists $r->{'_content'};
  }
  if ((defined($max) && $lcnt > $max) || (defined($maxc) && $ccnt > $maxc)) {
    my $r = {'lines' => $lcnt, 'shown' => 0};
    @ret = ($r);
  }
  unlink($_) for @efiles;
  rmdir($edir);

  endbatcher();
  return @ret;
}

my @simclasses = (
  'spec',
  'dsc',
  'changes',
  '(?:diff?|patch)(?:\.gz|\.bz2|\.xz|\.zstd?)?',
  '(?:tar|tar\.gz|tar\.bz2|tar\.xz|tar\.zstd?|tgz|tbz|gem|obscpio|livebuild|zip)',
);

# do not treat tracker ids as versions
my $trackers = qr/(bnc-\d+|bug-\d+|bsc-\d+|issue-\d+|cve-\d+-\d+)/i;

sub findsim {
  my ($old, $new) = @_;

  # find free files
  my @f = grep {!exists($old->{$_})} sort keys %$new;
  my @of = grep {!exists($new->{$_})} sort keys %$old;

  # classify them
  my %fc;	# file base name
  my %ft;	# file class
  for my $f (@f, @of) {
    next unless $f =~ /\./;
    next if exists $fc{$f};
    for my $sc (@simclasses) {
      my $fc = $f;
      if ($fc =~ s/\.$sc$//) {
	$fc{$f} = $fc;
	$ft{$f} = $sc;
	last;
      }
      $fc =~ s/\.bz2$//;
      $fc =~ s/\.gz$//;
      $fc =~ s/\.xz$//;
      $fc =~ s/\.zstd?$//;
      next if $fc =~ /\.(?:spec|dsc|changes)$/;	# no compression here!
      if ($fc =~ /^(.*)\.([^\/]+)$/) {
	$fc{$f} = $1;
	$ft{$f} = $2;
      }
    }
  }

  my %sim;
  my %s = map {$_ => 1} @of;	# old file pool

  # first pass: exact matches
  for my $f (grep {!exists($sim{$_})} @f) {
    my $fc = $fc{$f};
    my $ft = $ft{$f};
    next unless defined $fc;
    my @s = grep {defined($fc{$_}) && $fc{$_} eq $fc && $ft{$_} eq $ft} sort keys %s;
    if (@s) {
      unshift @s, grep {$old->{$_} eq $new->{$f}} @s if @s > 1;
      $sim{$f} = $s[0];
      $sim{$s[0]} = $f;
      delete $s{$s[0]};
    }
  }

  # second pass: ignore version, but same content
  for my $f (grep {!exists($sim{$_})} @f) {
    my $fc = $fc{$f};
    my $ft = $ft{$f};
    next unless defined $fc;
    my @s = grep {defined($ft{$_}) && $ft{$_} eq $ft} sort keys %s;
    my $fqp = '';
    if ($fc =~ /^($trackers)/) {
      $fqp = "\Q$1\E";
      $fc = substr($fc, length($1));
    }
    my $fq = "\Q$fc\E";
    $fq =~ s/\\\././g;
    $fq =~ s/[0-9.]+/.*/g;
    $fq = "$fqp$fq";
    @s = grep {/^$fq$/ && $old->{$_} eq $new->{$f}} @s;
    if (@s) {
      $sim{$f} = $s[0];
      $sim{$s[0]} = $f;
      delete $s{$s[0]};
    }
  }

  # third pass: ignore version
  for my $f (grep {!exists($sim{$_})} @f) {
    my $fc = $fc{$f};
    my $ft = $ft{$f};
    next unless defined $fc;
    my @s = grep {defined($ft{$_}) && $ft{$_} eq $ft} sort keys %s;
    my $fqp = '';
    if ($fc =~ /^($trackers)/) {
      $fqp = "\Q$1\E";
      $fc = substr($fc, length($1));
    }
    my $fq = "\Q$fc\E";
    $fq =~ s/\\\././g;
    $fq =~ s/[0-9.]+/.*/g;
    $fq = "$fqp$fq";
    @s = grep {/^$fq$/} @s;
    if (@s) {
      unshift @s, grep {$old->{$_} eq $new->{$f}} @s if @s > 1;
      $sim{$f} = $s[0];
      $sim{$s[0]} = $f;
      delete $s{$s[0]};
    }
  }

  return \%sim;
}


# return the filename of a resource
sub fn {
  my ($dir, $f) = @_;
  return undef unless defined $f;
  return ref($dir) ? $dir->($f) : "$dir/$f";
}

sub identicalcontent {
  my ($pold, $of, $pnew, $f) = @_;
  return 1 if fn($pold, $of, 1) eq fn($pnew, $f, 1);
  my $ofn = fn($pold, $of);
  my $fn = fn($pnew, $f);
  my @os = stat($ofn);
  my @s = stat($fn);
  return 1 if @s && @os && $s[0] == $os[0] && $s[1] == $os[1];
  return BSUtil::identicalfile($ofn, $fn);
}

sub srcdiff {
  my ($pold, $old, $pnew, $new, %opts) = @_;

  my $d = '';
  my $fmax = $opts{'fmax'};

  my @old = sort keys %$old;
  my @new = sort keys %$new;
  my $sim = $opts{'similar'} ? findsim($old, $new) : {};

  for my $extra ('changes', 'filelist', 'spec', 'dsc') {
    if ($extra eq 'filelist') {
      my @xold = grep {!exists($new->{$_})} sort keys %$old;
      my @xnew = grep {!exists($old->{$_})} sort keys %$new;
      if (@xold) {
	$d .= "\nold:\n----\n";
	$d .= "  $_\n" for @xold;
      }
      if (@xnew) {
	$d .= "\nnew:\n----\n";
	$d .= "  $_\n" for @xnew;
      }
      next;
    }
    my @xold = grep {/\.$extra$/} sort keys %$old;
    my @xnew = grep {/\.$extra$/} sort keys %$new;
    next unless @xnew || @xold;
    my %xold = map {$_ => 1} @xold;
    my $dd = '';
    my $diffarg = '-ub';
    $diffarg = '-U0' if $extra eq 'changes';
    for my $f (@xnew) {
      my $of;
      if ($xold{$f}) {
	$of = $f;
	delete $xold{$of};
	next if $old->{$of} eq $new->{$f} && identicalcontent($pold, $of, $pnew, $f);
      }
      $dd .= "\n++++++ new $extra file:\n" unless defined $of;
      my $r = filediff(fn($pold, $of), fn($pnew, $f), %opts, 'diffarg' => $diffarg, 'fmax' => undef);
      $dd .= adddiffheader($r, $of, $f);
    }
    if (%xold) {
      $dd .= "\n++++++ deleted $extra files:\n";
      $dd .= "--- $_\n" for sort keys %xold;
    }
    if ($dd ne '') {
      $d .= "\n";
      $d .= "$extra files:\n";
      $d .= "-------".('-' x length($extra))."\n";
      $d .= $dd;
    }
    @old = grep {!/\.$extra$/} @old;
    @new = grep {!/\.$extra$/} @new;
  }

  my %oold = map {$_ => 1} @old;
  my $dd = '';
  for my $f (@new) {
    my $of = exists($sim->{$f}) ? $sim->{$f} : defined($old->{$f}) ? $f : undef;
    if (defined $of) {
      delete $oold{$of};
      $dd .= "\n++++++ $of -> $f\n" if $of ne $f;
      next if $old->{$of} eq $new->{$f} && identicalcontent($pold, $of, $pnew, $f);
      $dd .= "\n++++++ $f\n" if $of eq $f;
    } else {
      $dd .= "\n++++++ $f (new)\n";
    }
    if ($opts{'doarchive'} && $f =~ /\.(?:tar|tgz|tar\.gz|tar\.bz2|tbz|tar\.xz|tar\.zstd?|gem|obscpio|livebuild|zip)$/) {
      if (defined $of) {
	my @r = tardiff(fn($pold, $of), fn($pnew, $f), %opts);
	for my $r (@r) {
	  $dd .= adddiffheader($r, $r->{'name'}, $r->{'name'});
	}
      }
      next;
    }
    my $r = filediff(fn($pold, $of), fn($pnew, $f), %opts);
    $dd .= adddiffheader($r, $of, $f);
  }
  if ($d ne '' && $dd ne '') {
    $d .= "\n";
    $d .= "other changes:\n";
    $d .= "--------------\n";
  }
  $d .= "$dd";

  if (%oold) {
    $d .= "\n++++++ deleted files:\n";
    $d .= "--- $_\n" for sort keys %oold;
  }
  if (1) {
    for my $of (sort keys %oold) {
      $d .= "\n++++++ $of (deleted)\n";
      if ($opts{'doarchive'} && $of =~ /\.(?:tar|tgz|tar\.gz|tar\.bz2|tbz|tar\.xz|tar\.zstd?|gem|obscpio|livebuild|zip)$/) {
        next;
      }
      my $r = filediff(fn($pold, $of), undef, %opts);
      $d .= adddiffheader($r, $of, undef);
    }
  }
  return $d;
}

sub unifieddiff {
  my ($pold, $old, $pnew, $new, %opts) = @_;

  my $sim = $opts{'similar'} ? findsim($old, $new) : {};
  my @changed;
  my @added;
  my @deleted;
  for (sort(keys %{ { %$old, %$new } })) {
    if (defined($sim->{$_}) && $sim->{$_} ne $_) {
      push @changed, $_ if $new->{$_};
    } elsif (!defined($old->{$_})) {
      push @added, $_;
    } elsif (!defined($new->{$_})) {
      push @deleted, $_;
    } elsif ($old->{$_} ne $new->{$_} || !identicalcontent($pold, $_, $pnew, $_)) {
      push @changed, $_;
    }
  }
  my $orevb = defined($opts{'oldrevision'}) ? " (revision $opts{'oldrevision'})" : '';
  my $revb = defined($opts{'newrevision'}) ? " (revision $opts{'newrevision'})" : '';
  my $d = '';
  for my $f (@changed) {
    my $of = defined($sim->{$f}) ? $sim->{$f} : $f;
    if ($f ne $of) {
      $d .= "Index: $of -> $f\n" . ("=" x 67) . "\n";
      next if $old->{$of} eq $new->{$f} && identicalcontent($pold, $of, $pnew, $f);
    } else {
      $d .= "Index: $f\n" . ("=" x 67) . "\n";
    }
    if ($opts{'doarchive'} && $f =~ /\.(?:tar|tgz|tar\.gz|tar\.bz2|tbz|tar\.xz|tar\.zstd?|gem|obscpio|livebuild|zip)$/) {
      my @r = tardiff(fn($pold, $of), fn($pnew, $f), %opts);
      for my $r (@r) {
        $d .= adddiffheader($r, "$r->{'name'}$orevb", "$r->{'name'}$revb");
      }
      next;
    }
    my $r = filediff(fn($pold, $of), fn($pnew, $f), %opts);
    $d .= adddiffheader($r, "$of$orevb", "$f$revb");
  }
  for my $f (@added) {
    $d .= "Index: $f\n" . ("=" x 67) . "\n";
    if ($opts{'doarchive'} && $f =~ /\.(?:tar|tgz|tar\.gz|tar\.bz2|tbz|tar\.xz|tar\.zstd?|gem|obscpio|livebuild|zip)$/) {
      my @r = tardiff(undef, fn($pnew, $f), %opts);
      for my $r (@r) {
        $d .= adddiffheader($r, "$r->{'name'} (added)", "$r->{'name'}$revb");
      }
      next;
    }
    my $r = filediff(undef, fn($pnew, $f), %opts);
    $d .= adddiffheader($r, "$f (added)", "$f$revb");
  }
  for my $f (@deleted) {
    $d .= "Index: $f\n" . ("=" x 67) . "\n";
    my $r = filediff(fn($pold, $f), undef, %opts);
    $d .= adddiffheader($r, "$f$orevb", "$f (deleted)");
  }
  return $d;
}

sub datadiff {
  my ($pold, $old, $pnew, $new, %opts) = @_;

  my @changed;
  my @added;
  my @deleted;

  my $sim = $opts{'similar'} ? findsim($old, $new) : {};

  my %done;
  for my $f (sort(keys %$new)) {
    my $of = defined($sim->{$f}) ? $sim->{$f} : $f;
    $done{$of} = 1;
    if (!defined($old->{$of})) {
      my @s = stat(fn($pnew, $f));
      my $r = filediff(undef, fn($pnew, $f), %opts);
      push @added, {'state' => 'added', 'diff' => $r, 'new' => {'name' => $f, 'md5' => $new->{$f}, 'size' => $s[7]}};
      next;
    }
    next if $f eq $of && $old->{$of} eq $new->{$f} && fn($pold, $of, 1) eq fn($pnew, $f, 1);
    my @os = stat(fn($pold, $of));
    my @s = stat(fn($pnew, $f));
    if ($old->{$of} eq $new->{$f}) {
      # identical md5
      if ((@s && @os && $s[0] == $os[0] && $s[1] == $os[1]) || BSUtil::identicalfile(fn($pold, $of), fn($pnew, $f))) {
	# identical content
	push @changed, {'state' => 'renamed', 'old' => {'name' => $of, 'md5' => $old->{$of}, 'size' => $os[7]}, 'new' => {'name' => $f, 'md5' => $new->{$f}, 'size' => $s[7]}} if $f ne $of;
	next;
      }
    }
    if ($opts{'doarchive'} && $f =~ /\.(?:tar|tgz|tar\.gz|tar\.bz2|tbz|tar\.xz|tar\.zstd?|gem|obscpio|livebuild|zip)$/) {
      my @r = tardiff(fn($pold, $of), fn($pnew, $f), %opts);
      if (@r == 0) {
	# tar changed, but content is the same (e.g. compression level change, different compressor)
	push @changed, {'state' => 'changed', 'old' => {'name' => $of, 'md5' => $old->{$of}, 'size' => $os[7]}, 'new' => {'name' => $f, 'md5' => $new->{$f}, 'size' => $s[7]}};
      } elsif (@r == 1 && !$r[0]->{'old'} && !$r[0]->{'new'}) {
	# tardiff was too big
	push @changed, {'state' => 'changed', 'diff' => $r[0], 'old' => {'name' => $of, 'md5' => $old->{$of}, 'size' => $os[7]}, 'new' => {'name' => $f, 'md5' => $new->{$f}, 'size' => $s[7]}};
	@r = ();
      }
      for my $r (@r) {
	delete($r->{'name'});
	$r->{'old'}->{'name'} = "$of/$r->{'old'}->{'name'}" if $r->{'old'};
	$r->{'new'}->{'name'} = "$f/$r->{'new'}->{'name'}" if $r->{'new'};
	$r->{'old'} ||= $r->{'new'};
	$r->{'new'} ||= $r->{'old'};
	push @changed, {'state' => ($r->{'state'} || 'changed'), 'diff' => $r, 'old' => delete($r->{'old'}), 'new' => delete($r->{'new'})};
      }
    } else {
      my $r = filediff(fn($pold, $of), fn($pnew, $f), %opts);
      push @changed, {'state' => 'changed', 'diff' => $r, 'old' => {'name' => $of, 'md5' => $old->{$of}, 'size' => $os[7]}, 'new' => {'name' => $f, 'md5' => $new->{$f}, 'size' => $s[7]}};
    }
  }
  for my $of (grep {!$done{$_}} sort(keys %$old)) {
    my @os = stat(fn($pold, $of));
    my $r = filediff(fn($pold, $of), undef, %opts);
    push @added, {'state' => 'deleted', 'diff' => $r, 'old' => {'name' => $of, 'md5' => $old->{$of}, 'size' => $os[7]}};
  }
  # fixup diff
  for (@changed, @added, @deleted) {
    if ($_->{'diff'}) {
      delete $_->{'diff'}->{'state'};
    } else {
      delete $_->{'diff'};
    }
  }
  return [ @changed, @added, @deleted ];
}

sub issues {
  my ($entry, $trackers, $ret) = @_;
  for my $tracker (@$trackers) {
    my @issues = $entry =~ /$tracker->{'regex'}/g;
    pop @issues if @issues & 1;	# hmm
    my %issues = @issues;
    for (sort keys %issues) {
      my $label = $tracker->{'label'};
      $label =~ s/\@\@\@/$issues{$_}/g;
      $ret->{$label} = {
	'name' => $issues{$_},
	'label' => $label,
        'tracker' => $tracker,
      };
    }
  }
}

sub preparetrackers {
  my ($trackers) = @_;
  $trackers = [ @{$trackers || []} ];
  for (@$trackers) {
    $_ = { %$_ };
    $_->{'regex'} = "($_->{'regex'})" unless $_->{'regex'} =~ /\(/;
    $_->{'regex'} = "($_->{'regex'})";
    eval {
      $_->{'regex'} = qr/$_->{'regex'}/;
    };
    if ($@) {
      warn($@);
      $_->{'regex'} = qr/___this_reGExp_does_NOT_match___/;
    }
  }
  return $trackers;
}

sub finalizeissues {
  for my $issue (@_) {
    my $tracker = $issue->{'tracker'};
    my $url = $tracker->{'show-url'};
    if ($url) {
      $url =~ s/\@\@\@/$issue->{'name'}/g;
      $issue->{'url'} = $url;
    }
    $issue->{'tracker'} = $tracker->{'name'};
  }
}

sub issuediff {
  my ($pold, $old, $pnew, $new, %opts) = @_;

  my $trackers = $opts{'trackers'};
  return [] unless @{$trackers || []};

  $trackers = preparetrackers($trackers);

  my %oldchanges;
  my %newchanges;
  for my $f (grep {/\.changes$/} sort(keys %$old)) {
    for (split(/------------------------------------------+/, readstr(fn($pold, $f)))) {
      $oldchanges{Digest::MD5::md5_hex($_)} = $_;
    }
  }
  for my $f (grep {/\.changes$/} sort(keys %$new)) {
    for (split(/------------------------------------------+/, readstr(fn($pnew, $f)))) {
      $newchanges{Digest::MD5::md5_hex($_)} = $_;
    }
  }
  my %oldissues;
  my %newissues;
  my %keptissues;
  for my $c (keys %oldchanges) {
    next if exists $newchanges{$c};
    issues($oldchanges{$c}, $trackers, \%oldissues);
  }
  for my $c (keys %newchanges) {
    next if exists $oldchanges{$c};
    issues($newchanges{$c}, $trackers, \%newissues);
  }
  if (%oldissues || %newissues) {
    for my $c (keys %oldchanges) {
      next unless exists $newchanges{$c};
      issues($oldchanges{$c}, $trackers, \%keptissues);
    }
  }
  my @added;
  my @changed;
  my @deleted;
  for (sort keys %newissues) {
    if (exists($oldissues{$_}) || exists($keptissues{$_})) {
      $newissues{$_}->{'state'} = 'changed';
      delete $oldissues{$_};
      push @changed, $newissues{$_};
    } else {
      $newissues{$_}->{'state'} = 'added';
      push @added, $newissues{$_};
    }
  }
  for (sort keys %oldissues) {
    if (exists($keptissues{$_})) {
      $oldissues{$_}->{'state'} = 'changed';
      push @changed, $oldissues{$_};
    } else {
      $oldissues{$_}->{'state'} = 'deleted';
      push @deleted , $oldissues{$_};
    }
  }
  finalizeissues(@changed, @added, @deleted);
  return [ @changed, @added, @deleted ];
}

1;

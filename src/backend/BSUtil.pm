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
# collection of useful functions
#

package BSUtil;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw{writexml writestr readxml readstr ls mkdir_p xfork str2utf8 data2utf8 str2utf8xml data2utf8xml};

use XML::Structured;
use POSIX;
use Fcntl qw(:DEFAULT :flock);
use Encode;
use Storable ();

use strict;

sub writexml {
  my ($fn, $fnf, $dd, $dtd) = @_;
  my $d = XMLout($dtd, $dd);
  local *F;
  open(F, '>', $fn) || die("$fn: $!\n");
  (syswrite(F, $d) || 0) == length($d) || die("$fn write: $!\n");
  close(F) || die("$fn close: $!\n");
  return unless defined $fnf;
  $! = 0;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n");
}

sub writestr {
  my ($fn, $fnf, $d) = @_;
  local *F;
  open(F, '>', $fn) || die("$fn: $!\n");
  if (length($d)) {
    (syswrite(F, $d) || 0) == length($d) || die("$fn write: $!\n");
  }
  close(F) || die("$fn close: $!\n");
  return unless defined $fnf;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n");
}

sub appendstr {
  my ($fn, $d) = @_;
  local *F;
  open(F, '>>', $fn) || die("$fn: $!\n");
  if (length($d)) {
    (syswrite(F, $d) || 0) == length($d) || die("$fn write: $!\n");
  }
  close(F) || die("$fn close: $!\n");
}

sub readstr {
  my ($fn, $nonfatal) = @_;
  local *F;
  if (!open(F, '<', $fn)) {
    die("$fn: $!\n") unless $nonfatal;
    return undef;
  }
  my $d = '';
  1 while sysread(F, $d, 8192, length($d));
  close F;
  return $d;
}

sub readxml {
  my ($fn, $dtd, $nonfatal) = @_;
  my $d = readstr($fn, $nonfatal);
  return $d unless defined $d;
  if ($d !~ /<.*?>/s) {
    die("$fn: not xml\n") unless $nonfatal;
    return undef;
  }
  return XMLin($dtd, $d) unless $nonfatal;
  eval { $d = XMLin($dtd, $d); };
  return $@ ? undef : $d;
}

sub touch($) {
  my ($file) = @_;
  if (-e $file) {
    utime(time, time, $file); 
  } else {
    # create new file, mtime is anyway current
    local *F;
    open(F, '>>', $file) || die("$file: $!\n");
    close(F) || die("$file close: $!\n");
  }
}

sub ls {
  local *D;
  opendir(D, $_[0]) || return ();
  my @r = grep {$_ ne '.' && $_ ne '..'} readdir(D);
  closedir D;
  return @r;
}

sub mkdir_p {
  my ($dir) = @_;

  return 1 if -d $dir;
  my $pdir;
  if ($dir =~ /^(.+)\//) {
    $pdir = $1;
    mkdir_p($pdir) || return undef;
  }
  while (!mkdir($dir, 0777)) {
    my $e = $!;
    return 1 if -d $dir;
    if (defined($pdir) && ! -d $pdir) {
      mkdir_p($pdir) || return undef;
      next;
    }
    $! = $e;
    warn("mkdir: $dir: $!\n");
    return undef;
  }
  return 1;
}

sub cleandir {
  my ($dir) = @_;

  my $ret = 1;
  return 1 unless -d $dir;
  for my $c (ls($dir)) {
    if (! -l "$dir/$c" && -d _) {
      cleandir("$dir/$c");
      $ret = undef unless rmdir("$dir/$c");
    } else {
      $ret = undef unless unlink("$dir/$c");
    }
  }
  return $ret;
}

sub linktree {
  my ($from, $to) = @_;
  return unless -d $from;
  mkdir_p($to);
  my @todo = sort(ls($from));
  while (@todo) {
    my $f = shift @todo;
    if (! -l "$from/$f" && -d _) {
      mkdir_p("$to/$f");
      unshift @todo, map {"$f/$_"} ls("$from/$f");
    } else {
      link("$from/$f", "$to/$f") || die("link $from/$f $to/$f: $!\n");
    }
  }
}

sub treeinfo {
  my ($dir) = @_;
  my @info;
  my @todo = sort(ls($dir));
  while (@todo) {
    my $f = shift @todo;
    my @s = lstat("$dir/$f");
    next unless @s;
    if (-d _) { 
      push @info, "$f";
      unshift @todo, map {"$f/$_"} ls("$dir/$f");
    } else {
      push @info, "$f $s[9]/$s[7]/$s[1]";
    }    
  }
  return \@info;
}

sub xfork {
  my $pid;
  while (1) {
    $pid = fork();
    last if defined $pid;
    die("fork: $!\n") if $! != POSIX::EAGAIN;
    sleep(5);
  }
  return $pid;
}

sub cp {
  my ($from, $to, $tof) = @_;
  local *F;
  local *T;
  open(F, '<', $from) || die("$from: $!\n");
  open(T, '>', $to) || die("$to: $!\n");
  my $buf;
  while (sysread(F, $buf, 8192)) {
    (syswrite(T, $buf) || 0) == length($buf) || die("$to write: $!\n");
  }
  close(F);
  close(T) || die("$to: $!\n");
  if (defined($tof)) {
    rename($to, $tof) || die("rename $to $tof: $!\n");
  }
}

sub str2utf8 {
  my ($oct) = @_;
  return $oct unless defined $oct;
  return $oct unless $oct =~ /[^\011\012\015\040-\176]/s;
  eval {
    Encode::_utf8_on($oct);
    $oct = encode('utf-8', $oct, Encode::FB_CROAK);
  };
  if ($@) {
    # assume iso-8859-1
    eval {
      Encode::_utf8_off($oct);
      $oct = encode('utf-8', $oct, Encode::FB_CROAK);
    };
    if ($@) {
      Encode::_utf8_on($oct);
      $oct = encode('utf-8', $oct, Encode::FB_XMLCREF);
    }
  }
  Encode::_utf8_off($oct);	# just in case...
  return $oct;
}

sub data2utf8 {
  my ($d) = @_;
  if (ref($d) eq 'ARRAY') {
    for my $dd (@$d) {
      if (ref($dd) eq '') {
        $dd = str2utf8($dd);
      } else {
        data2utf8($dd);
      }
    }
  } elsif (ref($d) eq 'HASH') {
    for my $dd (keys %$d) {
      if (ref($d->{$dd}) eq '') {
        $d->{$dd} = str2utf8($d->{$dd});
      } else {
        data2utf8($d->{$dd});
      }
    }
  }
}

sub str2utf8xml {
  my ($oct) = @_;
  return $oct unless defined $oct;
  return $oct unless $oct =~ /[^\011\012\015\040-\176]/s;
  $oct = str2utf8($oct);
  Encode::_utf8_on($oct);
  # xml does not accept all utf8 chars, escape the illegal
  $oct =~ s/([\000-\010\013\014\016-\037\177])/sprintf("&#x%x;",ord($1))/sge;
  $oct =~ s/([\x{d800}-\x{dfff}\x{fffe}\x{ffff}])/sprintf("&#x%x;",ord($1))/sge;
  Encode::_utf8_off($oct);
  return $oct;
}

sub data2utf8xml {
  my ($d) = @_;
  if (ref($d) eq 'ARRAY') {
    for my $dd (@$d) {
      if (ref($dd) eq '') {
        $dd = str2utf8xml($dd);
      } else {
        data2utf8xml($dd);
      }
    }
  } elsif (ref($d) eq 'HASH') {
    for my $dd (keys %$d) {
      if (ref($d->{$dd}) eq '') {
        $d->{$dd} = str2utf8xml($d->{$dd});
      } else {
        data2utf8xml($d->{$dd});
      }
    }
  }
}

sub lockopen {
  my ($fg, $op, $fn, $nonfatal) = @_;

  local *F = $fg; 
  while (1) {
    if (!open(F, $op, $fn)) {
      return undef if $nonfatal;
      die("$fn: $!\n");
    }
    flock(F, LOCK_EX) || die("flock $fn: $!\n");
    my @s = stat(F);
    return 1 if @s && $s[3];
    close F;
  }
}

sub lockopenxml {
  my ($fg, $op, $fn, $dtd, $nonfatal) = @_;
  if (!lockopen($fg, $op, $fn, $nonfatal)) {
    die("$fn: $!\n") unless $nonfatal;
    return undef;
  }
  my $d = readxml($fn, $dtd, $nonfatal);
  if (!$d) {
    local *F = $fg;
    close F;
  }
  return $d;
}

sub lockcreatexml {
  my ($fg, $fn, $fnf, $dd, $dtd) = @_;

  local *F = $fg; 
  writexml($fn, undef, $dd, $dtd);
  open(F, '<', $fn) || die("$fn: $!\n");
  flock(F, LOCK_EX | LOCK_NB) || die("lock: $!\n");
  if (!link($fn, $fnf)) {
    unlink($fn);
    close F;
    return undef;
  }
  unlink($fn);
  return 1;
}

sub isotime {
  my ($t) = @_;
  my @lt = localtime($t || time());
  return sprintf "%04d-%02d-%02d %02d:%02d:%02d", $lt[5] + 1900, $lt[4] + 1, @lt[3,2,1,0];
}

# XXX: does that really belong here?
sub enabled {
  my ($repoid, $disen, $default, $arch) = @_;
  return $default unless $disen;
  my $exact = 0;
  # the arch attr has a higher score/exactness than all other attrs
  if (($default || !defined($default)) && $disen->{'disable'}) {
    for (@{$disen->{'disable'}}) {
      my $e = 0;
      $_->{'arch'} eq $arch ? $e++ : next if exists($_->{'arch'});
      $_->{'repository'} eq $repoid ? $e++ : next if exists($_->{'repository'});
      $exact = $e;
      $default = 0;
      last;
    }
  }
  if (!$default && $disen->{'enable'}) {
    for (@{$disen->{'enable'}}) {
      my $e = 0;
      $_->{'arch'} eq $arch ? $e++ : next if exists($_->{'arch'});
      $_->{'repository'} eq $repoid ? $e++ : next if exists($_->{'repository'});
      next if $e < $exact;
      $default = 1;
      last;
    }
  }
  return $default;
}

sub store {
  my ($fn, $fnf, $dd) = @_;
  if (!Storable::nstore($dd, $fn)) {
    die("nstore $fn: $!\n");
  }
  return unless defined $fnf;
  $! = 0;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n");
}

sub retrieve {
  my ($fn, $nonfatal) = @_;
  my $dd;
  if (!$nonfatal) {
    $dd = Storable::retrieve($fn);
    die("retrieve $fn: $!\n") unless $dd;
  } else {
    eval { $dd = Storable::retrieve($fn); };
    if (!$dd && $nonfatal == 2) {
      if ($@) {
        warn($@);
      } else {
        warn("retrieve $fn: $!\n");
      }
    }
  }
  return $dd;
}

1;

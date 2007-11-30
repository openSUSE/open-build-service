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
@EXPORT = qw{writexml writestr readxml readstr ls mkdir_p xfork str2utf8 data2utf8};

use XML::Structured;
use POSIX;
use Fcntl qw(:DEFAULT :flock);
use Encode;

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

sub ls {
  local *D;
  opendir(D, $_[0]) || return ();
  my @r = grep {$_ ne '.' && $_ ne '..'} readdir(D);
  closedir D;
  return @r;
}

sub mkdir_p {
  my $dir = shift;

  return 1 if -d $dir;
  if ($dir =~ /^(.*)\//) {
    mkdir_p($1) || return undef;
  }
  if (!mkdir($dir, 0777)) {
    my $e = $!;
    return 1 if -d $dir;
    $! = $e;
    warn("mkdir: $dir: $!\n");
    return undef;
  }
  return 1;
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
  eval {
    Encode::_utf8_on($oct);
    $oct = encode('utf-8', $oct, Encode::FB_CROAK);
  };
  if ($@) {
    Encode::_utf8_off($oct);
    $oct = encode('utf-8', $oct, Encode::FB_CROAK);
    if ($@) {
      Encode::_utf8_on($oct);
      $oct = encode('utf-8', $oct, Encode::FB_XMLCREF);
    }
  }
  Encode::_utf8_off($oct);
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

sub lockopen {
  my ($fg, $op, $fn) = @_;

  local *F = $fg; 
  while (1) {
    return undef unless open(F, $op, $fn);
    flock(F, LOCK_EX) || die("flock $fn: $!\n");
    my @s = stat(F);
    return 1 if @s && $s[3];
    close F;
  }
}

sub lockopenxml {
  my ($fg, $op, $fn, $dtd, $nonfatal) = @_;
  if (!lockopen($fg, $op, $fn)) {
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

1;

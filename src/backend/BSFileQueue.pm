#
# Copyright (c) 2026 SUSE LLC
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
# Simple CSV based file queue, multiple processes can append entries
# to the and and one process reads the entries from the start.
#

package BSFileQueue;

use strict;

use POSIX;
use Fcntl qw(:DEFAULT :flock);

use BSUtil;

sub add_multiple {
  my ($fn, @mr) = @_;
  my $fd;
  BSUtil::lockopen($fd, '>>', $fn);
  my $oldlen = -s $fd;
  while (@mr) {
    my @r = @{shift @mr};
    die unless $r[0];
    s/([\000-\037%|=\177-\237])/sprintf("%%%02X", ord($1))/ge for @r;
    my $line = join('|', @r)."\n";
    (syswrite($fd, $line) || 0) == length($line) || die("syswrite $fn: $!\n");
  }
  close($fd);
  return $oldlen ? 0 : 1;
}

sub add {
  my ($fn, @r) = @_;
  return add_multiple($fn, \@r);
}

sub openqueue {
  my ($fn) = @_;
  my $fd;
  BSUtil::lockopen($fd, '<', $fn);
  return $fd;
}

sub renamequeue {
  my ($fn, $fnf) = @_;
  my $fd = openqueue($fn);
  die if -e $fnf;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n");
  close($fd);
}

sub getnext {
  my ($fd) = @_;
  my $line = <$fd>;
  return undef unless $line;
  my $l = length($line);
  die("bad line\n") unless chop($line) eq "\n";
  my @r = split('\|', $line);
  return $l unless $r[0];
  s/%([a-fA-F0-9]{2})/chr(hex($1))/ge for @r;
  return $l, @r;
}

# perl has no pwrite(), so we need to open a second file handle
# for marking processed entries

sub openmark {
  my ($fn) = @_;
  my $markfd;
  open($markfd, '+<', $fn) || die("markfd open $fn: $!\n");
  return $markfd;
}

sub markdone {
  my ($markfd, $off) = @_;
  defined(sysseek($markfd, $off, Fcntl::SEEK_SET)) || die("sysseek $off: $!\n");
  syswrite($markfd, "|", 1) == 1 || die("syswrite $off: $!\n");
}

1;

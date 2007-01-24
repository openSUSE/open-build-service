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
# deb binary package query functions
# (probably obsolete, should use Build::debq instead)
#

package BSDEBQ;

use Compress::Zlib;
use Digest::MD5 ();

use strict;

sub debq {
  my ($fn) = @_;

  local *F;
  if (ref($fn) eq 'GLOB') {
      *F = $fn;
  } elsif (!open(F, '<', $fn)) {
    warn("$fn: $!\n");
    return ();
  }
  my $data = '';
  sysread(F, $data, 4096);
  if (length($data) < 8+60) {
    warn("$fn: not a debian package\n");
    close F unless ref $fn;
    return ();
  }
  if (substr($data, 0, 8+16) ne "!<arch>\ndebian-binary   ") {
    close F unless ref $fn;
    return ();
  }
  my $len = substr($data, 8+48, 10);
  $len += $len & 1;
  if (length($data) < 8+60+$len+60) {
    my $r = 8+60+$len+60 - length($data);
    $r -= length($data);
    if ((sysread(F, $data, $r < 4096 ? 4096 : $r, length($data)) || 0) < $r) {
      warn("$fn: unexpected EOF\n");
      close F unless ref $fn;
      return ();
    }
  }
  $data = substr($data, 8 + 60 + $len);
  if (substr($data, 0, 16) ne 'control.tar.gz  ') {
    warn("$fn: control.tar.gz is not second ar entry\n");
    close F unless ref $fn;
    return ();
  }
  $len = substr($data, 48, 10);
  if (length($data) < 60+$len) {
    my $r = 60+$len - length($data);
    if ((sysread(F, $data, $r, length($data)) || 0) < $r) {
      warn("$fn: unexpected EOF\n");
      close F unless ref $fn;
      return ();
    }
  }
  close F;
  $data = substr($data, 60, $len);
  my $controlmd5 = Digest::MD5::md5_hex($data);		# our header signature
  $data = Compress::Zlib::memGunzip($data);
  if (!$data) {
    warn("$fn: corrupt control.tar.gz file\n");
    return ();
  }
  my $control;
  while (length($data) >= 512) {
    my $n = substr($data, 0, 100);
    $n =~ s/\0.*//s;
    my $len = oct('00'.substr($data, 124,12));
    my $blen = ($len + 1023) & ~511;
    if (length($data) < $blen) {
      warn("$fn: corrupt control.tar.gz file\n");
      return ();
    }
    if ($n eq './control') {
      $control = substr($data, 512, $len);
      last;
    }
    $data = substr($data, $blen);
  }
  my %res;
  my @control = split("\n", $control);
  while (@control) {
    my $c = shift @control;
    last if $c eq '';	# new paragraph
    my ($tag, $data) = split(':', $c, 2);
    next unless defined $data;
    $tag = uc($tag);
    while (@control && $control[0] =~ /^\s/) {
      $data .= "\n".substr(shift @control, 1);
    }
    $data =~ s/^\s+//s;
    $data =~ s/\s+$//s;
    $res{$tag} = $data;
  }
  $res{'CONTROL_MD5'} = $controlmd5;
  return %res;
}

1;

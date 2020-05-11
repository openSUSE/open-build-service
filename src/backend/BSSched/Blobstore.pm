# Copyright (c) 2018 SUSE LLC
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

package BSSched::Blobstore;

use strict;

use BSUtil;

my $paranoid = 1;

sub is_identical {
  my ($fn, $gn) = @_;
  local *F;
  local *G;
  return 0 unless open(F, '<', $fn);
  if (!open(G, '<', $gn)) {
    close(F);
    return 0;
  }
  my $df = '';
  my $dg = '';
  my $identical = 0;
  while (1) {
    my $lf = sysread(F, $df, 65536);
    my $lg = sysread(G, $dg, 65536);
    last if !defined($lf) || !defined($lg) || $lf != $lg;
    if ($lf == 0) {
      $identical = 1;
      last;
    }
    last if $df ne $dg;
  }
  close(F);
  close(G);
  return $identical
}

sub blobstore_lnk {
  my ($gctx, $f, $dir) = @_;
  my $blobdir = $gctx->{'blobdir'};
  return unless $blobdir;
  return unless $f =~ /^_blob\.sha256:([0-9a-f]{3})([0-9a-f]{61})$/s;
  my ($d, $b) = ($1, $2);
  my @s = stat("$blobdir/sha256/$d/$b");
  if (!@s) {
    mkdir_p("$blobdir/sha256/$d") unless -d "$blobdir/sha256/$d";
    return if link("$dir/$f", "$blobdir/sha256/$d/$b");
  }
  return unless link("$blobdir/sha256/$d/$b", "$blobdir/sha256/$d/$b.$$");
  # make sure the content is identical in paranoid mode
  if ($paranoid && !is_identical("$dir/$f", "$blobdir/sha256/$d/$b.$$")) {
    unlink("$blobdir/sha256/$d/$b.$$");
    return;
  }
  return if rename("$blobdir/sha256/$d/$b.$$", "$dir/$f");
  unlink("$blobdir/sha256/$d/$b.$$");
}

sub blobstore_chk {
  my ($gctx, $f) = @_;
  my $blobdir = $gctx->{'blobdir'};
  return unless $blobdir;
  return unless $f =~ /^_blob\.sha256:([0-9a-f]{3})([0-9a-f]{61})$/s;
  my @s = stat("$blobdir/sha256/$1/$2");
  unlink("$blobdir/sha256/$1/$2") if ($s[3] || 0) == 1;
}

1;

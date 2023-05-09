#
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
################################################################
#
# local registry support
#

package BSPublisher::Containerinfo;

use BSUtil;
use BSXML;

sub construct_container_tar {
  my ($containerinfo, $doopen) = @_;
  my $blobdir = $containerinfo->{'blobdir'};
  die("need a blobdir to reconstruct containers\n") unless $blobdir;
  my $manifest = $containerinfo->{'tar_manifest'};
  my $mtime = $containerinfo->{'tar_mtime'};
  my $blobids = $containerinfo->{'tar_blobids'};
  die("containerinfo is incomplete\n") unless $mtime && $manifest && $blobids;
  my @tar;
  for my $blobid (@$blobids) {
    my $file = "$blobdir/_blob.$blobid";
    if ($doopen) {
      my $fd;
      open($fd, '<', $file) || die("$file: $!\n");
      $file = $fd;
    }
    die("missing blobid $blobid\n") unless -e $file;
    push @tar, {'name' => $blobid, 'file' => $file, 'mtime' => $mtime, 'offset' => 0, 'size' => (-s _), 'blobid' => $blobid};
  }
  push @tar, {'name' => 'manifest.json', 'data' => $manifest, 'mtime' => $mtime, 'size' => length($manifest)};
  return (\@tar, $mtime, $containerinfo->{'layer_compression'});
}

sub nevra {
  my ($bin) = @_;
  my $evr = $bin->{'version'};
  $evr = "$bin->{'epoch'}:$evr" if $bin->{'epoch'};
  $evr .= "-$bin->{'release'}" if defined $bin->{'release'};
  return "$bin->{'name'}-$evr.$bin->{'binaryarch'}";
}

sub create_packagelist {
  my ($containerinfo) = @_;
  my @bins;
  my %basepackages;
  return undef unless $containerinfo->{'container_packages'};
  my $bf;
  my %summaries;
  # read .report file to get package summary information
  if ($containerinfo->{'container_report'}) {
    my $report = readxml($containerinfo->{'container_report'}, $BSXML::report, 1) || {};
    for my $bin (@{$report->{'binary'} || []}) {
      $summaries{nevra($bin)} = $bin->{'summary'} if $bin->{'summary'};
    }
  }
  if ($containerinfo->{'container_basepackages'} && open($bf, '<', $containerinfo->{'container_basepackages'})) {
    while(<$bf>) {
      chomp;
      my @s = split(/\|/, $_);
      $basepackages{"$s[0]|$s[1]|$s[2]|$s[3]|$s[4]|$s[5]"} = 1;
    }
    close($bf);
  }
  my $f;
  return undef unless open($f, '<', $containerinfo->{'container_packages'});
  while(<$f>) {
    chomp;
    my @s = split(/\|/, $_);
    next if @s < 6;
    next if $s[0] eq 'gpg-pubkey';
    my $bin = {
      'name' => $s[0],
      'version' => $s[2],
      'release' => $s[3],
      'binaryarch' => $s[4],
    };
    $bin->{'disturl'} = $s[5] if $s[5] ne '(none)' && $s[5] ne 'None';
    $bin->{'license'} = $s[6] if $s[6];
    $bin->{'epoch'} = $s[1] if $s[1] ne '' && $s[1] ne '(none)' && $s[1] ne 'None';
    if ($s[1] eq 'None' && $s[3] eq 'None') {
      # debian case, split version as kiwi does not do it
      my $evr = $s[2];
      $bin->{'epoch'} = $1 if $evr =~ s/^(\d+)://;
      $bin->{'version'} = $evr;
      $bin->{'release'} = '0';
      if ($evr =~ /^(.+)-([^-]+)$/) {
	$bin->{'version'} = $1;
	$bin->{'release'} = $2;
      }
    }
    $bin->{'base'} = 1 if $basepackages{"$s[0]|$s[1]|$s[2]|$s[3]|$s[4]|$s[5]"};
    if (%summaries) {
      my $summary = $summaries{nevra($bin)};
      $bin->{'summary'} = $summary if $summary;
    }
    push @bins, $bin;
  }
  close($f);
  return \@bins;
}

1;

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

sub create_packagelist {
  my ($containerinfo) = @_;
  my @bins;
  my %basepackages;
  return undef unless $containerinfo->{'container_packages'};
  my $bf;
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
    push @bins, $bin;
  }
  close($f);
  return \@bins;
}

1;

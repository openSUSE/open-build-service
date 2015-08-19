#
#
# Copyright (c) 2008 Marcus Huewe
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
# The Download on Demand Metadata Parser for deb md files ("Packages" files)
#

package Meta::Debmd;
use strict;
use warnings;
use Data::Dumper;

my %tagmap = (
  'Package' => 'name',
  'Version' => 'version',
  'Provides' => 'provides',
  'Depends' => 'requires',
  'Pre-Depends' => 'requires',
  'Filename' => 'path',
  'Source' => 'source',
  'Architecture' => 'arch',
);

sub parse {
  my $fn = shift;

  my %packs = ();
  my $cur = {};
  open(F, '<', $fn) or die("open: $!\n");
  while (<F>) {
    chomp;
    # Empty line signifies the end of a package section
    if (/^$/) {
      $cur->{'hdrmd5'} = 0;
      my $rel = exists $cur->{'release'} ? "-$cur->{'release'}" : '';
      push @{$cur->{'provides'}}, "$cur->{'name'} = $cur->{'version'}$rel";
      $cur->{'requires'} = [] unless exists $cur->{'requires'};
      $cur->{'source'} = $cur->{'name'} unless exists $cur->{'source'};
      $packs{$cur->{'name'}} = $cur;
      $cur = {};
      next;
    }
    next unless /^(Package|Version|Provides|Depends|Pre-Depends|Filename|Source|Architecture|Size):\s(.*)/;
    my ($tag, $what) = ($1, $2);
    if ($tag =~ /^[\w-]*Depends|Provides/) {
      my @m = $what =~ /([^\s,]+)(\s[^,]*)?[\s,]*/g;
      my @l = ();
      while (@m) {
        my ($pack, $vers) = splice(@m, 0, 2);
        $pack .= $vers if defined $vers;
        push @l, $pack;
      }
      # stolen from the Build/Deb.pm
      s/\(([^\)]*)\)/$1/g for @l;
      s/<</</g for @l;
      s/>>/>/g for @l;

      push @{$cur->{$tagmap{$tag}}}, @l;
      next;
    }
    if ($tag eq 'Size') {
      $cur->{'id'} = "-1/$what/-1";
      next;
    }
    $cur->{$tagmap{$tag}} = $what;
    if ($tag eq 'Version') {
      # stolen from Build/Deb.pm
      if ($what =~ /^(.*)-(.*?)$/) {
        $cur->{'version'} = $1;
        $cur->{'release'} = $2;
      }
    }
  }
  close(F);
  return \%packs;
}

1;

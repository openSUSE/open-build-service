#
# Copyright (c) 2006-2012 Novell Inc.
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
# Defines what architectures we can build
#

package BSCando;

#
# the cando table mapps the host architecture to the repository architectures
# that can be built on the host.
#

#FIXME 3.0: obsolete the not exiting arm architectures

our %cando = (
  # aarch64_ilp32: is just a software architecure convention
  'aarch64' => [ 'aarch64', 'aarch64_ilp32', 'armv8l:linux32', 'armv7l:linux32', 'armv7hl:linux32', 'armv6l:linux32', 'armv6hl:linux32' ],
  'aarch64_ilp32' => [ 'aarch64_ilp32', 'aarch64' ],
  'armv4l'  => [ 'armv4l'                                                                                                 ],
  'armv5l'  => [ 'armv4l', 'armv5l'                    , 'armv5el'                                                        ],
  'armv6l'  => [ 'armv4l', 'armv5l', 'armv6l'          , 'armv5el', 'armv6el'                                             ],
  'armv7l'  => [ 'armv4l', 'armv5l', 'armv6l', 'armv7l', 'armv5el', 'armv6el', 'armv6hl', 'armv7el', 'armv7hl' ],
  'armv8l'  => [ 'armv4l', 'armv5l', 'armv6l', 'armv7l', 'armv5el', 'armv6el', 'armv6hl', 'armv7el', 'armv7hl', 'armv8el', 'armv8hl', 'armv8l' ], # armv8l & armv7l are considered to be identical on rpm level

  'sh4'     => [ 'sh4' ],

  'i586'    => [           'i586' ],
  'i686'    => [           'i586',         'i686' ],
  'x86_64'  => [ 'x86_64', 'i586:linux32', 'i686:linux32' ],

  'k1om'    => [           'k1om' ],

  'parisc'  => [ 'hppa', 'hppa64:linux64' ],
  'parisc64'=> [ 'hppa64', 'hppa:linux32' ],

  'ppc'     => [ 'ppc' ],
  'ppc64'   => [ 'ppc64le', 'ppc64', 'ppc:linux32' ],
  'ppc64p7' => [ 'ppc64le', 'ppc64p7', 'ppc:linux32' ],
  'ppc64le' => [ 'ppc64le', 'ppc64', 'ppc:linux32' ],

  'ia64'    => [ 'ia64' ],

  'loongarch64' => [ 'loongarch64' ],

  'riscv64' => [ 'riscv64' ],

  's390'    => [ 's390' ],
  's390x'   => [ 's390x', 's390:linux32' ],

  'sparc'   => [ 'sparcv8', 'sparc' ],
  'sparc64' => [ 'sparc64v', 'sparc64', 'sparcv9v', 'sparcv9', 'sparcv8:linux32', 'sparc:linux32' ],

  'mips'    => [ 'mips' ],
  'mips64'  => [ 'mips64', 'mips:mips32' ],

  'm68k'    => [ 'm68k' ],

  'local'   => [ 'local' ],
);

our %knownarch;

for my $harch (keys %cando) {
  for my $arch (@{$cando{$harch} || []}) {
    if ($arch =~ /^(.*):/) {
      $knownarch{$1}->{$harch} = $arch;
    } else {
      $knownarch{$arch}->{$harch} = $arch;
    }
  }
}

1;

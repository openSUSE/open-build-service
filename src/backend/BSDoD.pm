#
# Copyright (c) 2015 Michael Schroeder, SUSE Inc.
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
# Download on Demand parser
#

package BSDoD;

use Build::Repo;
use Build::Deb;
use Build::Rpm;

use strict;

my %compatarch = ( 
    'armv4l'  => ['arm', 'armel',                                                                                                                   'noarch'],
    'armv5l'  => ['arm', 'armel', 'armv5el', 'armv5tel', 'armv5tevl' ,                                                                              'noarch'],
    'armv6l'  => ['arm', 'armel',                                                   'armv6l', 'armv6el',                                            'noarch'],
    'armv7l'  => ['arm', 'armel',                                                                                    'armv7l', 'armv7el',           'noarch'],
    'armv5el' => ['arm', 'armel', 'armv5el', 'armv5tel', 'armv5tevl' ,                                                                              'noarch'],
    'armv6el' => ['arm', 'armel',                                                   'armv6l', 'armv6el',                                            'noarch'],
    'armv7el' => ['arm', 'armel',                                                                                    'armv7l', 'armv7el',           'noarch'],
    'armv7hl' => ['armhf', 'armv7hl', 'armv7nhl',                                 'noarch'],
    'ppc'     => ['ppc',                                                          'noarch'],
    'ppc64'   => ['ppc', 'ppc64',                                                 'noarch'],
    'sh4'     => ['sh4',                                                          'noarch'],
    'ia64'    => ['ia64',                                                         'noarch'],
    's390'    => ['s390',                                                         'noarch'],
    's390x'   => ['s390', 's390x',                                                'noarch'],
    'sparc'   => ['sparc',                                                        'noarch'],
    'sparc64' => ['sparc', 'sparc64',                                             'noarch'],
    'mips'    => ['mips',                                                         'noarch'],
    'mips64'  => ['mips', 'mips64',                                               'noarch'],
    'i586'    => [          'i386', 'i486', 'i586', 'i686',                       'noarch'],
    'i686'    => [          'i386', 'i486', 'i586', 'i686',                       'noarch'],
    'x86_64'  => ['x86_64',                                                       'noarch'],
);

sub cmppkg {
  my ($op, $p) = @_;
  # reconstruct evr
  my $evr = $p->{'epoch'} ? "$p->{'epoch'}:$p->{'version'}" : $p->{'version'};
  $evr .= "-$p->{'release'}" if defined $p->{'release'};
  my $oevr = $op->{'epoch'} ? "$op->{'epoch'}:$op->{'version'}" : $op->{'version'};
  $oevr .= "-$op->{'release'}" if defined $op->{'release'};
  if ($p->{'path'} =~ /\.deb$/) {
    return Build::Deb::verscmp($oevr, $evr);
  } else {
    return Build::Rpm::verscmp($oevr, $evr);
  }
}

sub addpkg {
  my ($cache, $p, $archfilter) = @_;

  return unless $p->{'location'} && $p->{'name'} && $p->{'arch'};
  return if $archfilter && !$archfilter->{$p->{'arch'}};
  $p->{'path'} = delete $p->{'location'};
  my $key = "$p->{'name'}.$p->{'arch'}";
  return if $cache->{$key} && cmppkg($cache->{$key}, $p) > 0;	# highest version only
  $cache->{$key} = $p;
}

sub gencookie {
  my ($doddata, $dir) = @_;
  my @s = stat("$dir/$doddata->{'metafile'}");
  return undef unless @s;
  return "1/$s[9]/$s[7]/$s[1]";
}

sub parse {
  my ($doddata, $dir, $arch) = @_;
  my $mtype = $doddata->{'mtype'} || 'mtype not set';
  $mtype = 'deb' if $mtype eq 'debmd';
  $mtype = 'susetags' if $mtype eq 'susetagsmd';
  my $archfilter;
  if ($mtype eq 'rpmmd' || $mtype eq 'susetags') {
    # do arch filtering for rpmmd/susetags hybrid repos
    $arch ||= 'noarch';
    $archfilter = { map { $_ => 1} @{$compatarch{$arch} || [ $arch, 'noarch' ] } };
  }
  my $cache = {};
  my $cookie = gencookie($doddata, $dir);
  return "$doddata->{'metafile'}: $!" unless $cookie;
  eval {
    Build::Repo::parse($mtype, "$dir/$doddata->{'metafile'}", sub { addpkg($cache, $_[0], $archfilter) }, 'addselfprovides' => 1, 'normalizedeps' => 1, 'withchecksum' => 1);
  };
  if ($@) {
    my $error = $@;
    chomp $error;
    return $error;
  }
  for (values %$cache) {
    $_->{'id'} = 'dod';
    $_->{'hdrmd5'} = 'd0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0';
  }    
  $cache->{'/url'} = $doddata->{'baseurl'};
  $cache->{'/dodcookie'} = $cookie;
  return $cache;
}

sub checkcookie {
  my ($doddata, $dir, $dodcookie) = @_;
  return 0 unless $dodcookie;
  my $cookie = gencookie($doddata, $dir);
  return 0 unless $cookie;
  return $dodcookie eq $cookie ? 1 : 0;
}

1;

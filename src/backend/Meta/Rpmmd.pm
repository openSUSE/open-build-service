#
#
# Copyright (c) 2008 Marcus Huewe
# Copyright (c) 2008 Martin Mohring
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
# The Download on Demand Metadata Parser for rpm md files ("primary.xml" files)
#

package Meta::Rpmmd;
use strict;
use warnings;
use XML::Parser;

sub parse {
  my ($fn, $opts) = @_;
  my $h = rpmmdhandler->new(@{$opts->{'arch'}});
  my $p = XML::Parser->new(Handlers => {
                            Start => sub { return $h->start_handler(@_); },
                            End => sub { return $h->end_handler(@_); },
                            Char => sub { return $h->char_handler(@_); },
                           }, ErrorContext => 2);
  eval {
    $p->parsefile($fn);
  };
  die("parse: $@") if $@;
  return $h->getrepodata();
}

1;

package rpmmdhandler;
use strict;
use warnings;
use Data::Dumper;

sub new {
  my ($class, @arch) = @_;
  my $self = {};
  $self->{'repodata'} = {};
  $self->{'pack'} = {};
  $self->{'arch'} = [ @arch ]; # XXX: are there cases where we want to mix i586 and i686?
  $self->{'reqprov'} = ();
  $self->{'curchar'} = '';
  $self->{'attrs'} = [ qw(version location rpm:entry size) ];
  $self->{'chars'} = [ qw(name arch rpm:sourcerpm) ];
  return bless($self, $class);
}

sub addversrel {
  my ($self, $attrs) = @_;
  $self->{'pack'}->{'version'} = $attrs->{'ver'};
  $self->{'pack'}->{'release'} = $attrs->{'rel'};
  $self->{'pack'}->{'epoch'} = $attrs->{'epoch'} if exists $attrs->{'epoch'} && $attrs->{'epoch'} != 0;
}

sub addreqprov {
  my ($self, $attrs) = @_;
  my %flags = ( 'EQ' => '=', 'LE' => '<=', 'GE' => '>=', 'LT' => '<', 'GT' => '>' );
  my $name = $attrs->{'name'};
  unless ($name =~ /^(rpmlib\(|\/)/) {
    $name .= exists $attrs->{'flags'} ? " $flags{$attrs->{'flags'}} " : "";
    $name .= exists $attrs->{'epoch'} && $attrs->{'epoch'} != 0 ? "$attrs->{'epoch'}:" : "";
    $name .= exists $attrs->{'ver'} ? $attrs->{'ver'} : "";
    $name .= exists $attrs->{'rel'} ? "-$attrs->{'rel'}" : "";
    push @{$self->{'reqprov'}}, $name;
  }
}

sub addlocation {
  my ($self, $attrs) = @_;
  $self->{'pack'}->{'path'} = $attrs->{'href'};
}

sub addsize {
  my ($self, $attrs) = @_;
  $self->{'pack'}->{'id'} = "-1/$attrs->{'package'}/-1"; # XXX: the <time /> tag provides time etc. but do we really need it?
}

sub getrepodata {
  my ($self) = @_;
  return $self->{'repodata'};
}

# XML::Parser handlers

sub start_handler {
  my ($self, $e, $name, %attrs) = @_;
  $self->{'pack'}->{'hdrmd5'} = "0" if $name eq 'package';
  return unless grep { $name eq $_ } @{$self->{'attrs'}};
  $self->addversrel(\%attrs) if $name eq 'version';
  $self->addreqprov(\%attrs) if $name eq 'rpm:entry';
  $self->addlocation(\%attrs) if $name eq 'location';
  $self->addsize(\%attrs) if $name eq 'size';
}

sub end_handler {
    my %cando = (
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
  my ($self, $e, $name) = @_;
  if (grep { $name eq $_ } @{$self->{'chars'}}) {
    $name = 'source' if $name eq 'rpm:sourcerpm';
    $self->{'pack'}->{$name} = $self->{'curchar'};
    $self->{'curchar'} = '';
  }
  if ($name =~ /rpm:(provides|requires)/) {
    $name =~ s/rpm://;
    $self->{'pack'}->{$name} = $self->{'reqprov'};
    $self->{'reqprov'} = ();
  } elsif ($name =~ /rpm:(obsoletes|supplements|conflicts|recommends|suggests|enhances)/) {
    $self->{'reqprov'} = ();
  }
  $self->{'repodata'}->{$self->{'pack'}->{'name'}} = $self->{'pack'} if $name eq 'package' && grep { $self->{'pack'}->{'arch'} eq $_ } @{$self->{'arch'}}, @{$cando{@{$self->{'arch'}}[0]}};
  $self->{'pack'} = {} if $name eq 'package';
}

sub char_handler {
  my ($self, $e, $text) = @_;
  return unless grep { $e->{'Context'}[-1] eq $_ } @{$self->{'chars'}};
  my $tag = $e->{'Context'}[-1];
  if ($tag eq 'rpm:sourcerpm') {
    $tag = 'source';
    # stolen from Build/Rpm.pm
    $text =~ s/-[^-]*-[^-]*\.[^\.]*\.rpm//;
  }
  $self->{'curchar'} .= $text;
}

1;

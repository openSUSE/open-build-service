package Meta::Susetagsmd;
use strict;
use warnings;
use Build::Susetags;

sub parse {
  my ($fn, $opts) = @_;

  my %cando = (
	'armv4l'  => ['arm', 'armel',                                   'noarch'],
	'armv5l'  => ['arm', 'armel', 'armv5el',                        'noarch'],
	'armv7l'  => ['arm', 'armel', 'armv5el', 'armv7el',             'noarch'],
	'armv5el' => ['arm', 'armel', 'armv5el',                        'noarch'],
	'armv7el' => ['arm', 'armel', 'armv5el', 'armv7el',             'noarch'],
	'armv7hl' => ['armhf', 'armv7hl', 'armv7nhl',                   'noarch'],
	'ppc'     => ['ppc',                                            'noarch'],
	'ppc64'   => ['ppc', 'ppc64',                                   'noarch'],
	'sh4'     => ['sh4',                                            'noarch'],
	'ia64'    => ['ia64',                                           'noarch'],
	's390'    => ['s390',                                           'noarch'],
	's390x'   => ['s390', 's390x',                                  'noarch'],
	'sparc'   => ['sparc',                                          'noarch'],
	'sparc64' => ['sparc', 'sparc64',                               'noarch'],
	'mips'    => ['mips',                                           'noarch'],
	'mips64'  => ['mips', 'mips64',                                 'noarch'],
	'i586'    => [          'i386', 'i486', 'i586',                 'noarch'],
	'i686'    => [          'i386', 'i486', 'i586', 'i686',         'noarch'],
	'x86_64'  => ['x86_64',                                         'noarch'],
	);
  my %tags = ( 'Prv' => 'provides', 'Req' => 'requires',
               'Loc' => 'path', 'Src' => 'source' );
  my $pkgs = Build::Susetags::parse($fn, \%tags, undef, @{$cando{$opts->{'arch'}->[0]}});
  my $tmp = {};
  while (my ($k, $p) = each(%$pkgs)) {
    delete $pkgs->{$k};
    $tmp->{$p->{'name'}} = $p;
    $p->{'provides'} = [ grep { !/(rpmlib\(|\/)/ } @{$p->{'provides'}} ];
    $p->{'requires'} = [ grep { !/(rpmlib\(|\/)/ } @{$p->{'requires'}} ];
    $p->{'source'} =~ s/\s.*//;
    $p->{'path'} = $p->{'arch'} . '/' . [ split(' ', $p->{'path'}) ]->[1];
    $p->{'hdrmd5'} = 0;
    $p->{'id'} = '-1/-1/-1';
  }
  return $tmp;
}

1;

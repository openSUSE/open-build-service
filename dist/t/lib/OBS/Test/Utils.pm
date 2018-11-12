package OBS::Test::Utils;
use strict;
use warnings;

sub get_package_version {
  my ($pkg, $num) = @_;
  my @pkg_ver = `rpm -q --qf '%{version}' $pkg`;
  my $raw_ver = $pkg_ver[0];
  chomp $raw_ver;
  $raw_ver =~ s/^([\d\.]*).*/$1/;
  my @ver_raw = split(/\./, $raw_ver);
  my @ver = splice(@ver_raw, 0, $num);
  return join('.',@ver);
}

1;

package OBS::Test::Utils;
use strict;
use warnings;

sub get_package_version {
  my ($pkg, $num) = @_;
  my @pkg_ver = `rpm -q --qf '%{version}' $pkg`;
  my @ver_raw = split(/\./,$pkg_ver[0]);
  my @ver = splice(@ver_raw, 0, $num);
  return join('.',@ver);
}

1;

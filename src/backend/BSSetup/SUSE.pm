package BSSetup::SUSE;

use base 'BSSetup::Base';

sub install_pkg {
  my ($self, @pkgs) = @_;

  for my $pkg (@pkgs) {
     $self->print_log($DEBUG, "Checking if package $pkg is installed");
     my $rpm = `rpm -q $pkg`;
     if (!$? && $rpm) {
       chomp $rpm;
       $self->print_log($DEBUG, "Installed package $rpm found");
     } else {
       #local $/ = undef;
       $self->print_log($DEBUG, "Package $pkg not found. Installing...\n");
       my $cmd = "zypper -n install $pkg";
       my $out = `$cmd`;
       die "Command '$cmd' failed:\n$out" if $?;
     }
  }

  return 1
}

1;

#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 5;
use FindBin;
use File::Path qw(make_path remove_tree);
use File::Copy;
my $RCODE=0;

my $TMP_DIR="$FindBin::Bin/tmp";

# prepare TMP_DIR
remove_tree($TMP_DIR);
make_path($TMP_DIR);
chdir($TMP_DIR);

# checkout home:Admin
system("osc co home:Admin");

ok(!$?,"Checking preparation of project");

# prepare package
eval {
  chdir("home:Admin") || die "Could not change to directory 'home:Admin': $!";
  mkdir("obs-testpackage") || die "Could not create directory 'obs-testpackage':$!";
  system("osc add obs-testpackage");
  die "Could not add package 'obs-testpackage' via osc" if ($?);
  chdir("obs-testpackage") || die "Could not change to directory '".cwd()."/obs-testpackage': $!";

  my $src="$FindBin::Bin/fixtures/obs-testpackage._service";
  my $dst="./_service";
  copy($src,$dst) or die "Copy '$src' -> '$dst' failed: $!";
  system("osc ar");
  die "Could not add files to package via osc!" if ($?);
};

ok(!$@,"Checking preparation of package");

# commit package
system('osc ci -m "initial version"');
ok(!$?,"Checking initial commit of package obs-testpackage");

eval {
  # wait for package to finish build
  system("osc r -w");
  die "Error while waiting for package to finish" if ($?);
};

ok(!$@,"Finished building of package");
my @succeed;

eval {
  my @result = `osc r`;

  # count succeed
  my $succeed = 0;
  @succeed = grep { /succeeded/ } @result;
};

my $r = ok(@succeed == 2,"Checking succeed builds");
if (! $r) {
  open(F,">","$TMP_DIR/.SKIP") || die "Error while touching $TMP_DIR/.SKIP: $!";
  close(F);
}

exit 0

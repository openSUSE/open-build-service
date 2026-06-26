use strict;
use warnings;

use Test::More tests => 50;
use FindBin;

use lib "$FindBin::Bin/lib/";
use Test::Mock::BSConfig;

require_ok('BSUtil');

#sub enabled {
#  my ($repoid, $disen, $default, $arch) = @_;

my $result = {};
$result->{'repo:disabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:disabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:enabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:enabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:disabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:disabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:enabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:enabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:disabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:disabled'}->{'i586'} = [qw/0 1/];
$result->{'repo:enabled'}->{'x86_64'} = [qw/0 1/];
$result->{'repo:enabled'}->{'i586'} = [qw/0 1/];

my @default_repoids = qw/repo:disabled repo:enabled/;
my @default_archs   = qw/x86_64 i586/;

sub run_all_test_with_disen {
  my %opts      = @_;
  my $disen     = $opts{disen};
  my @repoids   = @{$opts{repos}};
  my @archs     = @{$opts{archs}};
  my @defaults  = qw/0 1/;
  my $tres = {};
  for my $repo (@repoids) {
    for my $arch (@archs) {
      my @tres = ();
      my $c1 = 0;
      for my $default (@defaults) {
        my $got = BSUtil::enabled($repo,$disen,$default,$arch);
        is($got,$result->{$repo}->{$arch}->[$c1],"Checking combination ( $repo / $arch / $default )");
        $c1++;
        #if ($ENV{PERL_TEST_RECORD_RESULTS}) {
        #  $result->{$repo}->{$arch} = [];
        #  push(@tres,$got);
      }
      #print '$result->{\''.$repo.'\'}->{\''.$arch."'} = [ qw/@tres/ ];\n";
    } 
  }
}


my $disen  = {
  disabled => [
    { repository => 'openSUSE:Disabled' , arch => 'x86_64'  }
  ]
};

run_all_test_with_disen(disen=>$disen,repos=>\@default_repoids,archs=>\@default_archs);

$disen  = {
  disabled => [
    { repository => 'openSUSE:Disabled' , arch => 'x86_64'  },
    { arch => 'i586' }
  ]
};
run_all_test_with_disen(disen=>$disen,repos=>\@default_repoids,archs=>\@default_archs);

$disen  = {
  disabled => [
    { repository => 'openSUSE:Disabled' },
  ]
};
run_all_test_with_disen(disen=>$disen,repos=>\@default_repoids,archs=>\@default_archs);

# Test the functions of BSUtil
# some variables used during testing
my @file_arr;
my $got = ""; #result variable
my $ev1 = { 'key1' => '1', 'key2' => '2' };
my $ev2 = { 'key1' => '1', 'key2' => '2' };
my $unev = { 'key1' => '1', 'key3' => '3' };

# check if identical works correctly
ok(BSUtil::identical($ev1,$ev2) == 1, "BSUtil testing identical comparsion");
ok(BSUtil::identical($ev1,$unev) == 0, "BSUtil testing unidentical comparsion");

# creating a directory
my $testdir = "$FindBin::Bin/tmp/0004";
system('rm', '-rf', $testdir) if -e $testdir;
die if -e $testdir;
$testdir .= '/';

my $dir_is = ok(BSUtil::mkdir_p($testdir) == 1, "creating test directory");

# creating a file and push it to array for later checks
my $tmp_test_file = $testdir . 'BSUtil_touch_test';
my $file_is= ok ( eval { BSUtil::touch($tmp_test_file) },  "BSUtil::touch $tmp_test_file");
push @file_arr, 'BSUtil_touch_test';

# Test string functions (writestr, appendstr, readstr
SKIP: {
  skip "Skipping file tests. The file or directory could not be created!", 5 if $file_is == 0 || $dir_is == 0;  

  my $test_string = "Test the file and string functions";
  BSUtil::writestr($tmp_test_file,undef,$test_string);
  my $start_size = -s $tmp_test_file || 0;
  ok( $start_size > 0, "BSUtil::writestr testing");

  $got = BSUtil::readstr($tmp_test_file);
  is($got,$test_string,"BSUtil::readstr testing");

  BSUtil::appendstr($tmp_test_file,$test_string . "_2");
  ok ($start_size < -s $tmp_test_file, "BSUtil::appendstr testing");
  $got = BSUtil::readstr($tmp_test_file);
  is($got,$test_string . $test_string . "_2", "BSUtil::readstr checking content after append");

  # Test cp function if BSUtil and copy a file
  my $cp_fn = $testdir . 'BSUtil_touch_cp';
  BSUtil::cp($tmp_test_file,$cp_fn);
  ok( -e $cp_fn, "BSUtil::cp testing");
  push @file_arr, 'BSUtil_touch_cp'; #push it to array for later tests

}

SKIP: {
  skip "Skipping XML tests. The directory could not be created",3 if $dir_is == 0;

  # XML test hash
  my $xml_test = {
    xml => '<user login="foo" password="bar"/>',
    dtd => [ 'user' => 'login', 'password'],
    pstruct  => { 'login' => 'foo', 'password' => 'bar' },
  };
  my $xml_file = $testdir . 'BSUtil_xml_test';

  # Test xml write function
  BSUtil::writexml($xml_file,undef,$xml_test->{'pstruct'},$xml_test->{'dtd'});
  ok ( -s $xml_file > 0, "BSUtil::writexml writing xml test file");
  push @file_arr, 'BSUtil_xml_test'; #push it to array for later tests

  # Test reread of the xml into perl hash
  is_deeply(BSUtil::readxml($xml_file,$xml_test->{'dtd'}), $xml_test->{'pstruct'}, "BSUtil testing xml conversion to perl struct");
  my $xml = BSUtil::toxml($xml_test->{'pstruct'},$xml_test->{'dtd'});
  chomp($xml);
  my $expected_xml = $xml_test->{'xml'};
  is($xml, $expected_xml, "BSUtil testing perl struct conversion to xml");
}

SKIP: {
  skip "Skipping lock and clean tests due to prior errors",4 if $file_is == 0 || $dir_is == 0;

  # Testing file locking (Open file with lock; test; Close; test)
  local *FH;
  BSUtil::lockopen(\*FH,"<",$tmp_test_file);
  my $locker = BSUtil::lockcheck("<",$tmp_test_file);
  ok($locker == 0,"BSUtil opened $tmp_test_file with LOCK_EX flock()");
  close(FH);
  $locker = BSUtil::lockcheck("<",$tmp_test_file);
  ok($locker == 1,"closed $tmp_test_file and freed lock");

  #Test BSUtil::ls against the generated files array by prior tests
  my @ls_arr = sort(BSUtil::ls($testdir));
  @file_arr = sort(@file_arr);

  is_deeply(\@ls_arr, \@file_arr, "Checking the content of $testdir");

  #Test cleaning of directory
  BSUtil::cleandir($testdir);
  @ls_arr = BSUtil::ls($testdir);
  ok(scalar(@ls_arr) == 0, "Checking the content of $testdir after cleaning");
}

#Test utf8 detection and conversion
my $latin1 = "m\x{c7}gtig";
ok(BSUtil::checkutf8($latin1) == 0, "Checking if BSUtil spots $latin1 as non-utf8");
my $utf8_con = BSUtil::str2utf8($latin1);
ok(BSUtil::checkutf8($utf8_con) == 1, "Checking if BSUtil converts $latin1 to $utf8_con");

my $log_print = "";
my $test_log_string = "This is the test log string";
BSUtil::setdebuglevel($BSConfig::debuglevel) if $BSConfig::debuglevel;

# Test the printlog function without loglevel for backwards compatibility.
do {
  local *STDOUT;
  open STDOUT, '>', \$log_print;
  BSUtil::printlog($test_log_string);
};
like($log_print, qr/$test_log_string/, "BSUtil testing the printlog function without loglevel");

# Test the printlog function with loglevel
for(my $testcount = 0; $testcount <= ($BSConfig::debuglevel + 2); $testcount++) {
  do {
    local *STDOUT;
    open STDOUT, '>', \$log_print;
    BSUtil::printlog($test_log_string, $testcount);
  };
  if ($testcount <= $BSConfig::debuglevel) {
    like($log_print, qr/$test_log_string/, "BSUtil testing the printlog function wih level $testcount");
  } else {
    unlike ($log_print, qr/$test_log_string/, "BSutil printlog should not print level $testcount");
  }
}

exit 0;

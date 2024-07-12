use strict;
use warnings;

use Test::More tests => 4;
use FindBin;

#use Data::Dumper;
#$Data::Dumper::Sortkeys = 1;

require_ok('BSTar');

sub slurp {
  local $/;
  open(my $fd, '<', $_[0]) || die("$_[0]: $!\n");
  return scalar(<$fd>);
}

sub listtarfile {
  my ($file) = @_;
  open(my $fd, '<', $_[0]) || die("$_[0]: $!\n");
  return $fd, BSTar::list($fd);
}

my ($result, $expected);

my $tar1 = "$FindBin::Bin/data/0024/testtar.tar";

$expected = [
  { 'chksum' => 4581, 'gid' => 0, 'gname' => '', 'linkname' => '', 'magic' => 'ustar', 'major' => 0, 'minor' => 0, 'mode' => 493, 'mtime' => 1720698119, 'name' => 'testtar/', 'size' => 0, 'tartype' => '5', 'uid' => 0, 'uname' => '', 'version' => '00' },
  { 'chksum' => 5311, 'gid' => 0, 'gname' => '', 'linkname' => '', 'magic' => 'ustar', 'major' => 0, 'minor' => 0, 'mode' => 493, 'mtime' => 1720698170, 'name' => 'testtar/sub dir/', 'size' => 0, 'tartype' => '5', 'uid' => 0, 'uname' => '', 'version' => '00' },
  { 'chksum' => 5751, 'gid' => 0, 'gname' => '', 'linkname' => '', 'magic' => 'ustar', 'major' => 0, 'minor' => 0, 'mode' => 420, 'mtime' => 1720698170, 'name' => 'testtar/sub dir/test', 'offset' => 1536, 'size' => 0, 'tartype' => '0', 'uid' => 0, 'uname' => '', 'version' => '00' },
  { 'chksum' => 5137, 'gid' => 0, 'gname' => '', 'linkname' => '', 'magic' => 'ustar', 'major' => 0, 'minor' => 0, 'mode' => 420, 'mtime' => 1720698111, 'name' => 'testtar/world', 'offset' => 2048, 'size' => 6, 'tartype' => '0', 'uid' => 0, 'uname' => '', 'version' => '00' },
  { 'chksum' => 5666, 'gid' => 0, 'gname' => '', 'linkname' => 'world', 'magic' => 'ustar', 'major' => 0, 'minor' => 0, 'mode' => 511, 'mtime' => 1720698119, 'name' => 'testtar/hello', 'size' => 0, 'tartype' => '2', 'uid' => 0, 'uname' => '', 'version' => '00' }
];

my ($tarfd, $tarlist) = listtarfile($tar1);
is_deeply($tarlist, $expected, "listtar");

$expected = "hello\n";
$result = BSTar::extract($tarfd, (grep {$_->{'name'} eq 'testtar/world'} @$tarlist)[0]);
is($result, $expected, "extract testtar/world");

my $newtar = '';
BSTar::writetar(sub {$newtar .= $_[0]}, $tarlist, 'file' => $tarfd);
ok($newtar eq slurp($tar1), "tar round trip");


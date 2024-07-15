use strict;
use warnings;

use Test::More tests => 4;
use FindBin;

#use Data::Dumper;
#$Data::Dumper::Sortkeys = 1;

require_ok('BSCpio');

sub slurp {
  local $/;
  open(my $fd, '<', $_[0]) || die("$_[0]: $!\n");
  return scalar(<$fd>);
}

sub listcpiofile {
  my ($file) = @_;
  open(my $fd, '<', $_[0]) || die("$_[0]: $!\n");
  return $fd, BSCpio::list($fd);
}

my ($result, $expected);

my $cpiofile1 = "$FindBin::Bin/data/0025/test.cpio";

$expected = [
  { 'cpiotype' => 4,  'mode' => 16877, 'mtime' => 1720698119, 'name' => 'test', 'namesize' => 5, 'size' => 0 },
  { 'cpiotype' => 4,  'mode' => 16877, 'mtime' => 1720698170, 'name' => 'test/sub dir', 'namesize' => 13, 'size' => 0 },
  { 'cpiotype' => 8,  'mode' => 33188, 'mtime' => 1720698170, 'name' => 'test/sub dir/test', 'namesize' => 18, 'offset' => 368, 'size' => 0 },
  { 'cpiotype' => 8,  'mode' => 33188, 'mtime' => 1720698111, 'name' => 'test/world', 'namesize' => 11, 'offset' => 492, 'size' => 6 },
  { 'cpiotype' => 10, 'mode' => 41471, 'mtime' => 1720698119, 'name' => 'test/hello', 'namesize' => 11, 'offset' => 624, 'size' => 5 }
];

my ($fd, $list) = listcpiofile($cpiofile1);
is_deeply($list, $expected, "listcpio");

$expected = "hello\n";
$result = BSCpio::extract($fd, (grep {$_->{'name'} eq 'test/world'} @$list)[0]);
is($result, $expected, "extract test/world");

my $newcpio = '';
BSCpio::writecpio(sub {$newcpio .= $_[0]}, $list, 'file' => $fd);
ok($newcpio eq slurp($cpiofile1), "cpio round trip");

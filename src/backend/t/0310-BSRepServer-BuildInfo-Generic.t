use strict;
use warnings;

use Test::More tests => 2;                      # last test to print

use BSRPC;
use BSUtil;
use BSXML;
use Data::Dumper;

no warnings;

$INC{'BSConfig.pm'} = 'BSConfig.pm';
$BSConfig::bsdir = 'testdata/buildinfo';
$BSConfig::srcserver = 'srcserver';
$BSConfig::repodownload = 'http://download.opensuse.org/repositories';

*BSRPC::rpc = sub {
  my ($param, $xmlargs, @args) = @_;
  $param = {'uri' => $param} if ref($param) ne 'HASH';
  my $uri = $param->{'uri'};
  for (@args) {
    $_ = BSRPC::urlencode($_);
    s/%3D/=/;
  }
  $uri = "$uri?" . join('&', @args);
  $uri =~ s/\//_/g;
  $uri =~ s/_/\//;
  $uri = "testdata/buildinfo/$uri";
  die("missing fixture: $uri\n") unless -e $uri;
  if ($xmlargs) {
    return BSUtil::readxml($uri, $xmlargs);
  } else {
    return BSUtil::readstr($uri, $xmlargs);
  }
};
use warnings;

use_ok("BSRepServer::BuildInfo");

my ($bi) = BSRepServer::BuildInfo->new(projid=>'openSUSE:13.2', repoid=>'standard', arch=>'i586', packid=>'screen')->getbuildinfo();
my $xbi = BSUtil::readxml("testdata/buildinfo/result/buildinfo_13_2_screen", $BSXML::buildinfo);

$bi->{'bdep'}  = [ sort {$a->{'name'} cmp $b->{'name'}} @{$bi->{'bdep'} || []} ];
$xbi->{'bdep'} = [ sort {$a->{'name'} cmp $b->{'name'}} @{$xbi->{'bdep'} || []} ];

is_deeply($bi, $xbi, 'buildinfo for screen');


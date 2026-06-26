#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 5;
use Sys::Hostname;
use Data::Dumper;
use FindBin;

BEGIN {
  unshift @INC, "/usr/lib/obs/server/";
}

use XML::Structured;


my $oscrc  = "$ENV{HOME}/.oscrc";
my $apiurl = "https://" . (hostname()||'localhost');

if ( -f $oscrc ) {
  open(F, '<', $oscrc) || die "Could not open $oscrc: $!";
  while (<F>) {
    $apiurl = $1 if (/^\s*apiurl\s*=\s*(.*)$/);
  }
  close F;
} else {
  open(F, '>', $oscrc) || die "Could not open $oscrc: $!";
  print F "
[general]
apiurl = $apiurl
[$apiurl]
user = Admin
pass = opensuse
";
  close F;
}

my $out;

$out = `osc api about`;

my $dtd = [
  about    => 
    "title",
    "revision",
    "description",
    "last_deployment",
    "commit",
  ,
];

my $xml;
eval {
  $xml = XMLin($dtd, $out);
  $out = `rpm -q --qf %{version} obs-server`;
};

is($@, '', 'Checking for xml converting error');

ok($out eq $xml->{revision}, "Checking api about version") || print $?;

$out = `osc -A $apiurl ls 2>&1|grep 401`;
is($out, "", "Checking authorization for osc");

$out = `curl -ik $apiurl/apidocs/index 2>/dev/null |grep "200 OK"`;
ok($out, "Checking for $apiurl/apidocs/index");

$out = `curl -I $apiurl 2>/dev/null|head -1|grep -w "200 OK"`;
is($out, "HTTP/1.1 200 OK\r\n", "Checking $apiurl for http status code 200");

exit 0;

#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 5;


use FindBin;
use lib "$FindBin::Bin/lib/";

use BSUtil;
use Test::Mock::BSConfig;
use Test::Mock::BSRPC;


@::ARGV = ('--testcase');
require_ok('./bs_worker');

$BSConfig::bsdir = $FindBin::Bin;
my $tmpdir = "$FindBin::Bin/tmp/1000";
mkdir($tmpdir);

my $buildinfo = {
  srcserver  => $BSConfig::srcserver,
  project    => 'project1',
  package    => 'package1',
  srcmd5     => 'f157738ddea737a2b7479996175a6cec',
  verifymd5  => 'f157738ddea737a2b7479996175a6cec',
  bdep       => [
                  {
                    'notmeta' => '1',
                    'name' => 'liblua5_4-5',
                    'preinstall' => '1'
                  },
                  {
                    'name' => 'aaa_base',
                    'notmeta' => '1',
                    'preinstall' => '1'
                  },
                  {
                    'preinstall' => '1',
                    'name' => 'filesystem',
                    'notmeta' => '1'
                  },
                ],
  path       => [
                  {
                    'server' => 'http://reposerver',
                    'repository' => 'openSUSE_Tumbleweed',
                    'project' => 'home:Admin'
                  },
                  {
                    'project' => 'openSUSE.org:openSUSE:Factory',
                    'server' => 'http://srcserver',
                    'repository' => 'snapshot'
                  },
                  {
                    'project' => 'openSUSE.org:openSUSE:Tumbleweed',
                    'server' => 'http://srcserver',
                    'repository' => 'standard'
                  },
                  {
                    'repository' => 'dod',
                    'server' => 'http://srcserver',
                    'project' => 'openSUSE.org:openSUSE:Tumbleweed'
                  },
                  {
                    'repository' => 'ports',
                    'server' => 'http://srcserver',
                    'project' => 'openSUSE.org:openSUSE:Factory'
                  }
                ],
  arch       => 'x86_64',
};

$Test::Mock::BSRPC::fixtures_map = {
  # getsources
  "srcserver/getsources?project=project1&package=package1&srcmd5=$buildinfo->{srcmd5}"
    => 'data/1000/srcserver/getsources',

  # getbinaries
  'reposerver/getbinaries?project=home:Admin&repository=openSUSE_Tumbleweed&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/reposerver/getbinaries_empty.cpio',
  'srcserver/getbinaries?project=openSUSE.org:openSUSE:Factory&repository=snapshot&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/srcserver/getbinaries_empty.cpio',
  'srcserver/getbinaries?project=openSUSE.org:openSUSE:Tumbleweed&repository=standard&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/srcserver/getbinaries_empty.cpio',
  'srcserver/getbinaries?project=openSUSE.org:openSUSE:Tumbleweed&repository=dod&arch=x86_64&binaries=liblua5_4-5,aaa_base,filesystem'
    => 'data/1000/srcserver/getbinaries.cpio',
};

my (@got, @expected);


# getsources

@got = getsources($buildinfo, $tmpdir);
@expected = ('f157738ddea737a2b7479996175a6cec  package1');
is_deeply(\@got, \@expected, 'getsources - Return value');

my $expected = [
                 {
                   'digest' => {
                     'sha256' => 'e237d5c5ea2b4dd327d2e103afd09572286609fbc9bf43cc9609f1371b4c8dd2'
                   },
                   'uri' => 'srcserver/source/project1/package1/hello_world.spec?rev=f157738ddea737a2b7479996175a6cec'
                 }
               ];
is_deeply($buildinfo->{'materials'}, $expected, "getsources - Add 'materials' of sources to \$buildinfo");


# getbinaries

my ($dir, $srcdir, $preinstallimagedata, $origins) = (
  "$tmpdir/var/cache/obs/worker/root_1/.pkgs",
  "$tmpdir/var/cache/obs/worker/root_1/.build-srcdir",
  undef,
  undef
);

@got = getbinaries($buildinfo, $dir, $srcdir, $preinstallimagedata, $origins);
@expected = ();
is_deeply(\@got, \@expected, 'getbinaries - Return value');

$expected = [
              {
                'digest' => {
                  'sha256' => 'e237d5c5ea2b4dd327d2e103afd09572286609fbc9bf43cc9609f1371b4c8dd2'
                },
                'uri' => 'srcserver/source/project1/package1/hello_world.spec?rev=f157738ddea737a2b7479996175a6cec'
              },
              {
                'digest' => {
                  'sha256' => 'acf63da2befc85cee24689330ddf62629681e59b5007fa3ffca09ff789f7cb28'
                },
                'uri' => 'http://srcserver/build/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/_repository/aaa_base.rpm'
              },
              {
                'digest' => {
                  'sha256' => 'be546d31264bf3ea084cd6c0bb659872eef0388583983379a72edfb26f021680'
                },
                'uri' => 'http://srcserver/build/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/_repository/filesystem.rpm'
              },
              {
                'digest' => {
                  'sha256' => '80c185cd2f7d2cc9960308a9ce07d97b20c098d7a71008ba7d74dfd1031cfe26'
                },
                'uri' => 'http://srcserver/build/openSUSE.org:openSUSE:Tumbleweed/dod/x86_64/_repository/liblua5_4-5.rpm'
              }
            ];
is_deeply($buildinfo->{'materials'}, $expected, "getbinaries- Add 'materials' of binaries to \$buildinfo");

BSUtil::cleandir($tmpdir);
rmdir($tmpdir);

# Copyright (c) 2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#

package BSRepServer::Registry;

use JSON::XS ();

use BSTUF;
use BSUtil;
use BSConfiguration;

use strict;

my $uploaddir = "$BSConfig::bsdir/upload";

sub select_manifest {
  my ($mani, $goarch, $goos) = @_;
  for my $m (@{$mani->{'manifests'} || []}) {
    return $m->{'digest'} if $m->{'platform'} && $m->{'platform'}->{'architecture'} eq $goarch && $m->{'platform'}->{'os'} eq $goos;
  }
  return undef;
}

sub extend_timestamp {
  my ($repodir, $tuf, $expires) = @_;

  my $data = $tuf->{'timestamp'};
  my $timestamp = JSON::XS::decode_json($data);
  mkdir_p($uploaddir);
  unlink("$uploaddir/timestampkey.$$");
  writestr("$uploaddir/timestampkey.$$", undef, $tuf->{'timestamp_privkey'});
  my @signcmd;
  push @signcmd, $BSConfig::sign;
  push @signcmd, '--project', ':tmpkey' if $BSConfig::sign_project;
  push @signcmd, '-P', "$uploaddir/timestampkey.$$";
  my $signfunc = sub { BSUtil::xsystem($_[0], @signcmd, '-O', '-h', 'sha256') };
  $timestamp = BSTUF::update_expires($timestamp, $signfunc, $expires);
  unlink("$uploaddir/timestampkey.$$");
  my $fd;
  BSUtil::lockopen($fd, '<', "$repodir/:tuf");
  $tuf = BSUtil::retrieve("$repodir/:tuf", 1);
  if ($tuf && $tuf->{'timestamp'} && $tuf->{'timestamp'} eq $data) {
    # ok to update
    $tuf->{'timestamp'} = $timestamp;
    $tuf->{'timestamp_expires'} = $expires;
    BSUtil::store("$repodir/.tuf.$$", "$repodir/:tuf", $tuf);
  }
  close($fd);
  return $tuf;
}

1;

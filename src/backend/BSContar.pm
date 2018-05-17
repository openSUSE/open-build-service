#
# Copyright (c) 2018 SUSE Inc.
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
################################################################
#
# Container tar file management
#

package BSContar;

use JSON::XS ();
use Digest::SHA ();
use Digest::MD5 ();
use Compress::Zlib ();

use BSUtil;
use BSTar;

use strict;

sub checksum_entry {
  my ($ent, $ctx) = @_;
  my $offset = 0;
  while (1) {
    my $chunk = BSTar::extract($ent->{'handle'}, $ent, $offset, 65536);
    last unless length($chunk);
    $ctx->add($chunk);
    $offset += length($chunk);
  }
}

sub compress_entry {
  my ($ent) = @_;

  my ($tmp, $tmp2);
  open($tmp, '+>', undef) || die;
  open($tmp2, "+>&", $tmp) || die;      # gzclose closes the file, grr...
  my $gz = Compress::Zlib::gzopen($tmp2, 'w') ;
  my $offset = 0;
  while (1) {
    my $chunk = BSTar::extract($ent->{'handle'}, $ent, $offset, 65536);
    last unless length($chunk);
    $gz->gzwrite($chunk) || die("gzwrite failed\n");
    $offset += length($chunk);
  }
  $gz->gzclose() && die("gzclose failed\n");
  my $compsize = -s $tmp;
  return { %$ent, 'offset' => 0, 'size' => $compsize, 'handle' => $tmp };
}

sub blobid_entry {
  my ($ent) = @_;
  my $ctx = Digest::SHA->new(256);
  checksum_entry($ent, $ctx);
  return "sha256:".$ctx->hexdigest();
}

sub write_entry {
  my ($ent, $fn) = @_;
  local *F;
  open(F, '>', $fn) || die("$fn: $!\n");
  my $offset = 0;
  while (1) {
    my $chunk = BSTar::extract($ent->{'handle'}, $ent, $offset, 65536);
    last unless length($chunk);
    print F $chunk or die("write: $!\n");
    $offset += length($chunk);
  }
  close(F) || die("close: $!\n");
}

sub detect_entry_compression {
  my ($ent) = @_;
  my $head = BSTar::extract($ent->{'handle'}, $ent, 0, 6);
  my $comp = '';
  if (substr($head, 0, 3) eq "\x42\x5a\x68") {
    $comp = 'bzip2';
  } elsif (substr($head, 0, 3) eq "\x1f\x8b\x08") {
    $comp = 'gzip';
  } elsif (substr($head, 0, 6) eq "\xfd\x37\x7a\x58\x5a\x00") {
    $comp = 'xz';
  }
  return $comp;
}

sub get_manifest {
  my ($tar) = @_;
  my $manifest_ent = $tar->{'manifest.json'};
  die("no manifest.json file found\n") unless $manifest_ent;
  my $manifest_json = BSTar::extract($manifest_ent->{'handle'}, $manifest_ent);
  my $manifest = JSON::XS::decode_json($manifest_json);
  die("tar contains no image\n") unless @{$manifest || []};
  die("tar contains more than one image\n") unless @$manifest == 1;
  $manifest = $manifest->[0];
  return ($manifest_ent, $manifest);
}

sub get_config {
  my ($tar, $manifest) = @_;
  my $config_file = $manifest->{'Config'};
  die("manifest has no Config\n") unless defined $config_file;
  my $config_ent = $tar->{$config_file};
  die("File $config_file not included in tar\n") unless $config_ent;
  my $config_json = BSTar::extract($config_ent->{'handle'}, $config_ent);
  my $config = JSON::XS::decode_json($config_json);
  return ($config_ent, $config);
}

sub create_manifest_entry {
  my ($manifest, $mtime) = @_;
  my %newmanifest = %$manifest;
  $newmanifest{'XXXLayers'} = delete $newmanifest{'Layers'};
  my $newmanifest_json = JSON::XS->new->utf8->canonical->encode([ \%newmanifest ]);
  $newmanifest_json =~ s/(.*)XXX/$1/s;
  my $newmanifest_ent = { 'name' => 'manifest.json', 'type' => '0', 'size' => length($newmanifest_json), 'data' => $newmanifest_json, 'mtime' => $mtime };
  return $newmanifest_ent;
}

sub checksum_tar {
  my ($tar) = @_;
  my $ctx = Digest::MD5->new();
  my $size = 0;
  my $writer = sub { $size += length($_[0]); $ctx->add($_[0]) };
  BSTar::writetar($writer, $tar);
  my $md5 = $ctx->hexdigest();
  return ($md5, $size);
}

1;

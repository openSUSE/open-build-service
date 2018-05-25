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

package BSRepServer::Containertar;

use JSON::XS ();

use BSTar;
use BSContar;
use BSHTTP;
use BSServer;
use BSUtil;

use strict;

sub normalize_container {
  my ($dir, $container, $writeblobs, $deletetar) = @_;

  # sanity check
  die("must not delete container if blobs are not stored\n") if $deletetar && !$writeblobs;

  # read containerinfo
  my $containerinfo_file = $container;
  die("container does not end in .tar\n") unless $containerinfo_file =~ s/\.tar$/\.containerinfo/;
  my $containerinfo_str = readstr("$dir/$containerinfo_file");
  my $containerinfo = JSON::XS::decode_json($containerinfo_str);

  # do the normalization
  local *TAR;
  open(TAR, '<', "$dir/$container") || die("$dir/$container: $!\n");
  my ($tar, $mtime, $config) = BSContar::normalize_container(\*TAR);
  my ($md5, $sha256, $size) = BSContar::checksum_tar($tar);
 
  # split in blobs/manifest, write blob files
  my @blob_entries = @$tar;
  my $manifest_entry = pop @blob_entries;
  if ($writeblobs) {
    BSContar::write_entry($_, "$dir/_blob.$_->{'blobid'}") for @blob_entries;
  }

  # add extra data to containerinfo
  $containerinfo->{'tar_manifest'} = $manifest_entry->{'data'};
  $containerinfo->{'tar_md5sum'} = $md5;
  $containerinfo->{'tar_sha256sum'} = $sha256;
  $containerinfo->{'tar_mtime'} = $mtime;
  $containerinfo->{'tar_size'} = $size;
  $containerinfo->{'tar_blobids'} = [ map {$_->{'blobid'}} @blob_entries ];
  $containerinfo->{'goarch'} = $config->{'architecture'};
  $containerinfo->{'goos'} = $config->{'os'};
  # XXX: should add a variant for arm
  BSRepServer::Containerinfo::writecontainerinfo("$dir/.$containerinfo_file", "$dir/$containerinfo_file", $containerinfo);

  if ($deletetar) {
    unlink("$dir/$container");
  } else {
    BSTar::writetarfile("$dir/.$container", "$dir/$container", $tar, $mtime);
  }
  # update checksum
  writestr("$dir/.$container.sha256", "$dir/$container.sha256", "$sha256  $container\n") if -f "$dir/$container.sha256";
}

sub construct_container_tar {
  my ($dir, $containerinfo, $usefd) = @_;
  my $manifest = $containerinfo->{'tar_manifest'};
  my $mtime = $containerinfo->{'tar_mtime'};
  my $size = $containerinfo->{'tar_size'};
  my $blobids = $containerinfo->{'tar_blobids'};
  die("containerinfo is incomplete\n") unless $mtime && $size && $manifest && $blobids;
  my @tar;
  for my $blobid (@$blobids) {
    my ($file, $blobsize);
    if ($usefd) {
      open($file, '<', "$dir/_blob.$blobid") || die("$dir/_blob.$blobid: $!\n");
      $blobsize = -s $file;
    } else {
      $file = "$dir/_blob.$blobid";
      die("$file: $!\n") unless -f $file;
      $blobsize = -s _;
    }
    push @tar, {'name' => $blobid, 'file' => $file, 'mtime' => $mtime, 'offset' => 0, 'size' => $blobsize};
  }
  push @tar, {'name' => 'manifest.json', 'data' => $manifest, 'mtime' => $mtime, 'size' => length($manifest)};
  return (\@tar, $size, $mtime);
}

sub get_containerinfo {
  my ($container) = @_;
  my $containerinfofile = $container;
  return undef unless $containerinfofile =~ s/\.tar$/.containerinfo/;
  return undef unless -f $containerinfofile;
  my $containerinfo;
  eval {
    my $containerinfo_str = readstr($containerinfofile);
    $containerinfo = JSON::XS::decode_json($containerinfo_str);
  };
  return undef unless $containerinfo && $containerinfo->{'tar_blobids'};
  return undef unless $containerinfo->{'file'} =~ /\.tar$/;
  return $containerinfo;
}

sub reply_container {
  my ($container) = @_;
  my $containerinfo = get_containerinfo($container);
  my $dir = $container;
  $dir =~ s/[^\/]*$/./;
  my ($tar, $size) = construct_container_tar($dir, $containerinfo, 1);
  reply_tar($tar, "Content-Length: $size");
  return 1;
}

sub stat_container {
  my ($container) = @_;
  my $containerinfo = get_containerinfo($container);
  return () unless $containerinfo;
  my @s;
  $s[7] = $containerinfo->{'tar_size'};
  $s[9] = $containerinfo->{'tar_mtime'};
  $s[20] = $containerinfo->{'tar_md5sum'};
  return @s;
}

sub open_container {
  my ($container) = @_;
  my $containerinfo = get_containerinfo($container);
  return undef unless $containerinfo;
  my $dir = $container;
  $dir =~ s/[^\/]*$/./;
  my ($tar) = construct_container_tar($dir, $containerinfo, 1);
  my $fd;
  open($fd, '+>', undef) || die("tmpfile open: $!\n");
  BSTar::writetar($fd, $tar);
  seek($fd, 0, 0);
  return $fd;
}

sub add_containers {
  my %tars;
  for (sort @_) {
    $tars{$1} = 1 if /(.*)\.containerinfo$/;
    delete $tars{$1} if /(.*)\.tar(?:\.gz|\.xz)?$/;
  }
  return (@_, map {"$_.tar"} sort keys %tars);
}

# tar helpers

sub tar_sender {
  my ($param, $sock) =@_;
  my $chunked = $param->{'chunked'};
  my $writer = sub {BSHTTP::swrite($sock, $_[0], $chunked)};
  BSTar::writetar($writer, $param->{'tar'});
  return '';
}

sub reply_tar {
  my ($tar, @hdrs) = @_;
  my $chunked;
  $chunked = 1 if grep {/^transfer-encoding:\s*chunked/i} @hdrs;
  my $param = {'tar' => $tar};
  $param->{'chunked'} = 1 if $chunked;
  BSServer::reply_stream(\&tar_sender, $param, 'Content-Type: application/x-tar', @hdrs);
}

1;

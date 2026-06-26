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

use BSConfiguration;
use BSTar;
use BSContar;
use BSHTTP;
use BSServer;
use BSUtil;

use strict;

my $uploaddir = "$BSConfig::bsdir/upload";

sub normalize_container {
  my ($dir, $container, $writeblobs, $deletetar, $arch) = @_;

  # sanity check
  die("must not delete container if blobs are not stored\n") if $deletetar && !$writeblobs;

  # read containerinfo
  my $containerinfo_file = $container;
  die("container does not end in .tar\n") unless $containerinfo_file =~ s/\.tar$/\.containerinfo/;
  my $containerinfo_str = readstr("$dir/$containerinfo_file");
  my $containerinfo = JSON::XS::decode_json($containerinfo_str);

  # do the normalization
  my $recompress;
  $recompress = 1 unless -f "$dir/$container.recompressed";
  unlink("$dir/$container.recompressed");
  local *TAR;
  open(TAR, '<', "$dir/$container") || die("$dir/$container: $!\n");
  # overwrite manifest tags with tags from containerinfo
  my ($tar, $mtime, $config, $config_id, $layercomp) = BSContar::normalize_container(\*TAR, $recompress, $containerinfo->{'tags'}, $uploaddir);
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
  $containerinfo->{'imageid'} = $config_id;
  $containerinfo->{'imageid'} =~ s/^sha256://;
  $containerinfo->{'goarch'} = $config->{'architecture'};
  $containerinfo->{'goos'} = $config->{'os'};
  if (!$config->{'variant'} && $arch) {
    # fake variant by looking at the scheduler architecture
    $config->{'variant'} = "v$1" if $config->{'architecture'} eq 'arm' && $arch =~ /^armv(\d+)/;
    $config->{'variant'} = "v8" if $config->{'architecture'} eq 'arm64';
  }
  $containerinfo->{'govariant'} = $config->{'variant'} if $config->{'variant'};
  delete $containerinfo->{'layer_compression'};
  $containerinfo->{'layer_compression'} = $layercomp if $layercomp && @$layercomp;
  BSRepServer::Containerinfo::writecontainerinfo("$dir/.$containerinfo_file", "$dir/$containerinfo_file", $containerinfo);

  if ($deletetar) {
    unlink("$dir/$container");
  } else {
    BSTar::writetarfile("$dir/.$container", "$dir/$container", $tar, 'mtime' => $mtime);
  }
  # update checksum
  if (-f "$dir/$container.sha256") {
    writestr("$dir/.$container.sha256", "$dir/$container.sha256", "$sha256  $container\n");
    utime($mtime, $mtime, "$dir/$container.sha256");
  }
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
  $s[21] = $containerinfo->{'tar_sha256sum'};
  $s[22] = $containerinfo;
  return @s;
}

sub open_container {
  my ($container) = @_;
  my $containerinfo = get_containerinfo($container);
  return undef unless $containerinfo;
  my $dir = $container;
  $dir =~ s/[^\/]*$/./;
  my ($tar, undef, $mtime) = construct_container_tar($dir, $containerinfo, 1);
  my $tmpfilename = "$uploaddir/open_container.$$";
  unlink($tmpfilename);
  my $fd;
  open($fd, '+>', $tmpfilename) || die("tmpfile open: $!\n");
  unlink($tmpfilename);
  BSTar::writetar($fd, $tar);
  seek($fd, 0, 0);
  utime($mtime, $mtime, $fd) if defined $mtime;
  return $fd;
}

sub write_container {
  my ($container, $fn, $fnf, $sha256sum) = @_;
  my $containerinfo = get_containerinfo($container);
  return undef unless $containerinfo;
  return undef if $sha256sum && $containerinfo->{'tar_sha256sum'} ne $sha256sum;
  my $dir = $container;
  $dir =~ s/[^\/]*$/./;
  my ($tar, undef, $mtime) = construct_container_tar($dir, $containerinfo, 1);
  BSTar::writetarfile($fn, $fnf, $tar, 'mtime' => $mtime);
  return 1;
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
  my $writer = BSHTTP::create_writer($sock, $param->{'chunked'});
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

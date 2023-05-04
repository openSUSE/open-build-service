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
use POSIX;

use BSUtil;
use BSTar;

use strict;

our $mt_docker_manifest     = 'application/vnd.docker.distribution.manifest.v2+json';
our $mt_docker_manifestlist = 'application/vnd.docker.distribution.manifest.list.v2+json';
our $mt_oci_manifest        = 'application/vnd.oci.image.manifest.v1+json';
our $mt_oci_index           = 'application/vnd.oci.image.index.v1+json';

our $mt_docker_config       = 'application/vnd.docker.container.image.v1+json';
our $mt_docker_layer_gzip   = 'application/vnd.docker.image.rootfs.diff.tar.gzip';
our $mt_oci_config          = 'application/vnd.oci.image.config.v1+json';
our $mt_oci_layer_gzip      = 'application/vnd.oci.image.layer.v1.tar+gzip';
our $mt_oci_layer_zstd      = 'application/vnd.oci.image.layer.v1.tar+zstd';
our $mt_helm_config         = 'application/vnd.cncf.helm.config.v1+json';

sub blobid {
  return 'sha256:'.Digest::SHA::sha256_hex($_[0]);
}

sub make_blob_entry {
  my ($name, $blob, %extra) = @_;
  my $blobid = blobid($blob);
  my $ent = { %extra, 'name' => $name, 'size' => length($blob), 'data' => $blob, 'blobid' => $blobid };
  return ($ent, $blobid);
}

sub checksum_entry {
  my ($ent, $ctx) = @_;
  my $offset = 0;
  while (1) {
    my $chunk = BSTar::extract($ent->{'file'}, $ent, $offset, 65536);
    last unless length($chunk);
    $ctx->add($chunk);
    $offset += length($chunk);
  }
}

sub comp2decompressor {
  my ($comp) = @_;
  return () unless defined $comp;
  return ('gunzip') if $comp eq 'gzip';
  return ('bunzip2') if $comp eq 'gzip2';
  return ('xzdec') if $comp eq 'xz';
  return ('zstdcat') if $comp eq 'zstd';
  return ('cat') if $comp eq '';
  return ();
}

sub compress_entry {
  my ($ent, $oldcomp, $newcomp, $outfile) = @_;

  $newcomp ||= 'gzip';
  die("unsupported compression $newcomp") if $newcomp ne 'gzip';
  my @compressor = ('zlib');
  @compressor = ('/usr/bin/obs-gzip-go') if -x '/usr/bin/obs-gzip-go';

  my @decompressor;
  $oldcomp = detect_entry_compression($ent) unless defined $oldcomp;
  if ($oldcomp) {
    @decompressor = comp2decompressor($oldcomp);
    die("unknown compression $oldcomp\n") unless @decompressor;
  }

  my $tmp;
  if (!defined($outfile)) {
    open($tmp, '+>', undef) || die("tmp file open: $!\n");
  } else {
    open($tmp, '+>', $outfile) || die("$outfile: $!\n");
  }

  # setup compressor
  local *F;
  my $pid = open(F, '|-');
  die("compressor fork: $!\n") unless defined $pid;
  if (!$pid) {
    if ($compressor[0] eq 'zlib') {
      my $gz = Compress::Zlib::gzopen($tmp, 'w') ;
      while (1) {
	my $chunk;
	my $r = sysread(STDIN, $chunk, 8192);
	die("read error: $!\n") unless defined $r;
	last unless $r;
        $gz->gzwrite($chunk) || die("gzwrite failed\n");
      }
      $gz->gzclose() && die("gzclose failed\n");
      POSIX::_exit(0);
    }
    open(STDOUT, "+>&", $tmp) || die("stdin dup\n");
    exec(@compressor);
    die("$compressor[0]: $!\n");
  }

  # setup decompressor if needed
  local *G;
  my $pid2;
  if ($oldcomp) {
    $pid2 = open(G, '|-');
    die("decompressor fork: $!\n") unless defined $pid2;
    if (!$pid2) {
      close($tmp);
      open(STDOUT, "+>&F") || die("decompress stdin dup\n");
      exec(@decompressor);
      die("$decompressor[0]: $!\n");
    }
  }

  # feed data
  my $offset = 0;
  while (1) {
    my $chunk = BSTar::extract($ent->{'file'}, $ent, $offset, 65536);
    last unless length($chunk);
    if ($pid2) {
      print G $chunk or die("compress_entry write: $!\n");
    } else {
      print F $chunk or die("compress_entry write: $!\n");
    }
    $offset += length($chunk);
  }
  close(G) or die("compress_entry $decompressor[0]: $?\n") if $pid2;
  close(F) or die("compress_entry $compressor[0]: $?\n");
  my $newent = { %$ent, 'offset' => 0, 'size' => (-s $tmp), 'file' => $tmp };
  delete $newent->{'blobid'};
  return $newent;
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
    my $chunk = BSTar::extract($ent->{'file'}, $ent, $offset, 65536);
    last unless length($chunk);
    print F $chunk or die("write: $!\n");
    $offset += length($chunk);
  }
  close(F) || die("close: $!\n");
}

sub detect_entry_compression {
  my ($ent) = @_;
  my $head = BSTar::extract($ent->{'file'}, $ent, 0, 6);
  my $comp = '';
  if (substr($head, 0, 3) eq "\x42\x5a\x68") {
    $comp = 'bzip2';
  } elsif (substr($head, 0, 3) eq "\x1f\x8b\x08") {
    $comp = 'gzip';
  } elsif (substr($head, 0, 6) eq "\xfd\x37\x7a\x58\x5a\x00") {
    $comp = 'xz';
  } elsif (substr($head, 0, 4) eq "\x28\xb5\x2f\xfd") {
    $comp = 'zstd';
  }
  return $comp;
}

sub get_digest_file_from_oci_tar {
  my ($tar, $digest) = @_;
  die("bad digest in oci tar\n") unless $digest && $digest =~ /:/;
  my $file = "blobs/$digest";
  $file =~ s/:/\//;
  die("no $file found in oci tar\n") unless $tar->{$file};
  return $file;
}

sub get_distmanifest_from_oci_tar {
  my ($tar) = @_;
  my $index_ent = $tar->{'index.json'};
  die("no index.json file found\n") unless $index_ent;
  my $index_json = BSTar::extract($index_ent->{'file'}, $index_ent);
  my $index = JSON::XS::decode_json($index_json);
  die("tar contains no oci manifest\n") unless @{$index->{'manifests'} || []};
  die("tar contains more than one oci manifest\n") unless  @{$index->{'manifests'}} == 1;
  my $distmanifest_file = "blobs/$index->{'manifests'}->[0]->{'digest'}";
  $distmanifest_file =~ s/:/\//;
  my $distmanifest_ent = $tar->{$distmanifest_file};
  die("no $distmanifest_file file found\n") unless $distmanifest_ent;
  my $distmanifest_json = BSTar::extract($distmanifest_ent->{'file'}, $distmanifest_ent);
  my $distmanifest = JSON::XS::decode_json($distmanifest_json);
  die("bad distmanifest\n") unless $distmanifest->{'config'};
  return ($distmanifest_ent, $distmanifest);
}

sub get_manifest_oci_tar {
  my ($tar) = @_;
  my ($distmanifest_ent, $distmanifest) = get_distmanifest_from_oci_tar($tar);
  my $configfile = get_digest_file_from_oci_tar($tar, $distmanifest->{'config'}->{'digest'});
  my @newlayers;
  my @newlayercomp;
  for my $l (@{$distmanifest->{'layers'} || []}) {
    push @newlayers, get_digest_file_from_oci_tar($tar, $l->{'digest'});
    if (($l->{'mediaType'} || '') eq $mt_oci_layer_zstd) {
      push @newlayercomp, 'zstd';
      my $ann = $l->{'annotations'};
      if ($ann->{'io.github.containers.zstd-chunked.manifest-position'}) {
	$newlayercomp[-1] = "zstd:chunked,$ann->{'io.github.containers.zstd-chunked.manifest-position'}";
	$newlayercomp[-1] .= ",$ann->{'io.github.containers.zstd-chunked.manifest-checksum'}" if $ann->{'io.github.containers.zstd-chunked.manifest-checksum'};
      }
    } elsif (($l->{'mediaType'} || '') eq $mt_oci_layer_gzip) {
      push @newlayercomp, 'gzip';
    } else {
      push @newlayercomp, undef;
    }
  }
  my $manifest = {
    'Config' => $configfile,
    'RepoTags' => [],
    'Layers' => \@newlayers,
  };
  my $manifest_ent = create_manifest_entry($manifest);
  return ($manifest_ent, $manifest, \@newlayercomp);
}

sub get_manifest {
  my ($tar) = @_;
  my $manifest_ent = $tar->{'manifest.json'};
  return get_manifest_oci_tar($tar) if !$manifest_ent && $tar->{'index.json'} && $tar->{'oci-layout'};
  die("no manifest.json file found\n") unless $manifest_ent;
  my $manifest_json = BSTar::extract($manifest_ent->{'file'}, $manifest_ent);
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
  my $config_json = BSTar::extract($config_ent->{'file'}, $config_ent);
  $config_ent->{'blobid'} ||= blobid($config_json);		# convenience
  my $config = JSON::XS::decode_json($config_json);
  return ($config_ent, $config);
}

sub create_manifest_entry {
  my ($manifest, $mtime) = @_;
  my %newmanifest = %$manifest;
  $newmanifest{'XXXLayers'} = delete $newmanifest{'Layers'};
  my $newmanifest_json = JSON::XS->new->utf8->canonical->encode([ \%newmanifest ]);
  $newmanifest_json =~ s/(.*)XXX/$1/s;
  my $newmanifest_ent = { 'name' => 'manifest.json', 'size' => length($newmanifest_json), 'data' => $newmanifest_json };
  $newmanifest_ent->{'mtime'} = $mtime if $mtime;
  return $newmanifest_ent;
}

sub checksum_tar {
  my ($tar) = @_;
  my $md5 = Digest::MD5->new();
  my $sha256 = Digest::SHA->new(256);
  my $size = 0;
  my $writer = sub { $size += length($_[0]); $md5->add($_[0]), $sha256->add($_[0]) };
  BSTar::writetar($writer, $tar);
  $md5 = $md5->hexdigest();
  $sha256 = $sha256->hexdigest();
  return ($md5, $sha256, $size);
}

sub normalize_container {
  my ($tarfd, $recompress, $repotags, $tmpdir) = @_;
  my @tarstat = stat($tarfd);
  die("stat: $!\n") unless @tarstat;
  my $mtime = $tarstat[9];
  my $tar = BSTar::list($tarfd);
  $_->{'file'} = $tarfd for @$tar;
  my %tar = map {$_->{'name'} => $_} @$tar;
  my ($manifest_ent, $manifest, $layercomp) = get_manifest(\%tar);
  my ($config_ent, $config) = get_config(\%tar, $manifest);

  # compress blobs
  my %newblobs;
  my @newlayers;
  my @newlayercomp;
  my $newconfig = blobid_entry($config_ent);
  $newblobs{$newconfig} ||= { %$config_ent, 'name' => $newconfig };
  my $cnt = 0;
  my @layercomp = @{$layercomp || []};
  for my $layer_file (@{$manifest->{'Layers'} || []}) {
    my $layer_ent = $tar{$layer_file};
    die("File $layer_file not included in tar\n") unless $layer_ent;
    my $lcomp = shift @layercomp;
    my $comp = detect_entry_compression($layer_ent);
    if ($comp eq 'zstd' && $lcomp && ($lcomp eq 'zstd' || $lcomp =~ /^zstd:chunked,/)) {
      my $blobid = blobid_entry($layer_ent);
      $newblobs{$blobid} ||= { %$layer_ent, 'name' => $blobid };
      push @newlayers, $blobid;
      push @newlayercomp, $lcomp;
      next;
    }
    my $newcomp = 'gzip';
    if (!$comp || $comp ne $newcomp || $recompress) {
      my $outfile;
      if ($tmpdir) {
	$outfile = "$tmpdir/.compress_entry_${cnt}.$$";
	$cnt++;
	unlink($outfile);
      }
      if ($comp) {
        print "recompressing $layer_ent->{'name'}... ";
      } else {
        print "compressing $layer_ent->{'name'}... ";
      }
      $layer_ent = compress_entry($layer_ent, $comp, $newcomp, $outfile);
      print "done.\n";
      unlink($outfile) if $outfile;
    }
    my $blobid = blobid_entry($layer_ent);
    $newblobs{$blobid} ||= { %$layer_ent, 'name' => $blobid };
    push @newlayers, $blobid;
    push @newlayercomp, $newcomp;
  }

  # create new manifest
  my $newmanifest = {
    'Config' => $newconfig,
    'RepoTags' => $repotags || $manifest->{'RepoTags'},
    'Layers' => \@newlayers,
  };
  my $newmanifest_ent = create_manifest_entry($newmanifest, $mtime);

  # create new tar (annotated with the file and blobid)
  my @newtar;
  for my $blobid (sort keys %newblobs) {
    my $ent = $newblobs{$blobid};
    push @newtar, {'name' => $blobid, 'mtime' => $mtime, 'offset' => $ent->{'offset'}, 'size' => $ent->{'size'}, 'file' => $ent->{'file'}, 'blobid' => $blobid};
  }
  $newmanifest_ent->{'blobid'} = blobid_entry($newmanifest_ent);
  push @newtar, $newmanifest_ent;

  return (\@newtar, $mtime, $config, $newconfig, \@newlayercomp);
}

sub _orderhash {
  my ($h, $o) = @_;
  my $n = 0;
  my %h = %$h;
  for (@$o) {
    $h{"!!!${n}_$_"} = delete $h{$_} if exists $h{$_};
    $n++;
  }
  return \%h;
}

my $blob_order = [ qw{mediaType size digest} ];
my $distmani_order = [ qw{schemaVersion mediaType config layers} ];
my $imagemani_order = [ qw{mediaType size digest platform} ];
my $distmanilist_order = [ qw{schemaVersion mediaType manifests} ];

sub create_dist_manifest {
  my ($manifest) = @_;
  my %m = %$manifest;
  $m{'config'} = _orderhash($m{'config'}, $blob_order) if $m{'config'};
  $m{'layers'} = [ map {_orderhash($_, $blob_order)} @{$m{'layers'}} ] if $m{'layers'};
  $manifest = _orderhash(\%m, $distmani_order);
  my $json = JSON::XS->new->utf8->canonical->pretty->encode($manifest);
  $json =~ s/!!!\d_//g;
  $json =~ s/\n$//s;
  return $json;
}

sub create_dist_manifest_list {
  my ($manifest) = @_;
  my %m = %$manifest;
  $m{'manifests'} = [ map {_orderhash($_, $imagemani_order)} @{$m{'manifests'}} ] if $m{'manifests'};
  $manifest = _orderhash(\%m, $distmanilist_order);
  my $json = JSON::XS->new->utf8->canonical->pretty->encode($manifest);
  $json =~ s/!!!\d_//g;
  $json =~ s/\n$//s;
  return $json;
}

sub container_from_helm {
  my ($chartfile, $config_json, $repotags) = @_;
  my $fd;
  die("$chartfile: $!\n") unless open($fd, '<', $chartfile);
  my @s = stat($fd);
  die("stat: $!\n") unless @s;
  my $mtime = $s[9];
  # create ent for the chart
  my $chartbasename = $chartfile;
  $chartbasename =~ s/^.*\///;
  my $chart_ent = { 'name' => $chartbasename, 'offset' => 0, 'size' => $s[7], 'mtime' => $mtime, 'file' => $fd };
  my @layercomp;
  if ($chartbasename =~ /($?:\.tar\.gz|\.tgz)$/) {
    $chart_ent->{'mimetype'} = 'application/vnd.cncf.helm.chart.content.v1.tar+gzip';
    push @layercomp, 'gzip';
  } else {
    $chart_ent->{'mimetype'} = 'application/vnd.cncf.helm.chart.content.v1.tar';
    push @layercomp, '';
  }
  # create ent for the config
  my ($config_ent) = make_blob_entry('config.json', $config_json, 'mtime' => $mtime, 'mimetype' => $mt_helm_config);
  # create ent for the manifest
  my $manifest = {
    'Layers' => [ $chartbasename ],
    'Config' => 'config.json',
    'RepoTags' => $repotags || [],
  };
  my $manifest_ent = create_manifest_entry($manifest, $mtime);
  my $tar = [ $manifest_ent, $config_ent, $chart_ent ];
  return ($tar, $mtime, \@layercomp);
}

sub create_config_data {
  my ($config_ent, $oci) = @_;
  my $config_data = {
    'mediaType' => $config_ent->{'mimetype'} || ($oci ? $mt_oci_config : $mt_docker_config),
    'size' => 0 + $config_ent->{'size'},
    'digest' => $config_ent->{'blobid'} || blobid_entry($config_ent),
  };
  return $config_data;
}

sub normalize_layer {
  my ($layer_ent, $oci, $comp, $newcomp, $lcomp) = @_;
  $lcomp = $comp unless defined $lcomp;
  $comp = 'zstd' if $comp && $comp =~ /^zstd:chunked/;
  $comp = detect_entry_compression($layer_ent) unless defined $comp;
  $newcomp ||= $oci && $comp eq 'zstd' ? 'zstd' : 'gzip';
  return ($layer_ent, $lcomp) if $newcomp eq 'zstd' && $comp eq $newcomp && $lcomp && $lcomp =~ /^zstd:chunked/;
  return ($layer_ent, $comp) if $layer_ent->{'mimetype'};		# do not change the compression if the mime type is already set
  if ($comp ne $newcomp) {
    if ($comp) {
      print "recompressing $layer_ent->{'name'}... ";
    } else {
      print "compressing $layer_ent->{'name'}... ";
    }
    $layer_ent = compress_entry($layer_ent, $comp, $newcomp);
    print "done.\n";
  }
  return ($layer_ent, $newcomp);
}

sub create_layer_data {
  my ($layer_ent, $oci, $comp, $annotations) = @_;
  my $lcomp = $comp;
  $comp = 'zstd' if $comp && $comp =~ /^zstd:chunked/;
  $comp = detect_entry_compression($layer_ent) unless defined $comp;
  my $layer_data = {
    'mediaType' => $layer_ent->{'mimetype'} || ($oci ? ($comp eq 'zstd' ? $mt_oci_layer_zstd : $mt_oci_layer_gzip) : $mt_docker_layer_gzip),
    'size' => 0 + $layer_ent->{'size'},
    'digest' => $layer_ent->{'blobid'} || blobid_entry($layer_ent),
  };
  $layer_data->{'annotations'} = { %$annotations } if $annotations;
  if ($comp eq 'zstd' && $lcomp && $lcomp =~ /^zstd:chunked/) {
    my @c = split(',', $lcomp);
    $layer_data->{'annotations'}->{'io.github.containers.zstd-chunked.manifest-position'} = $c[1] if $c[1];
    $layer_data->{'annotations'}->{'io.github.containers.zstd-chunked.manifest-checksum'} = $c[2] if $c[2];
  }
  return ($layer_ent, $layer_data);
}

sub create_dist_manifest_data {
  my ($config_data, $layer_data, $oci) = @_;
  my $mediaType = $oci ? $mt_oci_manifest : $mt_docker_manifest;
  my $mani = {
    'schemaVersion' => 2,
    'mediaType' => $mediaType,
    'config' => $config_data,
    'layers' => $layer_data,
  };
  return $mani;
}

sub create_dist_manifest_list_data {
  my ($multimanifest_data, $oci) = @_;
  my $mediaType = $oci ? $mt_oci_index : $mt_docker_manifestlist;
  my $manilist = {
    'schemaVersion' => 2,
    'mediaType' => $mediaType,
    'manifests' => $multimanifest_data,
  };
  return $manilist;
}

1;

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
use Scalar::Util;
use POSIX;
use Encode;

use BSUtil;
use BSTar;

use strict;

our $mt_docker_manifest     = 'application/vnd.docker.distribution.manifest.v2+json';
our $mt_docker_manifestlist = 'application/vnd.docker.distribution.manifest.list.v2+json';
our $mt_oci_manifest        = 'application/vnd.oci.image.manifest.v1+json';
our $mt_oci_index           = 'application/vnd.oci.image.index.v1+json';

our $mt_docker_config       = 'application/vnd.docker.container.image.v1+json';
our $mt_docker_layer        = 'application/vnd.docker.image.rootfs.diff.tar';
our $mt_docker_layer_gzip   = 'application/vnd.docker.image.rootfs.diff.tar.gzip';
our $mt_oci_config          = 'application/vnd.oci.image.config.v1+json';
our $mt_oci_layer           = 'application/vnd.oci.image.layer.v1.tar';
our $mt_oci_layer_gzip      = 'application/vnd.oci.image.layer.v1.tar+gzip';
our $mt_oci_layer_zstd      = 'application/vnd.oci.image.layer.v1.tar+zstd';
our $mt_helm_config         = 'application/vnd.cncf.helm.config.v1+json';
our $mt_artifacthub_config  = 'application/vnd.cncf.artifacthub.config.v1+yaml';
our $mt_artifacthub_layer   = 'application/vnd.cncf.artifacthub.repository-metadata.layer.v1.yaml';

sub blobid {
  return 'sha256:'.Digest::SHA::sha256_hex($_[0]);
}

sub make_blob_entry {
  my ($name, $blob, %extra) = @_;
  Encode::_utf8_off($blob);
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
  } elsif (ref($outfile)) {
    $tmp = $outfile;
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
  my $newent = { %$ent, 'offset' => 0, 'size' => (-s $tmp), 'file' => $tmp, 'layer_compression' => $newcomp };
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

sub layer_annotations_from_compression {
  my ($comp, $annotations) = @_;
  if ($comp && $annotations && $comp =~ /^zstd:chunked,/) {
    my @c = split(',', $comp);
    $annotations->{'io.github.containers.zstd-chunked.manifest-position'} = $c[1] if $c[1];
    $annotations->{'io.github.containers.zstd-chunked.manifest-checksum'} = $c[2] if $c[2];
  }
}

sub layer_mimetype_from_compression {
  my ($comp, $oci) = @_;
  $comp = 'unknown' unless defined $comp;
  my $mime_type;
  if ($oci) {
    $mime_type = $mt_oci_layer_zstd if $comp eq 'zstd' || $comp =~ /^zstd:chunked/;
    $mime_type = $mt_oci_layer_gzip if $comp eq 'gzip';
    $mime_type = $mt_oci_layer if $comp eq '';
  } else {
    $mime_type = $mt_docker_layer_gzip if $comp eq 'gzip';
    $mime_type = $mt_docker_layer if $comp eq '';
  }
  die("unknown mime type for '$comp' compression\n") unless $mime_type;
  return $mime_type;
}

sub layer_compression_from_mimetype {
  my ($mime_type, $annotations) = @_;
  $mime_type ||= '';
  my $comp;
  $comp = 'zstd' if $mime_type eq $mt_oci_layer_zstd;
  $comp = 'gzip' if $mime_type eq $mt_oci_layer_gzip || $mime_type eq $mt_docker_layer_gzip;
  $comp = '' if $mime_type eq $mt_oci_layer || $mime_type eq $mt_docker_layer;
  if ($comp && $comp eq 'zstd' && $annotations && $annotations->{'io.github.containers.zstd-chunked.manifest-position'}) {
    $comp = "zstd:chunked,$annotations->{'io.github.containers.zstd-chunked.manifest-position'}";
    $comp .= ",$annotations->{'io.github.containers.zstd-chunked.manifest-checksum'}" if $annotations->{'io.github.containers.zstd-chunked.manifest-checksum'};
  }
  return $comp;
}

sub get_file_from_oci_tar {
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
  my $distmanifest_file = get_file_from_oci_tar($tar, $index->{'manifests'}->[0]->{'digest'});
  my $distmanifest_ent = $tar->{$distmanifest_file};
  my $distmanifest_json = BSTar::extract($distmanifest_ent->{'file'}, $distmanifest_ent);
  my $distmanifest = JSON::XS::decode_json($distmanifest_json);
  die("bad distmanifest\n") unless $distmanifest->{'config'};
  return ($distmanifest_ent, $distmanifest);
}

sub get_manifest_oci_tar {
  my ($tar) = @_;
  my ($distmanifest_ent, $distmanifest) = get_distmanifest_from_oci_tar($tar);
  my $configfile = get_file_from_oci_tar($tar, $distmanifest->{'config'}->{'digest'});
  my @layerfiles;
  for my $l (@{$distmanifest->{'layers'} || []}) {
    my $layerfile = get_file_from_oci_tar($tar, $l->{'digest'});
    push @layerfiles, $layerfile;
    my $comp = layer_compression_from_mimetype($l->{'mediaType'}, $l->{'annotations'});
    $tar->{$layerfile}->{'layer_compression'} = $comp;
  }
  my $manifest = create_tar_manifest_data($configfile, \@layerfiles);
  my $manifest_ent = create_tar_manifest_entry($manifest);
  return ($manifest_ent, $manifest);
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
  return ($config_ent, {}) if $config_json eq '';		# workaround for artifacthub
  my $config = JSON::XS::decode_json($config_json);
  return ($config_ent, $config);
}

sub create_tar_manifest_entry {
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

sub set_layer_compression {
  my ($tar, $layer_compression) = @_;
  my @lcomp = @{$layer_compression || []};
  return unless @lcomp;
  my %tar = map {$_->{'name'} => $_} @$tar;
  my ($manifest_ent, $manifest) = get_manifest(\%tar);
  for my $layer_file (@{$manifest->{'Layers'} || []}) {
    my $layer_ent = $tar{$layer_file};
    die("File $layer_file not included in tar\n") unless $layer_ent;
    my $lcomp = shift @lcomp;
    $layer_ent->{'layer_compression'} = $lcomp if defined $lcomp;
  }
}

sub normalize_container {
  my ($file, $recompress, $repotags, $tmpdir) = @_;
  my ($tar, $mtime) = open_container_tar($file);
  my %tar = map {$_->{'name'} => $_} @$tar;
  my ($manifest_ent, $manifest) = get_manifest(\%tar);
  my ($config_ent, $config) = get_config(\%tar, $manifest);

  # compress blobs
  my %newblobs;
  my @newlayers;
  my @newlayercomp;
  my @newblobcomp;
  my $newconfig = blobid_entry($config_ent);
  $newblobs{$newconfig} ||= { %$config_ent, 'name' => $newconfig };
  my $cnt = 0;
  for my $layer_file (@{$manifest->{'Layers'} || []}) {
    my $layer_ent = $tar{$layer_file};
    die("File $layer_file not included in tar\n") unless $layer_ent;
    my $comp = defined($layer_ent->{'layer_compression'}) ? $layer_ent->{'layer_compression'} : detect_entry_compression($layer_ent);
    if ($comp && ($comp eq 'zstd' || $comp =~ /^zstd:chunked,/)) {
      my $blobid = blobid_entry($layer_ent);
      $newblobs{$blobid} ||= { %$layer_ent, 'name' => $blobid };
      push @newlayers, $blobid;
      push @newlayercomp, $comp;
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
    $newblobs{$blobid} ||= { %$layer_ent, 'name' => $blobid, 'layer_compression' => $newcomp };
    push @newlayers, $blobid;
    push @newlayercomp, $newcomp;
  }

  # create new manifest
  my $newmanifest = create_tar_manifest_data($newconfig, \@newlayers, $repotags || $manifest->{'RepoTags'});
  my $newmanifest_ent = create_tar_manifest_entry($newmanifest, $mtime);

  # create new tar (annotated with the file and blobid)
  my @newtar;
  for my $blobid (sort keys %newblobs) {
    my $ent = $newblobs{$blobid};
    push @newtar, {'name' => $blobid, 'mtime' => $mtime, 'offset' => $ent->{'offset'}, 'size' => $ent->{'size'}, 'file' => $ent->{'file'}, 'blobid' => $blobid, 'layer_compression' => $ent->{'layer_compression'}};
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

sub open_container_tar {
  my ($file) = @_;
  my $tarfd;
  if (ref($file)) {
    $tarfd = $file;
  } else {
    open($tarfd, '<', $file) || die("$file: $!\n");
  }
  my @s = stat($tarfd);
  die("$file: $!\n") unless @s;
  my $tar = BSTar::list($tarfd);
  $_->{'file'} = $tarfd for @$tar;
  return ($tar, $s[9]);
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
  if ($chartbasename =~ /($?:\.tar\.gz|\.tgz)$/) {
    $chart_ent->{'mimetype'} = 'application/vnd.cncf.helm.chart.content.v1.tar+gzip';
    $chart_ent->{'layer_compression'} = 'gzip';
  } else {
    $chart_ent->{'mimetype'} = 'application/vnd.cncf.helm.chart.content.v1.tar';
    $chart_ent->{'layer_compression'} = '';
  }
  # create ent for the config
  my ($config_ent) = make_blob_entry('config.json', $config_json, 'mtime' => $mtime, 'mimetype' => $mt_helm_config);
  # create ent for the manifest
  my $manifest = create_tar_manifest_data('config.json', [ $chartbasename ], $repotags);
  my $manifest_ent = create_tar_manifest_entry($manifest, $mtime);
  my $tar = [ $manifest_ent, $config_ent, $chart_ent ];
  return ($tar, $mtime)
}

sub unparse_yaml_string {
  my ($d) = @_;
  return "''" unless length $d;
  return "\"$d\"" if Scalar::Util::looks_like_number($d);
  if ($d =~ /[\x00-\x1f\x7f-\x9f\']/) {
    $d =~ s/\\/\\\\/g;
    $d =~ s/\"/\\\"/g;
    $d =~ s/([\x00-\x1f\x7f-\x9f])/'\x'.sprintf("%X",ord($1))/ge;
    return "\"$d\"";
  } elsif ($d =~ /^[\!\&*{}[]|>@`"'#%, ]/s) {
    return "'$d'";
  } elsif ($d =~ /: / || $d =~ / #/ || $d =~ /[: \t]\z/) {
    return "'$d'";
  } elsif ($d eq '~' || $d eq 'null' || $d eq 'true' || $d eq 'false' && $d =~ /^(?:---|\.\.\.)/s) {
    return "'$d'";
  } elsif ($d =~ /^[-?:](?:\s|\z)/s) {
    return "'$d'";
  } else {
    return $d;
  }
}

sub create_artifacthub_yaml {
  my ($artifacthubdata) = @_;
  my ($repoid, $name, $email) = split(':', $artifacthubdata, 3);
  my $yaml = '';
  $yaml .= "repositoryID: ".unparse_yaml_string($repoid)."\n" if $repoid;
  my $owners = '';
  $owners .= "    name: ".unparse_yaml_string($name)."\n" if $name;
  $owners .= "    email: ".unparse_yaml_string($email)."\n" if $email;
  $owners =~ s/^   /  -/;
  $yaml .= "owners:\n$owners" if $owners;
  return $yaml;
}

sub container_from_artifacthub {
  my ($artifacthubdata, $mtime) = @_;
  my $artifacthub_yaml = create_artifacthub_yaml($artifacthubdata);
  my $config_ent = { 'name' => 'config.yaml', 'mtime' => $mtime, 'data' => '', 'size' => 0, 'mimetype' => $mt_artifacthub_config };
  my $layer_ent = { 'name' => 'artifacthub-repo.yml', 'mtime' => $mtime, 'data' => $artifacthub_yaml, 'size' => length($artifacthub_yaml), 'mimetype' => $mt_artifacthub_layer, 'layer_compression' => '' };
  $layer_ent->{'annotations'}->{'org.opencontainers.image.title'} = 'artifacthub-repo.yml';
  my $manifest = create_tar_manifest_data('config.yaml', [ 'artifacthub-repo.yml' ], [ 'artifacthub.io' ]);
  my $manifest_ent = create_tar_manifest_entry($manifest, $mtime);
  my $tar = [ $manifest_ent, $config_ent, $layer_ent ];
  return ($tar, $mtime);
}

sub normalize_layer {
  my ($layer_ent, $oci, $comp, $newcomp) = @_;
  $comp = $layer_ent->{'layer_compression'} unless defined $comp;
  $comp = detect_entry_compression($layer_ent) unless defined $comp;
  $layer_ent->{'layer_compression'} = $comp;
  $newcomp ||= $oci && ($comp eq 'zstd' || $comp =~ /^zstd:chunked/) ? 'zstd' : 'gzip';
  return $layer_ent if $newcomp eq 'zstd' && $comp =~ /^zstd:chunked/;
  return $layer_ent if $layer_ent->{'mimetype'};
  if ($comp ne $newcomp) {
    if ($comp) {
      print "recompressing $layer_ent->{'name'}... ";
    } else {
      print "compressing $layer_ent->{'name'}... ";
    }
    $layer_ent = compress_entry($layer_ent, $comp, $newcomp);
    print "done.\n";
  }
  return $layer_ent;
}

sub create_tar_manifest_data {
  my ($configfile, $layerfiles, $tags) = @_;
  my $manifest = {
    'Config' => $configfile,
    'RepoTags' => $tags || [],
    'Layers' => $layerfiles,
  };
  return $manifest;
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

sub create_layer_data {
  my ($layer_ent, $oci, $annotations) = @_;
  my $mime_type = $layer_ent->{'mimetype'};
  my $comp = $layer_ent->{'layer_compression'};
  if (!$mime_type) {
    $comp = detect_entry_compression($layer_ent) unless defined $comp;
    $mime_type = layer_mimetype_from_compression($comp, $oci);
  }
  my $layer_data = {
    'mediaType' => $mime_type,
    'size' => 0 + $layer_ent->{'size'},
    'digest' => $layer_ent->{'blobid'} || blobid_entry($layer_ent),
  };
  my %annotations = (%{$layer_ent->{'annotations'} || {}}, %{$annotations || {}});
  layer_annotations_from_compression($comp, \%annotations);
  $layer_data->{'annotations'} = \%annotations if %annotations;
  return $layer_data;
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

sub make_platformstr {
  my ($goarch, $govariant, $goos) = @_;
  my $str = $goarch || 'any';
  $str .= "-$govariant" if defined $govariant;
  $str .= "\@$goos" if $goos && $goos ne 'linux';
  $str =~ s/[\/\s,]/_/g;
  return $str;
}

1;

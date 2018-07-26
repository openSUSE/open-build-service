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
  return ('cat') if $comp eq '';
  return ();
}

sub compress_entry {
  my ($ent, $oldcomp) = @_;

  my @compressor = ('zlib');
  @compressor = ('/usr/bin/obs-gzip-go') if -x '/usr/bin/obs-gzip-go';

  my @decompressor;
  $oldcomp = detect_entry_compression($ent) unless defined $oldcomp;
  if ($oldcomp) {
    @decompressor = comp2decompressor($oldcomp);
    die("unknown compression $oldcomp\n") unless @decompressor;
  }

  my $tmp;
  open($tmp, '+>', undef) || die;

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
  return { %$ent, 'offset' => 0, 'size' => (-s $tmp), 'file' => $tmp };
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
  }
  return $comp;
}

sub get_manifest {
  my ($tar) = @_;
  my $manifest_ent = $tar->{'manifest.json'};
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
  my $config = JSON::XS::decode_json($config_json);
  return ($config_ent, $config);
}

sub create_manifest_entry {
  my ($manifest, $mtime) = @_;
  my %newmanifest = %$manifest;
  $newmanifest{'XXXLayers'} = delete $newmanifest{'Layers'};
  my $newmanifest_json = JSON::XS->new->utf8->canonical->encode([ \%newmanifest ]);
  $newmanifest_json =~ s/(.*)XXX/$1/s;
  my $newmanifest_ent = { 'name' => 'manifest.json', 'size' => length($newmanifest_json), 'data' => $newmanifest_json, 'mtime' => $mtime };
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
  my ($tarfd, $recompress) = @_;
  my @tarstat = stat($tarfd);
  die("stat: $!\n") unless @tarstat;
  my $mtime = $tarstat[9];
  my $tar = BSTar::list($tarfd);
  $_->{'file'} = $tarfd for @$tar;
  my %tar = map {$_->{'name'} => $_} @$tar;
  my ($manifest_ent, $manifest) = get_manifest(\%tar);
  my ($config_ent, $config) = get_config(\%tar, $manifest);

  # compress blobs
  my %newblobs;
  my @newlayers;
  my $newconfig = blobid_entry($config_ent);
  $newblobs{$newconfig} ||= $config_ent;
  for my $layer_file (@{$manifest->{'Layers'} || []}) {
    my $layer_ent = $tar{$layer_file};
    die("File $layer_file not included in tar\n") unless $layer_ent;
    my $comp = detect_entry_compression($layer_ent);
    die("unsupported compression $comp\n") if $comp && $comp ne 'gzip';
    if (!$comp || $recompress) {
      if ($comp) {
        print "recompressing $layer_ent->{'name'}... ";
      } else {
        print "compressing $layer_ent->{'name'}... ";
      }
      $layer_ent = compress_entry($layer_ent, $comp);
      print "done.\n";
    }   
    my $blobid = blobid_entry($layer_ent);
    $newblobs{$blobid} ||= $layer_ent;
    push @newlayers, $blobid;
  }

  # create new manifest
  my $newmanifest = { 
    'Config' => $newconfig,
    'RepoTags' => $manifest->{'RepoTags'},
    'Layers' => \@newlayers,
  };  
  my $newmanifest_ent = create_manifest_entry($newmanifest, $mtime);

  # create new tar (annotated with the file and blobid)
  my @newtar;
  for my $blobid (sort keys %newblobs) {
    my $ent = $newblobs{$blobid};
    push @newtar, {'name' => $blobid, 'mtime' => $mtime, 'offset' => $ent->{'offset'}, 'size' => $ent->{'size'}, 'file' => $ent->{'file'}, 'blobid' => $blobid};
  }
  $newmanifest_ent->{'blobid'} = BSContar::blobid_entry($newmanifest_ent);
  push @newtar, $newmanifest_ent;

  return (\@newtar, $mtime, $config, $newconfig);
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
  $_ = _orderhash($_, $blob_order) for @{$m{'layers'} || []};
  $manifest = _orderhash(\%m, $distmani_order);
  my $json = JSON::XS->new->utf8->canonical->pretty->encode($manifest);
  $json =~ s/!!!\d_//g;
  $json =~ s/\n$//s;
  return $json;
}

sub create_dist_manifest_list {
  my ($manifest) = @_;
  my %m = %$manifest;
  $_ = _orderhash($_, $imagemani_order) for @{$m{'manifests'} || []};
  $manifest = _orderhash(\%m, $distmanilist_order);
  my $json = JSON::XS->new->utf8->canonical->pretty->encode($manifest);
  $json =~ s/!!!\d_//g;
  $json =~ s/\n$//s;
  return $json;
}

1;

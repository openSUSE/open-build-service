#
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
################################################################
#
# local registry support
#

package BSPublisher::Registry;

use Digest::SHA;

use BSConfiguration;
use BSUtil;
use BSVerify;
use BSPublisher::Blobstore;
use BSContar;
use BSRPC;

my $registrydir = "$BSConfig::bsdir/registry";


# registry layout:
#
# <repo>/info				information about the repository
# <repo>/manifests/<imageid>		contains manifest data
# <repo>/blobs/<blobid>			contains hardlinked blobs
# <repo>/tags/<tag>			hardlinked manifest data
# 

use strict;

sub ownrepo {
  my ($prp, $repo) = @_;
  my $registries = BSUtil::retrieve("$registrydir/:repos", 1);
  if ($registries->{$repo}) {
    # make sure the directory exists
    if (! -d "$registrydir/$repo") {
      my $lck;
      open($lck, '>>', "$registrydir/:repos");
      mkdir_p("$registrydir/$repo");
      close($lck);
    }
    return $registries->{$repo};
  }
  # new entry... lock...
  BSVerify::verify_regrepo($repo);

  # own in the source server
  my ($projid, $repoid) = split('/', $prp, 2);
  my $param = {
    'uri' => "$BSConfig::srcserver/ownregistryrepo",
    'request' => 'POST',
    'timeout' => 600,
  };
  my $owner = BSRPC::rpc($param, $BSXML::regrepoowner, "project=$projid", "repository=$repoid", "regrepo=$repo");
  return "$owner->{'project'}/$owner->{'repository'}" if $owner->{'project'} ne $projid || $owner->{'repository'} ne $repoid;

  mkdir_p($registrydir) unless -d $registrydir;
  my $lck;
  open($lck, '>>', "$registrydir/:repos");
  if (! -s "$registrydir/:repos") {
    $registries = {};
  } else {
    $registries = BSUtil::retrieve("$registrydir/:repos");
  }
  if (!$registries->{$repo}) {
    $registries->{$repo} = $prp;
    mkdir_p("$registrydir/$repo");
    BSUtil::store("$registrydir/:repos.new.$$", "$registrydir/:repos", $registries);
  }
  close($lck);
  return $registries->{$repo};
}

sub disownrepo {
  my ($prp, $repo) = @_;

  my ($projid, $repoid) = split('/', $prp, 2);
  # disown in the source server
  my $param = {
    'uri' => "$BSConfig::srcserver/disownregistry",
    'request' => 'POST',
    'timeout' => 600,
  };
  BSRPC::rpc($param, $BSXML::regrepoowner, "project=$projid", "repository=$repoid", "regrepo=$repo");

  my $lck;
  open($lck, '>>', "$registrydir/:repos");
  my $registries = BSUtil::retrieve("$registrydir/:repos");
  die("repository '$repo' is owned by $registries->{$repo}\n") if $registries->{$repo} && $registries->{$repo} ne $prp;
  my $dir = $repo;
  while ($dir =~ /\//) {
    rmdir("$registrydir/$dir");
    $dir =~ s/\/.*?$//;
  }
  rmdir("$registrydir/$dir");
  delete $registries->{$repo};
  BSUtil::store("$registrydir/:repos.new.$$", "$registrydir/:repos", $registries);
  close($lck);
}

sub push_blob {
  my ($repodir, $containerinfo, $ent) = @_;

  my $blobid = $ent->{'blobid'} || BSContar::blobid_entry($ent);
  my $dir = "$repodir/:blobs";
  return $blobid if -e "$dir/$blobid";
  mkdir_p($dir) unless -d $dir;
  unlink("$dir/.$blobid.$$");
  if ($containerinfo->{'uploadfile'}) {
    BSContar::write_entry($ent, "$dir/.$blobid.$$");
  } else {
    my $blobdir = $containerinfo->{'blobdir'};
    link("$blobdir/_blob.$blobid", "$dir/.$blobid.$$") || die("link $blobdir/_blob.$blobid $dir/.$blobid.$$: $!\n");
  }
  rename("$dir/.$blobid.$$", "$dir/$blobid") || die("rename $dir/.$blobid.$$ $dir/$blobid: $!\n");
  unlink("$dir/.$blobid.$$");
  #BSPublisher::Blobstore::blobstore_lnk($blobid, "$dir/$blobid");
  return $blobid;
}

sub push_manifest {
  my ($repodir, $mani_json) = @_;
  my $mani_id = 'sha256:'.Digest::SHA::sha256_hex($mani_json);
  my $dir = "$repodir/:manifests";
  return $mani_id if -e "$dir/$mani_id";
  mkdir_p($dir) unless -d $dir;
  unlink("$dir/.$mani_id.$$");
  writestr("$dir/.$mani_id.$$", "$dir/$mani_id", $mani_json);
  return $mani_id;
}

sub push_tag {
  my ($repodir, $tag, $mani_id) = @_;
  my $dir = "$repodir/:tags";
  my $mdir = "$repodir/:manifests";
  my @s1 = stat("$dir/$tag");
  my @s2 = stat("$mdir/$mani_id");
  return 0 if @s1 && @s2 && "$s1[0]/$s1[1]" eq "$s2[0]/$s2[1]";
  mkdir_p($dir) unless -d $dir;
  unlink("$mdir/.$mani_id.$$");
  link("$mdir/$mani_id", "$mdir/.$mani_id.$$") || die("link $mdir/$mani_id $mdir/.$mani_id.$$: $!\n");
  rename("$mdir/.$mani_id.$$", "$dir/$tag") || die("rename $mdir/.$mani_id.$$ $dir/$tag: $!\n");
  unlink("$mdir/.$mani_id.$$");
  return 1;
}

sub construct_container_tar {
  my ($containerinfo) = @_;
  my $blobdir = $containerinfo->{'blobdir'};
  die("need a blobdir to reconstruct containers\n") unless $blobdir;
  my $manifest = $containerinfo->{'tar_manifest'};
  my $mtime = $containerinfo->{'tar_mtime'};
  my $blobids = $containerinfo->{'tar_blobids'};
  die("containerinfo is incomplete\n") unless $mtime && $manifest && $blobids;
  my @tar;
  for my $blobid (@$blobids) {
    my $file;
    open($file, '<', "$blobdir/_blob.$blobid") || die("$blobdir/_blob.$blobid: $!");
    push @tar, {'name' => $blobid, 'file' => $file, 'mtime' => $mtime, 'offset' => 0, 'size' => (-s $file), 'blobid' => $blobid};
  }
  push @tar, {'name' => 'manifest.json', 'data' => $manifest, 'mtime' => $mtime, 'size' => length($manifest)};
  return (\@tar, $mtime);
}

sub push_containers {
  my ($prp, $repo, $multiarch, $tags) = @_;

  my $containerdigests = '';

  my $oprp = ownrepo($prp, $repo);
  if ($oprp ne $prp) {
    print "cannot push to $repo: owned by $oprp\n";
    return undef;
  }

  my $repodir = "$registrydir/$repo";

  my %done;

  # for cleanup
  my %knownblobs;
  my %knownmanifests;
  my %knowntags;

  my %info;

  for my $tag (sort keys %$tags) {
    eval { BSVerify::verify_regtag($tag) };
    if ($@) {
      warn("ignoring tag: $@");
      next;
    }
    die("must use multiarch if multiple containers are to be pushed\n") if @{$tags->{$tag}} > 1 && !$multiarch;
    my %multiplatforms;
    my @multimanifests;
    my @imginfos;
    for my $containerinfo (@{$tags->{$tag}}) {
      # check if we already processed this container with a different tag
      if ($done{$containerinfo}) {
	# yes, reuse data
        my ($multimani, $platformstr) = @{$done{$containerinfo}};
	if ($multiplatforms{$platformstr}) {
	  print "ignoring $containerinfo->{'file'}, already have $platformstr\n";
	  next;
	}
	$multiplatforms{$platformstr} = 1;
        push @multimanifests, $multimani;
	next;
      }

      my ($tar, $mtime);
      my $tarfd;
      if ($containerinfo->{'uploadfile'}) {
	open($tarfd, '<', $containerinfo->{'uploadfile'}) || die("$containerinfo->{'uploadfile'}: $!\n");
	($tar, $mtime) = BSContar::normalize_container($tarfd, 1);
      } else {
	($tar, $mtime) = construct_container_tar($containerinfo);
      }
      my %tar = map {$_->{'name'} => $_} @$tar;
      
      my ($manifest_ent, $manifest) = BSContar::get_manifest(\%tar);
      my ($config_ent, $config) = BSContar::get_config(\%tar, $manifest);

      my @layers = @{$manifest->{'Layers'} || []};
      die("container has no layers\n") unless @layers;
      my $config_layers = $config->{'rootfs'}->{'diff_ids'};
      die("layer number mismatch\n") if @layers != @{$config_layers || []};

      # see if a already have this arch/os combination
      my $platformstr = "architecture:$config->{'architecture'} os:$config->{'os'}";
      if ($multiplatforms{$platformstr}) {
	print "ignoring $containerinfo->{'file'}, already have $platformstr\n";
	close $tarfd if $tarfd;
	next;
      }
      $multiplatforms{$platformstr} = 1;

      # put config blob into repo
      my $config_blobid = push_blob($repodir, $containerinfo, $config_ent);
      $knownblobs{$config_blobid} = 1;
      my $config_data = {
	'mediaType' => 'application/vnd.docker.container.image.v1+json',
	'size' => $config_ent->{'size'},
	'digest' => $config_blobid,
      };

      # put layer blobs into repo
      my %layer_datas;
      my @layer_data;
      for my $layer_file (@layers) {
	if ($layer_datas{$layer_file}) {
	  # already did that file, just reuse old layer data
	  push @layer_data, $layer_datas{$layer_file};
	  next;
	}
	my $layer_ent = $tar{$layer_file};
	die("File $layer_file not included in tar\n") unless $layer_ent;
	my $blobid = push_blob($repodir, $containerinfo, $layer_ent);
        $knownblobs{$blobid} = 1;
	my $layer_data = {
	  'mediaType' => 'application/vnd.docker.image.rootfs.diff.tar.gzip',
	  'size' => $layer_ent->{'size'},
	  'digest' => $blobid,
	};
	push @layer_data, $layer_data;
	$layer_datas{$layer_file} = $layer_data;
      }
      close $tarfd if $tarfd;

      # put manifest into repo
      my $mani = { 
	'schemaVersion' => 2,
	'mediaType' => 'application/vnd.docker.distribution.manifest.v2+json',
	'config' => $config_data,
	'layers' => \@layer_data,
      };  
      my $mani_json = BSContar::create_dist_manifest($mani);
      my $mani_id = push_manifest($repodir, $mani_json);
      $knownmanifests{$mani_id} = 1;

      my $multimani = {
	'mediaType' => 'application/vnd.docker.image.manifest.v2+json',
	'size' => length($mani_json),
	'digest' => $mani_id,
	'platform' => {'architecture' => $config->{'architecture'}, 'os' => $config->{'os'}},
      };
      # cache result
      $done{$containerinfo} = [ $multimani, $platformstr ];
      push @multimanifests, $multimani;

      my $imginfo = {
	'imageid' => $config_blobid,
        'goarch' => $config->{'architecture'},
        'goos' => $config->{'os'},
	'distmanifest' => $mani_id,
      };
      $imginfo->{'disturl'} = $containerinfo->{'disturl'} if $containerinfo->{'disturl'};
      $imginfo->{'buildtime'} = $containerinfo->{'buildtime'} if $containerinfo->{'buildtime'};
      $imginfo->{'version'} = $containerinfo->{'version'} if $containerinfo->{'version'};
      $imginfo->{'release'} = $containerinfo->{'release'} if $containerinfo->{'release'};
      $imginfo->{'arch'} = $containerinfo->{'arch'};		# scheduler arch
      my @diff_ids = @{$config_layers || []};
      for (@layer_data) {
        push @{$imginfo->{'layers'}}, {
	  'diffid' => shift @diff_ids,
	  'blobid' => $_->{'digest'},
	  'blobsize' => $_->{'size'},
	};
      }
      push @imginfos, $imginfo;
    }
    next unless @multimanifests;
    my $taginfo = {
      'images' => \@imginfos,
    };
    my ($mani_id, $mani_size);
    if ($multiarch) {
      # create fat manifest
      my $mani = {
        'schemaVersion' => 2,
        'mediaType' => 'application/vnd.docker.distribution.manifest.list.v2+json',
        'manifests' => \@multimanifests,
      };
      my $mani_json = BSContar::create_dist_manifest_list($mani);
      $mani_id = push_manifest($repodir, $mani_json, \%knownmanifests);
      $mani_size = length($mani_json);
      $knownmanifests{$mani_id} = 1;
      $taginfo->{'distmanifesttype'} = 'list';
    } else {
      $mani_id = $multimanifests[0]->{'digest'};
      $mani_size = $multimanifests[0]->{'size'};
      $taginfo->{'distmanifesttype'} = 'image';
    }
    push_tag($repodir, $tag, $mani_id);
    $knowntags{$tag} = 1;
    $containerdigests .= "$mani_id $mani_size $tag\n";
    $taginfo->{'distmanifest'} = $mani_id;
    $info{$tag} = $taginfo;
  }

  # now get rid of old entries
  for (sort(ls("$repodir/:tags"))) {
    next if $knowntags{$_};
    unlink("$repodir/:tags/$_");
  }
  for (sort(ls("$repodir/:manifests"))) {
    next if $knownmanifests{$_};
    unlink("$repodir/:manifests/$_");
  }
  for (sort(ls("$repodir/:blobs"))) {
    next if $knownblobs{$_};
    unlink("$repodir/:blobs/$_");
    BSPublisher::Blobstore::blobstore_chk($_);
  }

  if (!%knowntags && !%knownmanifests && !%knownblobs) {
    rmdir("$repodir/:tags");
    rmdir("$repodir/:manifests");
    rmdir("$repodir/:blobs");
    unlink("$repodir/:info");
    disownrepo($prp, $repo);
  } else {
    my ($projid, $repoid) = split('/', $prp, 2);
    my $info = { 'project' => $projid, 'repository' => $repoid, 'tags' => \%info };
    BSUtil::store("$repodir/.info.$$", "$repodir/:info", $info);
  }

  # and we're done, return digests
  return $containerdigests;
}

1;

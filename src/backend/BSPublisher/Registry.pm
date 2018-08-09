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
use JSON::XS ();

use BSConfiguration;
use BSUtil;
use BSVerify;
use BSPublisher::Blobstore;
use BSContar;
use BSRPC;
use BSTUF;

my $registrydir = "$BSConfig::bsdir/registry";
my $uploaddir = "$BSConfig::bsdir/upload";

my $root_extra_expire = 183 * 24 * 3600;	# 6 months
my $targets_expire = 3 * 366 * 24 * 3600;	# 3 years
my $timestamp_expire = 14 * 24 * 3600;		# 14 days

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
    'uri' => "$BSConfig::srcserver/disownregistryrepo",
    'request' => 'POST',
    'timeout' => 600,
  };
  BSRPC::rpc($param, undef, "project=$projid", "repository=$repoid", "regrepo=$repo");

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

sub gen_timestampkey {
  print "local notary: generating timestamp keypair\n";
  my @keyargs = ('rsa@2048', '800');	# expire time does not matter...
  mkdir_p($uploaddir);
  unlink("$uploaddir/timestampkey.$$");
  my @signargs;
  push @signargs, '--project', ':tmpkey' if $BSConfig::sign_project;
  push @signargs, '-P', "$uploaddir/timestampkey.$$";
  my $pubkey = '';
  my $fd;
  open($fd, '-|', $BSConfig::sign, @signargs, '-g', @keyargs, "timestamp signing key", 'timestampsign@build.opensuse.org') || die("$BSConfig::sign: $!\n");
  1 while sysread($fd, $pubkey, 4096, length($pubkey));
  close($fd) || die("$BSConfig::sign: $?\n");
  my $privkey = readstr("$uploaddir/timestampkey.$$");
  unlink("$uploaddir/timestampkey.$$");
  $pubkey = BSPGP::unarmor($pubkey);
  $pubkey = BSPGP::pk2keydata($pubkey);
  die unless $pubkey;
  $pubkey = BSTUF::keydata2asn1($pubkey);
  $pubkey = MIME::Base64::encode_base64($pubkey, '');
  return ($privkey, $pubkey);
}

sub update_tuf {
  my ($prp, $repo, $gun, $containerdigests, $pubkey, $signargs) = @_;

  my ($projid, $repoid) = split('/', $prp, 2);
  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  push @signargs, @{$signargs || []};

  my $repodir = "$registrydir/$repo";
  my $now = time();
  my $tuf = { 'gun' => $gun };
  my $oldtuf = BSUtil::retrieve("$repodir/:tuf", 1) || {};

  my $gpgpubkey = BSPGP::unarmor($pubkey);
  my $pubkey_data = BSPGP::pk2keydata($gpgpubkey) || {};
  die("need an rsa pubkey for container signing\n") unless ($pubkey_data->{'algo'} || '') eq 'rsa';
  my $pubkey_times = BSPGP::pk2times($gpgpubkey) || {};
  # generate pub key and cert from pgp key data
  my $pub_bin = BSTUF::keydata2asn1($pubkey_data);

  my $root_expire = $pubkey_times->{'key_expire'} + $root_extra_expire;
  my $tbscert = BSTUF::mktbscert($gun, $pubkey_times->{'selfsig_create'}, $root_expire, $pub_bin);

  my $oldroot = $oldtuf->{'root'} ? JSON::XS::decode_json($oldtuf->{'root'}) : {};
  my $cmpres = BSTUF::cmprootcert($oldroot, $tbscert);
  my $cert;
  $cert = BSTUF::getrootcert($oldroot) if $cmpres == 2;		# reuse cert of old root
  $cert ||= BSTUF::mkcert($tbscert, \@signargs);

  if ($cmpres == 0) {
    # pubkey changed, better start from scratch
    delete $oldtuf->{'timestamp_privkey'};
    delete $oldtuf->{'root'};
    delete $oldtuf->{'targets'};
    delete $oldtuf->{'snapshot'};
    delete $oldtuf->{'timestamp'};
  }

  # generate timestamp sign key if not present
  if (!$oldtuf->{'timestamp_privkey'}) {
    ($tuf->{'timestamp_privkey'}, $tuf->{'timestamp_pubkey'}) = gen_timestampkey();
  } else {
    ($tuf->{'timestamp_privkey'}, $tuf->{'timestamp_pubkey'}) = ($oldtuf->{'timestamp_privkey'}, $oldtuf->{'timestamp_pubkey'});
  }

  # setup keys
  my $root_key = {
    'keytype' => 'rsa-x509',
    'keyval' => { 'private' => undef, 'public' => MIME::Base64::encode_base64($cert, '')},
  };
  my $timestamp_key = {
    'keytype' => 'rsa',
    'keyval' => { 'private' => undef, 'public' => $tuf->{'timestamp_pubkey'} },
  };
  my $root_key_id = Digest::SHA::sha256_hex(BSTUF::canonical_json($root_key));
  my $timestamp_key_id = Digest::SHA::sha256_hex(BSTUF::canonical_json($timestamp_key));

  #
  # setup root 
  #
  my $keys = {};
  $keys->{$root_key_id} = $root_key;
  $keys->{$timestamp_key_id} = $timestamp_key;

  my $roles = {};
  $roles->{'root'}      = { 'keyids' => [ $root_key_id ],      'threshold' => 1 };
  $roles->{'snapshot'}  = { 'keyids' => [ $root_key_id ],      'threshold' => 1 };
  $roles->{'targets'}   = { 'keyids' => [ $root_key_id ],      'threshold' => 1 };
  $roles->{'timestamp'} = { 'keyids' => [ $timestamp_key_id ], 'threshold' => 1 };

  my $root = {
    '_type' => 'Root',
    'consistent_snapshot' => $JSON::XS::false,
    'expires' => BSTUF::rfc3339time($root_expire),
    'keys' => $keys,
    'roles' => $roles,
  };
  $root->{'version'} = 1;
  $root->{'version'} = $oldroot->{'signed'}->{'version'} || 1 if $oldroot->{'signed'};
  if (BSTUF::canonical_json($root) eq BSTUF::canonical_json($oldroot->{'signed'} || {})) {
    $tuf->{'root'} = $oldtuf->{'root'};
  } else {
    print "local notary: updating root\n";
    my @key_ids = ( $root_key_id );
    if ($cmpres == 1) {
      # also add other ids that hopefully have the same public key...
      for (@{$oldroot->{'signatures'} || []}) {
        push @key_ids, $_->{'keyid'} if $_->{'keyid'};
      }
      @key_ids = BSUtil::unify(@key_ids);
      @key_ids = splice(@key_ids, 0, 2);	# enough for now
    }
    $tuf->{'root'} = BSTUF::updatedata($root, $oldroot, \@signargs, @key_ids);
  }

  my $manifests = {};
  for my $digest (split("\n", $containerdigests)) {
    next if $digest eq '';
    die("bad line in digest file\n") unless $digest =~ /^([a-z0-9]+):([a-f0-9]+) (\d+) (.+?)\s*$/;
    $manifests->{$4} = {
      'hashes' => { $1 => MIME::Base64::encode_base64(pack('H*', $2), '') },
      'length' => (0 + $3),
    };
  }

  my $oldtargets = $oldtuf->{'targets'} ? JSON::XS::decode_json($oldtuf->{'targets'}) : {};
  if ($oldtargets->{'signed'} && $oldtuf->{'root'} && $tuf->{'root'} eq $oldtuf->{'root'}) {
    if (BSUtil::identical($manifests, $oldtargets->{'signed'}->{'targets'})) {
      if (!$tuf->{'targets_expires'} || $now + 183 * 24 * 3600 < $tuf->{'targets_expires'}) {
        print "local notary: no change.\n";
        return;
      }
    }
  }

  my $targets = {
    '_type' => 'Targets',
    'delegations' => { 'keys' => {}, 'roles' => []},
    'expires' => BSTUF::rfc3339time($now + $targets_expire),
    'targets' => $manifests,
  };
  $tuf->{'targets'} = BSTUF::updatedata($targets, $oldtargets, \@signargs, $root_key_id);

  my $snapshot = {
    '_type' => 'Snapshot',
    'expires' => BSTUF::rfc3339time($now + $targets_expire),
  };
  BSTUF::addmetaentry($snapshot, 'root', $tuf->{'root'});
  BSTUF::addmetaentry($snapshot, 'targets', $tuf->{'targets'});
  my $oldsnapshot = $oldtuf->{'snapshot'} ? JSON::XS::decode_json($oldtuf->{'snapshot'}) : {};
  $tuf->{'snapshot'} = BSTUF::updatedata($snapshot, $oldsnapshot, \@signargs, $root_key_id);

  mkdir_p($uploaddir);
  unlink("$uploaddir/timestampkey.$$");
  writestr("$uploaddir/timestampkey.$$", undef, $tuf->{'timestamp_privkey'});
  my @signargs_timestamp;
  push @signargs_timestamp, '--project', ':tmpkey' if $BSConfig::sign_project;
  push @signargs_timestamp, '-P', "$uploaddir/timestampkey.$$";

  my $timestamp = {
    '_type' => 'Timestamp',
    'expires' => BSTUF::rfc3339time($now + $timestamp_expire),
  };
  BSTUF::addmetaentry($timestamp, 'snapshot', $tuf->{'snapshot'});
  my $oldtimestamp = $oldtuf->{'timestamp'} ? JSON::XS::decode_json($oldtuf->{'timestamp'}) : {};
  $tuf->{'timestamp'} = BSTUF::updatedata($timestamp, $oldtimestamp, \@signargs_timestamp, $timestamp_key_id);
  unlink("$uploaddir/timestampkey.$$");

  # add expire information
  $tuf->{'targets_expires'} = $now + $targets_expire;
  $tuf->{'timestamp_expires'} = $now + $timestamp_expire;

  my $fd;
  if (-e "$repodir/:tuf") {
    BSUtil::lockopen($fd, '<', "$repodir/:tuf");
    unlink("$repodir/:tuf.old");
    link("$repodir/:tuf", "$repodir/:tuf.old");
  }
  BSUtil::store("$repodir/.tuf.$$", "$repodir/:tuf", $tuf);
  close($fd) if $fd;
}

sub push_containers {
  my ($prp, $repo, $gun, $multiarch, $tags, $pubkey, $signargs) = @_;

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
    # delete empty repository
    rmdir("$repodir/:tags");
    rmdir("$repodir/:manifests");
    rmdir("$repodir/:blobs");
    unlink("$repodir/:info");
    unlink("$repodir/:tuf.old");
    unlink("$repodir/:tuf");
    disownrepo($prp, $repo);
    return $containerdigests;
  }

  # write info file
  my ($projid, $repoid) = split('/', $prp, 2);
  my $info = { 'project' => $projid, 'repository' => $repoid, 'tags' => \%info };
  $info->{'gun'} = $gun if $gun;
  my $oldinfo = BSUtil::retrieve("$repodir/:info", 1);
  if (BSUtil::identical($oldinfo, $info)) {
    print "local registry: no change\n";
  } else {
    BSUtil::store("$repodir/.info.$$", "$repodir/:info", $info);
  }

  # write TUF file
  if ($gun) {
    update_tuf($prp, $repo, $gun, $containerdigests, $pubkey, $signargs);
  } elsif (-e "$repodir/:tuf") {
    unlink("$repodir/:tuf.old");
    unlink("$repodir/:tuf");
  }

  # and we're done, return digests
  return $containerdigests;
}

1;

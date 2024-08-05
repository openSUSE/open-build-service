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

use Digest::SHA ();
use JSON::XS ();
use MIME::Base64 ();

use BSConfiguration;
use BSUtil;
use BSVerify;
use BSPublisher::Blobstore;
use BSPublisher::Containerinfo;
use BSContar;
use BSRPC;
use BSTUF;
use BSPGP;
use BSX509;
use BSConSign;
use BSRekor;

my $registrydir = "$BSConfig::bsdir/registry";
my $uploaddir = "$BSConfig::bsdir/upload";

my $root_extra_expire = 183 * 24 * 3600;	# 6 months
my $targets_expire = 3 * 366 * 24 * 3600;	# 3 years
my $timestamp_expire = 14 * 24 * 3600;		# 14 days
my $timestamp_keytype = 'rsa@2048';

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
      BSUtil::lockopen($lck, '>>', "$registrydir/:repos");
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
  BSUtil::lockopen($lck, '>>', "$registrydir/:repos");
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
  BSUtil::lockopen($lck, '>>', "$registrydir/:repos");
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
  my ($repodir, $ent) = @_;

  my $blobid = $ent->{'blobid'} || BSContar::blobid_entry($ent);
  my $dir = "$repodir/:blobs";
  return $blobid if -e "$dir/$blobid";
  mkdir_p($dir) unless -d $dir;
  unlink("$dir/.$blobid.$$");
  if ($ent->{'blobfile'}) {
    link($ent->{'blobfile'}, "$dir/.$blobid.$$") || die("link $ent->{'blobfile'} $dir/.$blobid.$$: $!\n");
  } else {
    BSContar::write_entry($ent, "$dir/.$blobid.$$");
  }
  rename("$dir/.$blobid.$$", "$dir/$blobid") || die("rename $dir/.$blobid.$$ $dir/$blobid: $!\n");
  unlink("$dir/.$blobid.$$");
  #BSPublisher::Blobstore::blobstore_lnk($blobid, "$dir/$blobid");
  return $blobid;
}

sub push_manifest {
  my ($repodir, $mani_json) = @_;
  my $mani_id = BSContar::blobid($mani_json);
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

sub push_manifestinfo {
  my ($repodir, $mani_id, $info_json) = @_;
  my $dir = "$repodir/:manifestinfos";
  mkdir_p($dir);
  unlink("$dir/.$mani_id.$$");
  writestr("$dir/.$mani_id.$$", "$dir/$mani_id", $info_json);
}

sub gen_timestampkey {
  print "local notary: generating timestamp keypair\n";
  my @keyargs = ($timestamp_keytype, '800', 'timestamp signing key', 'timestampsign@build.opensuse.org');	# only the keytype matters
  mkdir_p($uploaddir);
  unlink("$uploaddir/timestampkey.$$");
  my @signcmd;
  push @signcmd, $BSConfig::sign;
  push @signcmd, '--project', ':tmpkey' if $BSConfig::sign_project;
  push @signcmd, '-P', "$uploaddir/timestampkey.$$";
  my $pubkey = '';
  my $fd;
  open($fd, '-|', @signcmd, '-g', @keyargs) || die("$BSConfig::sign: $!\n");
  1 while sysread($fd, $pubkey, 4096, length($pubkey));
  close($fd) || die("$BSConfig::sign: $?\n");
  my $privkey = readstr("$uploaddir/timestampkey.$$");
  unlink("$uploaddir/timestampkey.$$");
  # convert gpg pubkey to x509 pubkey
  $pubkey = BSPGP::unarmor($pubkey);
  $pubkey = BSPGP::pk2keydata($pubkey);
  die unless $pubkey;
  $pubkey = BSX509::keydata2pubkey($pubkey);
  $pubkey = MIME::Base64::encode_base64($pubkey, '');
  return ($privkey, $pubkey);
}

sub update_tuf {
  my ($prp, $repo, $gun, $containerdigests, $pubkey, $signargs) = @_;

  my ($projid, $repoid) = split('/', $prp, 2);
  my @signcmd;
  push @signcmd, $BSConfig::sign;
  push @signcmd, '--project', $projid if $BSConfig::sign_project;
  push @signcmd, @{$signargs || []};
  my $signfunc =  sub { BSUtil::xsystem($_[0], @signcmd, '-O', '-h', 'sha256') };

  my $repodir = "$registrydir/$repo";
  my $now = time();
  my $tuf = { 'gun' => $gun };
  my $oldtuf = BSUtil::retrieve("$repodir/:tuf", 1) || {};

  my $gpgpubkey = BSPGP::unarmor($pubkey);
  my $pubkey_data = BSPGP::pk2keydata($gpgpubkey) || {};
  die("need an rsa pubkey for container signing\n") unless ($pubkey_data->{'algo'} || '') eq 'rsa';
  my $pubkey_times = BSPGP::pk2times($gpgpubkey) || {};
  # generate pub key and cert from pgp key data
  my $pub_bin = BSX509::keydata2pubkey($pubkey_data);

  my $root_expire = $pubkey_times->{'key_expire'} + $root_extra_expire;
  my $tbscert = BSTUF::mktbscert($gun, $pubkey_times->{'selfsig_create'}, $root_expire, $pub_bin);

  my $oldroot = $oldtuf->{'root'} ? JSON::XS::decode_json($oldtuf->{'root'}) : {};
  my $cmpres = BSTUF::cmprootcert($oldroot, $tbscert);
  my $cert;
  $cert = BSTUF::getrootcert($oldroot) if $cmpres == 2;		# reuse cert of old root
  $cert ||= BSTUF::mkcert($tbscert, $signfunc);

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
  my $root_key_id = BSTUF::key2keyid($root_key);
  my $timestamp_key_id = BSTUF::key2keyid($timestamp_key);

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
    $tuf->{'root'} = BSTUF::updatedata($root, $oldroot, $signfunc, @key_ids);
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
  $tuf->{'targets'} = BSTUF::updatedata($targets, $oldtargets, $signfunc, $root_key_id);

  my $snapshot = {
    '_type' => 'Snapshot',
    'expires' => BSTUF::rfc3339time($now + $targets_expire),
  };
  BSTUF::addmetaentry($snapshot, 'root', $tuf->{'root'});
  BSTUF::addmetaentry($snapshot, 'targets', $tuf->{'targets'});
  my $oldsnapshot = $oldtuf->{'snapshot'} ? JSON::XS::decode_json($oldtuf->{'snapshot'}) : {};
  $tuf->{'snapshot'} = BSTUF::updatedata($snapshot, $oldsnapshot, $signfunc, $root_key_id);

  mkdir_p($uploaddir);
  unlink("$uploaddir/timestampkey.$$");
  writestr("$uploaddir/timestampkey.$$", undef, $tuf->{'timestamp_privkey'});
  my @signcmd_timestamp;
  push @signcmd_timestamp, $BSConfig::sign;
  push @signcmd_timestamp, '--project', ':tmpkey' if $BSConfig::sign_project;
  push @signcmd_timestamp, '-P', "$uploaddir/timestampkey.$$";
  my $signfunc_timestamp =  sub { BSUtil::xsystem($_[0], @signcmd_timestamp, '-O', '-h', 'sha256') };

  my $timestamp = {
    '_type' => 'Timestamp',
    'expires' => BSTUF::rfc3339time($now + $timestamp_expire),
  };
  BSTUF::addmetaentry($timestamp, 'snapshot', $tuf->{'snapshot'});
  my $oldtimestamp = $oldtuf->{'timestamp'} ? JSON::XS::decode_json($oldtuf->{'timestamp'}) : {};
  $tuf->{'timestamp'} = BSTUF::updatedata($timestamp, $oldtimestamp, $signfunc_timestamp, $timestamp_key_id);
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

sub update_sigs {
  my ($prp, $repo, $gun, $imagedigests, $pubkey, $signargs) = @_;

  my $creator = 'OBS';
  my ($projid, $repoid) = split('/', $prp, 2);
  my @signcmd;
  push @signcmd, $BSConfig::sign;
  push @signcmd, '--project', $projid if $BSConfig::sign_project;
  push @signcmd, @{$signargs || []};
  my $signfunc =  sub { BSUtil::xsystem($_[0], @signcmd, '-D', '-h', 'sha256') };
  my $repodir = "$registrydir/$repo";
  my $oldsigs = BSUtil::retrieve("$repodir/:sigs", 1) || {};
  return if !%$oldsigs && !%$imagedigests;

  my $gpgpubkey = BSPGP::unarmor($pubkey);
  my $pubkey_fp = BSPGP::pk2fingerprint($gpgpubkey);
  if (($oldsigs->{'pubkey'} || '') ne $pubkey_fp || ($oldsigs->{'gun'} || '') ne $gun || ($oldsigs->{'creator'} || '') ne ($creator || '')) {
    $oldsigs = {};	# fingerprint/gun/creator mismatch, do not use old signatures
  }
  my $sigs = { 'pubkey' => $pubkey_fp, 'gun' => $gun, 'creator' => $creator, 'digests' => {} };
  for my $digest (sort keys %$imagedigests) {
    my %old = map { $_->[0] => $_->[1] } @{($oldsigs->{'digests'} || {})->{$digest} || []};
    my @d;
    for my $tag (sort keys %{$imagedigests->{$digest}}) {
      if ($old{$tag}) {
        push @d, [ $tag, $old{$tag} ];
	next;
      }
      print "creating atomic signature for $gun:$tag $digest\n";
      my $sig = BSConSign::create_atomic_signature($signfunc, $digest, "$gun:$tag", $creator);
      push @d, [ $tag, $sig ];
    }
    $sigs->{'digests'}->{$digest} = \@d;
  }
  if (BSUtil::identical($oldsigs, $sigs)) {
    print "local signatures: no change.\n";
    return;
  }
  if (%{$sigs->{'digests'}}) {
    BSUtil::store("$repodir/.sigs.$$", "$repodir/:sigs", $sigs);
  } else {
    unlink("$repodir/:sigs");
  }
}

sub create_cosign_manifest {
  my ($repodir, $oci, $knownmanifests, $knownblobs, @layer_ents) = @_;
  my $config_ent = BSConSign::create_cosign_config_ent(\@layer_ents);
  my $config_data = BSContar::create_config_data($config_ent, $oci);
  push_blob($repodir, $config_ent);
  $knownblobs->{$config_ent->{'blobid'}} = 1;
  my @layer_data;
  for my $layer_ent (@layer_ents) {
    push @layer_data, BSContar::create_layer_data($layer_ent, $oci);
    push_blob($repodir, $layer_ent);
    $knownblobs->{$layer_ent->{'blobid'}} = 1;
  }
  my $mani = BSContar::create_dist_manifest_data($config_data, \@layer_data, $oci);
  my $mani_json = BSContar::create_dist_manifest($mani);
  my $mani_id = push_manifest($repodir, $mani_json);
  $knownmanifests->{$mani_id} = 1;
  return $mani_id;
}

sub reuse_cosign_manifest {
  my ($repodir, $oci, $mani_id, $knownmanifests, $knownblobs, $numlayers) = @_;
  my $manifest_json = readstr("$repodir/:manifests/$mani_id", 1);
  return 0 unless $manifest_json;
  my $manifest = eval { JSON::XS::decode_json($manifest_json) };
  return 0 unless $manifest;
  return 0 unless $manifest->{'mediaType'} eq ($oci ? $BSContar::mt_oci_manifest : $BSContar::mt_docker_manifest);
  return 0 unless @{$manifest->{'layers'} || []} == $numlayers;
  $knownblobs->{$manifest->{'config'}->{'digest'}} = 1 if $manifest->{'config'};
  $knownblobs->{$_->{'digest'}} = 1 for @{$manifest->{'layers'} || []};
  $knownmanifests->{$mani_id} = 1;
  return 1;
}

sub update_cosign {
  my ($prp, $repo, $gun, $digests_to_cosign, $pubkey, $signargs, $rekorserver, $knownmanifests, $knownblobs) = @_;

  my $creator = 'OBS';
  my ($projid, $repoid) = split('/', $prp, 2);
  my @signcmd;
  push @signcmd, $BSConfig::sign;
  push @signcmd, '--project', $projid if $BSConfig::sign_project;
  push @signcmd, @{$signargs || []};
  my $signfunc =  sub { BSUtil::xsystem($_[0], @signcmd, '-O', '-h', 'sha256') };
  my $repodir = "$registrydir/$repo";
  my $oldsigs = BSUtil::retrieve("$repodir/:cosign", 1) || {};
  return if !%$oldsigs && !%$digests_to_cosign;
  my $gpgpubkey = BSPGP::unarmor($pubkey);
  my $pubkey_fp = BSPGP::pk2fingerprint($gpgpubkey);
  if (($oldsigs->{'pubkey'} || '') ne $pubkey_fp || ($oldsigs->{'gun'} || '') ne $gun || ($oldsigs->{'creator'} || '') ne ($creator || '')) {
    $oldsigs = {};	# fingerprint/gun/creator mismatch, do not use old signatures
  }
  my $sigs = { 'pubkey' => $pubkey_fp, 'gun' => $gun, 'creator' => $creator, 'digests' => {}, 'attestations' => {} };

  # update signatures
  for my $digest (sort keys %$digests_to_cosign) {
    my $oci = 1;	# always use oci mime types
    my $old = ($oldsigs->{'digests'} || {})->{$digest};
    if ($old && reuse_cosign_manifest($repodir, $oci, $old, $knownmanifests, $knownblobs, 1)) {
      $sigs->{'digests'}->{$digest} = $old;
      next;
    }
    print "creating cosign signature for $gun $digest\n";
    my ($cosign_ent, $sig) = BSConSign::create_cosign_signature_ent($signfunc, $digest, $gun, $creator);
    my $mani_id = create_cosign_manifest($repodir, $oci, $knownmanifests, $knownblobs, $cosign_ent);
    $sigs->{'digests'}->{$digest} = $mani_id;
    if ($rekorserver) {
      print "uploading cosign signature to $rekorserver\n";
      my $sslpubkey = BSX509::keydata2pubkey(BSPGP::pk2keydata($gpgpubkey));
      $sslpubkey = BSASN1::der2pem($sslpubkey, 'PUBLIC KEY');
      my $hash = 'sha256:'.Digest::SHA::sha256_hex($cosign_ent->{'data'});	# must match signfunc
      BSRekor::upload_hashedrekord($rekorserver, $hash, $sslpubkey, $sig);
    }
  }

  # update attestations
  for my $digest (sort keys %$digests_to_cosign) {
    my $oci = 1;	# always use oci mime types
    my $containerinfo = $digests_to_cosign->{$digest}->[1];
    my $numlayers = ($containerinfo->{'slsa_provenance_file'} ? 1 : 0) + ($containerinfo->{'spdx_file'} ? 1 : 0) + ($containerinfo->{'cyclonedx_file'} ? 1 : 0) + scalar(@{$containerinfo->{'intoto_files'} || []});
    if (!$numlayers) {
      delete $sigs->{'attestations'}->{$digest};
      next;
    }
    my $old = ($oldsigs->{'attestations'} || {})->{$digest};
    if ($old && reuse_cosign_manifest($repodir, $oci, $old, $knownmanifests, $knownblobs, $numlayers)) {
      $sigs->{'attestations'}->{$digest} = $old;
      next;
    }
    print "creating $numlayers cosign attestations for $gun $digest\n";
    my %predicatetypes;
    my @attestations;
    push @attestations, BSConSign::fixup_intoto_attestation(readstr($containerinfo->{'slsa_provenance_file'}), $signfunc, $digest, $gun, \%predicatetypes) if $containerinfo->{'slsa_provenance_file'};
    push @attestations, BSConSign::fixup_intoto_attestation(readstr($containerinfo->{'spdx_file'}), $signfunc, $digest, $gun, \%predicatetypes) if $containerinfo->{'spdx_file'};
    push @attestations, BSConSign::fixup_intoto_attestation(readstr($containerinfo->{'cyclonedx_file'}), $signfunc, $digest, $gun, \%predicatetypes) if $containerinfo->{'cyclonedx_file'};
    push @attestations, BSConSign::fixup_intoto_attestation(readstr($_), $signfunc, $digest, $gun, \%predicatetypes) for @{$containerinfo->{'intoto_files'} || []};
    my @attestation_ents = BSConSign::create_cosign_attestation_ents(\@attestations, undef, \%predicatetypes);
    my $mani_id = create_cosign_manifest($repodir, $oci, $knownmanifests, $knownblobs, @attestation_ents);
    $sigs->{'attestations'}->{$digest} = $mani_id;
    if ($rekorserver) {
      print "uploading cosign attestations to $rekorserver\n";
      my $sslpubkey = BSX509::keydata2pubkey(BSPGP::pk2keydata($gpgpubkey));
      $sslpubkey = BSASN1::der2pem($sslpubkey, 'PUBLIC KEY');
      for my $attestation (@attestations) {
        BSRekor::upload_intoto($rekorserver, $attestation, $sslpubkey);
      }
    }
  }

  if (BSUtil::identical($oldsigs, $sigs)) {
    print "local cosign signatures: no change.\n";
    return;
  }
  if (%{$sigs->{'digests'}}) {
    BSUtil::store("$repodir/.cosign.$$", "$repodir/:cosign", $sigs);
  } else {
    unlink("$repodir/:cosign");
  }
}

sub create_manifestinfo {
  my ($prp, $repo, $containerinfo, $imginfo) = @_;

  my $repodir = "$registrydir/$repo";
  my ($projid, $repoid) = split('/', $prp, 2);
  # copy so we can add/delete stuff
  $imginfo = { %$imginfo, 'project' => $projid, 'repository' => $repoid };
  delete $imginfo->{'containerinfo'};
  my $bins = BSPublisher::Containerinfo::create_packagelist($containerinfo);
  $_->{'base'} && ($_->{'base'} = \1) for @{$bins || []};	# turn flag to True
  $imginfo->{'packages'} = $bins if $bins;
  push_manifestinfo($repodir, $imginfo->{'distmanifest'}, JSON::XS->new->utf8->canonical->encode($imginfo));
}

sub open_container_tar {
  my ($containerinfo, $file) = @_;
  my ($tar, $mtime);
  if (($containerinfo->{'type'} || '') eq 'artifacthub') {
    ($tar, $mtime) = BSContar::container_from_artifacthub($containerinfo->{'artifacthubdata'});
  } elsif (!defined($file)) {
    ($tar, $mtime) = BSPublisher::Containerinfo::construct_container_tar($containerinfo, 1);
    # set blobfile in entries so we can create a link in push_blob
    for (@$tar) {
      $_->{'blobfile'} = "$containerinfo->{'blobdir'}/_blob.$_->{'blobid'}" if $_->{'blobid'};
    }
  } elsif (($containerinfo->{'type'} || '') eq 'helm') {
    ($tar, $mtime) = BSContar::container_from_helm($file, $containerinfo->{'config_json'}, $containerinfo->{'tags'});
  } else {
    ($tar, $mtime) = BSContar::open_container_tar($file);
  }
  die("incomplete containerinfo\n") unless $tar; 
  return ($tar, $mtime);
}

sub push_containers {
  my ($registry, $projid, $repoid, $repo, $tags, $data) = @_;

  my ($pubkey, $signargs) = ($data->{'pubkey'}, $data->{'signargs'});

  my $rekorserver = $registry->{'rekorserver'};
  my $gun = $registry->{'notary_gunprefix'} || $registry->{'server'};
  undef $gun if $gun && $gun eq 'local:';
  if ($gun) {
    $gun =~ s/^https?:\/\///;
    $gun = "$gun/$repo";
  }
  my $containerdigests = '';

  my $prp = "$projid/$repoid";
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
  my %knownimagedigests;
  my %digests_to_cosign;

  my %info;
  my %have_manifestinfos;
  %have_manifestinfos = map {$_ => 1} ls("$repodir/:manifestinfos") if -d "$repodir/:manifestinfos";

  for my $tag (sort keys %$tags) {
    eval { BSVerify::verify_regtag($tag) };
    if ($@) {
      warn("ignoring tag: $@");
      next;
    }
    my $containerinfos = $tags->{$tag};
    my $multiarch = $data->{'multiarch'};
    $multiarch = 1 if @$containerinfos > 1;
    $multiarch = 0 if @$containerinfos == 1 && ($containerinfos->[0]->{'type'} || '') eq 'helm';
    $multiarch = 0 if @$containerinfos == 1 && ($containerinfos->[0]->{'type'} || '') eq 'artifacthub';
    die("must use multiarch if multiple containers are to be pushed\n") if @$containerinfos > 1 && !$multiarch;
    my %multiplatforms;
    my @multimanifests;
    my @imginfos;
    my $oci;
    # use oci types if we have a helm chart or we use a nonstandard compression
    for my $containerinfo (@$containerinfos) {
      $oci = 1 if ($containerinfo->{'type'} || '') eq 'helm' || ($containerinfo->{'type'} || '') eq 'artifacthub';
      $oci = 1 if grep {$_ && $_ ne 'gzip'} @{$containerinfo->{'layer_compression'} || []};
    }
    for my $containerinfo (@$containerinfos) {
      # check if we already processed this container with a different tag
      if ($done{$containerinfo}) {
	# yes, reuse data
        my ($multimani, $platformstr, $imginfo) = @{$done{$containerinfo}};
	if ($multiplatforms{$platformstr}) {
	  print "ignoring $containerinfo->{'file'}, already have $platformstr\n";
	  next;
	}
	$multiplatforms{$platformstr} = 1;
        push @multimanifests, $multimani;
        push @imginfos, $imginfo;
        $knownimagedigests{$imginfo->{'distmanifest'}}->{$tag} = 1;
	next;
      }

      my ($tar, $mtime) = open_container_tar($containerinfo, $containerinfo->{'uploadfile'});
      my %tar = map {$_->{'name'} => $_} @$tar;

      my ($manifest_ent, $manifest) = BSContar::get_manifest(\%tar);
      my ($config_ent, $config) = BSContar::get_config(\%tar, $manifest);

      my @layers = @{$manifest->{'Layers'} || []};
      die("container has no layers\n") unless @layers;
      my $config_layers;
      if ($config->{'rootfs'} && $config->{'rootfs'}->{'diff_ids'}) {
        $config_layers = $config->{'rootfs'}->{'diff_ids'};
        die("layer number mismatch\n") if @layers != @{$config_layers || []};
      }

      # see if a already have this arch/os combination
      my $govariant = $config->{'variant'} || $containerinfo->{'govariant'};
      my $goarch = $config->{'architecture'} || 'any';
      my $goos = $config->{'os'} || 'any';
      my $platformstr = BSContar::make_platformstr($goarch, $govariant, $goos);
      if ($multiplatforms{$platformstr}) {
	print "ignoring $containerinfo->{'file'}, already have $platformstr\n";
	next;
      }
      $multiplatforms{$platformstr} = 1;

      # put config blob into repo
      my $config_data = BSContar::create_config_data($config_ent, $oci);
      my $config_blobid = $config_ent->{'blobid'} = $config_data->{'digest'};
      push_blob($repodir, $config_ent);
      $knownblobs{$config_blobid} = 1;

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
	# normalize layer (but not if we reconstructed or we already have the mime type)
	if (!$layer_ent->{'mimetype'} && $containerinfo->{'uploadfile'}) {
	  $layer_ent = BSContar::normalize_layer($layer_ent, $oci);
	}
	my $layer_data = BSContar::create_layer_data($layer_ent, $oci);
	push @layer_data, $layer_data;
	$layer_datas{$layer_file} = $layer_data;

        my $layer_blobid = $layer_ent->{'blobid'} = $layer_data->{'digest'};
        push_blob($repodir, $layer_ent);
        $knownblobs{$layer_blobid} = 1;
      }

      # put manifest into repo
      my $mani = BSContar::create_dist_manifest_data($config_data, \@layer_data, $oci);
      my $mani_json = BSContar::create_dist_manifest($mani);
      my $mani_id = push_manifest($repodir, $mani_json);
      $knownmanifests{$mani_id} = 1;
      $digests_to_cosign{$mani_id} = [ $oci, $containerinfo ];

      my $multimani = {
	'mediaType' => $mani->{'mediaType'},
	'size' => length($mani_json),
	'digest' => $mani_id,
	'platform' => {'architecture' => $goarch, 'os' => $goos},
      };
      $multimani->{'platform'}->{'variant'} = $govariant if $govariant;
      push @multimanifests, $multimani;

      my $imginfo = {
	'imageid' => $config_blobid,
        'goarch' => $goarch,
        'goos' => $goos,
	'distmanifest' => $mani_id,
	'containerinfo' => $containerinfo,	# tmp, will be deleted later
      };
      $imginfo->{'govariant'} = $govariant if $govariant;
      $imginfo->{'type'} = $containerinfo->{'type'} if $containerinfo->{'type'};
      $imginfo->{'package'} = $containerinfo->{'_origin'} if $containerinfo->{'_origin'};
      $imginfo->{'disturl'} = $containerinfo->{'disturl'} if $containerinfo->{'disturl'};
      $imginfo->{'buildtime'} = $containerinfo->{'buildtime'} if $containerinfo->{'buildtime'};
      $imginfo->{'version'} = $containerinfo->{'version'} if $containerinfo->{'version'};
      $imginfo->{'release'} = $containerinfo->{'release'} if $containerinfo->{'release'};
      $imginfo->{'arch'} = $containerinfo->{'arch'};		# scheduler arch
      my @diff_ids = @{$config_layers || []};
      for (@layer_data) {
        my $l = { 'blobid' => $_->{'digest'}, 'blobsize' => $_->{'size'} };
        $l->{'diffid'} = shift @diff_ids if @diff_ids;
        push @{$imginfo->{'layers'}}, $l;
      }
      push @imginfos, $imginfo;
      $knownimagedigests{$imginfo->{'distmanifest'}}->{$tag} = 1;
      # cache result
      $done{$containerinfo} = [ $multimani, $platformstr, $imginfo ];

      if (!$have_manifestinfos{$mani_id}) {
	create_manifestinfo($prp, $repo, $containerinfo, $imginfo);
	$have_manifestinfos{$mani_id} = 1;
      }
    }
    next unless @multimanifests;
    my $taginfo = {
      'images' => \@imginfos,
    };
    my ($mani_id, $mani_size);
    if ($multiarch) {
      # create fat manifest
      my $mani = BSContar::create_dist_manifest_list_data(\@multimanifests, $oci);
      my $mani_json = BSContar::create_dist_manifest_list($mani);
      $mani_id = push_manifest($repodir, $mani_json, \%knownmanifests);
      $mani_size = length($mani_json);
      $knownmanifests{$mani_id} = 1;
      $taginfo->{'distmanifesttype'} = 'list';
      $digests_to_cosign{$mani_id} = [ $oci ];
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
    $data->{'regdata_cb'}->($data, $registry, "$repo:$tag", $taginfo) if $data->{'regdata_cb'};
  }

  # write signatures file (need to do this early as it adds manifests/blobs)
  if ($gun && defined($pubkey) && %digests_to_cosign) {
    update_cosign($prp, $repo, $gun, \%digests_to_cosign, $pubkey, $signargs, $rekorserver, \%knownmanifests, \%knownblobs);
  } elsif (-e "$repodir/:cosign") {
    unlink("$repodir/:cosign");
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
  for (sort(keys %have_manifestinfos)) {
    next if $knownmanifests{$_};
    unlink("$repodir/:manifestinfos/$_");
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
    rmdir("$repodir/:manifestinfos");
    unlink("$repodir/:info");
    unlink("$repodir/:tuf.old");
    unlink("$repodir/:tuf");
    unlink("$repodir/:sigs");
    unlink("$repodir/:cosign");
    disownrepo($prp, $repo);
    return $containerdigests;
  }

  # get rid of the containerinfo elements again
  for my $taginfo (values %info) {
    delete $_->{'containerinfo'} for @{$taginfo->{'images'} || []};
  }

  # write info file
  my $info = { 'project' => $projid, 'repository' => $repoid, 'tags' => \%info };
  $info->{'gun'} = $gun if $gun;
  my $oldinfo = BSUtil::retrieve("$repodir/:info", 1);
  if (BSUtil::identical($oldinfo, $info)) {
    print "local registry: no change\n";
  } else {
    if ($data->{'notify'} && $gun) {
      for my $tag (sort keys %info) {
        $data->{'notify'}->("$gun:$tag") unless $oldinfo && BSUtil::identical(($oldinfo->{'tags'} || {})->{$tag}, $info{$tag});
      }
    }
    BSUtil::store("$repodir/.info.$$", "$repodir/:info", $info);
  }

  # write TUF file
  if ($gun && defined($pubkey)) {
    update_tuf($prp, $repo, $gun, $containerdigests, $pubkey, $signargs);
  } elsif (-e "$repodir/:tuf") {
    unlink("$repodir/:tuf.old");
    unlink("$repodir/:tuf");
  }

  # write signatures file
  if ($gun && defined($pubkey)) {
    update_sigs($prp, $repo, $gun, \%knownimagedigests, $pubkey, $signargs);
  } elsif (-e "$repodir/:sigs") {
    unlink("$repodir/:sigs");
  }

  # and we're done, return digests
  return $containerdigests;
}

1;

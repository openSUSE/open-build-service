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
use Digest::SHA ();
use Time::Local ();

use BSConfiguration;
use BSWatcher ':https';
use BSTUF;
use BSUtil;
use BSVerify;
use BSBearer;
use BSContar;

use BSRepServer::Containertar;
use BSRepServer::Containerinfo;


use strict;

my $uploaddir = "$BSConfig::bsdir/upload";
my $blobdir = "$BSConfig::bsdir/blobs";

my %registry_authenticators;

sub select_manifest {
  my ($mani, $goarch, $goos, $govariant) = @_;
  for my $m (@{$mani->{'manifests'} || []}) {
    next if $govariant && $m->{'platform'}->{'variant'} && $m->{'platform'}->{'variant'} ne $govariant;
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

sub blobstore_put {
  my ($f, $dir) = @_;
  return unless $f =~ /^_blob\.sha256:([0-9a-f]{3})([0-9a-f]{61})$/s;
  my ($d, $b) = ($1, $2);
  my @s = stat("$blobdir/sha256/$d/$b");
  if (!@s) {
    mkdir_p("$blobdir/sha256/$d") unless -d "$blobdir/sha256/$d";
    return if link("$dir/$f", "$blobdir/sha256/$d/$b");
  }
  return unless link("$blobdir/sha256/$d/$b", "$blobdir/sha256/$d/$b.$$");
  return if rename("$blobdir/sha256/$d/$b.$$", "$dir/$f");
  unlink("$blobdir/sha256/$d/$b.$$");
}

sub blobstore_get {
  my ($f, $dir) = @_;
  return undef unless $f =~ /^_blob\.sha256:([0-9a-f]{3})([0-9a-f]{61})$/s;
  my ($d, $b) = ($1, $2);
  return link("$blobdir/sha256/$d/$b", "$dir/$f") ? 1 : undef;
}

sub blob_matches_digest {
  my ($tmp, $digest) = @_;
  my $ctx;
  $ctx = Digest::SHA->new($1) if $digest =~ /^sha(256|512):/;
  return 0 unless $ctx;
  my $fd;
  return 0 unless open ($fd, '<', $tmp);
  $ctx->addfile($fd);
  close($fd);
  return (split(':', $digest, 2))[1] eq $ctx->hexdigest() ? 1 : 0;
}

sub doauthrpc {
  my ($param, $xmlargs, @args) = @_;
  $param = { %$param, 'resulthook' => sub { $xmlargs->($_[0]) } };
  return BSWatcher::rpc($param, $xmlargs, @args);
}

sub download_blobs {
  my ($dir, $url, $regrepo, $blobs, $proxy, $maxredirects) = @_;

  $url .= '/' unless $url =~ /\/$/;
  for my $blob (@$blobs) {
    next if -e "$dir/_blob.$blob";
    next if blobstore_get("_blob.$blob", $dir);
    my $tmp = "$dir/._blob.$blob.$$";
    my $authenticator = $registry_authenticators{"$url$regrepo"};
    $authenticator = $registry_authenticators{"$url$regrepo"} = BSBearer::generate_authenticator(undef, 'verbose' => 1, 'rpccall' => \&doauthrpc, 'proxy' => $proxy) unless $authenticator;
    my $bloburl = "${url}v2/$regrepo/blobs/$blob";
    # print "fetching: $bloburl\n";
    my $param = {'uri' => $bloburl, 'filename' => $tmp, 'receiver' => \&BSHTTP::file_receiver, 'proxy' => $proxy};
    $param->{'authenticator'} = $authenticator;
    $param->{'maxredirects'} = $maxredirects if defined $maxredirects;
    my $r;
    eval { $r = BSWatcher::rpc($param); };
    if ($@) {
      unlink($tmp);
      $@ =~ s/(\d* *)/$1$bloburl: /;
      die($@);
    }
    return unless defined $r;
    if (!blob_matches_digest($tmp, $blob)) {
      unlink($tmp);
      die("$bloburl: blob does not match digest\n");
    }
    rename($tmp, "$dir/_blob.$blob") || die("rename $tmp $dir/_blob.$blob: $!\n");
    blobstore_put("_blob.$blob", $dir);
  }
  return 1;
}

sub construct_containerinfo {
  my ($dir, $pkgname, $data, $blobs) = @_;

  BSVerify::verify_filename($pkgname);
  BSVerify::verify_simple($pkgname);

  # delete old cruft
  unlink("$dir/$pkgname.containerinfo");
  unlink("$dir/$pkgname.obsbinlnk");

  # try to get a timestamp from the config blob for reproducibility
  my $mtime = time();
  if (-e "$dir/_blob.$blobs->[0]" && -s _ < 65536) {
    my $configjson = readstr("$dir/_blob.$blobs->[0]", 1) || '';
    if ($configjson =~ /\"created\"\s*?:\s*?\"([123]\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/) {
      my $t = eval { Time::Local::timegm($6, $5, $4, $3, $2 - 1, $1) };
      warn($@) if $@;
      $mtime = $t if $t && $t < $mtime;
    }
  }

  # hack: get tags from provides
  my @tags;
  for (@{$data->{'provides' || []}}) {
    push @tags, $_ unless / = /;
  }
  push @tags, $data->{'name'} unless @tags;
  s/^container:// for @tags;
  my ($config, @layers) = @$blobs;
  my $manifest = BSContar::create_tar_manifest_data($config, \@layers, \@tags);
  my $manifest_ent = BSContar::create_tar_manifest_entry($manifest, $mtime);
  my $containerinfo = {
    'tar_manifest' => $manifest_ent->{'data'},
    'tar_size' => 1,	# make construct_container_tar() happy
    'tar_mtime' => $mtime,
    'tar_blobids' => $blobs,
    'name' => $pkgname,
    'version' => $data->{'version'},
    'imageid' => $config,
    'tags' => \@tags,
    'file' => "$pkgname.tar",
  };
  $containerinfo->{'imageid'} =~ s/^sha256://;	# like in Containertar.pm
  $containerinfo->{'release'} = $data->{'release'} if defined $data->{'release'};
  my ($tar) = BSRepServer::Containertar::construct_container_tar($dir, $containerinfo);
  ($containerinfo->{'tar_md5sum'}, $containerinfo->{'tar_sha256sum'}, $containerinfo->{'tar_size'}) = BSContar::checksum_tar($tar);
  if ($data->{'annotation'}) {
    my $annotation = BSUtil::fromxml($data->{'annotation'}, $BSXML::binannotation, 1) || {};
    $containerinfo->{'registry_refname'} = $annotation->{'registry_refname'} if $annotation->{'registry_refname'};
    $containerinfo->{'registry_digest'} = $annotation->{'registry_digest'} if $annotation->{'registry_digest'};
    $containerinfo->{'registry_fatdigest'} = $annotation->{'registry_fatdigest'} if $annotation->{'registry_fatdigest'};
  }
  BSRepServer::Containerinfo::writecontainerinfo("$dir/.$pkgname.containerinfo", "$dir/$pkgname.containerinfo", $containerinfo);

  # write obsbinlnk file (do this last!)
  my $lnk = BSRepServer::Containerinfo::containerinfo2nevra($containerinfo);
  $lnk->{'source'} = $lnk->{'name'};
  # add self-provides
  push @{$lnk->{'provides'}}, "$lnk->{'name'} = $lnk->{'version'}";
  for my $tag (@{$containerinfo->{tags}}) {
    push @{$lnk->{'provides'}}, "container:$tag" unless "container:$tag" eq $lnk->{'name'};
  }
  BSVerify::verify_nevraquery($lnk);
  $lnk->{'hdrmd5'} = $containerinfo->{'tar_md5sum'};
  $lnk->{'path'} = "$pkgname.tar";
  $lnk->{'annotation'} = $data->{'annotation'} if $data->{'annotation'};
  BSUtil::store("$dir/.$pkgname.obsbinlnk", "$dir/$pkgname.obsbinlnk", $lnk);
}

1;

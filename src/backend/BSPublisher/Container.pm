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
# Container handling of the publisher
#

package BSPublisher::Container;

use File::Temp qw/tempfile/;
use JSON::XS ();

use BSConfiguration;
use BSPublisher::Util;
use BSPublisher::Registry;
use BSPublisher::Containerinfo;
use BSUtil;
use BSTar;
use BSRepServer::Containerinfo;
use Build::Rpm;		# for verscmp_part

use strict;

my $uploaddir = "$BSConfig::bsdir/upload";

=head2 registries_for_prp - find registries for this project/repository
 
 Parameters:
  projid - published project
  repoid - published repository

 Returns:
  Array of registries

=cut

sub registries_for_prp {
  my ($projid, $repoid) = @_;
  return () unless $BSConfig::publish_containers && $BSConfig::container_registries;
  my @registries;
  my @s = @{$BSConfig::publish_containers};
  while (@s) {
    my ($k, $v) = splice(@s, 0, 2);
    if ("$projid/$repoid" =~ /^$k/ || $projid =~ /^$k/) {
      $v = [ $v ] unless ref $v;
      @registries = @$v;
      last;
    }
  }
  # convert registry names to configs
  for my $registry (BSUtil::unify(splice @registries)) {
    my $cr = $BSConfig::container_registries->{$registry};
    if (!$cr || (!$cr->{'server'} && !$cr->{'pushserver'})) {
      print "no valid registry config for '$registry'\n";
      next;
    }
    push @registries, { %$cr, '_name' => $registry };
  }
  return @registries;
}

sub have_good_project_signkey {
  my ($signargs) = @_;
  return 0 unless @{$signargs || []} >= 2;
  return 0 if $signargs->[0] ne '-P';
  return (-s $signargs->[1]) >= 10;
}

sub get_notary_pubkey {
  my ($projid, $pubkey, $signargs) = @_;

  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  push @signargs, '--signtype', 'notary' if $BSConfig::sign_type || $BSConfig::sign_type;
  push @signargs, @{$signargs || []};

  # ask the sign tool for the correct pubkey if we do not have a good sign key
  if ($BSConfig::sign_project && $BSConfig::sign && !have_good_project_signkey($signargs)) {
    local *S;
    open(S, '-|', $BSConfig::sign, @signargs, '-p') || die("$BSConfig::sign: $!\n");;
    $pubkey = '';
    1 while sysread(S, $pubkey, 4096, length($pubkey));
    if (!close(S)) {
      print "sign -p failed: $?\n";
      $pubkey = undef;
    }
  }

  # check pubkey
  die("could not determine pubkey for notary signing\n") unless $pubkey;
  my $pkalgo;
  eval { $pkalgo = BSPGP::pk2algo(BSPGP::unarmor($pubkey)) };
  if ($pkalgo && $pkalgo ne 'rsa') {
    print "public key algorithm is '$pkalgo', skipping notary upload\n";
    return (undef, undef);
  }
  # get rid of --project option
  splice(@signargs, 0, 2) if $BSConfig::sign_project;
  return ($pubkey, \@signargs);
}

=head2 default_container_mapper - map container data to registry repository/tags
 
=cut

sub default_container_mapper {
  my ($registry, $containerinfo, $projid, $repoid, $arch) = @_;

  my $repository_base = $registry->{repository_base} || '/';
  my $delimiter       = $registry->{repository_delimiter} || '/';
  $projid =~ s/:/$delimiter/g;
  $repoid =~ s/:/$delimiter/g;
  my $repository = lc("$repository_base$projid/$repoid");
  $repository =~ s/^\///;
  return map {"$repository/$_"} @{$containerinfo->{'tags'} || []};
}

sub calculate_container_state {
  my ($projid, $repoid, $containers, $multicontainer) = @_;
  my @registries = registries_for_prp($projid, $repoid);
  my $container_state = '';
  $container_state .= "//multi//" if $multicontainer;
  my @cs;
  for my $registry (@registries) {
    my $regname = $registry->{'_name'};
    my $mapper = $registry->{'mapper'} || \&default_container_mapper;
    for my $p (sort keys %$containers) {
      my $containerinfo = $containers->{$p};
      my $arch = $containerinfo->{'arch'};
      my @tags = $mapper->($registry, $containerinfo, $projid, $repoid, $arch);
      my $prefix = "$containerinfo->{'_id'}/$regname/$containerinfo->{'arch'}/";
      push @cs, map { "$prefix$_" } @tags;
    }
  }
  $container_state .= join('//', sort @cs);
  return $container_state;
}

=head2 cmp_containerinfo - compare the version/release of two containers
 
=cut

sub cmp_containerinfo {
  my ($containerinfo1, $containerinfo2) = @_;
  my $r;
  $r = Build::Rpm::verscmp_part($containerinfo1->{'version'} || '0', $containerinfo2->{'version'} || 0);
  return $r if $r;
  $r = Build::Rpm::verscmp_part($containerinfo1->{'release'} || '0', $containerinfo2->{'release'} || 0);
  return $r if $r;
  return 0;
}

=head2 upload_all_containers - upload found containers to the configured registries
 
=cut

sub upload_all_containers {
  my ($extrep, $projid, $repoid, $containers, $pubkey, $signargs, $multicontainer, $old_container_repositories) = @_;

  my $isdelete;
  if (!defined($containers)) {
    $isdelete = 1;
    $containers = {};
  } else {
    ($pubkey, $signargs) = get_notary_pubkey($projid, $pubkey, $signargs);
  }

  my $notary_uploads = {};
  my $have_some_trust;
  my @registries = registries_for_prp($projid, $repoid);

  my %allrefs;
  my %container_repositories;
  $old_container_repositories ||= {};
  for my $registry (@registries) {
    my $regname = $registry->{'_name'};
    my $registryserver = $registry->{pushserver} || $registry->{server};

    # collect uploads over all containers, decide which container to take
    # if there is a tag conflict
    my %uploads;
    my $mapper = $registry->{'mapper'} || \&default_container_mapper;
    for my $p (sort keys %$containers) {
      my $containerinfo = $containers->{$p};
      my $arch = $containerinfo->{'arch'};
      my $goarch = $containerinfo->{'goarch'};
      $goarch .= ":$containerinfo->{'govariant'}" if $containerinfo->{'govariant'};
      $goarch .= "_$containerinfo->{'goos'}" if $containerinfo->{'goos'} && $containerinfo->{'goos'} ne 'linux';
      my @tags = $mapper->($registry, $containerinfo, $projid, $repoid, $arch);
      for my $tag (@tags) {
	my ($reponame, $repotag) = ($tag, 'latest');
	($reponame, $repotag) = ($1, $2) if $tag =~ /^(.*):([^:\/]+)$/;
	if ($uploads{$reponame}->{$repotag}->{$goarch}) {
	  my $otherinfo = $containers->{$uploads{$reponame}->{$repotag}->{$goarch}};
	  next if cmp_containerinfo($otherinfo, $containerinfo) > 0;
	}
	$uploads{$reponame}->{$repotag}->{$goarch} = $p;
      }
    }

    # ok, now go through every repository and upload all tags
    for my $repository (sort keys %uploads) {
      $container_repositories{$regname}->{$repository} = 1;

      my $uptags = $uploads{$repository};

      if ($registryserver eq 'local:') {
	my $gunprefix = $registry->{'notary_gunprefix'} || $registry->{'server'};
	$have_some_trust = 1 if defined($pubkey) && $gunprefix && $gunprefix ne 'local:';
	do_local_uploads($registry, $projid, $repoid, $repository, $containers, $pubkey, $signargs, $multicontainer, $uptags);
      } else {
        do_remote_uploads($registry, $projid, $repoid, $repository, $containers, $pubkey, $signargs, $multicontainer, $uptags, $notary_uploads);
      }

      # add references
      my $pullserver = $registry->{'server'};
      if ($pullserver && $pullserver ne 'local:') {
        $pullserver =~ s/https?:\/\///;
        $pullserver =~ s/\/?$/\//;
        $pullserver = '' if $registryserver ne 'local:' && $pullserver =~ /docker.io\/$/;
	for my $tag (sort keys %$uptags) {
	  my @p = sort(values %{$uptags->{$tag}});
	  push @{$allrefs{$_}}, "$pullserver$repository:$tag" for @p;
	}
      }
    }

    # delete repositories of former publish runs that are now empty
    for my $repository (@{$old_container_repositories->{$regname} || []}) {
      next if $uploads{$repository};
      if ($registryserver eq 'local:') {
        do_local_uploads($registry, $projid, $repoid, $repository, $containers, $pubkey, $signargs, $multicontainer, undef);
	next;
      } else {
        do_remote_uploads($registry, $projid, $repoid, $repository, $containers, $pubkey, $signargs, $multicontainer, undef, $notary_uploads);
      }
    }
  }
  $have_some_trust = 1 if %$notary_uploads;

  # postprocessing: write readme, create links
  my %allrefs_pp;
  my %allrefs_pp_lastp;
  for my $p (sort keys %$containers) {
    my $containerinfo = $containers->{$p};
    my $pp = $p;
    $pp =~ s/.*?\/// if $multicontainer;
    $allrefs_pp_lastp{$pp} = $p;	# for link creation
    push @{$allrefs_pp{$pp}}, @{$allrefs{$p} || []};	# collect all archs for the link
  }
  for my $pp (sort keys %allrefs_pp_lastp) {
    mkdir_p($extrep);
    unlink("$extrep/$pp.registry.txt");
    if (@{$allrefs_pp{$pp} || []}) {
      unlink("$extrep/$pp");
      # write readme file where to find the container
      my @r = sort(BSUtil::unify(@{$allrefs_pp{$pp}}));
      my $readme = "This container can be pulled via:\n";
      $readme .= "  docker pull $_\n" for @r;
      $readme .= "\nSet DOCKER_CONTENT_TRUST=1 to enable image tag verification.\n" if $have_some_trust;
      writestr("$extrep/$pp.registry.txt", undef, $readme);
    } elsif ($multicontainer && $allrefs_pp_lastp{$pp} ne $pp) {
      # create symlink to last arch
      unlink("$extrep/$pp");
      symlink("$allrefs_pp_lastp{$pp}", "$extrep/$pp");
    }
  }

  # do notary uploads
  if (%$notary_uploads) {
    if ($isdelete) {
      delete_from_notary($projid, $notary_uploads);
    } else {
      if (!defined($pubkey)) {
	print "skipping notary upload\n";
      } else {
        upload_to_notary($projid, $notary_uploads, $signargs, $pubkey);
      }
    }
  }

  # turn container repos into arrays and return
  $_ = [ sort keys %$_ ] for values %container_repositories;
  return \%container_repositories;
}

sub reconstruct_container {
  my ($containerinfo, $dst, $dstfinal) = @_;
  my ($tar, $mtime) = BSPublisher::Containerinfo::construct_container_tar($containerinfo);
  BSTar::writetarfile($dst, $dstfinal, $tar, 'mtime' => $mtime) if $tar;
}

sub create_container_dist_info {
  my ($containerinfo, $oci, $platforms) = @_;
  my $file = $containerinfo->{'publishfile'};
  my ($tar, $mtime, $layer_compression);
  if (!defined($file)) {
    ($tar, $mtime, $layer_compression) = BSPublisher::Containerinfo::construct_container_tar($containerinfo, 1);
  } elsif (($containerinfo->{'type'} || '') eq 'helm') {
    ($tar, $mtime, $layer_compression) = BSContar::container_from_helm($file, $containerinfo->{'config_json'}, $containerinfo->{'tags'});
  } elsif ($file =~ /\.tar$/) {
    my $tarfd;
    open($tarfd, '<', $file) || die("$file: $!\n");
    $tar = BSTar::list($tarfd);
    $_->{'file'} = $tarfd for @$tar;
  } else {
    my $tmpfile = decompress_container($file);
    my $tarfd;
    open($tarfd, '<', $tmpfile) || die("$tmpfile: $!\n");
    unlink($tmpfile);
    $tar = BSTar::list($tarfd);
    $_->{'file'} = $tarfd for @$tar;
  }
  die("incomplete containerinfo\n") unless $tar;
  my %tar = map {$_->{'name'} => $_} @$tar;
  my ($manifest_ent, $manifest) = BSContar::get_manifest(\%tar);
  my ($config_ent, $config) = BSContar::get_config(\%tar, $manifest);
  my $goarch = $config->{'architecture'} || 'any';
  my $goos = $config->{'os'} || 'any';
  my $govariant = $containerinfo->{'govariant'};
  $govariant = $config->{'variant'} if $config->{'variant'};

  if ($platforms) {
    my $platformstr = "architecture:$goarch os:$goos";
    $platformstr .= " variant:$govariant" if $govariant;
    return undef if $platforms->{$platformstr};
    $platforms->{$platformstr} = 1;
  }

  my $config_data = BSContar::create_config_data($config_ent, $oci);
  my @layer_data;
  die("container has no layers\n") unless @{$manifest->{'Layers'} || []};
  my @layer_comp = @{$layer_compression || []};
  for my $layer_file (@{$manifest->{'Layers'}}) {
    my $layer_ent = $tar{$layer_file};
    die("file $layer_file not included in tar\n") unless $layer_ent;
    my $lcomp = shift @layer_comp;
    ($layer_ent, $lcomp) = BSContar::normalize_layer($layer_ent, $oci, $lcomp);
    my $layer_data = BSContar::create_layer_data($layer_ent, $oci, $lcomp);
    push @layer_data, $layer_data;
  }
  my $mani = BSContar::create_dist_manifest_data($config_data, \@layer_data, $oci);
  my $mani_json = BSContar::create_dist_manifest($mani);
  my $info = {
    'mediaType' => $mani->{'mediaType'},
    'size' => length($mani_json),
    'digest' => BSContar::blobid($mani_json),
    'platform' => {'architecture' => $goarch, 'os' => $goos},
  };
  $info->{'platform'}->{'variant'} = $govariant if $govariant;
  return $info;
}

sub create_container_index_info {
  my ($infos, $oci) = @_;
  my $mani = BSContar::create_dist_manifest_list_data($infos || [], $oci);
  my $mani_json = BSContar::create_dist_manifest_list($mani);
  my $info = {
    'mediaType' => $mani->{'mediaType'},
    'size' => length($mani_json),
    'digest' => BSContar::blobid($mani_json),
  };
  return $info;
}

sub query_repostate {
  my ($registry, $repository) = @_;
  my $registryserver = $registry->{pushserver} || $registry->{server};
  my $pullserver = $registry->{server};
  $pullserver =~ s/https?:\/\///;
  $pullserver =~ s/\/?$/\//;
  $pullserver = '' if $pullserver =~ /docker.io\/$/;
  $repository = "library/$repository" if $pullserver eq '' && $repository !~ /\//;
  mkdir_p($uploaddir);
  my $tempfile = "$uploaddir/publisher.$$.repostate";
  unlink($tempfile);
  print "querying state of $repository on $registryserver\n";
  my @opts = ('-l');
  push @opts, '--no-cosign-info' if $registry->{'cosign_nocheck'};
  my @cmd = ("$INC[0]/bs_regpush", '--dest-creds', '-', @opts, $registryserver, $repository);
  my $now = time();
  my $result = BSPublisher::Util::qsystem('echo', "$registry->{user}:$registry->{password}\n", 'stdout', $tempfile, @cmd);
  my $repostate;
  if (!$result) {
    my $fd;
    open ($fd, '<', $tempfile) || die("$tempfile: $!\n");
    $repostate = {};
    while (<$fd>) {
      my @s = split(' ', $_);
      if (@s == 4 && $s[0] =~ /\.(?:sig|att)$/ && $s[3] =~ /^cosigncookie=/) {
        $repostate->{$s[0]} = $s[3];
      } elsif (@s >= 2) {
        $repostate->{$s[0]} = $s[1];
      }
    }
    close($fd);
    printf "query took %d seconds, found %d tags\n", time() - $now, scalar(keys %$repostate);
  }
  unlink($tempfile);
  return $repostate;
}

sub create_manifestinfo {
  my ($registry, $prp, $repository, $containerinfo, $imginfo) = @_;

  my $dir = $registry->{'manifestinfos'};
  my $mani_id = $imginfo->{'distmanifest'};
  return unless $dir && $mani_id;
  return if "/$repository/" =~ /\/[\.\/]/;	# hey!
  return if -s "$dir/$repository/$mani_id";
  $imginfo = { %$imginfo };
  my ($projid, $repoid) = split('/', $prp, 2);
  $imginfo->{'type'} = $containerinfo->{'type'} if $containerinfo->{'type'};
  $imginfo->{'package'} = $containerinfo->{'_origin'} if $containerinfo->{'_origin'};
  $imginfo->{'disturl'} = $containerinfo->{'disturl'} if $containerinfo->{'disturl'};
  $imginfo->{'buildtime'} = $containerinfo->{'buildtime'} if $containerinfo->{'buildtime'};
  $imginfo->{'version'} = $containerinfo->{'version'} if $containerinfo->{'version'};
  $imginfo->{'release'} = $containerinfo->{'release'} if $containerinfo->{'release'};
  $imginfo->{'arch'} = $containerinfo->{'arch'};            # scheduler arch
  my $bins = BSPublisher::Containerinfo::create_packagelist($containerinfo);
  $_->{'base'} && ($_->{'base'} = \1) for @{$bins || []};       # turn flag to True
  $imginfo->{'packages'} = $bins if $bins;
  $imginfo->{'project'} = $projid;
  $imginfo->{'repository'} = $repoid;
  mkdir_p("$dir/$repository");
  my $imginfo_json = JSON::XS->new->utf8->canonical->encode($imginfo);
  unlink("$dir/$repository/.$mani_id.$$");
  writestr("$dir/$repository/.$mani_id.$$", "$dir/$repository/$mani_id", $imginfo_json);
}

sub compare_to_repostate {
  my ($registry, $repostate, $repository, $containerinfos, $tags, $multiarch, $oci, $cosigncookie, $cosign_attestation) = @_;
  my %expected;
  my $containerdigests = '';
  my $info;
  my $cosign_expect = $cosigncookie && !$registry->{'cosign_nocheck'} ? "cosigncookie=$cosigncookie" : '-';
  my $manifestinfodir;
  if ($registry->{'manifestinfos'} && "/$repository/" !~ /\/[\.\/]/) {
    $manifestinfodir = "$registry->{'manifestinfos'}/$repository";
  }
  my $missing_manifestinfo;
  if ($multiarch) {
    my %platforms;
    my @infos;
    for my $containerinfo (@$containerinfos) {
      $info = create_container_dist_info($containerinfo, $oci, \%platforms);
      $missing_manifestinfo = 1 if $manifestinfodir && ! -s "$manifestinfodir/$info->{'digest'}";
      if ($cosigncookie && $cosign_attestation && ($containerinfo->{'slsa_provenance'} || $containerinfo->{'spdx_file'} ||  $containerinfo->{'cyclonedx_file'} )) {
	my $atttag = $info->{'digest'};
	$atttag =~ s/:(.*)/-$1.att/;
	$expected{$atttag} = $cosign_expect;
      }
      push @infos, { %$info };	# copy so that size is not stringified
      $containerdigests .= "$info->{'digest'} $info->{'size'}\n";
      if ($cosigncookie) {
	my $sigtag = $info->{'digest'};
	$sigtag =~ s/:(.*)/-$1.sig/;
	$expected{$sigtag} = $cosign_expect;
      }
    }
    $info = create_container_index_info(\@infos, $oci);
  } else {
    my $containerinfo = $containerinfos->[0];
    $info = create_container_dist_info($containerinfo, $oci);
    $missing_manifestinfo = 1 if $manifestinfodir && ! -s "$manifestinfodir/$info->{'digest'}";
    if ($cosigncookie && $cosign_attestation && ($containerinfo->{'slsa_provenance'} || $containerinfo->{'spdx_file'} || $containerinfo->{'cyclonedx_file'})) {
      my $atttag = $info->{'digest'};
      $atttag =~ s/:(.*)/-$1.att/;
      $expected{$atttag} = $cosign_expect;
    }
  }
  $containerdigests .= "$info->{'digest'} $info->{'size'} $_\n" for @$tags;
  $expected{$_} = $info->{'digest'} for @$tags;
  if ($cosigncookie) {
    my $sigtag = $info->{'digest'};
    $sigtag =~ s/:(.*)/-$1.sig/;
    $expected{$sigtag} = $cosign_expect;
  }
  if (!$missing_manifestinfo && !grep {($repostate->{$_} || '') ne $expected{$_}} sort keys %expected) {
    return $containerdigests;
  }
  return undef;
}

=head2 upload_to_registry - upload container(s) to a set of tags

 Parameters:
  registry       - config for registry
  projid/repoid  - container origin
  repository     - registry repository name
  containerinfos - array of containers to upload (more than one for multiarch)
  tags           - array of tags to upload to

 Returns:
  containerdigests

=cut

sub upload_to_registry {
  my ($registry, $projid, $repoid, $repository, $containerinfos, $tags, $pubkey, $signargs, $multicontainer, $repostate) = @_;

  return '' unless @{$containerinfos || []} && @{$tags || []};
  
  my $registryserver = $registry->{pushserver} || $registry->{server};
  my $pullserver = $registry->{server};
  $pullserver =~ s/https?:\/\///;
  $pullserver =~ s/\/?$/\//;
  $repository = "library/$repository" if $repository !~ /\// && $registry->{server} =~ /docker.io\/?$/ && $repository !~ /\//;

  $multicontainer = 0;
  my $multiarch = @$containerinfos > 1 || $multicontainer ? 1 : 0;
  $multiarch = 0 if @$containerinfos == 1 && ($containerinfos->[0]->{'type'} || '') eq 'helm';
  my $oci;
  for my $containerinfo (@$containerinfos) {
    $oci = 1 if ($containerinfo->{'type'} || '') eq 'helm';
    $oci = 1 if grep {$_ && $_ ne 'gzip'} @{$containerinfo->{'layer_compression'} || []};
  }

  my $cosign = $registry->{'cosign'};
  $cosign = $cosign->($repository, $projid) if $cosign && ref($cosign) eq 'CODE';
  my $cosign_attestation = $cosign;
  if (defined $registry->{'cosign_attestation'}) {
    $cosign_attestation = $registry->{'cosign_attestation'};
    $cosign_attestation = $cosign_attestation->($repository, $projid) if $cosign_attestation && ref($cosign_attestation) eq 'CODE';
  }
  
  my $cosigncookie;
  if (defined($pubkey) && $cosign) {
    my $gun = $registry->{'notary_gunprefix'} || $registry->{'server'};
    $gun =~ s/^https?:\/\///;
    $gun .= "/$repository";
    my $creator = 'OBS';
    $cosigncookie = BSConSign::createcosigncookie($pubkey, $gun, $creator);
  }

  # check if the registry is up-to-date
  if ($repostate) {
    my $containerdigests = compare_to_repostate($registry, $repostate, $repository, $containerinfos, $tags, $multiarch, $oci, $cosigncookie, $cosign_attestation);
    return $containerdigests if defined $containerdigests;
  }

  # decompress tar files
  my @tempfiles;
  my @uploadfiles;
  my $blobdir;
  my $do_slsaprovenance;
  my $do_sbom;
  for my $containerinfo (@$containerinfos) {
    my $file = $containerinfo->{'publishfile'};
    my $wrote_containerinfo;
    if (!defined($file)) {
      # tar file needs to be constructed from blobs
      $blobdir = $containerinfo->{'blobdir'};
      die("need a blobdir for containerinfo uploads\n") unless $blobdir;
      push @uploadfiles, "$blobdir/container.".scalar(@uploadfiles).".containerinfo";
      BSRepServer::Containerinfo::writecontainerinfo($uploadfiles[-1], undef, $containerinfo);
      $wrote_containerinfo = 1;
    } elsif ($file =~ /(.*)\.tgz$/ && ($containerinfo->{'type'} || '') eq 'helm') {
      my $helminfofile = "$1.helminfo";
      $blobdir = $containerinfo->{'blobdir'};
      die("need a blobdir for helminfo uploads\n") unless $blobdir;
      die("bad publishfile\n") unless $helminfofile =~ /^\Q$blobdir\E\//;	# just in case
      push @uploadfiles, $helminfofile;
      BSRepServer::Containerinfo::writecontainerinfo($uploadfiles[-1], undef, $containerinfo);
      $wrote_containerinfo = 1;
    } elsif ($file =~ /\.tar$/) {
      push @uploadfiles, $file;
    } else {
      my $tmpfile = decompress_container($file);
      push @uploadfiles, $tmpfile;
      push @tempfiles, $tmpfile;
    }
    # copy provenance file into blobdir
    if ($wrote_containerinfo && $containerinfo->{'slsa_provenance'} && $cosign_attestation) {
      my $provenancefile = $uploadfiles[-1];
      die unless $provenancefile =~ s/\.[^\.]+$/.slsa_provenance.json/;
      writestr($provenancefile, undef, $containerinfo->{'slsa_provenance'});
      $do_slsaprovenance = 1;
    }
    if ($wrote_containerinfo && $containerinfo->{'spdx_file'} && $cosign_attestation) {
      my $spdx_file = $uploadfiles[-1];
      die unless $spdx_file =~ s/\.[^\.]+$/.spdx.json/;
      BSUtil::cp($containerinfo->{'spdx_file'}, $spdx_file) if $containerinfo->{'spdx_file'} ne $spdx_file;
      $do_sbom = 1;
    }
    if ($wrote_containerinfo && $containerinfo->{'cyclonedx_file'} && $cosign_attestation) {
      my $cyclonedx_file = $uploadfiles[-1];
      die unless $cyclonedx_file =~ s/\.[^\.]+$/.cdx.json/;
      BSUtil::cp($containerinfo->{'cyclonedx_file'}, $cyclonedx_file) if $containerinfo->{'cyclonedx_file'} ne $cyclonedx_file;
      $do_sbom = 1;
    }
  }

  # do the upload
  mkdir_p($uploaddir);
  my $containerdigestfile = "$uploaddir/publisher.$$.containerdigests";
  unlink($containerdigestfile);
  my $uploadinfofile;
  if ($registry->{'manifestinfos'}) {
    $uploadinfofile = "$uploaddir/publisher.$$.uploadinfos";
    unlink($uploadinfofile);
  }
  my @opts = map {('-t', $_)} @$tags;
  push @opts, '-m' if $multiarch;
  push @opts, '--oci' if $oci;
  push @opts, '-B', $blobdir if $blobdir;
  if ($cosigncookie) {
    my $gun = $registry->{'notary_gunprefix'} || $registry->{'server'};
    $gun =~ s/^https?:\/\///;
    $gun .= "/$repository";
    my @signargs;
    push @signargs, '--project', $projid if $BSConfig::sign_project;
    push @signargs, @{$signargs || []};
    my $pubkeyfile = "$uploaddir/publisher.$$.pubkey";
    push @tempfiles, $pubkeyfile;
    mkdir_p($uploaddir);
    unlink($pubkeyfile);
    writestr($pubkeyfile, undef, $pubkey);
    push @opts, '--cosign', '--cosigncookie', $cosigncookie;
    push @opts, '-p', $pubkeyfile, '-G', $gun, @signargs;
    push @opts, '--rekor', $registry->{'rekorserver'} if $registry->{'rekorserver'};
    push @opts, '--slsaprovenance' if $do_slsaprovenance;
    push @opts, '--sbom' if $do_sbom;
  }
  push @opts, '-F', $containerdigestfile;
  push @opts, '--write-info', $uploadinfofile if $uploadinfofile;
  my @cmd = ("$INC[0]/bs_regpush", '--dest-creds', '-', @opts, $registryserver, $repository, @uploadfiles);
  print "uploading to registry: @cmd\n";
  my $result = BSPublisher::Util::qsystem('echo', "$registry->{user}:$registry->{password}\n", 'stdout', '', @cmd);
  my $containerdigests = readstr($containerdigestfile, 1) || '';
  unlink($containerdigestfile);
  unlink($_) for @tempfiles;
  die("error while uploading to registry: $result\n") if $result;

  if ($uploadinfofile) {
    my $uploadinfo_json = readstr($uploadinfofile, 1);
    unlink($uploadinfofile);
    my $uploadinfo = $uploadinfo_json ? JSON::XS::decode_json($uploadinfo_json) : undef;
    my %uploadfiles;
    my $idx = 0;
    $uploadfiles{$uploadfiles[$idx++]} = $_ for @$containerinfos;
    for my $imginfo (@{$uploadinfo->{'images'} || []}) {
      next unless $imginfo->{'distmanifest'};
      my $containerinfo = $uploadfiles{delete $imginfo->{'file'}};
      create_manifestinfo($registry, "$projid/$repoid", $repository, $containerinfo, $imginfo);
    }
  }

  return $containerdigests;
}

sub delete_obsolete_tags_from_registry {
  my ($registry, $repository, $containerdigests, $repostate) = @_;

  return if $registry->{'nodelete'};
  if ($repostate) {
    my @keep;
    for (split("\n", $containerdigests)) {
      next if /^#/ || /^\s*$/;
      push @keep, "$1-$2.sig", "$1-$2.att" if /^([a-z0-9]+):([a-f0-9]+) (\d+)/;
      next if /^([a-z0-9]+):([a-f0-9]+) (\d+)\s*$/;       # ignore anonymous images
      die("bad line in digest file\n") unless /^([a-z0-9]+):([a-f0-9]+) (\d+) (.+?)\s*$/;
      push @keep, $4;
    }
    my %keep = map {$_ => 1} @keep;
    return unless grep {!$keep{$_}} keys %$repostate;
  }
  mkdir_p($uploaddir);
  my $containerdigestfile = "$uploaddir/publisher.$$.containerdigests";
  writestr($containerdigestfile, undef, $containerdigests);
  my $registryserver = $registry->{pushserver} || $registry->{server};
  my @cmd = ("$INC[0]/bs_regpush", '--dest-creds', '-', '-X', '-F', $containerdigestfile, $registryserver, $repository);
  print "deleting obsolete tags: @cmd\n";
  my $result = BSPublisher::Util::qsystem('echo', "$registry->{user}:$registry->{password}\n", 'stdout', '', @cmd);
  unlink($containerdigestfile);
  die("error while deleting tags from registry: $result\n") if $result;
}

=head2 add_notary_upload - add notary upload information for a repository

=cut

sub add_notary_upload {
  my ($notary_uploads, $registry, $repository, $digest) = @_;

  return unless $registry->{'notary'};
  my $gun = $registry->{'notary_gunprefix'} || $registry->{'server'};
  $gun =~ s/^https?:\/\///;
  $notary_uploads->{"$gun/$repository"} ||= {'registry' => $registry, 'digests' => '', 'gun' => "$gun/$repository"};
  $notary_uploads->{"$gun/$repository"}->{'digests'} .= $digest if $digest;
}

=head2 upload_to_notary - do all the collected notary uploads

=cut

sub upload_to_notary {
  my ($projid, $notary_uploads, $signargs, $pubkey) = @_;

  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  push @signargs, @{$signargs || []};

  my $pubkeyfile = "$uploaddir/publisher.$$.notarypubkey";
  mkdir_p($uploaddir);
  unlink($pubkeyfile);
  writestr($pubkeyfile, undef, $pubkey);
  my %failed_uploads;
  for my $uploadkey (sort keys %$notary_uploads) {
    my $uploaddata = $notary_uploads->{$uploadkey};
    my $registry = $uploaddata->{'registry'};
    my @pubkeyargs = ('-p', $pubkeyfile);
    @pubkeyargs = @{$registry->{'notary_pubkey_args'}} if $registry->{'notary_pubkey_args'};
    my $containerdigestfile = "$uploaddir/publisher.$$.containerdigests";
    writestr($containerdigestfile, undef, $uploaddata->{'digests'} || '');
    my @cmd = ("$INC[0]/bs_notar", '--dest-creds', '-', @signargs, @pubkeyargs, '-F', $containerdigestfile, $registry->{'notary'}, $uploaddata->{'gun'});
    print "Uploading to notary: @cmd\n";
    my $result = BSPublisher::Util::qsystem('echo', "$registry->{user}:$registry->{password}\n", 'stdout', '', @cmd);
    unlink($containerdigestfile);
    $failed_uploads{$uploaddata->{'gun'}} = $result if $result;
  }
  unlink($pubkeyfile);
  if (%failed_uploads) {
     warn("error while uploading to notary:\n");
     warn("failed for $_ $failed_uploads{$_}\n") for sort keys(%failed_uploads);
     die("error while uploading to notary\n");
  }
}

=head2 delete_from_notary - delete collected repositories

=cut

sub delete_from_notary {
  my ($projid, $notary_uploads) = @_;

  for my $uploadkey (sort keys %$notary_uploads) {
    my $uploaddata = $notary_uploads->{$uploadkey};
    die("delete_from_notary: digest not empty\n") if $uploaddata->{'digests'};
    my $registry = $uploaddata->{'registry'};
    my @cmd = ("$INC[0]/bs_notar", '--dest-creds', '-', '-D', $registry->{'notary'}, $uploaddata->{'gun'});
    print "deleting from notary: @cmd\n";
    my $result = BSPublisher::Util::qsystem('echo', "$registry->{user}:$registry->{password}\n", 'stdout', '', @cmd);
    die("error while uploading to notary: $result\n") if $result;
  }
}

=head2 decompress_container - decompress or copy container into a temporary file

 Function returns path to the temporay file

=cut

sub decompress_container {
  my ($in) = @_;

  my %ext2decomp = (
    'tbz' => 'bzcat',
    'tgz' => 'zcat',
    'bz2' => 'bzcat',
    'xz'  => 'xzcat',
    'gz'  => 'zcat',
  );
  my $decomp;
  $decomp = $ext2decomp{$1} if $in =~ /\.([^\.]+)$/;
  $decomp ||= 'cat';
  my ($fh, $tempfile) = tempfile();
  print "Decompressing: '$decomp $in > $tempfile'\n";
  BSPublisher::Util::qsystem('stdout', $tempfile, $decomp, $in);
  return $tempfile;
}

=head2 delete_container_repositories - delete obsolete repositories from the registry/notary

=cut

sub delete_container_repositories {
  my ($extrep, $projid, $repoid, $old_container_repositories) = @_;
  return unless $old_container_repositories;
  upload_all_containers($extrep, $projid, $repoid, undef, undef, undef, 0, $old_container_repositories);
}

=head2 do_local_uploads - sync containers to a repository in a local registry

=cut

sub do_local_uploads {
  my ($registry, $projid, $repoid, $repository, $containers, $pubkey, $signargs, $multicontainer, $uptags) = @_;

  my %todo;
  my @tempfiles;
  for my $tag (sort keys %{$uptags || {}}) {
    my $archs = $uptags->{$tag};
    for my $arch (sort keys %{$archs || {}}) {
      my $p = $archs->{$arch};
      my $containerinfo = $containers->{$p};
      my $file = $containerinfo->{'publishfile'};
      if (!defined($file)) {
        die("need a blobdir for containerinfo uploads\n") unless $containerinfo->{'blobdir'};
      } elsif ($file =~ /\.tar$/) {
	$containerinfo->{'uploadfile'} = $file;
      } elsif ($file =~ /\.tgz$/ && ($containerinfo->{'type'} || '') eq 'helm') {
	$containerinfo->{'uploadfile'} = $file;
      } else {
        my $tmpfile = decompress_container($file);
	$containerinfo->{'uploadfile'} = $tmpfile;
        push @tempfiles, $tmpfile;
      }
      push @{$todo{$tag}}, $containerinfo;
    }
  }
  eval {
    BSPublisher::Registry::push_containers($registry, $projid, $repoid, $repository, \%todo, $pubkey, $signargs, $multicontainer);
  };
  unlink($_) for @tempfiles;
  die($@) if $@;
}

=head2 do_remote_uploads - sync containers to a repository in a remote registry

=cut

sub do_remote_uploads {
  my ($registry, $projid, $repoid, $repository, $containers, $pubkey, $signargs, $multicontainer, $uptags, $notary_uploads) = @_;

  if (!$uptags) {
    my $containerdigests = '';
    add_notary_upload($notary_uploads, $registry, $repository, $containerdigests);
    delete_obsolete_tags_from_registry($registry, $repository, $containerdigests);
    return;
  }
  # find common containerinfos so that we can push multiple tags in one go
  my %todo;
  my %todo_p;
  for my $tag (sort keys %$uptags) {
    my @p = sort(values %{$uptags->{$tag}});
    my $joinp = join('///', @p);
    push @{$todo{$joinp}}, $tag;
    $todo_p{$joinp} = \@p;
  }
  my $pullserver = $registry->{server};
  $pullserver =~ s/https?:\/\///;
  $pullserver =~ s/\/?$/\//;
  $pullserver = '' if $pullserver =~ /docker.io\/$/;
  # query the current state
  my $repostate;
  $repostate = eval { query_repostate($registry, $repository) } if 1;
  # now do the uploads for the tag groups
  my $containerdigests = '';
  for my $joinp (sort keys %todo) {
    my @tags = @{$todo{$joinp}};
    my @containerinfos = map {$containers->{$_}} @{$todo_p{$joinp}};
    my $digests = upload_to_registry($registry, $projid, $repoid, $repository, \@containerinfos, \@tags, $pubkey, $signargs, $multicontainer, $repostate);
    $containerdigests .= $digests;
  }
  # all is pushed, now clean the rest
  add_notary_upload($notary_uploads, $registry, $repository, $containerdigests);
  delete_obsolete_tags_from_registry($registry, $repository, $containerdigests, $repostate);
}

1;

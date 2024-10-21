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
  my ($projid, $pubkey, $signargs, $signflavor) = @_;

  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  push @signargs, '--signtype', 'notary' if $BSConfig::sign_type || $BSConfig::sign_type;
  push @signargs, '--signflavor', $signflavor if $signflavor;
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
    print "public key algorithm is '$pkalgo', skipping container signing and notary upload\n";
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
  my ($projid, $repoid, $containers, $data) = @_;
  my @registries = registries_for_prp($projid, $repoid);
  my $container_state = '';
  $container_state .= "//multi//" if $data->{'multiarch'};
  my @cs;
  for my $registry (@registries) {
    my $regname = $registry->{'_name'};
    my $mapper = $registry->{'mapper'} || \&default_container_mapper;
    for my $p (sort keys %$containers) {
      my $containerinfo = $containers->{$p};
      my $arch = $containerinfo->{'arch'};
      my @tags = $mapper->($registry, $containerinfo, $projid, $repoid, $arch, $data->{'config'});
      my $prefix = "$containerinfo->{'_id'}/$regname/$arch/";
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
  my ($extrep, $projid, $repoid, $containers, $data, $old_container_repositories) = @_;

  my $isdelete;
  if (!defined($containers)) {
    $isdelete = 1;
    $containers = {};
  } else {
    my ($pubkey, $signargs) = get_notary_pubkey($projid, $data->{'pubkey'}, $data->{'signargs'}, $data->{'signflavor'});
    $data = { %$data, 'pubkey' => $pubkey, 'signargs' => $signargs };
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
    my $gunprefix = $registry->{'notary_gunprefix'} || $registry->{'server'} || '';
    $gunprefix =~ s/^https?:\/\///;

    my $tagdata = $data->{'tagdata_cb'} ? {} : undef;
    # collect uploads over all containers, decide which container to take
    # if there is a tag conflict
    my %uploads;
    my $mapper = $registry->{'mapper'} || \&default_container_mapper;
    for my $p (sort keys %$containers) {
      my $containerinfo = $containers->{$p};
      my $platformstr = BSContar::make_platformstr($containerinfo->{'goarch'} || $containerinfo->{'arch'}, $containerinfo->{'govariant'}, $containerinfo->{'goos'});
      $platformstr = 'any' if ($containerinfo->{'type'} || '') eq 'helm' || ($containerinfo->{'type'} || '') eq 'artifacthub';
      my @tags = $mapper->($registry, $containerinfo, $projid, $repoid, $containerinfo->{'arch'}, $data->{'config'});
      if ($tagdata) {
	$tagdata->{$p}->{'platformstr'} = $platformstr;
	$tagdata->{$p}->{'tags_seen'} = [ BSUtil::unify(map {/^(.*):([^:\/]+)$/ ? $_ : "$_:latest"} @tags) ];
      }
      for my $tag (@tags) {
	my ($reponame, $repotag) = ($tag, 'latest');
	($reponame, $repotag) = ($1, $2) if $tag =~ /^(.*):([^:\/]+)$/;
	if ($uploads{$reponame}->{$repotag}->{$platformstr}) {
	  my $otherinfo = $containers->{$uploads{$reponame}->{$repotag}->{$platformstr}};
	  next if cmp_containerinfo($otherinfo, $containerinfo) > 0;
	}
	$uploads{$reponame}->{$repotag}->{$platformstr} = $p;
      }
    }

    # record which tags we pushed to the registry
    if ($data->{'tagdata_cb'}) {
      for my $p (sort keys %$containers) {
	my $containerinfo = $containers->{$p};
	my $tags_seen = $tagdata->{$p}->{'tags_seen'} || [];
	my $tags_used = [];
	my $platformstr = $tagdata->{$p}->{'platformstr'};
	for my $tag (@$tags_seen) {
	  next unless $tag =~ /^(.*):([^:\/]+)$/;
	  push @$tags_used, $tag if $uploads{$1}->{$2}->{$platformstr} eq $p;
	}
	$data->{'tagdata_cb'}->($data, $registry, $containerinfo, $platformstr, $tags_seen, $tags_used);
      }
    }

    # ok, now go through every repository and upload all tags
    for my $repository (sort keys %uploads) {
      $container_repositories{$regname}->{$repository} = 1;

      my $uptags = $uploads{$repository};

      if ($registryserver eq 'local:') {
	$have_some_trust = 1 if defined($data->{'pubkey'}) && $gunprefix && $gunprefix ne 'local:';
	do_local_uploads($registry, $projid, $repoid, $repository, $containers, $data, $uptags);
      } else {
        do_remote_uploads($registry, $projid, $repoid, $repository, $containers, $data, $uptags, $notary_uploads);
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
        do_local_uploads($registry, $projid, $repoid, $repository, $containers, $data, undef);
	next;
      } else {
        do_remote_uploads($registry, $projid, $repoid, $repository, $containers, $data, undef, $notary_uploads);
      }
    }
  }
  $have_some_trust = 1 if %$notary_uploads;

  # postprocessing: write readme, create links
  my %allrefs_pp;
  my %allrefs_pp_lastp;
  my %helm_pp;
  for my $p (sort keys %$containers) {
    my $containerinfo = $containers->{$p};
    my $pp = $p;
    $pp =~ s/.*?\/// if $data->{'multiarch'};
    $allrefs_pp_lastp{$pp} = $p;	# for link creation
    push @{$allrefs_pp{$pp}}, @{$allrefs{$p} || []};	# collect all archs for the link
    $helm_pp{$pp} = 1 if ($containerinfo->{'type'} || '') eq 'helm';
  }
  for my $pp (sort keys %allrefs_pp_lastp) {
    mkdir_p($extrep);
    unlink("$extrep/$pp.registry.txt");
    if (@{$allrefs_pp{$pp} || []}) {
      unlink("$extrep/$pp") unless $helm_pp{$pp};
      # write readme file where to find the container
      my @r = sort(BSUtil::unify(@{$allrefs_pp{$pp}}));
      my $readme = "This container can be pulled via:\n";
      $readme .= "  docker pull $_\n" for @r;
      $readme .= "\nSet DOCKER_CONTENT_TRUST=1 to enable image tag verification.\n" if $have_some_trust;
      writestr("$extrep/$pp.registry.txt", undef, $readme);
    } elsif ($data->{'multiarch'} && $allrefs_pp_lastp{$pp} ne $pp) {
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
      if (!defined($data->{'pubkey'})) {
	print "skipping notary upload\n";
      } else {
        upload_to_notary($projid, $notary_uploads, $data);
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

sub open_container_tar {
  my ($containerinfo, $file) = @_;
  my ($tar, $mtime);
  if (($containerinfo->{'type'} || '') eq 'artifacthub') {
    ($tar, $mtime) = BSContar::container_from_artifacthub($containerinfo->{'artifacthubdata'});
  } elsif (!defined($file)) {
    ($tar, $mtime) = BSPublisher::Containerinfo::construct_container_tar($containerinfo, 1);
  } elsif (($containerinfo->{'type'} || '') eq 'helm') {
    ($tar, $mtime) = BSContar::container_from_helm($file, $containerinfo->{'config_json'}, $containerinfo->{'tags'});
  } elsif ($file =~ /\.tar$/) {
    ($tar, $mtime) = BSContar::open_container_tar($file);
  } else {
    my $tmpfile = decompress_container($file);
    my $tarfd;
    open($tarfd, '<', $tmpfile) || die("$tmpfile: $!\n");
    unlink($tmpfile);
    ($tar, $mtime) = BSContar::open_container_tar($tarfd);
  }
  die("incomplete containerinfo\n") unless $tar;
  return ($tar, $mtime);
}

sub create_container_dist_info {
  my ($containerinfo, $oci, $platforms, $imginfo) = @_;
  my ($tar, $mtime) = open_container_tar($containerinfo, $containerinfo->{'publishfile'});
  my %tar = map {$_->{'name'} => $_} @$tar;
  my ($manifest_ent, $manifest) = BSContar::get_manifest(\%tar);
  my ($config_ent, $config) = BSContar::get_config(\%tar, $manifest);
  my $goarch = $config->{'architecture'} || 'any';
  my $goos = $config->{'os'} || 'any';
  my $govariant = $containerinfo->{'govariant'};
  $govariant = $config->{'variant'} if $config->{'variant'};

  if ($platforms) {
    my $platformstr = BSContar::make_platformstr($goarch, $govariant, $goos);
    return undef if $platforms->{$platformstr};
    $platforms->{$platformstr} = 1;
  }

  my $config_data = BSContar::create_config_data($config_ent, $oci);
  my @layer_data;
  die("container has no layers\n") unless @{$manifest->{'Layers'} || []};
  for my $layer_file (@{$manifest->{'Layers'}}) {
    my $layer_ent = $tar{$layer_file};
    die("file $layer_file not included in tar\n") unless $layer_ent;
    $layer_ent = BSContar::normalize_layer($layer_ent, $oci);
    my $layer_data = BSContar::create_layer_data($layer_ent, $oci);
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
  if ($imginfo) {
    $imginfo->{'imageid'} = $config_data->{'digest'};
    $imginfo->{'goarch'} = $goarch;
    $imginfo->{'goos'} = $goos;
    $imginfo->{'govariant'} = $govariant if $govariant;
    $imginfo->{'distmanifest'} = $info->{'digest'};
    $imginfo->{'containerinfo'} = $containerinfo;
  }
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
  my ($registry, $repository, $tags, $subdigests, $missingok) = @_;
  my $registryserver = $registry->{pushserver} || $registry->{server};
  my $pullserver = $registry->{server};
  $pullserver =~ s/https?:\/\///;
  $pullserver =~ s/\/?$/\//;
  $pullserver = '' if $pullserver =~ /docker.io\/$/;
  $repository = "library/$repository" if $pullserver eq '' && $repository !~ /\//;
  mkdir_p($uploaddir);
  my $tempfile = "$uploaddir/publisher.$$.repostate";
  unlink($tempfile);
  my $tagsfile;
  my $registrystate = $registry->{'registrystate'};
  if ($tags) {
    return undef unless @$tags;
    print "querying state of ".scalar(@$tags)." tags of $repository on $registryserver\n";
    $tagsfile = "$uploaddir/publisher.$$.repotags";
    my $digestdata = '';
    $digestdata .= "sha256:0000000000000000000000000000000000000000000000000000000000000000 0 $_\n" for @$tags;
    writestr($tagsfile, undef, $digestdata);
  } else {
    print "querying state of $repository on $registryserver\n";
  }
  my @opts = ('-l');
  push @opts, '--cosign' if $tags;
  push @opts, '--no-cosign-info' if $registry->{'cosign_nocheck'};
  push @opts, '--listidx-no-info' if $subdigests;
  push @opts, '--missingok' if $missingok;
  push @opts, '-F', $tagsfile if $tagsfile;
  push @opts, '--old-listfile', "$registrystate/$repository/:oldlist" if $registrystate && -s "$registrystate/$repository/:oldlist";
  my @cmd = ("$INC[0]/bs_regpush", '--dest-creds', '-', @opts, $registryserver, $repository);
  my $now = time();
  my $result = BSPublisher::Util::qsystem('echo', "$registry->{user}:$registry->{password}\n", 'stdout', $tempfile, @cmd);
  my $repostate;
  if (!$result) {
    my $fd;
    open ($fd, '<', $tempfile) || die("$tempfile: $!\n");
    $repostate = {};
    my $lastdigest;
    while (<$fd>) {
      my @s = split(' ', $_);
      next unless @s;
      if ($s[0] =~ /^\//) {
	$subdigests->{$lastdigest}->{substr($s[0], 1)} = $s[1] if $subdigests && $lastdigest && @s >= 2;
	next;
      }
      $lastdigest = undef;
      if (@s >= 4 && $s[0] =~ /\.(?:sig|att)$/ && $s[-1] =~ /^cosigncookie=/) {
        $repostate->{$s[0]} = $s[-1];
      } elsif (@s >= 2) {
        $repostate->{$s[0]} = $s[1];
        $lastdigest = $s[1];
      }
    }
    close($fd);
    if ($registry->{'cosign_nocheck'}) {
      my $numcosigntags = grep {/^[a-z0-9]+-[a-f0-9]+\.(?:sig|att)$/} keys %$repostate;
      printf "query of %s took %d seconds, found %d tags and %d cosign tags\n", $repository, time() - $now, scalar(keys %$repostate) - $numcosigntags, $numcosigntags;
    } else {
      printf "query of %s took %d seconds, found %d tags\n", $repository, time() - $now, scalar(keys %$repostate);
    }
    if ($registrystate) {
      mkdir_p("$registrystate/$repository");
      rename($tempfile, "$registrystate/$repository/:oldlist")
    }
  }
  unlink($tagsfile) if $tagsfile;
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
  my ($projid, $repoid) = split('/', $prp, 2);
  # copy so we can add/delete stuff
  $imginfo = { %$imginfo, 'project' => $projid, 'repository' => $repoid };
  delete $imginfo->{'containerinfo'};
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
  mkdir_p("$dir/$repository");
  my $imginfo_json = JSON::XS->new->utf8->canonical->encode($imginfo);
  unlink("$dir/$repository/.$mani_id.$$");
  writestr("$dir/$repository/.$mani_id.$$", "$dir/$repository/$mani_id", $imginfo_json);
}

sub compare_to_repostate {
  my ($registry, $repostate, $repository, $containerinfos, $tags, $multiarch, $oci, $cosign, $taginfo) = @_;
  my %expected;
  my $containerdigests = '';
  my $info;
  my $cosigncookie = ($cosign || {})->{'cookie'};
  my $cosign_attestation = ($cosign || {})->{'attestation'};
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
      my $imginfo = $taginfo ? {} : undef;
      $info = create_container_dist_info($containerinfo, $oci, \%platforms, $imginfo);
      die("create_container_dist_info rejected container\n") unless $info;
      $missing_manifestinfo = 1 if $manifestinfodir && ! -s "$manifestinfodir/$info->{'digest'}";
      my $attestation_layers = ($containerinfo->{'slsa_provenance_file'} ? 1 : 0) + ($containerinfo->{'spdx_file'} ? 1 : 0) + ($containerinfo->{'cyclonedx_file'} ? 1 : 0) + scalar(@{$containerinfo->{'intoto_files'} || []});
      if ($cosigncookie && $cosign_attestation && $attestation_layers) {
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
      push @{$taginfo->{'images'}}, $imginfo if $taginfo;
    }
    $info = create_container_index_info(\@infos, $oci);
    if ($taginfo) {
      $taginfo->{'distmanifesttype'} = 'list';
      $taginfo->{'distmanifest'} = $info->{'digest'};
    }
  } else {
    my $containerinfo = $containerinfos->[0];
    my $imginfo = $taginfo ? {} : undef;
    $info = create_container_dist_info($containerinfo, $oci, undef, $imginfo);
    die("create_container_dist_info rejected container\n") unless $info;
    $missing_manifestinfo = 1 if $manifestinfodir && ! -s "$manifestinfodir/$info->{'digest'}";
    my $attestation_layers = ($containerinfo->{'slsa_provenance_file'} ? 1 : 0) + ($containerinfo->{'spdx_file'} ? 1 : 0) + ($containerinfo->{'cyclonedx_file'} ? 1 : 0) + scalar(@{$containerinfo->{'intoto_files'} || []});
    if ($cosigncookie && $cosign_attestation && $attestation_layers) {
      my $atttag = $info->{'digest'};
      $atttag =~ s/:(.*)/-$1.att/;
      $expected{$atttag} = $cosign_expect;
    }
    push @{$taginfo->{'images'}}, $imginfo if $taginfo;
  }
  if ($taginfo) {
    $taginfo->{'distmanifesttype'} = $multiarch ? 'list' : 'image';
    $taginfo->{'distmanifest'} = $info->{'digest'};
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
  my ($registry, $projid, $repoid, $repository, $containerinfos, $tags, $data, $repostate, $cosign) = @_;

  return '' unless @{$containerinfos || []} && @{$tags || []};
  
  my ($pubkey, $signargs) = ($data->{'pubkey'}, $data->{'signargs'});
  my $registryserver = $registry->{pushserver} || $registry->{server};
  my $pullserver = $registry->{server};
  $pullserver =~ s/https?:\/\///;
  $pullserver =~ s/\/?$/\//;
  $repository = "library/$repository" if $repository !~ /\// && $registry->{server} =~ /docker.io\/?$/ && $repository !~ /\//;

  my $multiarch = 0;	# XXX: use $data->{'multiarch'}
  $multiarch = 1 if @$containerinfos > 1;
  $multiarch = 0 if @$containerinfos == 1 && ($containerinfos->[0]->{'type'} || '') eq 'helm';
  $multiarch = 0 if @$containerinfos == 1 && ($containerinfos->[0]->{'type'} || '') eq 'artifacthub';
  my $oci;
  for my $containerinfo (@$containerinfos) {
    $oci = 1 if ($containerinfo->{'type'} || '') eq 'helm' || ($containerinfo->{'type'} || '') eq 'artifacthub';
    $oci = 1 if grep {$_ && $_ ne 'gzip'} @{$containerinfo->{'layer_compression'} || []};
  }

  my $gun = $registry->{'notary_gunprefix'} || $registry->{'server'};
  $gun =~ s/^https?:\/\///;
  $gun .= "/$repository";

  # check if the registry is up-to-date
  if ($repostate) {
    my $taginfo = $data->{'regdata_cb'} ? {} : undef;
    my $containerdigests = compare_to_repostate($registry, $repostate, $repository, $containerinfos, $tags, $multiarch, $oci, $cosign, $taginfo);
    if (defined $containerdigests) {
      if ($data->{'regdata_cb'}) {
        for my $tag (@$tags) {
          $data->{'regdata_cb'}->($data, $registry, "$repository:$tag", $taginfo);
        }
      }
      return $containerdigests;
    }
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
      if (($containerinfo->{'type'} || '') eq 'artifacthub') {
	push @uploadfiles, "artifacthub:$containerinfo->{'artifacthubdata'}";
	next;
      }
      # tar file needs to be constructed from blobs
      $blobdir = $containerinfo->{'blobdir'};
      die("need a blobdir for containerinfo uploads\n") unless $blobdir;
      push @uploadfiles, "$blobdir/container.".scalar(@uploadfiles).".containerinfo";
      BSRepServer::Containerinfo::writecontainerinfo($uploadfiles[-1], undef, $containerinfo);
      $wrote_containerinfo = $uploadfiles[-1];
    } elsif ($file =~ /(.*)\.tgz$/ && ($containerinfo->{'type'} || '') eq 'helm') {
      my $helminfofile = "$1.helminfo";
      $blobdir = $containerinfo->{'blobdir'};
      die("need a blobdir for helminfo uploads\n") unless $blobdir;
      die("bad publishfile\n") unless $helminfofile =~ /^\Q$blobdir\E\//;	# just in case
      push @uploadfiles, $helminfofile;
      BSRepServer::Containerinfo::writecontainerinfo($uploadfiles[-1], undef, $containerinfo);
      $wrote_containerinfo = $uploadfiles[-1];
    } elsif ($file =~ /\.tar$/) {
      push @uploadfiles, $file;
    } else {
      my $tmpfile = decompress_container($file);
      push @uploadfiles, $tmpfile;
      push @tempfiles, $tmpfile;
    }
    # copy provenance file into blobdir
    if ($wrote_containerinfo && $cosign && $cosign->{'attestation'}) {
      if ($containerinfo->{'slsa_provenance_file'}) {
	my $provenance_file = $wrote_containerinfo;
	die unless $provenance_file =~ s/\.[^\.]+$/.slsa_provenance.json/;
	BSUtil::cp($containerinfo->{'slsa_provenance_file'}, $provenance_file) if $containerinfo->{'slsa_provenance_file'} ne $provenance_file;
	$do_slsaprovenance = 1;
      }
      if ($containerinfo->{'spdx_file'}) {
	my $spdx_file = $wrote_containerinfo;
	die unless $spdx_file =~ s/\.[^\.]+$/.spdx.json/;
	BSUtil::cp($containerinfo->{'spdx_file'}, $spdx_file) if $containerinfo->{'spdx_file'} ne $spdx_file;
	$do_sbom = 1;
      }
      if ($containerinfo->{'cyclonedx_file'}) {
	my $cyclonedx_file = $wrote_containerinfo;
	die unless $cyclonedx_file =~ s/\.[^\.]+$/.cdx.json/;
	BSUtil::cp($containerinfo->{'cyclonedx_file'}, $cyclonedx_file) if $containerinfo->{'cyclonedx_file'} ne $cyclonedx_file;
	$do_sbom = 1;
      }
      my $nintoto = 0;
      for my $intoto (@{$containerinfo->{'intoto_files'} || []}) {
	my $intoto_file = $wrote_containerinfo;
	die unless $intoto_file =~ s/\.[^\.]+$/.$nintoto.intoto.json/;
	$nintoto++;
	BSUtil::cp($intoto, $intoto_file) if $intoto ne $intoto_file;
	$do_sbom = 1;
      }
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
  if ($cosign && $cosign->{'cookie'}) {
    my @signargs;
    push @signargs, '--project', $projid if $BSConfig::sign_project;
    push @signargs, @{$signargs || []};
    my $pubkeyfile = "$uploaddir/publisher.$$.pubkey";
    push @tempfiles, $pubkeyfile;
    mkdir_p($uploaddir);
    unlink($pubkeyfile);
    writestr($pubkeyfile, undef, $pubkey);
    push @opts, '--cosign', '--cosigncookie', $cosign->{'cookie'};
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

  if ($data->{'notify'}) {
    $data->{'notify'}->("$gun:$_") for @$tags;
  }

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
      $imginfo->{'containerinfo'} = $containerinfo;
      create_manifestinfo($registry, "$projid/$repoid", $repository, $containerinfo, $imginfo) if $registry->{'manifestinfos'};
    }
    if ($data->{'regdata_cb'}) {
      for my $tag (@{$uploadinfo->{'tags'} || []}) {
        $data->{'regdata_cb'}->($data, $registry, "$repository:$tag", $uploadinfo);
      }
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
    my @obsoletetags = grep {!$keep{$_}} keys %$repostate;
    return unless @obsoletetags;
    print "obsolete tags: @obsoletetags\n";
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
  my ($projid, $notary_uploads, $data) = @_;

  my ($pubkey, $signargs) = ($data->{'pubkey'}, $data->{'signargs'});
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
  my $data = {};
  upload_all_containers($extrep, $projid, $repoid, undef, $data, $old_container_repositories);
}

=head2 do_local_uploads - sync containers to a repository in a local registry

=cut

sub do_local_uploads {
  my ($registry, $projid, $repoid, $repository, $containers, $data, $uptags) = @_;

  my %todo;
  my @tempfiles;
  my $now = time();
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
  my $gun = $registry->{'notary_gunprefix'} || $registry->{'server'};
  $gun =~ s/^https?:\/\///;
  $gun = '' if $gun eq 'local:';
  if (($data->{'artifacthubdata'} || {})->{"$gun/$repository"} && !$uptags->{'artifacthub.io'}) {
    my $containerinfo = { 'type' => 'artifacthub', 'artifacthubdata' => $data->{'artifacthubdata'}->{"$gun/$repository"} };
    push @{$todo{'artifacthub.io'}}, $containerinfo;
  }
  eval {
    BSPublisher::Registry::push_containers($registry, $projid, $repoid, $repository, \%todo, $data);
  };
  unlink($_) for @tempfiles;
  die($@) if $@;
  printf "local updating of %s took %d seconds\n", $repository, time() - $now;
}


=head2 container_tag_deletion_safeguard - make sure no tags are deleted

=cut

sub container_tag_deletion_safeguard {
  my ($registry, $repository, $safeguard, $uptags, $repostate, $subdigests) = @_;

  return unless $safeguard;
  my $nodelete = $registry->{'nodelete'};
  print "tag deletion safeguard active for $repository (mode=$safeguard)\n";

  # query the tags from the registry unless we already have a state
  if (!defined $repostate) {
    $subdigests = {};
    $repostate = eval { query_repostate($registry, $repository, undef, $subdigests, 1) };
    die("need registry query result for the tag deletion safeguard: $@") if $@;
    die("need registry query result for the tag deletion safeguard\n") unless defined $repostate;
  }

  # check if we have missing containers
  my @missing;
  for my $tag (sort keys %$repostate) {
    next if $tag =~ /^([a-z0-9]+)-([a-f0-9]+)\.(?:sig|att)$/;
    if (!$uptags->{$tag}) {
      push @missing, $tag unless $nodelete;
      next;
    }
    my $digest = $repostate->{$tag};
    if ($subdigests->{$digest}) {
      for my $platformstr (sort keys %{$subdigests->{$digest}}) {
	push @missing, "$tag/$platformstr" unless $uptags->{$tag}->{$platformstr};
      }
    } else {
      # the tag is just an image and we do not know the platform
      # hope for the best
    }
  }
  if (@missing) {
    if ($safeguard == 2) {
      print("warning: tag deletion safeguard for $repository: found missing tags: @missing\n");
    } else {
      BSUtil::logcritical("tag deletion safeguard for $repository: found missing tags: @missing\n");
      die("tag deletion safeguard failed\n");
    }
  }
}


=head2 do_remote_uploads - sync containers to a repository in a remote registry

=cut

sub do_remote_uploads {
  my ($registry, $projid, $repoid, $repository, $containers, $data, $uptags, $notary_uploads) = @_;

  my $safeguard;
  if ($registry->{'container_tag_deletion_safeguard'}) {
    $safeguard = $registry->{'container_tag_deletion_safeguard'};
    $safeguard = $safeguard->($registry, $projid, $repoid, $repository, $data) if $safeguard && ref($safeguard) eq 'CODE';
    undef $safeguard unless $safeguard;
  }

  if (!$uptags) {
    if ($safeguard) {
      container_tag_deletion_safeguard($registry, $repository, $safeguard, {});
    }
    my $containerdigests = '';
    add_notary_upload($notary_uploads, $registry, $repository, $containerdigests);
    delete_obsolete_tags_from_registry($registry, $repository, $containerdigests);
    return;
  }

  my $gun = $registry->{'notary_gunprefix'} || $registry->{'server'};
  $gun =~ s/^https?:\/\///;
  $gun .= "/$repository";

  # check if we should do cosign and generate a cookie
  my $cosign;
  if (defined($data->{'pubkey'}) && $registry->{'cosign'} && %$uptags) {
    $cosign = $registry->{'cosign'};
    $cosign = $cosign->($repository, $projid) if $cosign && ref($cosign) eq 'CODE';
    $cosign = $cosign ? {} : undef;
  }
  if ($cosign) {
    my $creator = 'OBS';
    $cosign->{'cookie'} = BSConSign::create_cosign_cookie($data->{'pubkey'}, $gun, $creator);
    my $cosign_attestation = defined($registry->{'cosign_attestation'}) ? $registry->{'cosign_attestation'} : 1;
    $cosign_attestation = $cosign_attestation->($repository, $projid) if $cosign_attestation && ref($cosign_attestation) eq 'CODE';
    $cosign->{'attestation'} = 1 if $cosign_attestation;
  }

  # query the current state of the registry
  my $repostate;
  my $subdigests = $safeguard ? {} : undef;
  my $querytags;
  $querytags = [ sort keys %$uptags ] if $registry->{'nodelete'};
  $repostate = eval { query_repostate($registry, $repository, $querytags, $subdigests) } if 1;

  # check if we are allowed to remove tags
  if ($safeguard) {
    my %uptags = %$uptags;
    $uptags{'artifacthub.io'} ||= {'any' => undef} if ($data->{'artifacthubdata'} || {})->{$gun};
    container_tag_deletion_safeguard($registry, $repository, $safeguard, \%uptags, $repostate, $subdigests);
  }

  # find common containerinfos so that we can push multiple tags in one go
  my %todo;
  my %todo_p;
  for my $tag (sort keys %$uptags) {
    my $uptag = $uptags->{$tag};
    my @p = map {$uptag->{$_}} sort keys %$uptag;
    my $joinp = join('///', @p);
    push @{$todo{$joinp}}, $tag;
    $todo_p{$joinp} = \@p;
  }

  # now do the uploads for the tag groups
  my $now = time();
  my $containerdigests = '';
  for my $joinp (sort keys %todo) {
    my @tags = @{$todo{$joinp}};
    my @containerinfos = map {$containers->{$_}} @{$todo_p{$joinp}};
    my $digests = upload_to_registry($registry, $projid, $repoid, $repository, \@containerinfos, \@tags, $data, $repostate, $cosign);
    $containerdigests .= $digests;
  }
  if (($data->{'artifacthubdata'} || {})->{$gun} && !$uptags->{'artifacthub.io'}) {
    my $containerinfo = { 'type' => 'artifacthub', 'artifacthubdata' => $data->{'artifacthubdata'}->{$gun} };
    my $digests = upload_to_registry($registry, $projid, $repoid, $repository, [ $containerinfo ], [ 'artifacthub.io' ], $data, $repostate);
    $containerdigests .= $digests;
  }

  # all is pushed, now clean the rest
  add_notary_upload($notary_uploads, $registry, $repository, $containerdigests);
  delete_obsolete_tags_from_registry($registry, $repository, $containerdigests, $repostate);

  printf "syncing of %s took %d seconds\n", $repository, time() - $now;
}

1;

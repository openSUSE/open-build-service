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

use BSConfiguration;
use BSPublisher::Util;
use BSUtil;
use BSTar;
use BSRepServer::Containerinfo;

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
    if ($projid =~ /^$k/) {
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

=head2 upload_all_containers - upload found containers to the configured registries
 
=cut

sub upload_all_containers {
  my ($extrep, $projid, $repoid, $containers, $notary_uploads, $multicontainer, $old_container_repositories) = @_;

  my @registries = registries_for_prp($projid, $repoid);
  my %deleted_bins;
  my %allrefs;
  my %container_repositories;
  $old_container_repositories ||= {};
  for my $registry (@registries) {
    my $regname = $registry->{'_name'};

    # collect uploads over all containers
    my %uploads;
    my $mapper = $registry->{'mapper'} || \&default_container_mapper;
    for my $p (sort keys %$containers) {
      my $containerinfo = $containers->{$p};
      my $arch = $containerinfo->{'arch'};
      my @tags = $mapper->($registry, $containerinfo, $projid, $repoid, $arch);
      for my $tag (@tags) {
	if ($tag =~ /^(.*):([^:\/]+)$/) {
          $uploads{$1}->{$2}->{$arch} = $p;
	} else {
          $uploads{$tag}->{'latest'}->{$arch} = $p;
	}
      }
    }

    # ok, now go through every repository and upload all tags
    for my $repository (sort keys %uploads) {
      $container_repositories{$regname}->{$repository} = 1;
      # find common containerinfos so that we can push multiple tags in one go
      my $uptags = $uploads{$repository};
      my %todo;
      my %todo_p;
      for my $tag (sort keys %$uptags) {
	my @p = sort(values %{$uptags->{$tag}});
	my $joinp = join('///', @p);
	push @{$todo{$joinp}}, $tag;
	$todo_p{$joinp} = \@p;
      }
      # now do the upload
      my $containerdigests = '';
      for my $joinp (sort keys %todo) {
	my @tags = @{$todo{$joinp}};
	my @containerinfos = map {$containers->{$_}} @{$todo_p{$joinp}};
	my ($digest, @refs) = upload_to_registry($registry, \@containerinfos, $repository, \@tags);
	add_notary_upload($notary_uploads, $registry, $repository, $digest, \@tags);
	$containerdigests .= $digest;
	push @{$allrefs{$_}}, @refs for @{$todo_p{$joinp}};
      }
      # all is pushed, now clean the rest
      delete_obsolete_tags_from_registry($registry, $repository, $containerdigests);
    }

    # delete repositories of former publish runs that are now empty
    for my $repository (@{$old_container_repositories->{$regname} || []}) {
      next if $uploads{$repository};
      my $containerdigests = '';
      add_notary_upload($notary_uploads, $registry, $repository, $containerdigests);
      delete_obsolete_tags_from_registry($registry, $repository, $containerdigests);
    }
  }

  # postprocessing: delete/reconstruct containers
  my %allrefs_pp;
  my %allrefs_pp_lastp;
  for my $p (sort keys %$containers) {
    my $containerinfo = $containers->{$p};
    my $pp = $p;
    $pp =~ s/.*?\/// if $multicontainer;
    $allrefs_pp_lastp{$pp} = $p;	# for link creation
    if (@{$allrefs{$p} || []}) {
      # we uploaded this container to a registry, so we may delete it
      $deleted_bins{$p} = 1;
      $deleted_bins{"$p.sha256"} = 1;
      unlink("$extrep/$p");
      unlink("$extrep/$p.sha256");
      rmdir($1) if $multicontainer && $p =~ /(.*)\//;
      push @{$allrefs_pp{$pp}}, @{$allrefs{$p} || []};	# collect all archs for the link
    } elsif (!$containerinfo->{'publishfile'} && ! -e "$extrep/$p") {
      # container is virtual and was not uploaded, so reconstruct it
      reconstruct_container($containerinfo, "$extrep/$p");
    }
  }

  # postprocessing: write readme, create links
  for my $pp (sort keys %allrefs_pp_lastp) {
    mkdir_p($extrep);
    if (@{$allrefs_pp{$pp} || []}) {
      # write readme file where to find the container
      unlink("$extrep/$pp");
      my @r = sort(BSUtil::unify(@{$allrefs_pp{$pp}}));
      my $readme = "This container can be pulled via:\n";
      $readme .= "  docker pull $_\n" for @r;
      $readme .= "\nSet DOCKER_CONTENT_TRUST=1 to enable image tag verification.\n" if %{$notary_uploads || {}};
      writestr("$extrep/$pp.registry.txt", undef, $readme);
    } elsif ($multicontainer && $allrefs_pp_lastp{$pp} ne $pp) {
      # create symlink to last arch
      unlink("$extrep/$pp");
      symlink("$allrefs_pp_lastp{$pp}", "$extrep/$pp");
    }
  }

  # turn container repos into arrays and return
  $_ = [ sort keys %$_ ] for values %container_repositories;
  return (\%container_repositories, \%deleted_bins);
}

sub reconstruct_container {
  my ($containerinfo, $dst) = @_;
  my $manifest = $containerinfo->{'tar_manifest'};
  my $mtime = $containerinfo->{'tar_mtime'};
  my $blobids = $containerinfo->{'tar_blobids'};
  my $blobdir = $containerinfo->{'blobdir'};
  return unless $mtime && $manifest && $blobids && $blobdir;
  my @tar;
  for my $blobid (@$blobids) {
    my $file = "$blobdir/_blob.$blobid";
    die("missing blobid $blobid\n") unless -e $file;
    push @tar, {'name' => $blobid, 'file' => $file, 'mtime' => $mtime, 'offset' => 0, 'size' => (-s _)};
  }
  push @tar, {'name' => 'manifest.json', 'data' => $manifest, 'mtime' => $mtime, 'size' => length($manifest)};
  BSTar::writetarfile($dst, undef, \@tar, 'mtime' => $mtime);
}

=head2 upload_to_registry - upload containers

 Parameters:
  registry       - validated config for registry
  containerinfos - array of containers to upload (more than one for multiarch)
  repository     - registry repository name
  tags           - array of tags to upload to
  notary_uploads - hash to store notary information

 Returns:
  containerdigests + public references to uploaded containers

=cut

sub upload_to_registry {
  my ($registry, $containerinfos, $repository, $tags) = @_;

  return unless @{$containerinfos || []} && @{$tags || []};
  
  my $registryserver = $registry->{pushserver} || $registry->{server};
  my $pullserver = $registry->{server};
  $pullserver =~ s/https?:\/\///;
  $pullserver =~ s/\/?$/\//;
  $pullserver = '' if $pullserver =~ /docker.io\/$/;
  $repository = "library/$repository" if $pullserver eq '' && $repository !~ /\//;

  # decompress tar files
  my @tempfiles;
  my @uploadfiles;
  my $blobdir;
  for my $containerinfo (@$containerinfos) {
    my $file = $containerinfo->{'publishfile'};
    if (!defined($file)) {
      # tar file needs to be constructed from blobs
      $blobdir = $containerinfo->{'blobdir'};
      die("need a blobdir for containerinfo uploads\n") unless $blobdir;
      push @uploadfiles, "$blobdir/container.".scalar(@uploadfiles).".containerinfo";
      BSRepServer::Containerinfo::writecontainerinfo($uploadfiles[-1], undef, $containerinfo);
    } elsif ($file =~ /\.tar$/) {
      push @uploadfiles, $file;
    } else {
      my $tmpfile = decompress_container($file);
      push @uploadfiles, $tmpfile;
      push @tempfiles, $tmpfile;
    }
  }

  # do the upload
  mkdir_p($uploaddir);
  my $containerdigestfile = "$uploaddir/publisher.$$.containerdigests";
  unlink($containerdigestfile);
  my @opts = map {('-t', $_)} @$tags;
  push @opts, '-m' if @uploadfiles > 1;		# create multi arch container
  push @opts, '-B', $blobdir if $blobdir;
  my @cmd = ("$INC[0]/bs_regpush", '--dest-creds', '-', @opts, '-F', $containerdigestfile, $registryserver, $repository, @uploadfiles);
  print "Uploading to registry: @cmd\n";
  BSUtil::xsystem("$registry->{user}:$registry->{password}\n", @cmd);
  my $result = BSPublisher::Util::qsystem('echo', "$registry->{user}:$registry->{password}\n", 'stdout', '', @cmd);
  my $containerdigests = readstr($containerdigestfile, 1);
  unlink($containerdigestfile);
  unlink($_) for @tempfiles;
  die("Error while uploading to registry: $result\n") if $result;

  # return digest and public references
  $repository =~ s/^library\/([^\/]+)$/$1/ if $pullserver eq '';
  return ($containerdigests, map {"$pullserver$repository:$_"} @$tags);
}

sub delete_obsolete_tags_from_registry {
  my ($registry, $repository, $containerdigests) = @_;

  return if $registry->{'nodelete'};
  mkdir_p($uploaddir);
  my $containerdigestfile = "$uploaddir/publisher.$$.containerdigests";
  writestr($containerdigestfile, undef, $containerdigests);
  my $registryserver = $registry->{pushserver} || $registry->{server};
  my @cmd = ("$INC[0]/bs_regpush", '--dest-creds', '-', '-X', '-F', $containerdigestfile, $registryserver, $repository);
  print "Deleting obsolete tags: @cmd\n";
  my $result = BSPublisher::Util::qsystem('echo', "$registry->{user}:$registry->{password}\n", 'stdout', '', @cmd);
  unlink($containerdigestfile);
  die("Error while deleting tags from registry: $result\n") if $result;
}

=head2 add_notary_upload - add notary upload information for a repository

=cut

sub add_notary_upload {
  my ($notary_uploads, $registry, $repository, $digest, $tags) = @_;

  return unless $registry->{'notary'};
  my $gun = $registry->{'notary_gunprefix'} || $registry->{'server'};
  $gun =~ s/^https?:\/\///;
  if ($tags) {
    print "adding notary upload for $gun/$repository: @$tags\n";
  } else {
    print "adding empty notary upload for $gun/$repository\n";
  }
  $notary_uploads->{"$gun/$repository"} ||= {'registry' => $registry, 'digests' => '', 'gun' => "$gun/$repository"};
  $notary_uploads->{"$gun/$repository"}->{'digests'} .= $digest if $digest;
}

=head2 upload_to_notary - do all the collected notary uploads

=cut

sub upload_to_notary {
  my ($projid, $notary_uploads, $signargs, $pubkey) = @_;

  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  push @signargs, '--signtype', 'notary' if $BSConfig::sign_type || $BSConfig::sign_type;
  push @signargs, @{$signargs || []};

  # ask the sign tool for the correct pubkey if we do not have a sign key
  if (!@$signargs && $BSConfig::sign_project && $BSConfig::sign) {
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
    return;
  }

  my $pubkeyfile = "$uploaddir/publisher.$$.notarypubkey";
  mkdir_p($uploaddir);
  unlink($pubkeyfile);
  writestr($pubkeyfile, undef, $pubkey);
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
    if ($result) {
      unlink($pubkeyfile);
      die("Error while uploading to notary: $result\n");
    }
  }
  unlink($pubkeyfile);
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
    print "Deleting from notary: @cmd\n";
    my $result = BSPublisher::Util::qsystem('echo', "$registry->{user}:$registry->{password}\n", 'stdout', '', @cmd);
    die("Error while uploading to notary: $result\n") if $result;
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
  my $notary_uploads = {};
  my %containers;
  upload_all_containers($extrep, $projid, $repoid, \%containers, $notary_uploads, 0, $old_container_repositories);
  delete_from_notary($projid, $notary_uploads);
}

1;

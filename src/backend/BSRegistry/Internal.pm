#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
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
# The Publisher. Create repositories and push them to our mirrors.
#
package BSRegistry::Internal;

use strict;
use warnings;

use Digest::SHA ();
use File::Temp qw/tempfile tempdir/;
use JSON::XS;

use BSUtil;

=head1 qsystem - secure execution of system calls with output redirection

 Examples:

   qsystem('stdout', $tempfile, $decomp, $in);

   qsystem('chdir', $extrep, 'stdout', 'Packages.new', 'dpkg-scanpackages', '-m', '.', '/dev/null')

=cut

sub qsystem {
  my @args = @_;
  my $pid;
  local (*RH, *WH);
  if ($args[0] eq 'echo') {
    pipe(RH, WH) || die("pipe: $!\n");
  }
  if (!($pid = xfork())) {
    if ($args[0] eq 'echo') {
      close WH;
      open(STDIN, "<&RH");
      close RH;
      splice(@args, 0, 2);
    }
    open(STDOUT, ">/dev/null");
    if ($args[0] eq 'chdir') {
      chdir($args[1]) || die("chdir $args[1]: $!\n");
      splice(@args, 0, 2);
    }
    if ($args[0] eq 'stdout') {
      open(STDOUT, '>', $args[1]) || die("$args[1]: $!\n");
      splice(@args, 0, 2);
    }
    eval {
      exec(@args);
      die("$args[0]: $!\n");
    };
    warn($@) if $@;
    exit 1;
  }
  if ($args[0] eq 'echo') {
    close RH;
    print WH $args[1];
    close WH;
  }
  waitpid($pid, 0) == $pid || die("waitpid $pid: $!\n");
  return $?;
}


=head2 publish_container - publish container into internal registry

=cut

sub publish_container {
  my ($dir, $file, $info, $projid, $repoid, $arch, $tempfile, $container_dir) = @_;

  return if (!$BSConfig::deduplicate_container_layers);

  BSUtil::printlog("Starting deduplication of layers");
  my $sizes = {};

  mkdir_p("$container_dir/tmp");

  my $dirname = tempdir(DIR=>"$container_dir/tmp");

  my @cmd = ("tar", "-C", $dirname, "-xvf", $tempfile);

  BSUtil::printlog("Extracting layers with the command '@cmd'");
  

  my ($fh, $cmdout) = tempfile();
  qsystem('stdout', $cmdout, @cmd);

  my @files = split(/\n/, BSUtil::readstr($cmdout));

  for my $f (@files) {
    my $blob_file_dir = blob_file_dir($container_dir, $f);
    if ( $blob_file_dir ) {
      mkdir_p($blob_file_dir);
      my ($src, $dst) = ("$dirname/$f", "$blob_file_dir/data");
      BSUtil::printlog("Moving $src to $dst");
      rename($src, $dst) || die "Could not move file $src to $dst: $!";
      $sizes->{$f} = -s $dst;
    }
  }
  
  my $json     = BSUtil::readstr("$dirname/manifest.json");
  my $manifest = JSON::XS::decode_json($json);
  my $v2_manifest = prepare_v2_manifest($dirname, $sizes, $manifest->[0]);
  my $v2_manifest_sha256sum = Digest::SHA::sha256_hex($v2_manifest);
  my $v2_manifest_sha256dir = "sha256/$v2_manifest_sha256sum";
  my $blob_file_dir = blob_file_dir($container_dir, "sha256:$v2_manifest_sha256sum");

  foreach my $name_tag (@{$info->{tags}}) {
    my ($name, $tag) = split(/:/, $name_tag);
    BSUtil::mkdir_p($blob_file_dir);
    BSUtil::writestr("$blob_file_dir/data", undef, $v2_manifest);
    my $reg_repo_dir = lc("$projid/$repoid/$arch/$name");
    $reg_repo_dir =~ tr#:#/#;
    $reg_repo_dir = "$container_dir/v2/repositories/$reg_repo_dir";
    BSUtil::printlog("Using repositories directory: $reg_repo_dir");
    my $idx_dir = "_manifests/tags/$tag/index/$v2_manifest_sha256dir";
    my $cur_dir = "_manifests/tags/$tag/current/$v2_manifest_sha256dir";
    my $rev_dir = "_manifests/revisions/$v2_manifest_sha256dir";
    my @all_dirs = (
      "_uploads",
      "_manifests/tags",
      $idx_dir,
      $rev_dir,
      $cur_dir,
      "_layers",
    );

    for my $sdir (@all_dirs) {
      BSUtil::printlog("Creating dir: $reg_repo_dir/$sdir");
      mkdir_p("$reg_repo_dir/$sdir");
    }

    BSUtil::writestr("$reg_repo_dir/$idx_dir/link",undef,"sha256:$v2_manifest_sha256sum");
    BSUtil::writestr("$reg_repo_dir/$rev_dir/link",undef,"sha256:$v2_manifest_sha256sum");
    BSUtil::writestr("$reg_repo_dir/$cur_dir/link",undef,"sha256:$v2_manifest_sha256sum");

    for my $l (@{$manifest->[0]->{Layers}}, $manifest->[0]->{Config}) {
       $l =~ /:(.*)/;
       my $layers_dir = "$reg_repo_dir/_layers/sha256/$1";
       mkdir_p($layers_dir);
       BSUtil::writestr("$layers_dir/link", undef, $l);
    }
  }
  unlink("$dirname/manifest.json");
  rmdir($dirname) || die "Could not unlink '$dirname': $!";
}

sub blob_file_dir {
  my ($dir, $file) = @_;

  return  "$dir/v2/blobs/$1/$3/$2" if ( $file =~ /^(.*):((..).*)$/ );

  return;
}

sub prepare_v2_manifest {
  my ($dirname, $sizes, $manifest) = @_; 

  # home/admin/branches/opensuse.org/opensuse/templates/images/42.3/
  my $v2_manifest = {
    schemaVersion => 2,
    mediaType     => "application/vnd.docker.distribution.manifest.v2+json",
    config        => {
      mediaType     =>"application/vnd.docker.container.image.v1+json",
      digest        => $manifest->{Config},
      size          => $sizes->{$manifest->{Config}}
    },
    "layers"      => []
  };

  for my $l (@{$manifest->{Layers}}) {
    push(@{$v2_manifest->{layers}},
      {
         mediaType => "",
         size      => $sizes->{$l},
         digest    => $l
      }
    )
  };
  return JSON::XS->new->utf8->canonical->encode($v2_manifest);
}

1;

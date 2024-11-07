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

package BSSched::BuildJob::PreInstallImage;

use strict;
use warnings;

use Digest::MD5 ();

use BSUtil;
use BSSched::BuildJob;
use Build;
use BSSolv;		# for gen_meta
use Build;

=head1 NAME

BSSched::BuildJob::PreInstallImage - A Class to handle preinstall image builds

=head1 SYNOPSIS

my $h = BSSched::BuildJob::PreInstallImage->new()

$h->check();

$h->expand();

$h->rebuild();

=cut

=head2 new - TODO: add summary

 TODO: add description

=cut

sub new {
  return bless({}, $_[0]);
}

=head2 expand - TODO: add summary

 TODO: add description

=cut

sub expand {
  shift;
  goto &Build::get_deps;
}

=head2 check - check if a preinstall image needs to be rebuilt

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info, $buildtype, $edeps) = @_;

  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};

  # check if we're blocked
  my $notready = $ctx->{'notready'};
  my $dep2src = $ctx->{'dep2src'};
  my $dep2pkg = $ctx->{'dep2pkg'};
  my @blocked = grep {$notready->{$dep2src->{$_}}} @$edeps;
  if (@blocked) {
    splice(@blocked, 10, scalar(@blocked), '...') if @blocked > 10;
    return ('blocked', join(', ', @blocked));
  }

  # expand like in BSSched::BuildJob::create, so that we have all used packages
  # in the meta file
  my $bconf = $ctx->{'conf'};
  my ($eok, @bdeps) = Build::get_build($bconf, [], @{$info->{'dep'} || []});
  if (!$eok) {
    print "      - $packid (preinstallimage)\n";
    print "        unresolvable:\n";
    print "          $_\n" for @bdeps;
    return ('unresolvable', join(', ', @bdeps));
  }
  my @pdeps = Build::get_preinstalls($bconf);
  my @vmdeps = Build::get_vminstalls($bconf);
  @bdeps = BSUtil::unify(@pdeps, @vmdeps, @bdeps);

  # create meta
  my $pool = $ctx->{'pool'};
  my @new_meta;
  for my $dep (@bdeps) {
    my $p = $dep2pkg->{$dep};
    if (!$p) {
      print "      - $packid (preinstallimage)\n";
      print "        unresolvable:\n          $dep\n";
      return ('unresolvable', $dep);
    }
    push @new_meta, $pool->pkg2pkgid($p)."  $dep";
  }
  @new_meta = BSSolv::gen_meta([], @new_meta);
  return BSSched::BuildJob::metacheck($ctx, $packid, $pdata, 'preinstallimage', \@new_meta, [ \@bdeps ]);
}

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my ($bdeps, $reason) = @$data;
  return BSSched::BuildJob::create($ctx, $packid, $pdata, $info, [], $bdeps, $reason, 0);
}


=head2 update_preinstallimage - extract preinstallimage info from a built job

 TODO: add description

=cut

sub update_preinstallimage {
  my ($gctx, $prp, $packid, $dst, $jobdir) = @_;
  my $myarch = $gctx->{'arch'};
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  my $dirty;
  # wipe old
  my $imagedata = BSUtil::retrieve("$gdst/:preinstallimages", 1) || [];
  my $newimagedata = [ grep {$_->{'package'} ne $packid} @$imagedata ];
  if (@$newimagedata != @$imagedata) {
    $dirty = 1;
    $imagedata = $newimagedata;
  }
  my @all;
  @all = grep {/(?:\.tar\.xz|\.tar\.gz|\.tar\.zst|\.info)$/} grep {!/^\./} sort(ls($jobdir)) if $jobdir;
  my %all = map {$_ => 1} @all;
  my @imgs = grep {s/\.info$//} @all;
  for my $img (@imgs) {
    my $tar;
    next if (-s "$jobdir/$img.info") > 100000;
    if (-f "$jobdir/$img.tar.zst") {
      $tar = "$img.tar.zst";
    } elsif (-f "$jobdir/$img.tar.xz") {
      $tar = "$img.tar.xz";
    } elsif (-f "$jobdir/$img.tar.gz") {
      $tar = "$img.tar.gz";
    }
    next unless $tar;
    my @s = stat("$jobdir/$tar");
    next unless @s;
    my $info = readstr("$jobdir/$img.info", 1);
    next unless $info;
    my $id = Digest::MD5::md5_hex("$info/$s[9]/$s[7]/$s[1]");
    # calculate bitstring
    my $b = "\0" x 512;
    my @hdrmd5s;
    my @bins;
    for (split("\n", readstr("$jobdir/$img.info", 1))) {
      next unless /^([0-9a-f]{32})  ([^ ]+)$/s;
      vec($b, hex(substr($1, 0, 3)), 1) = 1;
      push @hdrmd5s, $1;
      push @bins, $2;
    }
    unlink("$jobdir/.preinstallimage.$id");
    link("$jobdir/$tar", "$jobdir/.preinstallimage.$id") || die("link $jobdir/$tar $jobdir/.preinstallimage.$id");
    if ($dst && $dst ne $jobdir) {
      unlink("$dst/.preinstallimage.$id");
      link("$jobdir/.preinstallimage.$id", "$dst/.preinstallimage.$id") || die("link $jobdir/.$id $dst/.preinstallimage.$id");
    }
    my $sizek = int(($s[7] + 1023) / 1024);
    push @$imagedata, {'package' => $packid, 'hdrmd5' => $id, 'file' => $tar, 'sizek' => $sizek, 'bitstring' => $b, 'hdrmd5s' => \@hdrmd5s, 'bins' => \@bins};
    $dirty = 1;
  }
  if ($dirty) {
    if (@$imagedata) {
      BSUtil::store("$gdst/.:preinstallimages", "$gdst/:preinstallimages", $imagedata);
    } else {
      unlink("$gdst/:preinstallimages");
    }
  }
}

1;

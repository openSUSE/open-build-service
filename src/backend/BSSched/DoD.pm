# Copyright (c) 2015 SUSE LLC
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
package BSSched::DoD;

use strict;
use warnings;

use BSUtil;

=head2 gencookie - generate a cookie from file metadata

 TODO: add description

=cut

sub gencookie {
  my ($datafile) = @_;
  my @s = stat($datafile);
  return @s ? "1/$s[9]/$s[7]/$s[1]" : undef;
}

=head2 readparsed - read the pre-parsed repository metadata

 TODO: add description

=cut

sub readparsed {
  my ($datafile) = @_;
  my $cookie = gencookie($datafile);
  return "doddata: $!" unless $cookie;
  my $data = BSUtil::retrieve($datafile, 2);
  return 'could not retrieve pre-parsed metadata' unless $data;
  my $baseurl = delete $data->{'/url'};
  return 'baseurl missing in data' unless $baseurl;
  for (values %$data) {
    $_->{'id'} = 'dod';
    $_->{'hdrmd5'} = 'd0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0';
  }
  $data->{'/url'} = $baseurl;
  $data->{'/dodcookie'} = $cookie;
  return $data;
}

=head2 put_doddata_in_cache - TODO: add summary

 TODO: add description

=cut

sub put_doddata_in_cache {
  my ($pool, $prp, $cache, $doddata, $dir) = @_;
  if (!$doddata) {
    return (0, $cache) if !$cache || !$cache->dodurl();
    $cache->updatedoddata() if defined &BSSolv::repo::updatedoddata;
    return(1, $cache);
  }
  if ($cache && $cache->dodurl() && defined(&BSSolv::repo::dodcookie)) {
    my $dodcookie = $cache->dodcookie();
    if ($dodcookie) {
      my $cookie = gencookie("$dir/doddata");
      return (0, $cache) if $cookie && $cookie eq $dodcookie;
    }
  }
  my $data = readparsed("$dir/doddata");
  if (!ref($data)) {
    print "    download on demand: $data\n";
    return undef;
  }
  if ($cache) {
    if (!defined &BSSolv::repo::updatedoddata) {
      print "    download on demand: cannot update dod data, perl-BSSolv is too old\n";
      return (0, $cache);
    }
    $cache->updatedoddata($data);
  } else {
    $cache = $pool->repofromdata($prp, $data);
  }
  return (1, $cache);
}

=head2 clean_obsolete_dodpackages - TODO: add summary

 TODO: add description

=cut

sub clean_obsolete_dodpackages {
  my ($cache, $dir, @bins) = @_;

  return @bins unless defined &BSSolv::repo::pkgpaths;
  my %paths = $cache->pkgpaths();
  my @nbins;
  my $nbinsdirty;
  while (@bins) {
    my ($path, $id) = splice(@bins, 0, 2);
    if ($paths{$path}) {
      push @nbins, $path, $id;
      next;
    }
    $nbinsdirty = 1;
    print "      - :full/$path [DoD cleanup]\n";
    unlink("$dir/$path");
  }
  $cache->updatefrombins($dir, @nbins) if $nbinsdirty;
  return @nbins;
}

=head2 dodcheck - TODO: add summary

 TODO: add description

=cut

sub dodcheck {
  my ($ctx, $pool, $arch, @pkgs) = @_;
  $ctx = $ctx->{'realctx'} if $ctx->{'realctx'};	# we need the real one to add entries
  my %names;
  if (defined &BSSolv::repo::dodcookie) {
    %names = (%names, $_->pkgnames()) for grep {$_->dodurl() || $_->dodcookie()} $pool->repos();
  } else {
    %names = (%names, $_->pkgnames()) for $pool->repos();
  }
  my %todownload;
  for my $pkg (@pkgs) {
    my $p = $names{$pkg};
    next unless $p && ($pool->pkg2pkgid($p) || '') eq 'd0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0';
    # ohhh, we have to download
    my $prp = $pool->pkg2reponame($p);
    $ctx->{'doddownloads'}->{"$prp/$arch"}->{$pkg} = 1;
    $todownload{$pkg} = 1;
  }
  return unless %todownload;
  return "downloading ".keys(%todownload)." dod packages";
}

=head2 dodfetch_resume- TODO: add summary

 TODO: add description

=cut

sub dodfetch_resume {
  my ($ctx, $handle, $error) = @_;
  my ($projid, $repoid, $arch) = split('/', $handle->{'_prpa'}, 3);
  if ($error) {
    if (BSSched::RPC::is_transient_error($error)) {
      $ctx->{'gctx'}->{'retryevents'}->addretryevent({'type' => 'repository', 'project' => $projid, 'repository' => $repoid, 'arch' => $arch});
    }
    return;
  }
  $ctx->setchanged($handle);
  # drop cache
  $ctx->{'gctx'}->{'repodatas'}->drop("$projid/$repoid", $arch);
}

=head2 dodfetch - TODO: add summary

 TODO: add description

=cut

sub dodfetch {
  my ($ctx) = @_;
  my $doddownloads = delete $ctx->{'doddownloads'};
  return unless $doddownloads;
  my $gctx = $ctx->{'gctx'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  for my $prpa (sort(keys %$doddownloads)) {
    my @pkgs = sort(keys %{$doddownloads->{$prpa} || {}});
    next unless @pkgs;
    print "    requesting ".@pkgs." dod packages from $prpa\n";
    my ($projid, $repoid, $arch) = split('/', $prpa, 3);
    my $server = $BSConfig::reposerver || $BSConfig::srcserver;
    if ($remoteprojs->{$projid}) {
      $server = $BSConfig::srcserver;
      $server = $remoteprojs->{$projid}->{'remoteurl'} if $remoteprojs->{$projid}->{'partition'};
    }
    my $param = {
      'uri' => "$server/build/$prpa/_repository",
      'receiver' => \&BSHTTP::null_receiver,
      'async' => {
        '_resume' => \&dodfetch_resume,
        '_changetype' => 'med',
        '_prpa' => $prpa,
      },
    };
    eval {
      $ctx->xrpc("dodfetch/$prpa", $param, undef, "view=binaryversions", map {"binary=$_"} @pkgs);
    };
    if ($@) {
      warn($@);
      $ctx->{'gctx'}->{'retryevents'}->addretryevent({'type' => 'repository', 'project' => $projid, 'repository' => $repoid, 'arch' => $arch});
    }
  }
}

=head2 get_dodata - get doddata definition from projpacks

 TODO: add description

=cut

sub get_doddata {
  my ($gctx, $prp, $arch) = @_;
  my ($projid, $repoid) = split('/', $prp, 2);
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid} || {};
  my $repo = (grep {$_->{'name'} eq $repoid} @{$proj->{'repository'} || []})[0] || {};
  return (grep {($_->{'arch'} || '') eq $arch} @{$repo->{'download'} || $proj->{'download'} || []})[0];
}

=head2 update_doddata_prp - TODO: add summary

 TODO: add description

=cut

sub update_doddata_prp {
  my ($gctx, $prp, $doddata) = @_;
  my $myarch = $gctx->{'arch'};
  my $dodprps = $gctx->{'dodprps'};
  return 0 if BSUtil::identical($doddata, $dodprps->{$prp});
  my ($projid, $repoid) = split('/', $prp, 2);
  my $f = "${projid}::${repoid}::$myarch";
  $f = ':'.Digest::MD5::md5_hex($f) if length($f) > 200;
  my $dodsdir = $gctx->{'dodsdir'};
  if (!$doddata) {
    unlink("$dodsdir/$f");
    delete $dodprps->{$prp};
  } else {
    mkdir_p($dodsdir);
    my $dd = { %$doddata, 'project' => $projid, 'repository' => $repoid };
    writexml("$dodsdir/.$f", "$dodsdir/$f", $dd, $BSXML::doddata);
    $dodprps->{$prp} = $doddata;
  }
  return 1;
}

=head2 update_doddata - TODO: add summary

 TODO: add description

=cut

sub update_doddata {
  my ($gctx, $projid, $proj) = @_;
  return unless $gctx->{'dodsdir'};
  my $myarch = $gctx->{'arch'};
  my $dodprps = $gctx->{'dodprps'};
  my $changed;
  my %prpseen;
  # update/add entries
  if ($proj) {
    for my $repo (@{$proj->{'repository'} || []}) {
      my $doddata = (grep {($_->{'arch'} || '') eq $myarch} @{$repo->{'download'} || []})[0];
      my $prp = "$projid/$repo->{'name'}";
      $prpseen{$prp} = 1;
      $changed = 1 if update_doddata_prp($gctx, $prp, $doddata);
    }
  }
  # delete no longer existing entries
  for my $prp (sort(keys %$dodprps)) {
    next unless (split('/', $prp, 2))[0] eq $projid;
    next if $prpseen{$prp};
    $changed = 1 if update_doddata_prp($gctx, $prp, undef);
  }
  my $dodsdir = $gctx->{'dodsdir'};
  BSUtil::touch("$dodsdir/.changed") if $changed && -d $dodsdir;
}

=head2 init_doddata - bring dodprps and dodsdir in sync with projpacks

 TODO: add description

=cut

sub init_doddata {
  my ($gctx) = @_;
  my $myarch = $gctx->{'arch'};
  my $changed;
  my %dodfiles;
  my $dodsdir = $gctx->{'dodsdir'};
  my $dodprps = $gctx->{'dodprps'} = {};
  my $projpacks = $gctx->{'projpacks'};
  for my $projid (sort keys %$projpacks) {
    for my $repo (@{($projpacks->{$projid} || {})->{'repository'} || []}) {
      next unless $repo->{'download'};
      my $doddata = (grep {($_->{'arch'} || '') eq $myarch} @{$repo->{'download'} || []})[0];
      next unless $doddata;
      my $repoid = $repo->{'name'};
      $dodprps->{"$projid/$repoid"} = $doddata;
      my $f = "${projid}::${repoid}::$myarch";
      $f = ':'.Digest::MD5::md5_hex($f) if length($f) > 200;
      $dodfiles{$f} = 1;
      my $dd = { %$doddata, 'project' => $projid, 'repository' => $repoid };
      my $olddd = readxml("$dodsdir/$f", $BSXML::doddata, 1);
      next if BSUtil::identical($olddd, $dd);
      mkdir_p($dodsdir);
      writexml("$dodsdir/.$f", "$dodsdir/$f", $dd, $BSXML::doddata);
      $changed = 1;
    }
  }
  for my $f (grep {!/^\./ && !$dodfiles{$_}} ls($dodsdir)) {
    my $olddd = readxml("$dodsdir/$f", $BSXML::doddata, 1);
    next if $olddd && $olddd->{'arch'} ne $myarch;
    unlink("$dodsdir/$f");
    $changed = 1;
  }
  BSUtil::touch("$dodsdir/.changed") if $changed && -d $dodsdir;
}

1;

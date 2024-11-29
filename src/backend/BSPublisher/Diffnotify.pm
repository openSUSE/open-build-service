#
# Copyright (c) 2024 SUSE LLC
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
# diff notifications
#

package BSPublisher::Diffnotify;

use strict;

use MIME::Base64 ();
use JSON::XS ();

use BSOBS;
use BSUtil;

my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

sub tagdata_callback {
  my ($data, $registry, $containerinfo, $platformstr, $tags_seen, $tags_used) = @_;
  my $registrydata = $data->{'registrydata'};
  my $gunprefix = $registry->{'notary_gunprefix'} || $registry->{'server'} || '';
  $gunprefix =~ s/^https?:\/\///;
  my $p = $containerinfo->{'_p'};
  $registrydata->{'tagdata'}->{$p}->{'platformstr'} = $platformstr;
  $registrydata->{'tagdata'}->{$p}->{'tags'}->{$gunprefix} = $tags_seen;
  $registrydata->{'tagdata'}->{$p}->{'visibletags'}->{$gunprefix} = $tags_used;
}

sub regdata_callback {
  my ($data, $registry, $tag, $taginfo) = @_;
  my $registrydata = $data->{'registrydata'};
  my $gunprefix = $registry->{'notary_gunprefix'} || $registry->{'server'} || '';
  $gunprefix =~ s/^https?:\/\///;
  my $islist = $taginfo->{'distmanifesttype'} eq 'list' ? 1 : 0;
  for my $imginfo (@{$taginfo->{'images'} || []}) {
    my $platformstr = BSContar::make_platformstr($imginfo->{'goarch'}, $imginfo->{'govariant'}, $imginfo->{'goos'});
    my $regtag = $islist ? "$tag\0$platformstr" : $tag;
    my $containerinfo = $imginfo->{'containerinfo'};
    my $info = { 'distmanifest' => $imginfo->{'distmanifest'}, 'imageid' => $imginfo->{'imageid'}, 'platform' => $platformstr, '_p' => $containerinfo->{'_p'} };
    $registrydata->{'regdata'}->{$gunprefix}->{$regtag} = $info;
  }
  if ($islist) {
    my $info = { 'distmanifest' => $taginfo->{'distmanifest'} };
    $registrydata->{'regdata'}->{$gunprefix}->{$tag} = $info;
  }
}

sub packtrack2bin {
  my ($pt, $filename, $containers) = @_;
  my $bin = { 'path' => $filename };
  for (qw{name epoch version release binaryid package disturl}) {
    $bin->{$_} = $pt->{$_} if defined $pt->{$_};
  }
  $bin->{'architecture'} = $pt->{'binaryarch'} if $pt->{'binaryarch'};
  $bin->{'schedulerarch'} = $pt->{'arch'} if $pt->{'arch'};
  my @assoc;
  if ($containers->{$filename}) {
    my $containerinfo = $containers->{$filename};
    for (@{$containerinfo->{'_associated'} || []}) {
      my $assoc = $_;
      $assoc =~ s/.*\///;
      push @{$bin->{'associated'}}, $assoc;
    }
  }
  return $bin;
}

sub is_unchanged {
  my ($o, $n) = @_;
  for (qw{binaryid distmanifest name epoch version release}) {
    return 0 if ($o->{$_} || '') ne ($n->{$_} || '');
  }
  return 1;
}

sub create_notification {
  my ($notify, $data, $oldstate, $newstate) = @_;

  my $n = {};
  $n->{'dag_run_id'} = "$data->{'publishid'}";
  $n->{'conf'}->{'project'} = $data->{'projid'};
  $n->{'conf'}->{'repository'} = $data->{'repoid'};
  $n->{'conf'}->{'binaries'} = [];
  my $bdiff = diffdata($oldstate->{'binaries'}, $newstate->{'binaries'}, 'path');
  for $b (@$bdiff) {
    $b = { %$b };
    $b->{'binaryname'} = delete $b->{'name'} if exists $b->{'name'};
    if (defined($b->{'path'})) {
      $b->{'name'} = $b->{'path'};
      $b->{'name'} =~ s/.*\///;
    }
    push @{$n->{'conf'}->{'binaries'}}, $b;
  }
  my $registries = $notify->{'no_registries'} ? {} : $newstate->{'registries'};
  for my $gunprefix (sort keys %$registries) {
    my $rdiff = diffdata((($oldstate->{'registries'} || {})->{$gunprefix} || {})->{'tags'}, $registries->{$gunprefix}->{'tags'}, 'tag');
    for $b (@$rdiff) {
      $b = { %$b };
      $b->{'binaryname'} = delete $b->{'name'} if exists $b->{'name'};
      if (defined($b->{'path'})) {
        $b->{'name'} = $b->{'path'};
        $b->{'name'} =~ s/.*\///;
      }
      push @{$n->{'conf'}->{'registries'}->{$gunprefix}->{'tags'}}, $b;
    }
  }
  return $n;
}

sub diffdata {
  my ($old, $new, $type) = @_;
  $old ||= [];
  $new ||= [];
  my @ret;
  my %old;
  my %new;
  for (@$old) {
    my $k = $_->{$type};
    $k =~ s/(:.*):/$1\0/ if $type eq 'tag';
    $old{$k} = $_;
  }
  for (@$new) {
    my $k = $_->{$type};
    $k =~ s/(:.*):/$1\0/ if $type eq 'tag';
    $new{$k} = $_;
  }
  for my $k (sort keys %{ { %old, %new } }) {
    my $o = $old{$k};
    my $n = $new{$k};
    my $r;
    if (!$o) {
      $r = { %$n, 'state' => 'added' };
    } elsif (!$n) {
      $r = { %$o, 'state' => 'removed' };
    } elsif (!BSUtil::identical($o, $n)) {
      if (is_unchanged($o, $n)) {
        $r = { %$n, 'state' => 'unchanged' };
      } else {
        $r = { %$n, 'state' => 'changed' };
      }
    }
    next unless $r;
    if (defined $r->{'package'}) {
      $r->{'flavor'} = '';
      if ($r->{'package'} =~ /(?<!^_product)(?<!^_patchinfo):./ && $r->{'package'} =~ /^(.*):(.*?)$/) {
        ($r->{'package'}, $r->{'flavor'}) = ($1, $2);
      }
      # hack: try to get flavor from disturl for aggregated containers
      $r->{'flavor'} = $1 if $r->{'flavor'} eq '' && $r->{'disturl'} && $r->{'disturl'} =~ /:([^:\/]+)$/;
    }
    push @ret, $r;
  }
  return \@ret;
}

sub notification {
  my ($extrep, $data, $notify, $packtrack, $containers, $registrydata) = @_;

  die("bad notification configuration\n") unless $notify->{'statedir'} && $notify->{'uri'};
  my @binaries;
  my %registries;
  for my $filename (sort(grep {!defined($packtrack->{$_}->{'medium'})} keys %$packtrack)) {
    my $pt = $packtrack->{$filename};
    my $bin = packtrack2bin($pt, $filename, $containers);
    if ($registrydata->{'tagdata'}->{$filename}) {
      $bin->{'platform'} = $registrydata->{'tagdata'}->{$filename}->{'platformstr'};
      $bin->{'tags'} = $registrydata->{'tagdata'}->{$filename}->{'tags'};
      $bin->{'visibletags'} = $registrydata->{'tagdata'}->{$filename}->{'visibletags'};
    }
    if ($bin->{'path'} =~ /^(.*)\.(?:$binsufsre)$/) {
      my $slsa = "$1.slsa_provenance.json";
      if (-e "$extrep/$slsa") {
	$slsa =~ s/.*\///;
        push @{$bin->{'associated'}}, $slsa;
      }
    }
    push @binaries, $bin;
  }

  for my $gunprefix (sort keys %{$registrydata->{'regdata'} || {}}) {
    my $tags = $registrydata->{'regdata'}->{$gunprefix};
    for my $tag (sort keys %$tags) {
      my $imageinfo = $tags->{$tag};
      my $pt;
      $pt = $packtrack->{$imageinfo->{'_p'}} if $imageinfo->{'_p'};
      my $bin;
      if ($pt) {
        $bin = packtrack2bin($pt, $imageinfo->{'_p'}, $containers);
        if ($imageinfo->{'imageid'}) {
	  $bin->{'binaryid'} = $imageinfo->{'imageid'};
	  $bin->{'binaryid'} =~ s/^.*?://;
        }
	$bin->{'distmanifest'} = $imageinfo->{'distmanifest'};
      } else {
	$bin = {};
	$bin->{'distmanifest'} = $imageinfo->{'distmanifest'};
      }
      $bin->{'tag'} = $tag;
      $bin->{'tag'} =~ s/\0/:/g;
      push @{$registries{$gunprefix}->{'tags'}}, $bin;
    }
  }

  # read old state
  my $prp = "$data->{'projid'}/$data->{'repoid'}";
  my $oldstate = BSUtil::retrieve("$notify->{'statedir'}/$prp/state", 1) || {};
  my $newstate = {
    'binaries' => \@binaries,
    'registries' => \%registries,
  };

  # create and send notification
  my $n = create_notification($notify, $data, $oldstate, $newstate);
  my $n_json = JSON::XS->new->utf8->canonical->encode($n);
  my $param = {
    'uri' => $notify->{'uri'}, 
    'request' => 'POST',
    'headers' => [ 'Accept: application/json', 'Content-type: application/json' ],
    'data' => $n_json,
  };
  if ($notify->{'user'}) {
    my $auth = $notify->{'user'};
    $auth .= ":$notify->{'password'}" if defined $notify->{'password'};
    $auth = "Authorization: Basic ".MIME::Base64::encode_base64($auth, '');
    push @{$param->{'headers'}}, $auth;
  }
  $param->{'ssl_verify'} = $notify->{'ssl_verify'} if defined $notify->{'ssl_verify'};
  BSRPC::rpc($param) unless $notify->{'uri'} eq 'null:';

  # save new state
  mkdir_p("$notify->{'statedir'}/$prp");
  BSUtil::store("$notify->{'statedir'}/$prp/.state.$$", "$notify->{'statedir'}/$prp/state", $newstate);

  # save what we sent
  writestr("$notify->{'statedir'}/$prp/.report.$$", "$notify->{'statedir'}/$prp/report", $n_json);
}

1;

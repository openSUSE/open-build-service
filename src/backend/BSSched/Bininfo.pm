# Copyright (c) 2025 SUSE LLC
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
package BSSched::Bininfo;

use strict;
use warnings;

use JSON::XS ();

use BSOBS;
use BSUtil;
use BSVerify;

use Build;


my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

sub helminfo2bininfo {
  my ($dir, $helminfo) = @_;
  return undef unless -e "$dir/$helminfo";
  return undef unless (-s _) < 100000;
  my $m = readstr("$dir/$helminfo");
  my $d;
  eval { $d = JSON::XS::decode_json($m); };
  return undef unless $d && ref($d) eq 'HASH';
  return undef unless $d->{'name'} && ref($d->{'name'}) eq '';
  return undef unless $d->{'version'} && ref($d->{'version'}) eq '';
  return undef unless !$d->{'tags'} || ref($d->{'tags'}) eq 'ARRAY';
  return undef unless $d->{'chart'} && ref($d->{'chart'}) eq '';
  my $info = { 'name' => "helm:$d->{'name'}",
               'version' => (defined($d->{'version'}) ? $d->{'version'} : '0'),
               'release' => (defined($d->{'release'}) ? $d->{'release'} : '0'),
               'arch' => (defined($d->{'arch'}) ? $d->{'arch'} : 'noarch') };
  eval { BSVerify::verify_nevraquery($info) };
  if ($@) {
    warn($@);
    return undef;
  }
  return $info;
}

=head2 create_bininfo - collect binary info of built artefacts

 TODO: add description

=cut

sub create_bininfo {
  my ($dir, $nonfatal) = @_;

  my $bininfo = {};
  for my $file (ls($dir)) {
    $bininfo->{'.nosourceaccess'} = {} if $file eq '.nosourceaccess';
    if ($file !~ /\.(?:$binsufsre)$/) {
      $bininfo->{'.nouseforbuild'} = {} if $file eq '.channelinfo' || $file eq 'updateinfo.xml' || $file eq '.updateinfodata' || $file eq '.nouseforbuild';
      if ($file =~ /\.obsbinlnk$/) {
	my @s = stat("$dir/$file");
	my $d = BSUtil::retrieve("$dir/$file", $nonfatal);
	next unless @s && $d;
	my $r = {%$d, 'filename' => $file, 'id' => "$s[9]/$s[7]/$s[1]"};
	delete $r->{'path'};
	$bininfo->{$file} = $r;
      } elsif ($file =~ /[-.]appdata\.xml$/ || $file eq '_modulemd.yaml' || $file =~ /slsa_provenance\.json$/ || $file eq 'updateinfo.xml') {
        local *F;
        open(F, '<', "$dir/$file") || next;
        my @s = stat(F);
        next unless @s;
        my $ctx = Digest::MD5->new;
        $ctx->addfile(*F);
        close F;
        $bininfo->{$file} = {'md5sum' => $ctx->hexdigest(), 'filename' => $file, 'id' => "$s[9]/$s[7]/$s[1]"};
      } elsif ($file =~ /\.helminfo$/) {
	my @s = stat("$dir/$file");
        next unless @s;
	my $r = helminfo2bininfo($dir, $file);
	die("$file: could not parse helminfo\n") if !$r && !$nonfatal;
	next unless $r;
	$r->{'filename'} = $file;
	$r->{'id'} = "$s[9]/$s[7]/$s[1]";
	$bininfo->{$file} = $r;
      }
      next;
    }
    my @s = stat("$dir/$file");
    next unless @s;
    my $id = "$s[9]/$s[7]/$s[1]";
    my $data;
    eval {
      my $leadsigmd5;
      die("no hdrmd5\n") unless Build::queryhdrmd5("$dir/$file", \$leadsigmd5);
      $data = Build::query("$dir/$file", 'evra' => 1);
      die("queury failed\n") unless $data;
      BSVerify::verify_nevraquery($data);
      $data->{'leadsigmd5'} = $leadsigmd5 if $leadsigmd5;
    };
    if ($@) {
      die("$file: $@") unless $nonfatal;
      warn("$file: $@");
      next;
    }
    $data->{'filename'} = $file;
    $data->{'id'} = $id;
    $bininfo->{$file} = $data;
  }
  return $bininfo;
}

1;

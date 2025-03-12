# Copyright (c) 2016 SUSE LLC
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
package BSSrcServer::Remote;

use strict;
use warnings;

use Digest::MD5;

use BSConfiguration;
use BSOBS;
use BSRPC;
use BSWatcher;
use BSUtil;
use BSRevision;
use BSXML;
use BSSrcrep;

my $remotecache = "$BSConfig::bsdir/remotecache";
my $projectsdir = "$BSConfig::bsdir/projects";

my $srcrep = "$BSConfig::bsdir/sources";
my $uploaddir = "$srcrep/:upload";

my $proxy;
$proxy = $BSConfig::proxy if defined $BSConfig::proxy;

my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

# remote getrev cache
our $collect_remote_getrev;
my $remote_getrev_todo;
my %remote_getrev_cache;

sub remoteprojid {
  my ($projid) = @_;
  my $rsuf = '';
  my $origprojid = $projid;

  my $proj = BSRevision::readproj_local($projid, 1);
  if ($proj) {
    return undef unless $proj->{'remoteurl'};
    if (!$proj->{'remoteproject'}) {
      delete $proj->{'remoteurl'};
      return $proj;
    }
    return {
      'name' => $projid,
      'root' => $projid,
      'remoteroot' => $proj->{'remoteproject'},
      'remoteurl' => $proj->{'remoteurl'},
      'remoteproject' => $proj->{'remoteproject'},
      'remoteproxy' => $proxy,
    };
  }
  while ($projid =~ /^(.*)(:.*?)$/) {
    $projid = $1;
    $rsuf = "$2$rsuf";
    $proj = BSRevision::readproj_local($projid, 1);
    if ($proj) {
      return undef unless $proj->{'remoteurl'};
      if ($proj->{'remoteproject'}) {
        $rsuf = "$proj->{'remoteproject'}$rsuf";
      } else {
        $rsuf =~ s/^://;
      }
      return {
        'name' => $origprojid,
        'root' => $projid,
        'remoteroot' => $proj->{'remoteproject'},
        'remoteurl' => $proj->{'remoteurl'},
        'remoteproject' => $rsuf,
        'remoteproxy' => $proxy,
      };
    }
  }
  return undef;
}

sub findpackages_remote {
  my ($projid, $proj, $nonfatal, $origins, $noexpand, $deleted) = @_;

  my @packids;
  my @args;
  push @args, 'deleted=1' if $deleted;
  push @args, 'expand=1' unless $noexpand || $deleted;
  my $r;
  eval {
    $r = BSRPC::rpc({'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}", 'proxy' => $proj->{'remoteproxy'}}, $BSXML::dir, @args);
  };
  if ($@ && $@ =~ /^404/) {
    # remote project does not exist
    die($@) unless $nonfatal;
    return ();
  }
  if ($@) {
    die($@) unless $nonfatal && $nonfatal > 0;  # -1: internal projectlink recursion, errors are still fatal
    warn($@);
    push @packids, ':missing_packages' if $nonfatal == 2;
    return @packids;
  }
  @packids = map {$_->{'name'}} @{($r || {})->{'entry'} || []};
  if ($origins) {
    for my $entry (@{($r || {})->{'entry'} || []}) {
      $origins->{$entry->{'name'}} = defined($entry->{'originproject'}) ? maptoremote($proj, $entry->{'originproject'}) : $projid;
    }
  }
  return @packids;
}

sub maptoremote {
  my ($proj, $projid) = @_;
  return "$proj->{'root'}:$projid" unless $proj->{'remoteroot'};
  return $proj->{'root'} if $projid eq $proj->{'remoteroot'};
  return '_unavailable' if $projid !~ /^\Q$proj->{'remoteroot'}\E:(.*)$/;
  return "$proj->{'root'}:$1";
}

sub mappackagedata {
  my ($pack, $lproj) = @_;
  $pack->{'project'} = $lproj->{'name'};	# local name;
  if ($pack->{'devel'} && exists($pack->{'devel'}->{'project'})) {
    $pack->{'devel'}->{'project'} = maptoremote($lproj, $pack->{'devel'}->{'project'});
  }
}

sub mapprojectdata {
  my ($proj, $lproj) = @_;
  $proj->{'name'} = $lproj->{'name'};		# local name;
  for my $repo (@{$proj->{'repository'} || []}) {
    for my $pathel (@{$repo->{'path'} || []}) {
      $pathel->{'project'} = maptoremote($lproj, $pathel->{'project'});
    }
    for my $pathel (@{$repo->{'releasetarget'} || []}) {
      $pathel->{'project'} = maptoremote($lproj, $pathel->{'project'});
    }
  }
  for my $link (@{$proj->{'link'} || []}) {
    $link->{'project'} = maptoremote($lproj, $link->{'project'});
  }
}

sub fetchremoteproj {
  my ($proj, $projid, $remotemap) = @_;
  return undef unless $proj && $proj->{'remoteurl'} && $proj->{'remoteproject'};
  $projid ||= $proj->{'name'};
  if ($BSStdServer::isajax) {
    die("fetchremoteproj: remotemap is not implemented\n") if $remotemap;
    my $jev = $BSServerEvents::gev;
    return $jev->{"fetchremoteproj_$projid"} if exists $jev->{"fetchremoteproj_$projid"};
  }
  my $c;
  if ($remotemap) {
    my $rproj = $remotemap->{$projid};
    if ($rproj) {
      die($rproj->{'error'}) if $rproj->{'error'};
      return $rproj unless $rproj->{'proto'};
      $c = $rproj->{'config'};  # save old config
    }
  }
  print "fetching remote project data for $projid\n";
  my $param = {
    'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}/_meta",
    'timeout' => 60,
    'proxy' => $proj->{'remoteproxy'},
  };
  my $rproj = eval { BSWatcher::rpc($param, $BSXML::proj) };
  $rproj = {'error' => $@, 'proto' => 1} if $@;
  return undef if $BSStdServer::isajax && !defined($rproj);
  $rproj->{$_} = $proj->{$_} for qw{root remoteroot remoteurl remoteproject remoteproxy};
  $rproj->{'config'} = $c if defined $c;
  mapprojectdata($rproj, $proj);
  $remotemap->{$projid} = $rproj if $remotemap;
  if ($BSStdServer::isajax) {
    my $jev = $BSServerEvents::gev;
    $jev->{"fetchremoteproj_$projid"} = $rproj;
  }
  die($rproj->{'error'}) if $rproj->{'error'};
  return $rproj;
}

sub fetchremoteconfig {
  my ($proj, $projid, $remotemap) = @_;
  return undef unless $proj && $proj->{'remoteurl'} && $proj->{'remoteproject'};
  $projid ||= $proj->{'name'};
  if ($BSStdServer::isajax) {
    die("fetchremoteconfig: remotemap is not implemented\n") if $remotemap;
    my $jev = $BSServerEvents::gev;
    return $jev->{"fetchremoteconfig_$projid"} if exists $jev->{"fetchremoteconfig_$projid"};
  }
  if ($remotemap) {
    my $rproj = $remotemap->{$projid};
    if ($rproj) {
      die($rproj->{'error'}) if $rproj->{'error'};
      return $rproj->{'config'} if defined $rproj->{'config'};
    } else {
      $rproj = {'proto' => 1};
      $rproj->{$_} = $proj->{$_} for qw{root remoteroot remoteurl remoteproject remoteproxy};
      $remotemap->{$projid} = $rproj;
    }
  }
  print "fetching remote project config for $projid\n";
  my $param = {
    'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}/_config",
    'timeout' => 60,
    'proxy' => $proj->{'remoteproxy'},
  };
  my $c = eval { BSWatcher::rpc($param, undef) };
  if ($@) {
    $remotemap->{$projid}->{'error'} = $@ if $remotemap;
    die($@);
  }
  if ($BSStdServer::isajax) {
    return undef unless defined($c);
    my $jev = $BSServerEvents::gev;
    $jev->{"fetchremoteconfig_$projid"} = $c;
  }
  $remotemap->{$projid}->{'config'} = $c if $remotemap;
  return $c;
}

sub readconfig_remote {
  my ($projid, $proj) = @_;
  my $param = {
    'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}/_config",
    'timeout' => 600,
    'proxy' => $proj->{'remoteproxy'},
  }; 
  return BSRPC::rpc($param, undef);
}

# returns undef if the project does not exist
sub readproject_remote {
  my ($projid, $proj, $rev, $missingok) = @_;
  my @args;
  push @args, "rev=$rev" if $rev;
  my $param = {
    'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}/_meta",
    'timeout' => 600,
    'proxy' => $proj->{'remoteproxy'},
  };
  my $rproj;
  eval {
    $rproj = BSRPC::rpc($param, $BSXML::proj, @args);
  };
  die($@) if $@ && (!$missingok || $@ !~ /^404/);
  if ($rproj) {
    mapprojectdata($rproj, $proj);
    delete $rproj->{'person'};
    delete $rproj->{'group'};
    $rproj->{'mountproject'} = $proj->{'root'} if defined($proj->{'root'});
  }
  return $rproj;
}

# returns undef if the project or package does not exist
# dies on other errors
sub readpackage_remote {
  my ($projid, $proj, $packid, $rev, $missingok) = @_;
  my @args;
  push @args, "rev=$rev" if $rev;
  my $param = {
    'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}/$packid/_meta",
    'timeout' => 600,
    'proxy' => $proj->{'remoteproxy'},
  };
  my $pack;
  eval {
    $pack = BSRPC::rpc($param, $BSXML::pack, @args);
  };
  die($@) if $@ && (!$missingok || $@ !~ /^404/);
  if ($pack) {
    mappackagedata($pack, $proj);
    delete $pack->{'person'};
    delete $pack->{'group'};
    delete $pack->{$_} for map {$_->[0]} @BSXML::flags;
  }
  return $pack;
}


sub fill_remote_getrev_cache_projid {
  my ($projid, $packids) = @_;

  return unless $packids && @$packids;
  print "filling remote_getrev cache for $projid @$packids\n";
  my $proj = remoteprojid($projid);
  return unless $proj;
  my $silist;
  my @args;
  push @args, 'view=info';
  push @args, 'nofilename=1';
  push @args, map {"package=$_"} @$packids;
  eval {
    $silist = BSRPC::rpc({'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}", 'proxy' => $proj->{'remoteproxy'}}, $BSXML::sourceinfolist, @args);
  };
  warn($@) if $@;
  return unless $silist;
  for my $si (@{$silist->{'sourceinfo'} || []}) {
    my $packid = $si->{'package'};
    my $rev = {};
    if ($si->{'linked'}) {
      $rev->{'linked'} = [];
      for my $l (@{$si->{'linked'}}) {
        $l->{'project'} = maptoremote($proj, $l->{'project'});
        push @{$rev->{'linked'}}, $l if defined($l->{'project'}) && $l->{'project'} ne '_unavailable';
      }
    }
    $rev->{'srcmd5'} = $si->{'verifymd5'} || $si->{'srcmd5'};
    delete $rev->{'srcmd5'} unless defined $rev->{'srcmd5'};
    if ($si->{'error'}) {
      if ($si->{'error'} =~ /^(\d+) +(.*?)$/) {
        $si->{'error'} = "$1 remote error: $2";
      } else {
        $si->{'error'} = "remote error: $si->{'error'}";
      }
      if ($si->{'error'} eq 'no source uploaded') {
        delete $si->{'error'};
        $rev->{'srcmd5'} = $BSSrcrep::emptysrcmd5;
      } elsif ($si->{'verifymd5'} || $si->{'error'} =~ /^404[^\d]/) {
        $rev->{'error'} = $si->{'error'};
        $remote_getrev_cache{"$projid/$packid/"} = $rev;
      } else {
        next;
      }
    }
    next unless $rev->{'srcmd5'};
    next unless BSSrcrep::existstree($projid, $packid, $rev->{'srcmd5'});
    $rev->{'vrev'} = $si->{'vrev'} || '0';
    $rev->{'rev'} = $si->{'rev'} || $rev->{'srcmd5'};
    $remote_getrev_cache{"$projid/$packid/"} = $rev;
  }
}

sub fill_remote_getrev_cache {
  for my $projid (sort keys %{$remote_getrev_todo || {}}) {
    my @packids = sort keys %{$remote_getrev_todo->{$projid} || {}};
    next if @packids <= 1;
    while (@packids) {
      my @chunk;
      my $len = 20;
      while (@packids) {
        my $packid = shift @packids;
        push @chunk, $packid;
        $len += 9 + length($packid);
        last if $len > 1900;
      }
      fill_remote_getrev_cache_projid($projid, \@chunk);
    }
  }
  $remote_getrev_todo = {};
}

sub getrev_remote {
  my ($projid, $proj, $packid, $rev, $linked, $missingok) = @_;
  # check if we already know this srcmd5, if yes don't bother to contact
  # the remote server
  if ($rev && $rev =~ /^[0-9a-f]{32}$/) {
    if (BSSrcrep::existstree($projid, $packid, $rev)) {
      return {'project' => $projid, 'package' => $packid, 'rev' => $rev, 'srcmd5' => $rev};
    }
  }
  if (defined($rev) && $rev eq '0') {
    return {'srcmd5' => $BSSrcrep::emptysrcmd5, 'project' => $projid, 'package' => $packid};
  }
  my @args;
  push @args, 'expand=1';
  push @args, "rev=$rev" if defined $rev;
  my $cacherev = !defined($rev) || $rev eq 'build' ? '' : $rev;
  if ($remote_getrev_cache{"$projid/$packid/$cacherev"}) {
    $rev = { %{$remote_getrev_cache{"$projid/$packid/$cacherev"}} };
    push @$linked, map { { %$_ } } @{$rev->{'linked'}} if $linked && $rev->{'linked'};
    if ($rev->{'error'}) {
      return {'project' => $projid, 'package' => $packid, 'srcmd5' => $BSSrcrep::emptysrcmd5} if $missingok && $rev->{'error'} =~ /^404[^\d]/;
      die("$rev->{'error'}\n");
    }
    delete $rev->{'linked'};
    $rev->{'project'} = $projid;
    $rev->{'package'} = $packid;
    return $rev;
  }
  if ($collect_remote_getrev && $cacherev eq '') {
    $remote_getrev_todo->{$projid}->{$packid} = 1;
    die("collect_remote_getrev\n");
  }
  my $dir;
  eval {
    $dir = BSRPC::rpc({'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}/$packid", 'proxy' => $proj->{'remoteproxy'}}, $BSXML::dir, @args, 'withlinked') if $linked;
  };
  if (!$dir || $@) {
    eval {
      $dir = BSRPC::rpc({'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}/$packid", 'proxy' => $proj->{'remoteproxy'}}, $BSXML::dir, @args);
    };
    if ($@) {
      return {'project' => $projid, 'package' => $packid, 'srcmd5' => $BSSrcrep::emptysrcmd5} if $missingok && $@ =~ /^404[^\d]/;
      die($@);
    }
  }
  if ($dir->{'error'}) {
    if ($linked && $dir->{'linkinfo'} && $dir->{'linkinfo'}->{'linked'}) {
      # add linked info for getprojpack
      for my $l (@{$dir->{'linkinfo'}->{'linked'}}) {
        $l->{'project'} = maptoremote($proj, $l->{'project'});
        push @$linked, $l if defined($l->{'project'}) && $l->{'project'} ne '_unavailable';
      }
    }
    die("$dir->{'error'}\n");
  }
  $rev = {};
  $rev->{'project'} = $projid;
  $rev->{'package'} = $packid;
  $rev->{'rev'} = $dir->{'rev'} || $dir->{'srcmd5'};
  $rev->{'srcmd5'} = $dir->{'srcmd5'};
  $rev->{'vrev'} = $dir->{'vrev'};
  $rev->{'vrev'} ||= '0';
  # now put everything in local source repository
  my $files = {};
  for my $entry (@{$dir->{'entry'} || []}) {
    $files->{$entry->{'name'}} = $entry->{'md5'};
    # check if we already have the file
    next if -e BSRevision::revfilename($rev, $entry->{'name'}, $entry->{'md5'});
    # nope, download it
    if ($linked && $entry->{'size'} > 8192) {
      # getprojpack request, hand over to AJAX
      BSHandoff::rpc("/source/$projid/$packid", undef, "rev=$dir->{'srcmd5'}", 'view=notify');
      die("download in progress\n");
    }
    mkdir_p($uploaddir);
    my $param = {
      'uri' => "$proj->{'remoteurl'}/source/$proj->{'remoteproject'}/$packid/$entry->{'name'}",
      'filename' => "$uploaddir/$$",
      'withmd5' => 1,
      'receiver' => \&BSHTTP::file_receiver,
      'proxy' => $proj->{'remoteproxy'},
    };
    my $res = BSRPC::rpc($param, undef, "rev=$rev->{'srcmd5'}");
    die("file download failed\n") unless $res && $res->{'md5'} eq $entry->{'md5'};
    BSSrcrep::addfile($projid, $packid, "$uploaddir/$$", $entry->{'name'}, $entry->{'md5'});
  }
  my $srcmd5 = BSSrcrep::addmeta($projid, $packid, $files);
  if ($dir->{'serviceinfo'}) {
    $dir->{'srcmd5'} = $rev->{'srcmd5'} = $srcmd5;
  }
  my @linked;
  if ($dir->{'linkinfo'}) {
    my $li = $dir->{'linkinfo'};
    # hack: the following line is used because we fake a linkinfo element
    # for project links... compatibility to old versions sure has some
    # drawbacks...
    if (defined($li->{'project'})) {
      $dir->{'srcmd5'} = $rev->{'srcmd5'} = $srcmd5;
      $rev->{'rev'} = $rev->{'srcmd5'} unless $dir->{'rev'};
    }
    if ($linked) {
      # add linked info for getprojpack
      if ($li->{'linked'}) {
        for my $l (@{$li->{'linked'}}) {
          $l->{'project'} = maptoremote($proj, $l->{'project'});
          push @linked, $l if defined($l->{'project'}) && $l->{'project'} ne '_unavailable';
        }
        undef $li;
      }
      while ($li) {
        my $lprojid = $li->{'project'};
        my $lpackid = $li->{'package'};
        last unless defined($lprojid) && defined($lpackid);
        my $mlprojid = maptoremote($proj, $lprojid);
        last unless defined($mlprojid) && $mlprojid ne '_unavailable';
        push @linked, {'project' => $mlprojid, 'package' => $lpackid};
        last unless $li->{'srcmd5'} && !$li->{'error'};
        my $ldir;
        eval {
          $ldir = BSRPC::rpc({'uri' => "$proj->{'remoteurl'}/source/$lprojid/$lpackid", 'proxy' => $proj->{'remoteproxy'}}, $BSXML::dir, "rev=$li->{'srcmd5'}");
        };
        last if $@ || !$ldir;
        $li = $ldir->{'linkinfo'};
      }
      push @$linked, @linked;
    }
  }
  die("srcmd5 mismatch\n") if $dir->{'srcmd5'} ne $srcmd5;
  if (!$dir->{'linkinfo'} || $linked) {
    my %revcopy = %$rev;
    delete $revcopy{'project'};         # save mem
    delete $revcopy{'package'};
    $revcopy{'linked'} = [ map { { %$_ } } @linked ] if $dir->{'linkinfo'};
    $remote_getrev_cache{"$projid/$packid/$cacherev"} = \%revcopy;
  }
  return $rev;
}

sub remote_getrev_setup {
  my ($projid) = @_;

  my $jev = $BSServerEvents::gev;
  my $proj = remoteprojid($projid);
  die("missing project/package\n") unless $proj;
  $jev->{'remoteurl'} = $proj->{'remoteurl'};
  $jev->{'remoteproject'} = $proj->{'remoteproject'};
  $jev->{'remoteproxy'} = $proj->{'remoteproxy'};
}

sub remote_getrev_getfilelist {
  my ($projid, $packid, $srcmd5) = @_;

  my $jev = $BSServerEvents::gev;
  remote_getrev_setup($projid) unless $jev->{'remoteurl'};

  my $param = {
    'uri' => "$jev->{'remoteurl'}/source/$jev->{'remoteproject'}/$packid",
    'proxy' => $jev->{'remoteproxy'},
  };   
  return BSWatcher::rpc($param, $BSXML::dir, "rev=$srcmd5");
}

sub remote_getrev_getfiles {
  my ($projid, $packid, $srcmd5, $filelist) = @_;

  my $jev = $BSServerEvents::gev;
  remote_getrev_setup($projid) unless $jev->{'remoteurl'};

  # get missing files
  my $rev = {'project' => $projid, 'package' => $packid};
  my $havesize = 0; 
  my $needsize = 0; 
  my @need;
  for my $entry (@{$jev->{'filelist'}->{'entry'} || []}) {
    if (-e BSRevision::revfilename($rev, $entry->{'name'}, $entry->{'md5'})) {
      $havesize += $entry->{'size'};
    } else {
      push @need, $entry;
      $needsize += $entry->{'size'};
    }    
  }
  my $serial;
  if (@need) {
    $serial = BSWatcher::serialize("$jev->{'remoteurl'}/source");
    return undef unless $serial;
    mkdir_p($uploaddir);
  }
  if (@need > 1 && $havesize < 8192) {
    # download full cpio source
    my %need = map {$_->{'name'} => $_} @need;
    my $tmpcpiofile = "$$-$jev->{'id'}-tmpcpio";
    my $param = {
      'uri' => "$jev->{'remoteurl'}/source/$jev->{'remoteproject'}/$packid",
      'directory' => $uploaddir,
      'tmpcpiofile' => "$uploaddir/$tmpcpiofile",
      'withmd5' => 1,
      'receiver' => \&BSHTTP::cpio_receiver,
      'proxy' => $jev->{'remoteproxy'},
      'map' => sub { $need{$_[1]} ? "$tmpcpiofile.$_[1]" : undef },
      'cpiopostfile' => sub {
        my $name = substr($_[1]->{'name'}, length("$tmpcpiofile."));
        die("file download confused\n") unless $need{$name} && $_[1]->{'md5'} eq $need{$name}->{'md5'};
        BSSrcrep::addfile($projid, $packid, "$uploaddir/$_[1]->{'name'}", $name, $_[1]->{'md5'});
       },
    };
    my $res;
    eval {
      $res = BSWatcher::rpc($param, undef, "rev=$srcmd5", 'view=cpio');
    };
    if ($@) {
      my $err = $@;
      BSWatcher::serialize_end($serial) if $serial;
      die($err);
    }
    return undef unless $res;
  }
  for my $entry (@need) {
    next if -e BSRevision::revfilename($rev, $entry->{'name'}, $entry->{'md5'});
    my $param = {
      'uri' => "$jev->{'remoteurl'}/source/$jev->{'remoteproject'}/$packid/$entry->{'name'}",
      'filename' => "$uploaddir/$$-$jev->{'id'}",
      'withmd5' => 1,
      'receiver' => \&BSHTTP::file_receiver,
      'proxy' => $jev->{'remoteproxy'},
    };
    my $res;
    eval {
      $res = BSWatcher::rpc($param, undef, "rev=$srcmd5");
    };
    if ($@) {
      my $err = $@;
      BSWatcher::serialize_end($serial) if $serial;
      die($err);
    }
    return undef unless $res;
    die("file download failed\n") unless $res && $res->{'md5'} eq $entry->{'md5'};
    die unless -e "$uploaddir/$$-$jev->{'id'}";
    BSSrcrep::addfile($projid, $packid, "$uploaddir/$$-$jev->{'id'}", $entry->{'name'}, $entry->{'md5'});
  }
  BSWatcher::serialize_end($serial) if $serial;
  return '';
}

sub getremotebinarylist {
  my ($proj, $projid, $repoid, $arch, $binaries, $modules) = @_;

  my $jev = $BSServerEvents::gev;
  my $binarylist;
  $binarylist = $jev->{'binarylist'} if $BSStdServer::isajax;
  $binarylist ||= {};
  $jev->{'binarylist'} = $binarylist if $BSStdServer::isajax;

  # fill binarylist
  my @missing = grep {!exists $binarylist->{$_}} @$binaries;
  while (@missing) {
    my $param = {
      'uri' => "$proj->{'remoteurl'}/build/$proj->{'remoteproject'}/$repoid/$arch/_repository",
      'proxy' => $proj->{'remoteproxy'},
    };
    # chunk it
    my $binchunkl = 0;
    for (splice @missing) {
      $binchunkl += 10 + length($_);
      last if @missing && $binchunkl > 1900;
      push @missing, $_;
    }
    my @args = ('view=names');
    push @args, map {"module=$_"} @{$modules || []};
    push @args, map {"binary=$_"} @missing;
    my $binarylistcpio = BSWatcher::rpc($param, $BSXML::binarylist, @args);
    return undef if $BSStdServer::isajax && !$binarylistcpio;
    for my $b (@{$binarylistcpio->{'binary'} || []}) {
      my $bin = $b->{'filename'};
      if ($bin =~ /^container:/) {
	$bin =~ s/\.tar(?:\..+)?$//;
      } else {
	$bin =~ s/\.(?:$binsufsre)$//;
      }
      $binarylist->{$bin} = $b;
    }
    # make sure that we don't loop forever if the server returns incomplete data
    for (@missing) {
      $binarylist->{$_} = {'filename' => $_, 'size' => 0} unless $binarylist->{$_};
    }
    @missing = grep {!exists $binarylist->{$_}} @$binaries;
  }
  return $binarylist;
}

sub getserialkey {
  my ($op, $projid) = @_;
  my $key = "$op/$projid";
  if ($BSConfig::interconnect_serialize_slots) {
    $key = unpack('N', Digest::MD5::md5($key)) % $BSConfig::interconnect_serialize_slots;
    $key = "interconnect_serialize_slots#$key";
  }
  return $key;
}

sub getremotebinaryversions {
  my ($proj, $projid, $repoid, $arch, $binaries, $modules, $withevr) = @_;

  my $jev = $BSStdServer::isajax ? $BSServerEvents::gev : undef;

  if ($jev && $jev->{'binaryversions_shared_result'}) {
    print "returning shared result for getremotebinaryversions $projid/$repoid\n";
    return $jev->{'binaryversions_shared_result'};
  }

  if ($jev && !$jev->{'binaryversions_key'}) {
    my $key = "$projid/$repoid/$arch";
    $key .= '//'.join('/', sort(@{$binaries || []}));
    $key .= '//'.join('/', sort(@{$modules || []}));
    $key .= "//withevr" if $withevr;
    $jev->{'binaryversions_key'} = $key;
  }

  my $serialkey = getserialkey('getremotebinaryversions', $projid);
  my $serial;
  if ($BSStdServer::isajax) {
    $serial = BSWatcher::serialize($serialkey);
    return undef unless $serial;
  }

  my $binaryversions;
  $binaryversions = $jev->{'binaryversions'} if $jev;
  $binaryversions ||= {};
  $jev->{'binaryversions'} = $binaryversions if $jev;

  # fill binaryversions
  my @missing = grep {!exists $binaryversions->{$_}} @$binaries;
  while (@missing) {
    # chunk it
    my $binchunkl = 0;
    for (splice @missing) {
      $binchunkl += 10 + length($_);
      last if @missing && $binchunkl > 1900;
      push @missing, $_;
    }
    my $param = {
      'uri' => "$proj->{'remoteurl'}/build/$proj->{'remoteproject'}/$repoid/$arch/_repository",
      'proxy' => $proj->{'remoteproxy'},
    };
    my @args = ('view=binaryversions', 'nometa=1');
    push @args, map {"module=$_"} @{$modules || []};
    push @args, map {"binary=$_"} @missing;
    push @args, 'withevr=1' if $withevr && (!$jev || !$jev->{'binaryversions_withevr_unsupported'});
    my $bvl;
    eval { $bvl = BSWatcher::rpc($param, $BSXML::binaryversionlist, @args) };
    if ($@) {
      if ($@ =~ /unknown parameter.*withevr/ && !$jev->{'binaryversions_withevr_unsupported'}) {
	$jev->{'binaryversions_withevr_unsupported'} = 1;
	@missing = grep {!exists $binaryversions->{$_}} @$binaries;
	next;
      }
      die($@);
    }
    return undef if $BSStdServer::isajax && !$bvl;
    for (@{$bvl->{'binary'} || []}) {
      my $bin = $_->{'name'};
      if ($bin =~ /^container:/) {
        $bin =~ s/\.tar(?:\..+)?$//;
      } else {
        $bin =~ s/\.(?:$binsufsre)$//;
      }
      $binaryversions->{$bin} = $_;
    }
    # make sure that we don't loop forever if the server returns incomplete data
    for (@missing) {
      $binaryversions->{$_} = {'name' => $_, 'error' => 'not available'} unless $binaryversions->{$_};
    }
    @missing = grep {!exists $binaryversions->{$_}} @$binaries;
  }
  # check if we can donate the result
  if ($serial) {
    my @serial_waiting = BSWatcher::serialize_waiting($serialkey);
    for my $waiting (reverse(@serial_waiting)) {
      next if $jev->{'binaryversions_key'} ne ($waiting->{'binaryversions_key'} || '');
      $waiting->{'binaryversions_shared_result'} = $binaryversions;
      BSWatcher::serlialize_advance($waiting);
    }
  }
  BSWatcher::serialize_end($serial);
  return $binaryversions;
}

sub getpackagebinaryversionlist {
  my ($proj, $projid, $repoid, $arch, $packages, $view) = @_;
  my $xmldtd = $view eq 'binarychecksums' ? $BSXML::packagebinarychecksums : $BSXML::packagebinaryversionlist;
  my $elname = $view eq 'binarychecksums' ? 'binarychecksums' : 'binaryversionlist';
  my $jev = $BSStdServer::isajax ? $BSServerEvents::gev : undef;

  my $serialkey = getserialkey('getpackagebinaryversionlist', $projid);
  my $serial;
  if ($BSStdServer::isajax) {
    $serial = BSWatcher::serialize($serialkey);
    return undef unless $serial;
  }

  my $binaryversionlist;
  $binaryversionlist = $jev->{'binaryversionlist'} if $jev;
  $binaryversionlist ||= {};
  $jev->{'binaryversionlist'} = $binaryversionlist if $jev;
  my @missing = grep {!exists $binaryversionlist->{$_}} @$packages;
  while (@missing) {
    # chunk it
    my $chunkl = 0;
    for (splice @missing) {
      $chunkl += 9 + length($_);
      last if @missing && $chunkl > 1900;
      push @missing, $_;
    }
    my $param = {
     'uri' => "$proj->{'remoteurl'}/build/$proj->{'remoteproject'}/$repoid/$arch",
     'proxy' => $proj->{'remoteproxy'},
    };
    my @args = ("view=$view");
    push @args, map {"package=$_"} @missing;
    my $pbvl = BSWatcher::rpc($param, $xmldtd, @args);
    return undef if $BSStdServer::isajax && !$pbvl;
    for (@{$pbvl->{$elname} || []}) {
      $binaryversionlist->{$_->{'package'}} = $_;
    }
    $binaryversionlist->{$_} ||= undef for @missing;
    @missing = grep {!exists $binaryversionlist->{$_}} @$packages;
  }
  BSWatcher::serialize_end($serial);
  return { $elname => [ map {$binaryversionlist->{$_}} grep {$binaryversionlist->{$_}} @$packages ] };
}

sub clean_random_cache_slot {
  my $slot = sprintf("%02x", (int(rand(256))));
  print "cleaning slot $slot\n";
  if (-d "$remotecache/$slot") {
    my $now = time();
    my $num = 0;
    for my $f (ls("$remotecache/$slot")) {
      my @s = stat("$remotecache/$slot/$f");
      next if $s[8] >= $now - 24*3600;
      unlink("$remotecache/$slot/$f");
      $num++;
    }
    print "removed $num unused files\n" if $num;
  }
}

sub getremotebinaries_cache {
  my ($cacheprefix, $binaries, $binarylist) = @_;

  my @fetch;
  my @reply;
  local *LOCK;
  mkdir_p($remotecache);
  BSUtil::lockopen(\*LOCK, '>>', "$remotecache/lock");
  for my $bin (@$binaries) {
    my $b = $binarylist->{$bin};
    if (!$b || !$b->{'size'} || !$b->{'mtime'}) {
      push @reply, {'name' => $bin, 'error' => 'not available'};
      next;
    }
    my $cachemd5 = Digest::MD5::md5_hex("$cacheprefix/$bin");
    substr($cachemd5, 2, 0, '/');
    my @s = stat("$remotecache/$cachemd5");
    if (!@s || $s[9] != $b->{'mtime'} || $s[7] != $b->{'size'}) {
      push @fetch, $bin;
    } else {
      utime time(), $s[9], "$remotecache/$cachemd5";
      push @reply, {'name' => $b->{'filename'}, 'filename' => "$remotecache/$cachemd5"};
    }
  }
  clean_random_cache_slot();
  close(LOCK);
  return (\@reply, @fetch);
}

sub getremotebinaries_putincache {
  my ($cacheprefix, $bin, $tmpname) = @_;
  my $cachemd5 = Digest::MD5::md5_hex("$cacheprefix/$bin");
  substr($cachemd5, 2, 0, '/');
  mkdir_p("$remotecache/".substr($cachemd5, 0, 2));
  rename($tmpname, "$remotecache/$cachemd5");
  return "$remotecache/$cachemd5";
}

sub getremotebinaries {
  my ($proj, $projid, $repoid, $arch, $binaries, $binarylist, $modules) = @_;

  # check the cache
  my $cacheprefix = "$projid/$repoid/$arch";
  $cacheprefix .= '/'.join('/', sort(@$modules)) if @{$modules || []};
  my ($reply, @fetch) = getremotebinaries_cache($cacheprefix, $binaries, $binarylist);
  return $reply unless @fetch;

  my $jev = $BSServerEvents::gev;

  my $serialmd5 = Digest::MD5::md5_hex("$projid/$repoid/$arch");

  # serialize this upload
  my $serial = BSWatcher::serialize("$remotecache/$serialmd5.lock");
  return undef unless $serial;

  print "fetch: @fetch\n";
  my %fetch = map {$_ => $binarylist->{$_}} @fetch;
  my $param = {
    'uri' => "$proj->{'remoteurl'}/build/$proj->{'remoteproject'}/$repoid/$arch/_repository",
    'receiver' => \&BSHTTP::cpio_receiver,
    'tmpcpiofile' => "$remotecache/upload$serialmd5.cpio",
    'directory' => $remotecache,
    'map' => "upload$serialmd5:",
    'proxy' => $proj->{'remoteproxy'},
  };
  # work around api bug: only get 50 packages at a time
  @fetch = splice(@fetch, 0, 50) if @fetch > 50;
  my @args = ('view=cpio');
  push @args, map {"module=$_"} @{$modules || []};
  push @args, map {"binary=$_"} @fetch;
  my $cpio = BSWatcher::rpc($param, undef, @args);
  return undef if $BSStdServer::isajax && !$cpio;
  for my $f (@{$cpio || []}) {
    my $bin = $f->{'name'};
    $bin =~ s/^upload.*?://;
    if ($bin =~ /^container:/) {
      $bin =~ s/\.tar(?:\..+)?$//;
    } else {
      $bin =~ s/\.(?:$binsufsre)$//;
    }
    if (!$fetch{$bin}) {
      unlink("$remotecache/$f->{'name'}");
      next;
    }
    $binarylist->{$bin}->{'size'} = $f->{'size'};
    $binarylist->{$bin}->{'mtime'} = $f->{'mtime'};
    my $filename = getremotebinaries_putincache($cacheprefix, $bin, "$remotecache/$f->{'name'}");
    push @$reply, {'name' => $fetch{$bin}->{'filename'}, 'filename' => $filename};
    delete $fetch{$bin};
  }
  BSWatcher::serialize_end($serial);

  if (@{$cpio || []} >= 50) {
    # work around api bug: get rest
    delete $jev->{'binarylist'} if $BSStdServer::isajax;
    my $binarylist = getremotebinarylist($proj, $projid, $repoid, $arch, $binaries);
    return undef unless $binarylist;
    return getremotebinaries($proj, $projid, $repoid, $arch, $binaries, $binarylist);
  }

  for (sort keys %fetch) {
    push @$reply, {'name' => $_, 'error' => 'not available'};
  }

  return $reply;
}

1;

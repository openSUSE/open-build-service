package BSRepServer;

use strict;

use BSConfiguration;
use BSRPC ':https';
use BSUtil;
use Build;

my $reporoot = "$BSConfig::bsdir/build";

my @binsufs = qw{rpm deb pkg.tar.gz pkg.tar.xz};
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

sub getconfig {
  my ($projid, $repoid, $arch, $path) = @_;

  my @configpath = map {"path=$_"} @{$path || []};
  my $config = BSRPC::rpc("$BSConfig::srcserver/getconfig", undef, "project=$projid", "repository=$repoid", @configpath);
  my $bconf = Build::read_config($arch, [split("\n", $config)]);
  $bconf->{'binarytype'} ||= 'UNDEFINED';
  return $bconf;
}

sub addrepo_scan {
  my ($pool, $prp, $arch) = @_;
  my $dir = "$reporoot/$prp/$arch/:full";
  my $repobins = {};
  my $cnt = 0; 

  my $cache;
  if (-s "$dir.solv") {
    eval {$cache = $pool->repofromfile($prp, "$dir.solv");};
    warn($@) if $@;
    return $cache if $cache;
    print "local repo $prp\n";
  }
  my @bins;
  local *D;
  if (opendir(D, $dir)) {
    @bins = grep {/\.(?:$binsufsre)$/s && !/^\.dod\./s} readdir(D);
    closedir D;
    if (!@bins && -s "$dir.subdirs") {
      for my $subdir (split(' ', readstr("$dir.subdirs"))) {
        push @bins, map {"$subdir/$_"} grep {/\.(?:$binsufsre)$/} ls("$dir/$subdir");    }
    }
  }
  for (splice @bins) {
    my @s = stat("$dir/$_");
    next unless @s;
    push @bins, $_, "$s[9]/$s[7]/$s[1]";
  }
  if ($cache) {
    $cache->updatefrombins($dir, @bins);
  } else {
    $cache = $pool->repofrombins($prp, $dir, @bins);
  }
  return $cache;
}

sub read_gbininfo {
  my ($dir, $collect) = @_;
  my $gbininfo = BSUtil::retrieve("$dir/:bininfo", 1);
  if ($gbininfo) {
    my $gbininfo_m = BSUtil::retrieve("$dir/:bininfo.merge", 1);
    if ($gbininfo_m) {
      delete $gbininfo_m->{'/outdated'};
      for (keys %$gbininfo_m) {
	if ($gbininfo_m->{$_}) {
	  $gbininfo->{$_} = $gbininfo_m->{$_};
	} else {
          # keys with empty values will be deleted
	  delete $gbininfo->{$_};
	}
      }
    }
  }
  if (!$gbininfo && $collect) {
    $gbininfo = {};
    for my $packid (grep {!/^[:\.]/} sort(ls($dir))) {
      next if $packid eq '_deltas' || $packid eq '_volatile' || ! -d "$dir/$packid";
      $gbininfo->{$packid} = read_bininfo("$dir/$packid");
    }
  }
  return $gbininfo;
}

sub read_bininfo {
  my ($dir) = @_;
  my $bininfo = BSUtil::retrieve("$dir/.bininfo", 1);
  return $bininfo if $bininfo;
  # .bininfo not present or old style, generate it
  $bininfo = {};
  for my $file (ls($dir)) {
    if ($file =~ /\.(?:$binsufsre)$/) {
      my @s = stat("$dir/$file");
      my ($hdrmd5, $leadsigmd5);
      $hdrmd5 = Build::queryhdrmd5("$dir/$file", \$leadsigmd5);
      next unless $hdrmd5;
      my $r = {'filename' => $file, 'id' => "$s[9]/$s[7]/$s[1]"};
      $r->{'hdrmd5'} = $hdrmd5;
      $r->{'leadsigmd5'} = $leadsigmd5 if $leadsigmd5;
      $bininfo->{$file} = $r;
    } elsif ($file =~ /\.obsbinlnk$/) {
      my @s = stat("$dir/$file");
      my $d = BSUtil::retrieve("$dir/$file", 1);
      next unless @s && $d;
      my $r = {%$d, 'filename' => $file, 'id' => "$s[9]/$s[7]/$s[1]"};
      delete $r->{'path'};
      $bininfo->{$file} = $r;
    } elsif ($file =~ /[-.]appdata\.xml$/) {
      local *F;
      open(F, '<', "$dir/$file") || next;
      my @s = stat(F);
      next unless @s;
      my $ctx = Digest::MD5->new;
      $ctx->addfile(*F);
      close F;
      $bininfo->{$file} = {'md5sum' => $ctx->hexdigest(), 'filename' => $file, 'id' => "$s[9]/$s[7]/$s[1]"};
    } elsif ($file eq '.nosourceaccess') {
      $bininfo->{'.nosourceaccess'} = {};
    } elsif ($file eq '.channelinfo' || $file eq 'updateinfo.xml') {
      $bininfo->{'.nouseforbuild'} = {};
    }
  }
  return $bininfo;
}

sub getpreinstallimages {
  my ($prpa) = @_;
  return undef unless -e "$reporoot/$prpa/:preinstallimages";
  if (-l "$reporoot/$prpa/:preinstallimages") {
    # small hack: allow symlink to another prpa's file
    my $l = readlink("$reporoot/$prpa/:preinstallimages") || '';
    my @l = split('/', "$prpa////$l", -1);
    $l[-4] = $l[0] if $l[-4] eq '' || $l[-4] eq '..';
    $l[-3] = $l[1] if $l[-3] eq '' || $l[-3] eq '..';
    $l[-2] = $l[2] if $l[-2] eq '' || $l[-2] eq '..';
    $prpa = "$l[-4]/$l[-3]/$l[-2]";
  }
  return BSUtil::retrieve("$reporoot/$prpa/:preinstallimages", 1);
}

1;

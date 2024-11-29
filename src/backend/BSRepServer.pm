package BSRepServer;

use strict;

use BSConfiguration;
use BSOBS;
use BSRPC ':https';
use BSUtil;
use BSVerify;
use Build;

use BSSolv;

my $reporoot = "$BSConfig::bsdir/build";

my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

sub getconfig {
  my ($projid, $repoid, $arch, $path) = @_;

  my @configpath = map {"path=$_"} @{$path || []};
  my $config = BSRPC::rpc("$BSConfig::srcserver/getconfig", undef, "project=$projid", "repository=$repoid", @configpath);
  my $bconf = Build::read_config($arch, [split("\n", $config)]);
  $bconf->{'binarytype'} ||= 'UNDEFINED';
  return $bconf;
}

my @setup_pool_with_repo_cache;

sub setup_pool_with_repo {
  my ($prp, $arch, $modules) = @_;
  my $dir = "$reporoot/$prp/$arch/:full";
  
  if ($BSStdServer::isajax) {
    my @s = stat("$dir.solv");
    if (@s && $s[7] >= 65536) {
      my $cachekey = "$s[9]/$s[7]/$s[1]/$prp/$arch/".join('/', @{$modules || []});
      for my $idx (0..7) {
	if (($setup_pool_with_repo_cache[$idx][0] || '') eq $cachekey) {
	  print "setup_pool_with_repo cache hit for $cachekey at index $idx\n";
	  unshift @setup_pool_with_repo_cache, splice(@setup_pool_with_repo_cache, $idx, 1) if $idx;
	  return $setup_pool_with_repo_cache[0][1], $setup_pool_with_repo_cache[0][2];
	}
      }
      print "setup_pool_with_repo cache miss for $cachekey\n";
      my $pool = BSSolv::pool->new();
      $pool->setmodules($modules || []) if defined &BSSolv::pool::setmodules;
      my $repo = eval { $pool->repofromfile($prp, "$dir.solv") };
      my @s2 = stat("$dir.solv");
      if ($repo && @s2 && "$s2[9]/$s2[7]/$s2[1]" eq "$s[9]/$s[7]/$s[1]") {
        pop @setup_pool_with_repo_cache;
        unshift @setup_pool_with_repo_cache, [$cachekey, $pool, $repo];
        return $pool, $repo;
      }
    }
  }
  my $pool = BSSolv::pool->new();
  $pool->setmodules($modules || []) if defined &BSSolv::pool::setmodules;
  my $repo = BSRepServer::addrepo_scan($pool, $prp, $arch);
  return ($pool, $repo);
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
  my ($dir, $collect, $withquery) = @_;
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
      $gbininfo->{$packid} = read_bininfo("$dir/$packid", $withquery);
    }
  }
  return $gbininfo;
}

sub read_bininfo {
  my ($dir, $withquery) = @_;
  my $bininfo = BSUtil::retrieve("$dir/.bininfo", 1);
  return $bininfo if $bininfo;
  # .bininfo not present or old style, generate it
  $bininfo = {};
  for my $file (ls($dir)) {
    $bininfo->{'.nosourceaccess'} = {} if $file eq '.nosourceaccess';
    $bininfo->{'.nouseforbuild'} = {} if $file eq '.channelinfo' || $file eq 'updateinfo.xml' || $file eq '.updateinfodata';
    if ($file =~ /\.(?:$binsufsre)$/) {
      my @s = stat("$dir/$file");
      my $r = {};
      eval {
	my $leadsigmd5;
	$r->{'hdrmd5'} = Build::queryhdrmd5("$dir/$file", \$leadsigmd5);
	if ($withquery) {
	  $r = Build::query("$dir/$file", 'evra' => 1);
	  BSVerify::verify_nevraquery($r) if $r;
	}
	die("missing hdrmd5\n") unless $r && $r->{'hdrmd5'};
	$r->{'leadsigmd5'} = $leadsigmd5 if $leadsigmd5;
      };
      next if $@;
      $r->{'filename'} = $file;
      $r->{'id'} = "$s[9]/$s[7]/$s[1]";
      $bininfo->{$file} = $r;
    } elsif ($file =~ /\.obsbinlnk$/) {
      my @s = stat("$dir/$file");
      my $d = BSUtil::retrieve("$dir/$file", 1);
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

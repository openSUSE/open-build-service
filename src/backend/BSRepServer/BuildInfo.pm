package BSRepServer::BuildInfo;

use strict;
use warnings;

use BSConfiguration;
use BSRPC ':https';
use BSUtil;
#use BSFileDB;
use BSXML;
use Build;
use BSSolv;
use BSRepServer;

my $proxy;
$proxy = $BSConfig::proxy if defined($BSConfig::proxy);

my $historylay = [qw{versrel bcnt srcmd5 rev time duration}];
my $reporoot = "$BSConfig::bsdir/build";
my $extrepodir = "$BSConfig::bsdir/repos";
my $extrepodb = "$BSConfig::bsdir/db/published";
my @binsufs = qw{rpm deb pkg.tar.gz pkg.tar.xz};
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

sub expandkiwipath_hash {
  my ($info, $repo) = @_;
  return map {$_->{'project'} eq '_obsrepositories' ? @{$repo->{'path'} || []} : ($_)} @{$info->{'path'} || []};
}

sub expandkiwipath {
  return map {"$_->{'project'}/$_->{'repository'}"} expandkiwipath_hash(@_);
}

sub map_to_extrep {
  my ($prp, $prp_ext) = @_;
  
  my $extrep = "$extrepodir/$prp_ext";
  return $extrep unless $BSConfig::publishredirect;
  if ($BSConfig::publishedredirect_use_regex || $BSConfig::publishedredirect_use_regex) {
    for my $key (sort {$b cmp $a} keys %{$BSConfig::publishredirect}) {
      if ($prp =~ /^$key/) {
        $extrep = $BSConfig::publishredirect->{$key};
        last;
      }    
    }    
  } elsif (exists($BSConfig::publishredirect->{$prp})) {
    $extrep = $BSConfig::publishredirect->{$prp};
  }
  $extrep = $extrep->($prp, $prp_ext) if $extrep && ref($extrep) eq 'CODE';
  return $extrep;
}

sub getbuildenv {
  my ($projid, $repoid, $arch, $packid, $srcmd5) = @_;
  my $res = BSRPC::rpc({
    'uri' => "$BSConfig::srcserver/source/$projid/$packid",
  }, $BSXML::dir, "rev=$srcmd5");
  my %entries = map {$_->{'name'} => $_} @{$res->{'entry'} || []};
  my $bifile = "_buildenv.$repoid.$arch";
  $bifile = '_buildenv' unless $entries{$bifile};
  die("srcserver is confused about the buildenv\n") unless $entries{$bifile};
  return BSRPC::rpc({
    'uri' => "$BSConfig::srcserver/source/$projid/$packid/$bifile",
  }, $BSXML::buildinfo, "rev=$srcmd5");
}

sub getkiwiproductpackages {
  my ($proj, $repo, $pdata, $info, $deps, $remotemap) = @_;

  my $nodbgpkgs = $info->{'nodbgpkgs'};
  my $nosrcpkgs = $info->{'nosrcpkgs'};
  my @got;
  my %imagearch = map {$_ => 1} @{$info->{'imagearch'} || []};
  my @archs = grep {$imagearch{$_}} @{$repo->{'arch'} || []};
  die("no architectures to use for packages\n") unless @archs;
  my @deps = @{$deps || []};
  my %deps = map {$_ => 1} @deps;
  delete $deps{''};
  my @aprps = expandkiwipath($info, $repo);
  my $allpacks = $deps{'*'} ? 1 : 0; 

  # sigh. Need to get the project kind...
  # it would be much easier to have this in the repo...
  my %prjkind;
  for my $aprp (@aprps) {
    my ($aprojid) = split('/', $aprp, 2);
    next if $aprojid eq $proj->{'name'};
    next if $remotemap->{$aprojid};
    $prjkind{$aprojid} = undef;
  }
  if (%prjkind) {
    print "fetching project kind for ".keys(%prjkind)." projects\n";
    my $projpack = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, 'nopackages', 'noremote', 'ignoredisable', map {"project=$_"} sort(keys %prjkind));
    for my $p (@{$projpack->{'project'} || []}) {
      $prjkind{$p->{'name'}} = $p->{'kind'} if exists $prjkind{$p->{'name'}};
    }
  }
  $prjkind{$proj->{'name'}} = $proj->{'kind'};

  for my $aprp (@aprps) {
    my %known;
    my ($aprojid, $arepoid) = split('/', $aprp, 2);
    for my $arch (@archs) {
      my $aprojidkind = $prjkind{$aprojid};
      $aprojidkind = $remotemap->{$aprojid}->{'kind'} if $remotemap->{$aprojid};
      my $seen_binary;
      $seen_binary = {} if ($aprojidkind || '') eq 'maintenance_release';

      my $gbininfo = BSRepServer::read_gbininfo("$reporoot/$aprp/$arch");
      # support for remote projects
      if (!$gbininfo && $remotemap->{$aprojid}) {
	my $remoteproj = $remotemap->{$aprojid};
	print "fetching remote project binary state for $aprp/$arch\n";
	my $param = {
	  'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$arepoid/$arch",
	  'timeout' => 200,
	  'proxy' => $proxy,
	};
	my $packagebinarylist = BSRPC::rpc($param, $BSXML::packagebinaryversionlist, "view=binaryversions");
	$gbininfo = {};
	for my $binaryversionlist (@{$packagebinarylist->{'binaryversionlist'} || []}) {
	  my %bins;
	  for my $binary (@{$binaryversionlist->{'binary'} || []}) {
	    next unless $binary->{'name'} =~ /^(?:::import::.*::)?(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/;
	    $bins{$binary->{'name'}} = {'filename' => $binary->{'name'}, 'name' => $1, 'arch' => $2};
	  }
	  $gbininfo->{$binaryversionlist->{'package'}} = \%bins;
	}
      }

      # fast if we have gbininfo
      if ($gbininfo) {
        for my $apackid (BSSched::ProjPacks::orderpackids({'kind' => $aprojidkind}, keys %$gbininfo)) {
	  next if $apackid eq '_volatile';
	  my $bininfo = $gbininfo->{$apackid} || {};
	  # skip channels/patchinfos
	  next if $bininfo->{'.nouseforbuild'};
	  my $needit;
	  for my $b (values %$bininfo) {
	    my $n = $b->{'name'};
	    next unless defined $n;
	    next unless $deps{$n} || ($allpacks && !$deps{"-$n"});
	    next if $nodbgpkgs && $b->{'filename'} =~ /-(?:debuginfo|debugsource)-/;
	    next if $nosrcpkgs && $b->{'filename'} =~ /\.(?:nosrc|src)\.rpm$/;
	    $needit = 1;
	    last;
	  }
	  next unless $needit;
	  # need it
	  my @bi = sort keys %$bininfo;
	  # put imports last
	  my @ibi = grep {/^::import::/} @bi;
	  if (@ibi) {
	    @bi = grep {!/^::import::/} @bi;
	    push @bi, @ibi;
	  }
	  for my $bf (@bi) {
	    my $b = $bininfo->{$bf};
            next unless $b->{'filename'};
	    next if $nodbgpkgs && $b->{'filename'} =~ /-(?:debuginfo|debugsource)-/;
	    next if $nosrcpkgs && $b->{'filename'} =~ /\.(?:nosrc|src)\.rpm$/;
	    if ($seen_binary && defined($b->{'name'})) {
	      next if $seen_binary->{"$b->{'name'}.$b->{'arch'}"};
	      $seen_binary->{"$b->{'name'}.$b->{'arch'}"} = 1;
	    }
	    if ($b->{'filename'} =~ /^(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/ || $b->{'filename'} =~ /^.*-appdata.xml$/) {
	      push @got, "$aprp/$arch/$apackid/$b->{'filename'}";
	    }
	  }
	}
	next;
      }

      my $depends = BSUtil::retrieve("$reporoot/$aprp/$arch/:depends", 1);
      next unless $depends && $depends->{'subpacks'};
      my %apackids = (%{$depends->{'subpacks'} || {}}, %{$depends->{'pkgdeps'}});
      for my $apackid (BSSched::ProjPacks::orderpackids({'kind' => $aprojidkind}, keys %apackids)) {
	next if $apackid eq '_volatile';
	next if -e "$reporoot/$aprp/$arch/$apackid/updateinfo.xml";
	next if -e "$reporoot/$aprp/$arch/$apackid/.channelinfo";
        if (!$allpacks && $depends->{'subpacks'}->{$apackid}) {
	  next unless grep {$deps{$_}} @{$depends->{'subpacks'}->{$apackid} || []};
        }
        # need package, scan content
	my @bins = grep {/\.rpm$|\.xml$/} ls ("$reporoot/$aprp/$arch/$apackid");
	my @ibins = grep {/^::import::/} @bins;
	if (@ibins) {
	  @bins = grep {!/^::import::/} @bins;
	  push @bins, @ibins;
	}
        my $needit;
	for my $b (@bins) {
	  next unless $b =~ /^(?:::import::.*::)?(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/;
	  next unless $deps{$1} || ($allpacks && !$deps{"-$1"});
	  next if $nodbgpkgs && $b =~ /-(?:debuginfo|debugsource)-/;
	  next if $nosrcpkgs && $b =~ /\.(?:nosrc|src)\.rpm$/;
	  $needit = 1;
	  last;
	}
        next unless $needit;
	for my $b (@bins) {
	  next unless $b =~ /^(?:::import::.*::)?(.+)-[^-]+-[^-]+\.([a-zA-Z][^\.\-]*)\.rpm$/;
	  if ($seen_binary) {
	    next if $seen_binary->{"$1.$2"};
	    $seen_binary->{"$1.$2"} = 1;
	  }
	  next if $nodbgpkgs && $b =~ /-(?:debuginfo|debugsource)-/;
	  next if $nosrcpkgs && $b =~ /\.(?:nosrc|src)\.rpm$/;
	  push @got, "$aprp/$arch/$apackid/$b";
	}
        for my $b (@bins) {
	  push @got, "$aprp/$arch/$apackid/$b" if $b =~ /^.*-appdata.xml$/;
        }
      }
    }
  }
  return @got;
}

sub get_projpack_via_rpc {
  my ($projid, $repoid, $arch, $packid, $pdata) = @_;
  my $projpack;
  my @args = ("project=$projid", "repository=$repoid", "arch=$arch", "parseremote=1");
  if (defined($packid)) {
    push @args, "package=$packid";
  } else {
    push @args, "nopackages";
  }
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
  if (!$pdata) {
    $projpack = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, 'withsrcmd5', 'withdeps', 'withrepos', 'expandedrepos', 'withremotemap', 'ignoredisable', @args);
    die("404 no such project/package/repository\n") unless $projpack->{'project'};
  } else {
    $projpack = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, 'withrepos', 'expandedrepos', 'withremotemap', @args);
    die("404 no such project/repository\n") unless $projpack->{'project'};
  }

  my $proj = $projpack->{'project'}->[0];
  die("no such project\n") unless $proj && $proj->{'name'} eq $projid;
  my $repo = $proj->{'repository'}->[0];
  die("no such repository\n") unless $repo && $repo->{'name'} eq $repoid;

  return $projpack;
}

sub getbuildinfo {
  my ($cgi, $projid, $repoid, $arch, $packid, $pdata) = @_;
  my $projpack = get_projpack_via_rpc($projid, $repoid, $arch, $packid, $pdata);

  my %remotemap = map {$_->{'project'} => $_} @{$projpack->{'remotemap'} || []};
  my $proj = $projpack->{'project'}->[0];
  my $repo = $proj->{'repository'}->[0];

  if (!$pdata) {
    $pdata = $proj->{'package'}->[0];
    die("no such package\n") unless $pdata && $pdata->{'name'} eq $packid;
    die("$pdata->{'error'}\n") if $pdata->{'error'};
    $pdata->{'buildenv'} = getbuildenv($projid, $repoid, $arch, $packid, $pdata->{'srcmd5'}) if $pdata->{'hasbuildenv'};
  }
  die("$pdata->{'buildenv'}->{'error'}\n") if $pdata->{'buildenv'} && $pdata->{'buildenv'}->{'error'};

  my $info = $pdata->{'info'}->[0];
  die("bad info\n") unless $info && $info->{'repository'} eq $repoid;

  my $buildtype = $pdata->{'buildtype'} || Build::recipe2buildtype($info->{'file'}) || 'spec';

  my @configpath;
  my $kiwitype;
  if ($buildtype eq 'kiwi') {
    if (@{$info->{'path'} || []}) {
      # fill in all remotemap entries we need
      my @args = map {"project=$_->{'project'}"} grep {$_->{'project'} ne '_obsrepositories'} @{$info->{'path'}};
      if (@args) {
        push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
        my $pp = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, 'withremotemap', 'nopackages', @args);
        %remotemap = (%remotemap, map {$_->{'project'} => $_} @{$pp->{'remotemap'} || []});
      }
    }
    if ($info->{'imagetype'} && $info->{'imagetype'}->[0] eq 'product') {
      $kiwitype = 'product';
    } else {
      $kiwitype = 'image';
    }
    # a repo with no path will expand to just the prp as the only element
    if ($kiwitype eq 'image' || @{$repo->{'path'} || []} < 2) {
      @configpath = expandkiwipath($info, $repo);
      # always put ourselfs in front
      unshift @configpath, "$projid/$repoid" unless @configpath && $configpath[0] eq "$projid/$repoid";
    }
  }
  my $bconf = BSRepServer::getconfig($projid, $repoid, $arch, \@configpath);
  $bconf->{'type'} = $buildtype if $buildtype;

  my $ret;
  $ret->{'project'} = $projid;
  $ret->{'repository'} = $repoid;
  $ret->{'package'} = $packid if defined $packid;
  $ret->{'downloadurl'} = $BSConfig::repodownload if defined $BSConfig::repodownload;
  $ret->{'arch'} = $arch;
  $ret->{'hostarch'} = $bconf->{'hostarch'} if $bconf->{'hostarch'};
  $ret->{'path'} = $repo->{'path'} || [];
  my @prp = map {"$_->{'project'}/$_->{'repository'}"} @{$repo->{'path'} || []};
  if ($buildtype eq 'kiwi') {
    $ret->{'imagetype'} = $info->{'imagetype'} || [];
    if (@prp < 2 || grep {$_->{'project'} eq '_obsrepositories'} @{$info->{'path'} || []}) {
      $ret->{'path'} = [ expandkiwipath_hash($info, $repo) ];
    } else {
      push @{$ret->{'path'}}, @{$info->{'path'} || []};	# XXX: should unify
    }
    if ($kiwitype eq 'image' || @{$repo->{'path'} || []} < 2) {
      @prp = expandkiwipath($info, $repo);
    }
  }
  if ($cgi->{'internal'}) {
    for (@{$ret->{'path'}}) {
      if ($remotemap{$_->{'project'}}) {
        $_->{'server'} = $BSConfig::srcserver;
      } else {
        $_->{'server'} = $BSConfig::reposerver;
      }
    }
  } else {
    for my $r (@{$ret->{'path'}}) {
      next if $remotemap{$r->{'project'}};	# what to do with those?
      my $rprp = "$r->{'project'}/$r->{'repository'}";
      my $rprp_ext = $rprp;
      $rprp_ext =~ s/:/:\//g;
      my $rurl = BSRepServer::get_downloadurl($rprp, $rprp_ext);
      $r->{'url'} = $rurl if $rurl;
    }
  }
  $ret->{'srcmd5'} = $pdata->{'srcmd5'} if $pdata->{'srcmd5'};
  $ret->{'verifymd5'} = $pdata->{'verifymd5'} || $pdata->{'srcmd5'} if $pdata->{'verifymd5'} || $pdata->{'srcmd5'};
  $ret->{'rev'} = $pdata->{'rev'} if $pdata->{'rev'};
  if ($pdata->{'error'}) {
    $ret->{'error'} = $pdata->{'error'};
    return ($ret, $BSXML::buildinfo);
  }
  my $debuginfo = BSUtil::enabled($repoid, $proj->{'debuginfo'}, undef, $arch);
  $debuginfo = BSUtil::enabled($repoid, $proj->{'package'}->[0]->{'debuginfo'}, $debuginfo, $arch) if defined($packid);
  $ret->{'debuginfo'} = $debuginfo ? 1 : 0;

  if (defined($packid) && exists($pdata->{'versrel'})) {
    $ret->{'versrel'} = $pdata->{'versrel'};
    my $h = BSFileDB::fdb_getmatch("$reporoot/$projid/$repoid/$arch/$packid/history", $historylay, 'versrel', $pdata->{'versrel'}, 1);
    $h = {'bcnt' => 0} unless $h;
    $ret->{'bcnt'} = $h->{'bcnt'} + 1;
    my $release = $ret->{'versrel'};
    $release =~ s/.*-//;
    if (exists($bconf->{'release'})) {
      if (defined($bconf->{'release'})) {
	$ret->{'release'} = $bconf->{'release'};
	$ret->{'release'} =~ s/\<CI_CNT\>/$release/g;
	$ret->{'release'} =~ s/\<B_CNT\>/$ret->{'bcnt'}/g;
      }
    } else {
      $ret->{'release'} = "$release.".$ret->{'bcnt'};
    }
  }

  if (defined $info->{'file'}) {
    $ret->{'specfile'} = $info->{'file'};
    $ret->{'file'} = $info->{'file'};
  }
  if ($info->{'error'}) {
    $ret->{'error'} = $info->{'error'};
    return ($ret, $BSXML::buildinfo);
  }

  my $pool = BSSolv::pool->new();
  $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';

  if ($pdata->{'ldepfile'}) {
    # have local deps, add them to pool
    my $data = {};
    Build::readdeps({ %$bconf }, $data, $pdata->{'ldepfile'});
    delete $data->{'/url'};
    delete $data->{'/external/'};
    my $r = $pool->repofromdata('', $data);
    die("ldepfile repo add failed\n") unless $r;
  }

  for my $prp (@prp) {
    my ($rprojid, $rrepoid) = split('/', $prp, 2);
    my $r;
    if ($remotemap{$rprojid}) {
      $r = BSRepServer::addrepo_remote($pool, $prp, $arch, $remotemap{$rprojid});
    } else {
      $r = BSRepServer::addrepo_scan($pool, $prp, $arch);
    }
    die("repository $prp not available\n") unless $r;
  }

  $pool->createwhatprovides();
  my %dep2pkg;
  my %dep2src;
  for my $p ($pool->consideredpackages()) {
    my $n = $pool->pkg2name($p);
    $dep2pkg{$n} = $p;
    $dep2src{$n} = $pool->pkg2srcname($p);
  }
  my $pname = $info->{'name'};
  my @subpacks = grep {defined($dep2src{$_}) && $dep2src{$_} eq $pname} keys %dep2src;
  @subpacks = () if $buildtype eq 'kiwi';
  if ($info->{'subpacks'}) {
    $ret->{'subpack'} = $info->{'subpacks'};
  } elsif (@subpacks) {
    $ret->{'subpack'} = [ @subpacks ];
  }

  # expand meta deps
  my @edeps = @{$info->{'dep'} || []};
  local $Build::expand_dbg = 1 if $cgi->{'debug'};
  $ret->{'expanddebug'} = '' if $cgi->{'debug'};
  if (grep {$_ eq '-simple_expansion_hack'} @edeps) {
    # special hack to expand dependencies without the build packages
    delete $bconf->{'ignore'};
    delete $bconf->{'ignoreh'};
    $bconf->{'preinstall'} = [];
    $bconf->{'vminstall'} = [];
    $bconf->{'required'} = [];
    $bconf->{'support'} = [];
  }
  if ($buildtype eq 'kiwi' && $kiwitype eq 'product') {
    @edeps = (1, @edeps);
  } elsif ($buildtype eq 'kiwi') {
    my $bconfignore = $bconf->{'ignore'};
    my $bconfignoreh = $bconf->{'ignoreh'};
    delete $bconf->{'ignore'};
    delete $bconf->{'ignoreh'};
    my $xp = BSSolv::expander->new($pool, $bconf);
    no warnings 'redefine';
    local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
    use warnings 'redefine';
    @edeps = Build::get_build($bconf, [], @edeps, '--ignoreignore--');
    $bconf->{'ignore'} = $bconfignore if $bconfignore;
    $bconf->{'ignoreh'} = $bconfignoreh if $bconfignoreh;
    if (defined($ret->{'expanddebug'})) {
      $ret->{'expanddebug'} .= "\n" if $ret->{'expanddebug'};
      $ret->{'expanddebug'} .= "=== kiwi image expansion\n";
      $ret->{'expanddebug'} .= $xp->debugstr() if defined &BSSolv::expander::debugstr;
    }
  } elsif ($pdata->{'buildenv'}) {
     @edeps = (1);
  } else {
    my $xp = BSSolv::expander->new($pool, $bconf);
    no warnings 'redefine';
    local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
    use warnings 'redefine';
    @edeps = Build::get_deps($bconf, \@subpacks, @edeps);
    if (defined($ret->{'expanddebug'})) {
      $ret->{'expanddebug'} .= "\n" if $ret->{'expanddebug'};
      $ret->{'expanddebug'} .= "=== meta deps expansion\n";
      $ret->{'expanddebug'} .= $xp->debugstr() if defined &BSSolv::expander::debugstr;
    }
  }
  if (! shift @edeps) {
    $ret->{'error'} = "unresolvable: ".join(', ', @edeps);
    return ($ret, $BSXML::buildinfo);
  }

  my $epool;
  if ($buildtype eq 'kiwi' && $kiwitype eq 'image' && @{$repo->{'path'} || []} >= 2) {
    # use different path for system setup
    $bconf = BSRepServer::getconfig($projid, $repoid, $arch);
    @prp = map {"$_->{'project'}/$_->{'repository'}"} @{$repo->{'path'} || []};
    $epool = $pool;
    $pool = BSSolv::pool->new();
    $pool->settype('deb') if $bconf->{'binarytype'} eq 'deb';
    for my $prp (@prp) {
      my ($rprojid, $rrepoid) = split('/', $prp, 2);
      my $r;
      if ($remotemap{$rprojid}) {
	$r = BSRepServer::addrepo_remote($pool, $prp, $arch, $remotemap{$rprojid});
      } else {
	$r = BSRepServer::addrepo_scan($pool, $prp, $arch);
      }
      die("repository $prp not available\n") unless $r;
    }
    $pool->createwhatprovides();
  }

  # create expander
  my $xp = BSSolv::expander->new($pool, $bconf);
  no warnings 'redefine';
  local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
  use warnings 'redefine';

  # expand sysbuild deps
  my @sysdeps;
  if ($buildtype eq 'kiwi') {
    @sysdeps = Build::get_sysbuild($bconf, "kiwi-$kiwitype", [ @{$cgi->{'add'} || []}, grep {/^kiwi-.*:/} @{$info->{'dep'} || []} ]);
  } else {
    @sysdeps = Build::get_sysbuild($bconf, $buildtype);
  }
  if (@sysdeps && defined($ret->{'expanddebug'})) {
    $ret->{'expanddebug'} .= "\n" if $ret->{'expanddebug'};
    $ret->{'expanddebug'} .= "=== sysdeps expansion\n";
    $ret->{'expanddebug'} .= $xp->debugstr() if defined &BSSolv::expander::debugstr;
  }

  # expand build deps
  my @bdeps;
  if ($pdata->{'buildenv'}) {
    @bdeps = (1);
  } elsif ($cgi->{'deps'}) {
    @bdeps = Build::get_deps($bconf, \@subpacks, @{$info->{'dep'} || []}, @{$cgi->{'add'} || []});
  } elsif ($buildtype eq 'kiwi') {
    @bdeps = (1, @edeps);	# reuse meta deps
  } else {
    @bdeps = (@{$info->{'dep'} || []}, @{$cgi->{'add'} || []});
    push @bdeps, '--ignoreignore--' if @sysdeps;
    my @prereqs = grep {!/^\// || $bconf->{'fileprovides'}->{$_}} @{$info->{'prereq'} || []};
    unshift @prereqs, '--directdepsend--' if @prereqs;
    @bdeps = Build::get_build($bconf, \@subpacks, @bdeps, @prereqs);
    if (defined($ret->{'expanddebug'})) {
      $ret->{'expanddebug'} .= "\n" if $ret->{'expanddebug'};
      $ret->{'expanddebug'} .= "=== build expansion\n";
      $ret->{'expanddebug'} .= $xp->debugstr() if defined &BSSolv::expander::debugstr;
    }
  }
  if (!shift(@bdeps)) {
    undef $xp;
    undef $Build::expand_dbg if $cgi->{'debug'};
    $ret->{'error'} = "unresolvable: ".join(', ', @bdeps);
    return ($ret, $BSXML::buildinfo);
  }

  if (@sysdeps && !shift(@sysdeps)) {
    undef $xp;
    undef $Build::expand_dbg if $cgi->{'debug'};
    $ret->{'error'} = "unresolvable: ".join(', ', @sysdeps);
    return ($ret, $BSXML::buildinfo);
  }
  undef $xp;

  my @pdeps = Build::get_preinstalls($bconf);
  my @vmdeps = Build::get_vminstalls($bconf);
  my %runscripts = map {$_ => 1} Build::get_runscripts($bconf);
  my %bdeps = map {$_ => 1} @bdeps;
  my %pdeps = map {$_ => 1} @pdeps;
  my %vmdeps = map {$_ => 1} @vmdeps;
  my %edeps = map {$_ => 1} @edeps;
  my %sysdeps = map {$_ => 1} @sysdeps;

  if ($pdata->{'buildenv'}) {
    my @allpackages;
    if (defined &BSSolv::pool::allpackages) {
      @allpackages = $pool->allpackages();
    } else {
      # crude way to get ids of all packages
      my $npkgs = 0;
      for my $r ($pool->repos()) {
        my @pids = $r->getpathid();
        $npkgs += @pids / 2;
      }
      @allpackages = 2 ... ($npkgs + 1) if $npkgs;
    }
    my %allpackages;
    for my $p (@allpackages) {
      my $n = $pool->pkg2name($p);
      my $hdrmd5 = $pool->pkg2pkgid($p);
      next unless $n && $hdrmd5;
      push @{$allpackages{"$n.$hdrmd5"}}, $p;
    }
    @bdeps = @{$pdata->{'buildenv'}->{'bdep'}};
    # check if we got em all
    if (grep {$_->{'hdrmd5'} && !$allpackages{"$_->{'name'}.$_->{'hdrmd5'}"}} @bdeps) {
      # nope, need to search package data as well
      for my $aprp (@prp) {
	my ($aprojid, $arepoid) = split('/', $aprp, 2);
        my $gbininfo = BSRepServer::read_gbininfo("$reporoot/$aprp/$arch");
	if ($gbininfo) {
	  for my $packid (sort keys %$gbininfo) {
	    for (map {$gbininfo->{$packid}->{$_}} sort keys %{$gbininfo->{$packid}}) {
	      next unless $_->{'name'} && $_->{'hdrmd5'};
	      $_->{'package'} = $packid;
	      $_->{'prp'} = $aprp;
              push @{$allpackages{"$_->{'name'}.$_->{'hdrmd5'}"}}, $_;
	    }
	  }
	}
        if (!$gbininfo && $remotemap{$aprojid}) {
	  my $remoteproj = $remotemap{$aprojid};
	  print "fetching remote project binary state for $aprp/$arch\n";
	  my $param = {
	    'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$arepoid/$arch",
	    'timeout' => 200,
	    'proxy' => $proxy,
	  };
	  my $packagebinarylist = BSRPC::rpc($param, $BSXML::packagebinaryversionlist, "view=binaryversions");
	  for my $binaryversionlist (@{$packagebinarylist->{'binaryversionlist'} || []}) {
	    for my $binary (@{$binaryversionlist->{'binary'} || []}) {
	      next unless $binary->{'hdrmd5'};
	      # XXX: rpm filenames don't have the epoch...
	      next unless $binary->{'name'} =~ /^(?:::import::.*::)?(.+)-(?:(\d+?):)?([^-]+)-([^-]+)\.([a-zA-Z][^\.\-]*)\.rpm$/;
	      my $d = {
		'name' => $1,
		'epoch' => $2,
		'version' => $3,
		'release' => $4,
		'arch' => $5,
		'filename' => $binary->{'name'},
		'prp' => $aprp,
		'package' => $binaryversionlist->{'package'},
	      };
	      push @{$allpackages{"$1.$binary->{'hdrmd5'}"}}, $d;
	    }
	  }
	}
      }
    }
    for (@bdeps) {
      $_->{'name'} =~ s/\.rpm$//;	# workaround bug in buildenv generation
      if ($_->{'hdrmd5'}) {
	my $n = $_->{'name'};
	my $hdrmd5 = $_->{'hdrmd5'};
	die("package $n\@$hdrmd5 is unavailable\n") unless $allpackages{"$n.$hdrmd5"};
	my $p = $allpackages{"$n.$hdrmd5"}->[0];
	my ($d, $prp);
	if (ref($p)) {
	  $d = $p;
          $prp = $d->{'prp'};
	} else {
          $d = $pool->pkg2data($p);
          $prp = $pool->pkg2reponame($p);
	}
        ($_->{'project'}, $_->{'repository'}) = split('/', $prp) if $prp ne '';
        $_->{'epoch'} = $d->{'epoch'} if $d->{'epoch'};
        $_->{'version'} = $d->{'version'};
        $_->{'release'} = $d->{'release'} if exists $d->{'release'};
        $_->{'arch'} = $d->{'arch'} if $d->{'arch'};
        $_->{'package'} = $d->{'package'} if defined $d->{'package'};
      } else {
	die("buildenv package $_->{'name'} has no hdrmd5 set\n");
      }
      $_->{'notmeta'} = 1; 
      $_->{'preinstall'} = 1 if $pdeps{$_->{'name'}};
      $_->{'vminstall'} = 1 if $vmdeps{$_->{'name'}};
      $_->{'runscripts'} = 1 if $runscripts{$_->{'name'}};
    }
    $ret->{'bdep'} = \@bdeps;
    return ($ret, $BSXML::buildinfo);
  }

  if ($buildtype eq 'kiwi' && $kiwitype eq 'product') {
    # things are very different here. first we have the packages needed for kiwi
    # from the full tree
    @bdeps = BSUtil::unify(@pdeps, @vmdeps, @sysdeps);
    for (splice(@bdeps)) {
      my $b = {'name' => $_};
      my $p = $dep2pkg{$_};
      if (!$cgi->{'internal'}) {
	my $prp = $pool->pkg2reponame($p);
	($b->{'project'}, $b->{'repository'}) = split('/', $prp) if $prp ne '';
      }
      my $d = $pool->pkg2data($p);
      $b->{'epoch'} = $d->{'epoch'} if $d->{'epoch'};
      $b->{'version'} = $d->{'version'};
      $b->{'release'} = $d->{'release'} if exists $d->{'release'};
      $b->{'arch'} = $d->{'arch'} if $d->{'arch'};
      $b->{'notmeta'} = 1;
      $b->{'preinstall'} = 1 if $pdeps{$_};
      $b->{'vminstall'} = 1 if $vmdeps{$_};
      $b->{'runscripts'} = 1 if $runscripts{$_};
      push @bdeps, $b;
    }

    # now the binaries from the packages
    my @bins = getkiwiproductpackages($proj, $repo, $pdata, $info, \@edeps, \%remotemap);
    for my $b (@bins) {
      my @bn = split('/', $b);
      my $d = { 'binary' => $bn[-1] };
      if ($bn[-1] =~ /^(?:::import::.*::)?(.+)-([^-]+)-([^-]+)\.([a-zA-Z][^\.\-]*)\.rpm$/) {
        $d->{'name'} = $1;
        $d->{'version'} = $2; 
        $d->{'release'} = $3;
        $d->{'arch'} = $4;
      } else {
        # for now we only support appdata.xml
        next unless $bn[-1] =~ /^(.*)-appdata.xml$/;
      }
      $d->{'project'} = $bn[0];
      $d->{'repository'} = $bn[1];
      $d->{'repoarch'} = $bn[2] if $bn[2] ne $arch;
      $d->{'package'} = $bn[3];
      $d->{'noinstall'} = 1;
      push @bdeps, $d;
    }
    if ($info->{'extrasource'}) {
      push @bdeps, map {{
        'name' => $_->{'file'}, 'version' => '', 'repoarch' => $_->{'arch'}, 'arch' => 'src',
        'project' => $_->{'project'}, 'package' => $_->{'package'}, 'srcmd5' => $_->{'srcmd5'},
      }} @{$info->{'extrasource'}};
    }
    $ret->{'bdep'} = \@bdeps;
    return ($ret, $BSXML::buildinfo);
  }

  my @rdeps;
  if ($buildtype eq 'kiwi' && $kiwitype eq 'image' && $epool) {
    # have special system setup pool, first add image packages, then fall through to system setup packages
    for (@bdeps) {
      my $p = $dep2pkg{$_};
      my $b = {'name' => $_};
      if (!$cgi->{'internal'}) {
	my $prp = $epool->pkg2reponame($p);
	($b->{'project'}, $b->{'repository'}) = split('/', $prp) if $prp ne '';
      }
      my $d = $epool->pkg2data($p);
      $b->{'epoch'} = $d->{'epoch'} if $d->{'epoch'};
      $b->{'version'} = $d->{'version'};
      $b->{'release'} = $d->{'release'} if exists $d->{'release'};
      $b->{'arch'} = $d->{'arch'} if $d->{'arch'};
      $b->{'noinstall'} = 1;
      push @rdeps, $b;
    }
    @edeps = @bdeps = ();
    %edeps = %bdeps = ();
    %dep2pkg = ();
    for my $p ($pool->consideredpackages()) {
      my $n = $pool->pkg2name($p);
      $dep2pkg{$n} = $p;
    }
  }

  @bdeps = BSUtil::unify(@pdeps, @vmdeps, @edeps, @bdeps, @sysdeps);
  for (@bdeps) {
    my $b = {'name' => $_};
    my $p = $dep2pkg{$_};
    if (!$cgi->{'internal'}) {
      my $prp = $pool->pkg2reponame($p);
      ($b->{'project'}, $b->{'repository'}) = split('/', $prp) if $prp ne '';
    }
    my $d = $pool->pkg2data($p);
    $b->{'epoch'} = $d->{'epoch'} if $d->{'epoch'};
    $b->{'version'} = $d->{'version'};
    $b->{'release'} = $d->{'release'} if exists $d->{'release'};
    $b->{'arch'} = $d->{'arch'} if $d->{'arch'};
    $b->{'preinstall'} = 1 if $pdeps{$_};
    $b->{'vminstall'} = 1 if $vmdeps{$_};
    $b->{'runscripts'} = 1 if $runscripts{$_};
    $b->{'notmeta'} = 1 unless $edeps{$_};
    if (@sysdeps) {
      $b->{'installonly'} = 1 if $sysdeps{$_} && !$bdeps{$_} && $buildtype ne 'kiwi';
      $b->{'noinstall'} = 1 if $bdeps{$_} && !($sysdeps{$_} || $vmdeps{$_} || $pdeps{$_});
    }
    push @rdeps, $b;
  }

  # add extra source (needed for kiwi)
  # ADRIAN: is it not enough to do this for product only above ?
  if ($info->{'extrasource'}) {
    push @rdeps, map {{
      'name' => $_->{'file'}, 'version' => '', 'repoarch' => $_->{'arch'}, 'arch' => 'src',
      'project' => $_->{'project'}, 'package' => $_->{'package'}, 'srcmd5' => $_->{'srcmd5'},
    }} @{$info->{'extrasource'}};
  }

  $ret->{'bdep'} = \@rdeps;
  return ($ret, $BSXML::buildinfo);
}

1;

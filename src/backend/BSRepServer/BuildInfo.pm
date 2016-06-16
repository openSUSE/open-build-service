package BSRepServer::BuildInfo;

use strict;
use warnings;

use Data::Dumper;

use BSConfiguration;
use BSRPC ':https';
use BSUtil;
use BSFileDB;
use BSXML;
use Build;
use BSSolv;
use BSRepServer;
use BSRepServer::Checker;
use BSRepServer::BuildInfo::Generic;
use BSRepServer::BuildInfo::KiwiImage;
use BSRepServer::BuildInfo::KiwiProduct;

my $historylay = [qw{versrel bcnt srcmd5 rev time duration}];
my @binsufs = qw{rpm deb pkg.tar.gz pkg.tar.xz};
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

sub new {

  my $class = shift;
  my $self  = {@_};

  my $gctx = {
	arch        => $self->{arch},
	reporoot    => "$BSConfig::bsdir/build",
	#extrepodir  => "$BSConfig::bsdir/repos",
	#extrepodb   => "$BSConfig::bsdir/db/published",
	remoteproxy => $BSConfig::proxy,
  };

  my $ctx = BSRepServer::Checker->new($gctx);

  $self->{gctx} = $gctx;
  $self->{ctx}  = $ctx;

  bless($self,$class);

  # get projpack information for generating remotemap
  $self->get_projpack_via_rpc();
  $self->{proj}      = $self->{projpack}->{'project'}->[0];
  $self->{repo}      = $self->{proj}->{'repository'}->[0];

  # generate initial remotemap
  $self->{remotemap} = { map {$_->{'project'} => $_} @{$self->{projpack}->{'remotemap'} || []} };

  # create pdata (package data) if needed and verify
  my $pdata = $self->{pdata};
  if (!$pdata) {
    $pdata = $self->{proj}->{'package'}->[0];
    die("no such package\n") unless $pdata && $pdata->{'name'} eq $self->{packid};
    die("$pdata->{'error'}\n") if $pdata->{'error'};
    $pdata->{'buildenv'} = getbuildenv($self->{projid}, $self->{repoid}, $self->{arch}, $self->{packid}, $pdata->{'srcmd5'}) if $pdata->{'hasbuildenv'};
  }
  die("$pdata->{'buildenv'}->{'error'}\n") if $pdata->{'buildenv'} && $pdata->{'buildenv'}->{'error'};
  $self->{pdata}     = $pdata;

  # Prepartion for selection of handler
  $self->{info} = $pdata->{'info'}->[0];
  die("bad info\n") unless $self->{info} && $self->{info}->{'repository'} eq $self->{repoid};

  my $buildtype = $pdata->{'buildtype'} || Build::recipe2buildtype($self->{info}->{'file'}) || 'spec';

  my $kiwitype;
  if ($buildtype eq 'kiwi') {
    if ($self->{info}->{'imagetype'} && $self->{info}->{'imagetype'}->[0] eq 'product') {
	  $self->{handler} = BSRepServer::BuildInfo::KiwiProduct->new();
    } else {
	  $self->{handler} = BSRepServer::BuildInfo::KiwiImage->new();
    }
  } else {
	  $self->{handler} = BSRepServer::BuildInfo::Generic->new(buildtype=>$buildtype);
  }
  return $self;
}

sub expandkiwipath_hash {
  my ($info, $repo) = @_;
  return map {$_->{'project'} eq '_obsrepositories' ? @{$repo->{'path'} || []} : ($_)} @{$info->{'path'} || []};
}

sub expandkiwipath {
  return map {"$_->{'project'}/$_->{'repository'}"} expandkiwipath_hash(@_);
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

sub getpreinstallimages {
  my ($self, $prpa) = @_;
  my $reporoot = $self->{gctx}->{reporoot};
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

sub getkiwiproductpackages {
  my ($self,$proj, $repo, $pdata, $info, $deps) = @_;
  my $remotemap = $self->{remotemap};
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

      my $gbininfo = $self->{ctx}->read_gbininfo($aprp, $arch);

      if (!$gbininfo) {
        push @got, $self->getkiwiproductpackages_compat($aprp, $arch, \%deps , $allpacks, $seen_binary, $aprojidkind);
        next;
      }
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
    }
  }
  return @got;
}

=head2 getkiwiproductpackages_compat - for old projects without bininfo

=cut

sub getkiwiproductpackages_compat {
  my ($self, $aprp, $arch, $deps, $allpacks, $seen_binary, $aprojidkind) = @_;
  my @got;
  my $nodbgpkgs = $self->{info}->{'nodbgpkgs'};
  my $nosrcpkgs = $self->{info}->{'nosrcpkgs'};
  my $reporoot  = $self->{gctx}->{reporoot};

  my $depends = BSUtil::retrieve("$self->{gctx}->{reporoot}/$aprp/$arch/:depends", 1);
  next unless $depends && $depends->{'subpacks'};
  my %apackids = (%{$depends->{'subpacks'} || {}}, %{$depends->{'pkgdeps'}});
  for my $apackid (BSSched::ProjPacks::orderpackids({'kind' => $aprojidkind}, keys %apackids)) {
    next if $apackid eq '_volatile';
    next if -e "$reporoot/$aprp/$arch/$apackid/updateinfo.xml";
    next if -e "$reporoot/$aprp/$arch/$apackid/.channelinfo";
    if (!$allpacks && $depends->{'subpacks'}->{$apackid}) {
      next unless grep {$deps->{$_}} @{$depends->{'subpacks'}->{$apackid} || []};
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
      next unless $deps->{$1} || ($allpacks && !$deps->{"-$1"});
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

  return @got;
}

sub get_projpack_via_rpc {
  my ($self) = @_;
  
  # prepare args for rpc call
  my @args = ("project=$self->{projid}", "repository=$self->{repoid}", "arch=$self->{arch}", "parseremote=1");
  if (defined($self->{packid})) {
    push @args, "package=$self->{packid}";
  } else {
    push @args, "nopackages";
  }
  push @args, "partition=$BSConfig::partition" if $BSConfig::partition;

  # fetch projpack information via rpc
  if (!$self->{pdata}) {
    $self->{projpack} = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, 'withsrcmd5', 'withdeps', 'withrepos', 'expandedrepos', 'withremotemap', 'ignoredisable', @args);
    die("404 no such project/package/repository\n") unless $self->{projpack}->{'project'};
  } else {
    $self->{projpack} = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, 'withrepos', 'expandedrepos', 'withremotemap', @args);
    die("404 no such project/repository\n") unless $self->{projpack}->{'project'};
  }

  # verify projpack
  my $proj = $self->{projpack}->{'project'}->[0];
  die("no such project\n") unless $proj && $proj->{'name'} eq $self->{projid};
  my $repo = $proj->{'repository'}->[0];
  die("no such repository\n") unless $repo && $repo->{'name'} eq $self->{repoid};

}

=head2 get_deps_from_buildenv - Take _buildenv parameter for cgi as input for dependency generation

Parameters:

  $ret
  $pdata
  \@prp
  \%pdeps
  \%vmdeps
  \%runscripts

=cut

sub get_deps_from_buildenv {
  my $self      = shift;
  my $arch      = $self->{arch};
  my $pool      = $self->{pool};
  my $remotemap = $self->{remotemap};
  my ($ret,$pdata,$prp,$pdeps,$vmdeps,$runscripts) = @_;
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
  my @bdeps = @{$pdata->{'buildenv'}->{'bdep'}};
  # check if we got em all
  if (grep {$_->{'hdrmd5'} && !$allpackages{"$_->{'name'}.$_->{'hdrmd5'}"}} @bdeps) {
    # nope, need to search package data as well
    for my $aprp (@$prp) {
      my ($aprojid, $arepoid) = split('/', $aprp, 2);
      my $gbininfo = $self->{ctx}->read_gbininfo($aprp, $arch);
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
      if (!$gbininfo && $remotemap->{$aprojid}) {
	my $remoteproj = $remotemap->{$aprojid};
	print "fetching remote project binary state for $aprp/$arch\n";
	my $param = {
	  'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$arepoid/$arch",
	  'timeout' => 200,
	  'proxy' => $self->{gctx}->{remoteproxy},
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
    die("buildenv package $_->{'name'} has no hdrmd5 set\n") if ( ! $_->{'hdrmd5'} );

    my $n      = $_->{'name'};
    my $hdrmd5 = $_->{'hdrmd5'};
    die("package $n\@$hdrmd5 is unavailable\n") unless $allpackages{"$n.$hdrmd5"};

    my $p = $allpackages{"$n.$hdrmd5"}->[0];
    my ($d, $prp);

    if (ref($p)) {
      $d   = $p;
      $prp = $d->{'prp'};
    } else {
      $d   = $pool->pkg2data($p);
      $prp = $pool->pkg2reponame($p);
    }
    ($_->{'project'}, $_->{'repository'}) = split('/', $prp) if $prp ne '';
    $_->{'version'} = $d->{'version'};
    $_->{'epoch'}   = $d->{'epoch'}   if $d->{'epoch'};
    $_->{'release'} = $d->{'release'} if exists $d->{'release'};
    $_->{'arch'}    = $d->{'arch'}    if $d->{'arch'};
    $_->{'package'} = $d->{'package'} if defined $d->{'package'};
    $_->{'notmeta'}    = 1;
    $_->{'preinstall'} = 1 if $pdeps->{$_->{'name'}};
    $_->{'vminstall'}  = 1 if $vmdeps->{$_->{'name'}};
    $_->{'runscripts'} = 1 if $runscripts->{$_->{'name'}};
  }
  $ret->{'bdep'} = \@bdeps;
  return ($ret, $BSXML::buildinfo);
}

sub calc_build_deps_kiwiproduct {
  my $self = shift;
  my $pool = $self->{pool};
  my ($ret, $pdeps, $vmdeps, $sysdeps, $edeps, $runscripts, $dep2pkg) = @_ ;
  my $remotemap = $self->{remotemap};
  # things are very different here. first we have the packages needed for kiwi
  # from the full tree
  my @bdeps = BSUtil::unify(@$pdeps, @$vmdeps, @$sysdeps);
  for (splice(@bdeps)) {
	my $b = {'name' => $_};
	my $p = $dep2pkg->{$_};
	if (!$self->{'internal'}) {
	  my $prp = $pool->pkg2reponame($p);
	  ($b->{'project'}, $b->{'repository'}) = split('/', $prp) if $prp ne '';
	}
	my $d = $pool->pkg2data($p);
	$b->{'version'}      = $d->{'version'};
	$b->{'notmeta'}      = 1;
	$b->{'epoch'}        = $d->{'epoch'}   if $d->{'epoch'};
	$b->{'release'}      = $d->{'release'} if exists $d->{'release'};
	$b->{'arch'}         = $d->{'arch'}    if $d->{'arch'};
	$b->{'preinstall'}   = 1 if $pdeps->{$_};
	$b->{'vminstall'}    = 1 if $vmdeps->{$_};
	$b->{'runscripts'}   = 1 if $runscripts->{$_};
	push @bdeps, $b;
  }

  # now the binaries from the packages
  my @bins = $self->getkiwiproductpackages($self->{proj}, $self->{repo}, $self->{pdata}, $self->{info}, $edeps);
  for my $b (@bins) {
	my @bn = split('/', $b);
	my $d = { 'binary' => $bn[-1] };
	if ($bn[-1] =~ /^(?:::import::.*::)?(.+)-([^-]+)-([^-]+)\.([a-zA-Z][^\.\-]*)\.rpm$/) {
	  $d->{'name'}    = $1;
	  $d->{'version'} = $2;
	  $d->{'release'} = $3;
	  $d->{'arch'}    = $4;
	} else {
	  # for now we only support appdata.xml
	  next unless $bn[-1] =~ /^(.*)-appdata.xml$/;
	}
	$d->{'repoarch'}   = $bn[2] if $bn[2] ne $self->{arch};
	$d->{'project'}    = $bn[0];
	$d->{'repository'} = $bn[1];
	$d->{'package'}    = $bn[3];
	$d->{'noinstall'}  = 1;
	push @bdeps, $d;
  }
  if ($self->{info}->{'extrasource'}) {
	push @bdeps, map {{
	  'name' => $_->{'file'}, 'version' => '', 'repoarch' => $_->{'arch'}, 'arch' => 'src',
	  'project' => $_->{'project'}, 'package' => $_->{'package'}, 'srcmd5' => $_->{'srcmd5'},
	}} @{$self->{info}->{'extrasource'}};
  }
  $ret->{'bdep'} = \@bdeps;
  return ($ret, $BSXML::buildinfo);
}

sub getbuildinfo {
  my $self = shift;
  # The following definition are here for performance and compability reason
  my ($projid, $repoid, $arch, $packid, $pdata, $info, $repo, $proj) = ($self->{projid},$self->{repoid},$self->{arch},$self->{packid},$self->{pdata},$self->{info}, $self->{repo}, $self->{proj});
  my $projpack = $self->{projpack};

  #my @configpath = $self->{handler}->expand_configpath;
  #my %remotemap  = $self->{handler}->append_to_remotemap;
  my $buildtype = $self->{handler}->buildtype;
  my $kiwitype  = $self->{handler}->kiwitype;
  #my %remotemap;
  my $remotemap = $self->{remotemap};
  my @configpath;
  if ($buildtype eq 'kiwi') {
    # sub append_to_remotemap (\%remotemap,$info->{path});
    if (@{$info->{'path'} || []}) {
      # fill in all remotemap entries we need
      my @args = map {"project=$_->{'project'}"} grep {$_->{'project'} ne '_obsrepositories'} @{$info->{'path'}};
      if (@args) {
        push @args, "partition=$BSConfig::partition" if $BSConfig::partition;
        my $pp = BSRPC::rpc("$BSConfig::srcserver/getprojpack", $BSXML::projpack, 'withremotemap', 'nopackages', @args);
        map {$remotemap->{$_->{'project'}} = $_} @{$pp->{'remotemap'} || []};
      }
    }
	# / sub append_to_remotemap
    # sub expand_configpath
    # $self->{handler}->expand_configpath($self->{info},$self->{repo})
    # a repo with no path will expand to just the prp as the only element
    if ($kiwitype eq 'image' || @{$repo->{'path'} || []} < 2) {
      @configpath = expandkiwipath($info, $repo);
      # always put ourselfs in front
      unshift @configpath, "$projid/$repoid" unless @configpath && $configpath[0] eq "$projid/$repoid";
    }
  }


  # TODO: implement $self->{handler}->buildtype
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
  if ($self->{'internal'}) {
    for (@{$ret->{'path'}}) {
      if ($remotemap->{$_->{'project'}}) {
        $_->{'server'} = $BSConfig::srcserver;
      } else {
        $_->{'server'} = $BSConfig::reposerver;
      }
    }
  } else {
    for my $r (@{$ret->{'path'}}) {
      next if $remotemap->{$r->{'project'}};	# what to do with those?
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
    my $h = BSFileDB::fdb_getmatch("$self->{gctx}->{reporoot}/$projid/$repoid/$arch/$packid/history", $historylay, 'versrel', $pdata->{'versrel'}, 1);
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

  $self->{pool} = BSSolv::pool->new();
  $self->{pool}->settype('deb') if $bconf->{'binarytype'} eq 'deb';

  if ($pdata->{'ldepfile'}) {
    # have local deps, add them to pool
    my $data = {};
    Build::readdeps({ %$bconf }, $data, $pdata->{'ldepfile'});
    delete $data->{'/url'};
    delete $data->{'/external/'};
    my $r = $self->{pool}->repofromdata('', $data);
    die("ldepfile repo add failed\n") unless $r;
  }

  for my $prp (@prp) {
    my ($rprojid, $rrepoid) = split('/', $prp, 2);
    my $r;
    if ($remotemap->{$rprojid}) {
      $r = BSRepServer::addrepo_remote($self->{pool}, $prp, $arch, $remotemap->{$rprojid});
    } else {
      $r = BSRepServer::addrepo_scan($self->{pool}, $prp, $arch);
    }
    die("repository $prp not available\n") unless $r;
  }

  $self->{pool}->createwhatprovides();
#TODO: pack to object
  my %dep2pkg;
  my %dep2src;
  for my $p ($self->{pool}->consideredpackages()) {
    my $n = $self->{pool}->pkg2name($p);
    $dep2pkg{$n} = $p;
    $dep2src{$n} = $self->{pool}->pkg2srcname($p);
  }
  my $pname = $info->{'name'};
  my @subpacks = grep {defined($dep2src{$_}) && $dep2src{$_} eq $pname} keys %dep2src;
  @subpacks = () if $buildtype eq 'kiwi';
  if ($info->{'subpacks'}) {
    $ret->{'subpack'} = $info->{'subpacks'};
  } elsif (@subpacks) {
    $ret->{'subpack'} = [ sort @subpacks ];
  }

  # expand meta deps
  my @edeps = @{$info->{'dep'} || []};
  local $Build::expand_dbg = 1 if $self->{'debug'};
  $ret->{'expanddebug'} = '' if $self->{'debug'};
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
    my $xp = BSSolv::expander->new($self->{pool}, $bconf);
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
    my $xp = BSSolv::expander->new($self->{pool}, $bconf);
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
    $epool = $self->{pool};
    $self->{pool} = BSSolv::pool->new();
    for my $prp (@prp) {
      my ($rprojid, $rrepoid) = split('/', $prp, 2);
      my $r;
      if ($remotemap->{$rprojid}) {
	$r = BSRepServer::addrepo_remote($self->{pool}, $prp, $arch, $remotemap->{$rprojid});
      } else {
	$r = BSRepServer::addrepo_scan($self->{pool}, $prp, $arch);
      }
      die("repository $prp not available\n") unless $r;
    }
    $self->{pool}->createwhatprovides();
  }

  # create expander
  my $xp = BSSolv::expander->new($self->{pool}, $bconf);
  no warnings 'redefine';
  local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
  use warnings 'redefine';

  # expand sysbuild deps
  my @sysdeps;
  if ($buildtype eq 'kiwi') {
    @sysdeps = Build::get_sysbuild($bconf, "kiwi-$kiwitype", [ @{$self->{'add'} || []}, grep {/^kiwi-.*:/} @{$info->{'dep'} || []} ]);
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
  } elsif ($self->{'deps'}) {
    @bdeps = Build::get_deps($bconf, \@subpacks, @{$info->{'dep'} || []}, @{$self->{'add'} || []});
  } elsif ($buildtype eq 'kiwi') {
    @bdeps = (1, @edeps);	# reuse meta deps
  } else {
    @bdeps = (@{$info->{'dep'} || []}, @{$self->{'add'} || []});
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
    undef $Build::expand_dbg if $self->{'debug'};
    $ret->{'error'} = "unresolvable: ".join(', ', @bdeps);
    return ($ret, $BSXML::buildinfo);
  }

  if (@sysdeps && !shift(@sysdeps)) {
    undef $xp;
    undef $Build::expand_dbg if $self->{'debug'};
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
    return $self->get_deps_from_buildenv($ret,$pdata,\@prp,\%pdeps,\%vmdeps,\%runscripts);
  }
  if ($buildtype eq 'kiwi' && $kiwitype eq 'product') {
    return $self->calc_build_deps_kiwiproduct($ret,\@pdeps,\@vmdeps,\@sysdeps,\@edeps,\%runscripts,\%dep2pkg);
  }

  my @rdeps;
  # TBC: fs - epool is only set if repo path greater than two
  # Question: is this really an performance optimization or could 
  #           we handle this in a more general way
  if ($buildtype eq 'kiwi' && $kiwitype eq 'image' && $epool) {
    
    # have special system setup pool, first add image packages, then fall through to system setup packages
    for (@bdeps) {
      my $p = $dep2pkg{$_};
      my $b = {'name' => $_};
      if (!$self->{'internal'}) {
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
    for my $p ($self->{pool}->consideredpackages()) {
      my $n = $self->{pool}->pkg2name($p);
      $dep2pkg{$n} = $p;
    }
  }

  my @preimghdrs;
  @bdeps = BSUtil::unify(@pdeps, @vmdeps, @edeps, @bdeps, @sysdeps);
  for (@bdeps) {
    my $b = {'name' => $_};
    my $p = $dep2pkg{$_};
    if (!$self->{'internal'}) {
      my $prp = $self->{pool}->pkg2reponame($p);
      ($b->{'project'}, $b->{'repository'}) = split('/', $prp) if $prp ne '';
    }
    my $d = $self->{pool}->pkg2data($p);
    $b->{'version'}    = $d->{'version'};
    $b->{'epoch'}      = $d->{'epoch'}   if $d->{'epoch'};
    $b->{'release'}    = $d->{'release'} if exists $d->{'release'};
    $b->{'arch'}       = $d->{'arch'}    if $d->{'arch'};
    $b->{'preinstall'} = 1 if $pdeps{$_};
    $b->{'vminstall'}  = 1 if $vmdeps{$_};
    $b->{'runscripts'} = 1 if $runscripts{$_};
    $b->{'notmeta'}    = 1 unless $edeps{$_};
    if (@sysdeps) {
      $b->{'installonly'} = 1 if $sysdeps{$_} && !$bdeps{$_} && $buildtype ne 'kiwi';
      $b->{'noinstall'} = 1 if $bdeps{$_} && !($sysdeps{$_} || $vmdeps{$_} || $pdeps{$_});
    }
    push @rdeps, $b;
    push @preimghdrs, $self->{pool}->pkg2pkgid($p) if !$b->{'noinstall'};
  }

  if (!$self->{'internal'}) {
    my %neededhdrmd5s = map {$_ => 1} grep {$_} @preimghdrs;
    my @prpas = map {$_->name() . "/$arch"} $self->{pool}->repos();

    my $bestimgn = 2; 
    my $bestimg;

    for my $prpa (@prpas) {
      my $images = $self->getpreinstallimages($prpa);
      next unless $images;
      for my $img (@$images) {
       next if @{$img->{'hdrmd5s'} || []} < $bestimgn;
       next unless $img->{'sizek'} && $img->{'hdrmd5'};
       next if grep {!$neededhdrmd5s{$_}} @{$img->{'hdrmd5s'} || []}; 
       next if $prpa eq "$projid/$repoid/$arch" && $packid && $img->{'package'} eq $packid;
       $img->{'prpa'} = $prpa;
       $bestimg = $img;
       $bestimgn = @{$img->{'hdrmd5s'} || []}; 
      }
    }
    if ($bestimg) {
      my $pi = {'package' => $bestimg->{'package'}, 'filename' => "_preinstallimage.$bestimg->{'hdrmd5'}", 'binary' => $bestimg->{'bins'}, 'hdrmd5' => $bestimg->{'hdrmd5'}};
      ($pi->{'project'}, $pi->{'repository'}) = split('/', $bestimg->{'prpa'}, 3);
      my $rprp = "$pi->{'project'}/$pi->{'repository'}";
      my $rprp_ext = $rprp;
      $rprp_ext =~ s/:/:\//g;
      my $rurl = BSRepServer::get_downloadurl($rprp, $rprp_ext);
      $pi->{'url'} = $rurl if $rurl;
      $ret->{'preinstallimage'} = $pi;
    }
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

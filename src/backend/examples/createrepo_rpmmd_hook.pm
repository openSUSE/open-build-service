package BSConfig::Hooks::createrepo_rpmmd;

#
#  CONFIG:
#
#  $BSConfig::repomd_hook_masterregex           -  only work on projects that match this
#  $BSConfig::repomd_hook_expires = [
#    'regexp' => expire'
#  ...
#  ]                                            -  set expire time for the project, first match wins
#  $BSConfig::repomd_hook_euladir               -  global eula dir
#  $BSConfig::repomd_hook_extraeuladir          -  project based eulas
#  $BSConfig::repomd_hook_unpacklegacy          -  turn on legacy rpm unpacking
#  $BSConfig::repomd_hook_dumpprimarychecksums  - location of the dumpprimarychecksums helper
# 

die("Can only be used from BSConfig\n") unless $BSConfig::bsdir;

use Digest;
use Digest::MD5 ();
use Build::Rpm;
use Data::Dumper;
use File::Temp qw/ tempdir /;

use BSUtil;

use strict;

sub calcchecksum {
  my ($filename, $sum) = @_;

  local *F;
  open(F, '<', $filename) || die("$filename: $!\n");
  my %known = (
    'sha' => 'SHA-1',
    'sha1' => 'SHA-1',
    'sha256' => 'SHA-256',
  );
  die("unknown checksum type: $sum\n") unless $known{$sum};
  my $ctx = Digest->new($known{$sum});
  $ctx->addfile(\*F);
  close F;
  return $ctx->hexdigest();
}

my $susedata_dtd = [
    'susedata' =>
	'xmlns',
	'packages',
     [[ 'package' =>
	    'pkgid',
	    'name',
	    'arch',
	  [ 'version' =>
		'epoch',
		'ver',
		'rel',
	  ],
	 [[ 'eula' =>
		'lang',
		'_content',
	 ]],
	  [ 'keyword' ],
	  [ 'diskusage' =>
	      [ 'dirs' =>
		 [[ 'dir' =>
			'name',
			'size',
			'count',
		 ]],
	      ],
	  ],
     ]],
];

my $suseinfo_dtd = [
    'suseinfo' =>
	'xmlns',
	[],
	'expire',
];

my $prodfile_dtd = [
    'product' =>
        'id',
        'schemeversion',
        [],
        'vendor',
        'name',
        'version',
        'baseversion',
        'patchlevel',
        'predecessor',
        'migrationtarget',
        'release',
        'arch',
        'endoflife',
        'productline',
      [ 'register' =>
	    [],
	    'target',
	    'release',
	    'flavor',
	  [ 'repositories' =>
	     [[ 'repository' =>
		    'path',
	     ]],
          ],
      ],
      [ 'upgrades' =>
	    [],
	  [ 'upgrade' =>
		[],
		'name',
		'summary',
		'product',
		'notify',
		'status',
	  ],
      ],
        'updaterepokey',
        'summary',
        'shortsummary',
        'description',
      [ 'linguas' =>
	 [[ 'language' =>
		'_content',
	 ]],
      ],
      [ 'urls' =>
	 [[ 'url' =>
		'name',
		'_content',
	 ]],
      ],
      [ 'buildconfig' =>
	    'producttheme',
	    'betaversion',
	    'allowresolving',
	    'mainproduct',
      ],
      [ 'installconfig' =>
	    'defaultlang',
	    'datadir',
	    'descriptiondir',
	    'descrdir',
	  [ 'references' =>
		'name',
		'version',
	  ],
	  [ 'releasepackage' =>
		'name',
		'flag',
		'version',
		'release',
	  ],
	    'distribution',
	  [ 'obsoletepackage' ],
      ],
	'runtimeconfig',
	[ 'productdependency' =>
		'relationship',
		'name',
		'baseversion',
		'patchlevel',
		'flag',
	],
];

my $productsfile_dtd = [
    'products' =>
     [[ 'product' =>
	    [],
	    'name',
	  [ 'version' =>
		'ver',
		'rel',
		'epoch',
	  ],
	    'arch',
	    'vendor',
	    'summary',
	    'description',
     ]],
];


sub unpack_legacy_product {
  my ($rpm, $productdata) = @_;

  my $unpack_dir = tempdir("produnpack-XXXXXX", TMPDIR => 1, CLEANUP => 1);
  die unless $unpack_dir && -d $unpack_dir;
  my $pid;
  if (!($pid = BSUtil::xfork())) {
    chdir($unpack_dir) || die("chdir $unpack_dir: $!\n");
    open(STDOUT, '>', '/dev/null');
    exec('/usr/bin/unrpm', $rpm);
    die("/usr/bin/unrpm: $!\n");
  }
  waitpid($pid, 0) == $pid || die("waitpid $pid: $!\n");
  warn("unrpm: exit status $?\n") if $?;
  my $products;
  for my $prod (grep {/\.prod$/} sort(ls("$unpack_dir/etc/products.d"))) {
    my $cprod = readxml("$unpack_dir/etc/products.d/$prod", $prodfile_dtd);
    $cprod->{$_} ||= '0' for qw{epoch version release};
    my $skey = "$cprod->{'name'}:$cprod->{'arch'}:$cprod->{'epoch'}:$cprod->{'version'}:$cprod->{'release'}";
    $productdata->{$skey}->{$_} = $cprod->{$_} for qw{name arch vendor summary description};
    $productdata->{$skey}->{'version'}->{'epoch'} = $cprod->{'epoch'};
    $productdata->{$skey}->{'version'}->{'ver'} = $cprod->{'version'};
    $productdata->{$skey}->{'version'}->{'rel'} = $cprod->{'release'};
  }
  BSUtil::cleandir($unpack_dir);
  rmdir($unpack_dir);
}

sub calcdudata {
  my ($rpm, $maxdepth) = @_;
  my %q = Build::Rpm::rpmq($rpm, 1027, 1028, 1030, 1095, 1096, 1116, 1117, 1118);
  if (!$q{1027}) {
    $q{1027} = $q{1117} || [];
    my @di = @{$q{1116} || []};
    $_ = $q{1118}->[shift @di] . $_ for @{$q{1027}};
  }
  my @modes = @{$q{1030} || []};
  my @devs = @{$q{1095} || []};
  my @inos = @{$q{1096} || []};
  my @names = @{$q{1027} || []};
  my @sizes = @{$q{1028} || []};
  my %seen;
  my %dirnum;
  my %subdirnum;
  my %dirsize;
  my %subdirsize;
  my ($name, $first);
  for $name (@names) {
    my $mode = shift @modes;
    my $dev = shift @devs;
    my $ino = shift @inos;
    my $size = shift @sizes;
    # strip leading slash
    # prefix is either empty or ends in /
    $name = "usr/src/packages/$name" unless $name =~ s/^\///;

    # check if regular file
    next if ($mode & 0170000) != 0100000;
    # don't count hardlinks twice
    next if $seen{"$dev $ino"};
    $seen{"$dev $ino"} = 1;

    # rounded size in kbytes
    $size = int ($size / 1024) + 1;

    $name = '' unless $name =~ s/\/[^\/]*$//;
    if (($name =~ tr/\///) < $maxdepth) {
      $dirsize{"$name/"} += $size;
      $dirnum{"$name/"} += 1;
      $subdirsize{"$name/"} ||= 0;    # so we get all keys
    }
    # traverse though path stripping components from the back
    $name =~ s/\/[^\/]*$// while ($name =~ tr/\///) > $maxdepth;

    while ($name ne '') {
      $name = '' unless $name =~ s/\/[^\/]*$//;
      $subdirsize{"$name/"} += $size;
      $subdirnum{"$name/"} += 1;
    }
  }
  my @dulist;
  for $name (sort keys %subdirsize) {
    next unless $dirsize{$name} || $subdirsize{$name};
    $dirsize{$name} ||= 0;
    $subdirsize{$name} ||= 0;
    $dirnum{$name} ||= 0;
    $subdirnum{$name} ||= 0;
    # SUSETAGS: "$name $dirsize{$name} $subdirsize{$name} $dirnum{$name} $subdirnum{$name}";

    # workaround for libsolv parser bug, make sure dir starts with '/'
    my $xname = $name;
    $xname = "/$xname" unless $xname =~ /^\//;
    push @dulist, { 'name' => $xname, 'size' => $dirsize{$name} + $subdirsize{$name}, 'count' => $dirnum{$name} + $subdirnum{$name} };
  }
  return { 'dirs' => { 'dir' => \@dulist } };
}

sub createrepo_rpmmd_hook {
  my ($projid, $repoid, $extrep, $options, $data) = @_;

  my @oldrepodata = ls("$extrep/repodata");

  # dudata calc is expensive, so reuse old data if present
  my %olddudata;
  if ($options->{'diskusage'}) {
    my $oldsusedatafile = (grep {/susedata\.xml/} @oldrepodata)[0];
    if ($oldsusedatafile) {
      my $oldsusedata = '';
      if ($oldsusedatafile =~ /\.gz$/) {
        local *F;
	if (open(F, '-|', 'gunzip', '-dc', '--', "$extrep/repodata/$oldsusedatafile")) {
	    1 while sysread(F, $oldsusedata, 8192, length($oldsusedata));
	    close(F) || warn("$extrep/repodata/$oldsusedatafile: $?\n");
	}
      } else {
	$oldsusedata = readstr("$extrep/repodata/$oldsusedatafile", 2);
      }
      if ($oldsusedata) {
        $oldsusedata = BSUtil::fromxml($oldsusedata, $susedata_dtd, 2);
	for my $pkg (@{$oldsusedata->{'package'} || []}) {
	  $olddudata{$pkg->{'pkgid'}} = $pkg->{'diskusage'} if $pkg->{'pkgid'} && $pkg->{'diskusage'};
	}
      }
    }
  }

  unlink("$extrep/repodata/$_") for grep {/(?:suseinfo|susedata|products)\.xml/} @oldrepodata;

  return unless $projid =~ /^$BSConfig::repomd_hook_masterregex/;

  my @legacyargs;
  if ($options->{'sha512'}) {
    push @legacyargs, '--unique-md-filenames', '--checksum=sha512';
  } elsif ($options->{'legacy'}) {
    push @legacyargs, '--simple-md-filenames', '--checksum=sha';
  } else {
    # the default in newer createrepos
    push @legacyargs, '--unique-md-filenames', '--checksum=sha256';
  }
  # createrepo_c 1.0.0 changed the default to zstd. In order to preserve
  # compatibility with SLE12 and SLE15 GA we need to set gz
  if ($options->{'compression-zstd'}) {
    push @legacyargs, '--compress-type=zstd';
  } else {
    push @legacyargs, '--compress-type=gz';
  }

  if ($BSConfig::repomd_hook_expires) {
    my $expire;
    my @ex = @$BSConfig::repomd_hook_expires;
    while (@ex) {
      if ($projid =~ /^$ex[0]/) {
	$expire = $ex[1];
	last;
      }
      splice(@ex, 0, 2);
    }
    if ($expire) {
      my $suseinfo = {
	'xmlns' => 'http://linux.duke.edu/metadata/repo',
	'expire' => $expire,
      };
      print "    adding suseinfo.xml to repodata\n";
      writexml("$extrep/repodata/suseinfo.xml", undef, $suseinfo, $suseinfo_dtd);
      ::qsystem('modifyrepo', "$extrep/repodata/suseinfo.xml", "$extrep/repodata", @legacyargs) && print("    modifyrepo failed: $?\n");
      unlink("$extrep/repodata/suseinfo.xml");
    }
  }

  my %eulas;
  if ($BSConfig::repomd_hook_euladir) {
    for my $eula (sort(ls($BSConfig::repomd_hook_euladir))) {
      next unless $eula =~ /^(.*)\.(..)$/;
      push @{$eulas{$1}}, [$eula, $2, $2 eq 'en' ? -1 : 1, "$BSConfig::repomd_hook_euladir/$eula"];
    }
  }
  if ($BSConfig::repomd_hook_extraeuladir) {
    for my $eula (sort(ls("$BSConfig::repomd_hook_extraeuladir/$projid"))) {
      next unless $eula =~ /^(.*)\.(..)$/;
      push @{$eulas{$1}}, [$eula, $2, $2 eq 'en' ? -1 : 1, "$BSConfig::repomd_hook_extraeuladir/$projid/$eula"];
    }
  }

  # retrieve supportstatus from updateinfos
  my %supportstatus;
  my %superseded_by;
  for my $up (@{$data->{'updateinfos'} || []}) {
    for my $cl (@{($up->{'pkglist'} || {})->{'collection'} || []}) {
      for my $pkg (@{$cl->{'package'} || []}) {
        if ($pkg->{'superseded_by'}) {
          $superseded_by{"$pkg->{'arch'}/$pkg->{'filename'}"} = $pkg->{'superseded_by'};
          $supportstatus{"$pkg->{'arch'}/$pkg->{'filename'}"} = 'superseded';
        }
        if ($pkg->{'supportstatus'}) {
          $supportstatus{"$pkg->{'arch'}/$pkg->{'filename'}"} = $pkg->{'supportstatus'};
        }
      }
    }
  }

  return unless %eulas || %supportstatus;

  my $subdir = '';
  $subdir = 'rpm/' if -d "$extrep/rpm";

  my @susedata;
  my $productdata = {};

  my @archs = grep {!/^\./ && $_ ne 'repodata' && -d "$extrep/$subdir$_"} sort(ls("$extrep/$subdir"));
  my $checksumcache;
  for my $arch (@archs) {
    my @rpms = sort(grep {/\.rpm$/} ls("$extrep/$subdir$arch"));
    @rpms = grep {!/\.delta\.rpm$/} @rpms;
    for my $rpm (@rpms) {
      # good enough for our purposes
      next unless $rpm =~ /^(.+)-[^-]+-[^-]+\.[a-zA-Z][^\/\.\-]*\.rpm$/;
      my $guessedname = $1;
      my $path = "$arch/$rpm";
      my $q;
      my @pe;
      my @kw;
      if ($eulas{$guessedname}) {
        $q = Build::Rpm::query("$extrep/$subdir$path", 'evra' => 1);
        die("query on $extrep/$subdir$path failed\n") unless $q;
        die("rpm is badly named: $guessedname - $q->{'name'}\n") unless $q->{'name'} eq $guessedname;
        if ($eulas{$q->{'name'}}) {
	  for my $eula (sort {$a->[2] <=> $b->[2] || $a->[0] cmp $b->[0]} @{$eulas{$q->{'name'}}}) {
	    my $txt = readstr("$eula->[3]", 1);
	    next unless $txt;
	    $txt = BSUtil::str2utf8xml($txt);
	    my $ee = {'_content' => $txt};
	    $ee->{'lang'} = $eula->[1] if $eula->[1] ne 'en';
	    push @pe, $ee;
	  }
	}
      }
      if ($BSConfig::repomd_hook_unpacklegacy && $options->{'legacy'} && ($guessedname =~ /-release/ || $guessedname =~ /-migration/)) {
	my $deps = Build::Rpm::query("$extrep/$subdir$path", 'alldeps' => 1);
	die("query on $extrep/$subdir$path failed\n") unless $deps;
	if (grep {/^product/} @{$deps->{'provides'} || []}) {
	  unpack_legacy_product("$extrep/$subdir$path", $productdata);
	}
      }
      if ($superseded_by{$path}) {
	push @kw, "support_superseded($superseded_by{$path})";
      } elsif ($supportstatus{$path}) {
	push @kw, $supportstatus{$path};
      }
      s/^(l\d|unsupported|acc|superseded)$/support_$1/ for @kw;

      next unless @pe || @kw || $options->{'diskusage'};

      if (!$checksumcache) {
	$checksumcache = {};
        my $primary = (grep {/primary\.xml/} sort(ls("$extrep/repodata")))[0];
        if ($primary) {
	  local *F;
	  my $dumpprimarychecksums = $BSConfig::repomd_hook_dumpprimarychecksums || 'dumpprimarychecksums';
          if (open(F, '-|', $dumpprimarychecksums, "$extrep/repodata/$primary")) {
	    while (<F>) {
	      chomp;
	      my @s = split(' ', $_, 5);
	      next unless @s == 5;
	      $checksumcache->{$s[4]} = \@s;
	    }
	    close F;
          }
        }
      }

      if ($checksumcache->{"$subdir$path"}) {
	my $s = $checksumcache->{"$subdir$path"};
	my $evr = $s->[3];
	die unless $evr =~ /^(?:([0-9]+):)?(.*?)-([^-]*)$/;
	$q = {
	  'chksum' => $s->[0],
	  'name' => $s->[1],
	  'arch' => $s->[2],
          'epoch' => $1 || 0,
          'version' => $2,
          'release' => $3,
	};
      } else {
	print "warning: $subdir$path not found in checksum cache\n";
        $q ||= Build::Rpm::query("$extrep/$subdir$path", 'evra' => 1);
        die("query on $extrep/$subdir$path failed\n") unless $q;
        $q->{'chksum'} = calcchecksum("$extrep/$subdir$path", $options->{'legacy'} ? 'sha' : 'sha256');
      }

      my $pd = {
        'pkgid' => $q->{'chksum'},
        'name' => $q->{'name'},
        'arch' => $q->{'arch'},
        'version' => {
          'epoch' => $q->{'epoch'} || 0,
          'ver' => $q->{'version'},
          'rel' => $q->{'release'},
        },
      };
      $pd->{'eula'} = \@pe if @pe;
      $pd->{'keyword'} = \@kw if @kw;

      if ($options->{'diskusage'}) {
	my $du = $olddudata{$q->{'chksum'}};
	$du ||= calcdudata("$extrep/$subdir$path", 3);
	$pd->{'diskusage'} = $du if $du;
      }

      push @susedata, $pd;
    }
  }
  if (@susedata) {
    my $susedata = {
      'xmlns' => 'http://linux.duke.edu/metadata/susedata',
      'packages' => scalar(@susedata),
      'package' => \@susedata,
    };
    print "    adding susedata.xml to repodata\n";
    writexml("$extrep/repodata/susedata.xml", undef, $susedata, $susedata_dtd);
    ::qsystem('modifyrepo', "$extrep/repodata/susedata.xml", "$extrep/repodata", @legacyargs) && print("    modifyrepo failed: $?\n");
    unlink("$extrep/repodata/susedata.xml");
  }
  my @productdata = map {$productdata->{$_}} sort keys %$productdata;
  if (@productdata) {
    my $proddata = { 'product' => \@productdata, };
    print "    adding products.xml to repodata\n";
    writexml("$extrep/repodata/products.xml", undef, $proddata, $productsfile_dtd);
    ::qsystem('modifyrepo', "$extrep/repodata/products.xml", "$extrep/repodata", @legacyargs) && print("    modifyrepo failed: $?\n");
    unlink("$extrep/repodata/products.xml");
  }

}

\&createrepo_rpmmd_hook;

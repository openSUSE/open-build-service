
package Build;

our $expand_dbg;

use strict;

my $std_macros = q{
%define ix86 i386 i486 i586 i686 athlon
%define arm armv4l armv4b armv5l armv5b armv5tel armv5teb
%define arml armv4l armv5l armv5tel
%define armb armv4b armv5b armv5teb
};

sub unify {
  my %h = map {$_ => 1} @_;
  return grep(delete($h{$_}), @_);
}

sub read_config_dist {
  my ($dist, $archpath, $configdir) = @_;

  my $arch = $archpath;
  $arch = 'noarch' unless defined $arch;
  $arch =~ s/:.*//;
  $arch = 'noarch' if $arch eq '';
  die("Please specify a distribution!\n") unless defined $dist;
  if ($dist !~ /\//) {
    $configdir = '.' unless defined $configdir;
    $dist =~ s/-.*//;
    $dist = "sl$dist" if $dist =~ /^\d/;
    $dist = "$configdir/$dist.conf";
    $dist = "$configdir/default.conf" unless -e $dist;
  }
  die("$dist: $!\n") unless -e $dist;
  my $cf = read_config($arch, $dist);
  die("$dist: parse error\n") unless $cf;
  return $cf;
}

sub read_config {
  my ($arch, $cfile) = @_;
  my @macros = split("\n", $std_macros);
  push @macros, "%define _target_cpu $arch";
  push @macros, "%define _target_os linux";
  my $config = {'macros' => \@macros};
  my @config;
  if (ref($cfile)) {
    @config = @$cfile;
  } elsif (defined($cfile)) {
    local *CONF;
    return undef unless open(CONF, '<', $cfile);
    @config = <CONF>;
    close CONF;
    chomp @config;
  }
  # create verbatim macro blobs
  my @newconfig;
  while (@config) {
    push @newconfig, shift @config;
    next unless $newconfig[-1] =~ /^\s*macros:\s*$/si;
    $newconfig[-1] = "macros:\n";
    while (@config) {
      my $l = shift @config;
      last if $l =~ /^\s*:macros\s*$/si;
      $newconfig[-1] .= "$l\n";
    }
  }
  my @spec;
  read_spec($config, \@newconfig, \@spec);
  $config->{'preinstall'} = [];
  $config->{'runscripts'} = [];
  $config->{'required'} = [];
  $config->{'support'} = [];
  $config->{'keep'} = [];
  $config->{'prefer'} = [];
  $config->{'ignore'} = [];
  $config->{'conflict'} = [];
  $config->{'substitute'} = {};
  $config->{'optflags'} = {};
  $config->{'rawmacros'} = '';
  $config->{'repotype'} = [];
  for my $l (@spec) {
    $l = $l->[1] if ref $l;
    next unless defined $l;
    my @l = split(' ', $l);
    next unless @l;
    my $ll = shift @l;
    my $l0 = lc($ll);
    if ($l0 eq 'macros:') {
      $l =~ s/.*?\n//s;
      $config->{'rawmacros'} .= $l;
      next;
    }
    if ($l0 eq 'preinstall:' || $l0 eq 'required:' || $l0 eq 'support:' || $l0 eq 'keep:' || $l0 eq 'prefer:' || $l0 eq 'ignore:' || $l0 eq 'conflict:' || $l0 eq 'runscripts:') {
      push @{$config->{substr($l0, 0, -1)}}, @l;
    } elsif ($l0 eq 'substitute:') {
      next unless @l;
      $ll = shift @l;
      push @{$config->{'substitute'}->{$ll}}, @l;
    } elsif ($l0 eq 'optflags:') {
      next unless @l;
      $ll = shift @l;
      $config->{'optflags'}->{$ll} = join(' ', @l);
    } elsif ($l0 eq 'repotype:') {
      $config->{'repotype'} = [ @l ];
    } elsif ($l0 !~ /^[#%]/) {
      warn("unknown keyword in config: $l0\n");
    }
  }
  for my $l (qw{preinstall required support keep runscripts repotype}) {
    $config->{$l} = [ unify(@{$config->{$l}}) ];
  }
  for my $l (keys %{$config->{'substitute'}}) {
    $config->{'substitute'}->{$l} = [ unify(@{$config->{'substitute'}->{$l}}) ];
  }
  $config->{'preferh'} = { map {$_ => 1} @{$config->{'prefer'}} };
  my %ignore;
  for (@{$config->{'ignore'}}) {
    if (!/:/) {
      $ignore{$_} = 1;
      next;
    }
    my @s = split(/[,:]/, $_);
    my $s = shift @s;
    $ignore{"$s:$_"} = 1 for @s;
  }
  $config->{'ignoreh'} = \%ignore;
  my %conflicts;
  for (@{$config->{'conflict'}}) {
    my @s = split(/[,:]/, $_);
    my $s = shift @s;
    push @{$conflicts{$s}}, @s;
    push @{$conflicts{$_}}, $s for @s;
  }
  for (keys %conflicts) {
    $conflicts{$_} = [ unify(@{$conflicts{$_}}) ]
  }
  $config->{'conflicth'} = \%conflicts;
  $config->{'type'} = (grep {$_ eq 'rpm'} @{$config->{'preinstall'} || []}) ? 'spec' : 'dsc';
  # add rawmacros to our macro list
  if ($config->{'rawmacros'} ne '') {
    for my $rm (split("\n", $config->{'rawmacros'})) {
      if ((@macros && $macros[-1] =~ /\\$/) || $rm !~ /^%/) {
	push @macros, $rm;
      } else {
	push @macros, "%define ".substr($rm, 1);
      }
    }
  }
  return $config;
}

sub do_subst {
  my ($config, @deps) = @_;
  my @res;
  my %done;
  my $subst = $config->{'substitute'};
  while (@deps) {
    my $d = shift @deps;
    next if $done{$d};
    if ($subst->{$d}) {
      unshift @deps, @{$subst->{$d}};
      push @res, $d if grep {$_ eq $d} @{$subst->{$d}};
    } else {
      push @res, $d;
    }
    $done{$d} = 1;
  }
  return @res;
}

sub get_build {
  my ($config, $subpacks, @deps) = @_;
  my @ndeps = grep {/^-/} @deps;
  my %keep = map {$_ => 1} (@deps, @{$config->{'keep'} || []}, @{$config->{'preinstall'}});
  for (@{$subpacks || []}) {
    push @ndeps, "-$_" unless $keep{$_};
  }
  my %ndeps = map {$_ => 1} @ndeps;
  @deps = grep {!$ndeps{$_}} @deps;
  push @deps, @{$config->{'preinstall'}};
  push @deps, @{$config->{'required'}};
  push @deps, @{$config->{'support'}};
  @deps = grep {!$ndeps{"-$_"}} @deps;
  @deps = do_subst($config, @deps);
  @deps = grep {!$ndeps{"-$_"}} @deps;
  @deps = expand($config, @deps, @ndeps);
  return @deps;
}

sub get_deps {
  my ($config, $subpacks, @deps) = @_;
  my @ndeps = grep {/^-/} @deps;
  my %keep = map {$_ => 1} (@deps, @{$config->{'keep'} || []}, @{$config->{'preinstall'}});
  for (@{$subpacks || []}) {
    push @ndeps, "-$_" unless $keep{$_};
  }
  my %ndeps = map {$_ => 1} @ndeps;
  @deps = grep {!$ndeps{$_}} @deps;
  push @deps, @{$config->{'required'}};
  @deps = grep {!$ndeps{"-$_"}} @deps;
  @deps = do_subst($config, @deps);
  @deps = grep {!$ndeps{"-$_"}} @deps;
  my %bdeps = map {$_ => 1} (@{$config->{'preinstall'}}, @{$config->{'support'}});
  delete $bdeps{$_} for @deps;
  @deps = expand($config, @deps, @ndeps);
  if (@deps && $deps[0]) {
    my $r = shift @deps;
    @deps = grep {!$bdeps{$_}} @deps;
    unshift @deps, $r;
  }
  return @deps;
}

sub get_preinstalls {
  my ($config) = @_;
  return @{$config->{'preinstall'}};
}

sub get_runscripts {
  my ($config) = @_;
  return @{$config->{'runscripts'}};
}

###########################################################################

sub readrpmdeps {
  my ($config, $pkgidp, @depfiles) = @_;

  my %provides = ();
  my %requires = ();
  local *F;
  my %prov;
  for my $depfile (@depfiles) {
    if (ref($depfile) eq 'HASH') {
      for my $rr (keys %$depfile) {
	$prov{$rr} = $depfile->{$rr}->{'provides'};
	$requires{$rr} = $depfile->{$rr}->{'requires'};
      }
      next;
    }
    open(F, "<$depfile") || die("$depfile: $!\n");
    while(<F>) {
      my @s = split(' ', $_);
      my $s = shift @s;
      my @ss; 
      while (@s) {
	if ($s[0] =~ /^\//) {
	  shift @s;
	  next;
	}
	if ($s[0] =~ /^rpmlib\(/) {
	  shift @s;
	  shift @s;
	  shift @s;
	  next;
	}
	push @ss, shift @s;
	if (@s && $s[0] =~ /^[<=>]/) {
	  shift @s;
	  shift @s;
	}
      }
      my %ss; 
      @ss = grep {!$ss{$_}++} @ss;
      if ($s =~ s/^P:(.*):$/$1/) {
	my $pkgid = $s;
	$s =~ s/-[^-]+-[^-]+-[^-]+$//;
	$prov{$s} = \@ss; 
	$pkgidp->{$s} = $pkgid if $pkgidp;
      } elsif ($s =~ s/^R:(.*):$/$1/) {
	my $pkgid = $s;
	$s =~ s/-[^-]+-[^-]+-[^-]+$//;
	$requires{$s} = \@ss; 
	$pkgidp->{$s} = $pkgid if $pkgidp;
      }
    }
    close F;
  }
  for my $p (keys %prov) {
    push @{$provides{$_}}, $p for unify(@{$prov{$p}});
  }
  $config->{'providesh'} = \%provides;
  $config->{'requiresh'} = \%requires;
}

sub forgetrpmdeps {
  my $config;
  delete $config->{'providesh'};
  delete $config->{'requiresh'};
}

sub expand {
  my ($config, @p) = @_;

  my $conflicts = $config->{'conflicth'};
  my $prefer = $config->{'preferh'};
  my $ignore = $config->{'ignoreh'};

  my $provides = $config->{'providesh'};
  my $requires = $config->{'requiresh'};

  my %xignore = map {substr($_, 1) => 1} grep {/^-/} @p;
  @p = grep {!/^-/} @p;
 
  my %p = map {$_ => 1} grep {$requires->{$_}} @p;

  my %aconflicts;
  for my $p (keys %p) {
    $aconflicts{$_} = 1 for @{$conflicts->{$p} || []};
  }

  while (@p) {
    my $didsomething = 0;
    my @error = ();
    my @uerror = ();
    my @usolve = ();
    my @rerror = ();
    for my $p (splice @p) {
      for my $r (@{$requires->{$p} || [$p]}) {
	next if $ignore->{"$p:$r"} || $xignore{"$p:$r"};
	next if $ignore->{$r} || $xignore{$r};
	my @q = @{$provides->{$r} || []};
	next if grep {$p{$_}} @q;
	next if grep {$xignore{$_}} @q;
	next if grep {$ignore->{"$p:$_"} || $xignore{"$p:$_"}} @q;
	@q = grep {!$aconflicts{$_}} @q;
	if (!@q) {
	  if ($r eq $p) {
	    push @rerror, "nothing provides $r";
	  } else {
	    push @rerror, "nothing provides $r needed by $p";
	  }
	  next;
	}
	if (@q > 1 && grep {$conflicts->{$_}} @q) {
	  # delay this one as some conflict later on might
	  # clear things up
	  push @p, $p unless @p && $p[-1] eq $p;
	  print "undecided about $p:$r: @q\n" if $expand_dbg;
	  if ($r ne $p) {
	    push @uerror, "have choice for $r needed by $p: @q";
	  } else {
	    push @uerror, "have choice for $r: @q";
	  }
	  push @usolve, @q;
	  push @usolve, map {"$p:$_"} @q;
	  next;
	}
	if (@q > 1) {
	  my @pq = grep {!$prefer->{"-$_"} && !$prefer->{"-$p:$_"}} @q;
	  @q = @pq if @pq;
	  @pq = grep {$prefer->{$_} || $prefer->{"$p:$_"}} @q;
	  if (@pq > 1) {
	    my %pq = map {$_ => 1} @pq;
	    @q = (grep {$pq{$_}} @{$config->{'prefer'}})[0];
	  } elsif (@pq == 1) {
	    @q = @pq;
	  }
	}
	if (@q > 1) {
	  if ($r ne $p) {
	    push @error, "have choice for $r needed by $p: @q";
          } else {
	    push @error, "have choice for $r: @q";
          }
	  push @p, $p unless @p && $p[-1] eq $p;
	  next;
	}
	push @p, $q[0];
	print "added $q[0] because of $p:$r\n" if $expand_dbg;
	$p{$q[0]} = 1;
	$aconflicts{$_} = 1 for @{$conflicts->{$q[0]} || []};
	$didsomething = 1;
	@error = ();
      }
    }
    if (@rerror) {
      return undef, @rerror;
    }
    if (!$didsomething && @error) {
      return undef, @error;
    }
    if (!$didsomething && @usolve) {
      # only conflicts left
      print "looking at conflicts: @usolve\n" if $expand_dbg;
      @usolve = grep {$prefer->{$_}} @usolve;
      if (@usolve > 1) {
        my %usolve = map {$_ => 1} @usolve;
        @usolve  = (grep {$usolve{$_}} @{$config->{'prefer'}})[0];
      }
      if (@usolve) {
	$usolve[0] =~ s/:.*//;
        push @p, $usolve[0];
        print "added $usolve[0]\n" if $expand_dbg;
        $p{$usolve[0]} = 1;
        $aconflicts{$_} = 1 for @{$conflicts->{$usolve[0]} || []};
	next;
      }
      return undef, @uerror;
    }
  }
  return 1, (sort keys %p);
}

sub add_all_providers {
  my ($config, @p) = @_;
  my $provides = $config->{'providesh'};
  my $requires = $config->{'requiresh'};
  my %a;
  for my $p (@p) {
    for my $r (@{$requires->{$p} || [$p]}) {
      $a{$_} = 1 for @{$provides->{$r} || []};
    }
  }
  push @p, keys %a;
  return unify(@p);
}

###########################################################################

sub expr {
  my $expr = shift;
  my $lev = shift;

  $lev ||= 0;
  my ($v, $v2);
  $expr =~ s/^\s+//;
  my $t = substr($expr, 0, 1);
  if ($t eq '(') {
    ($v, $expr) = expr(substr($expr, 1), 0);
    return undef unless defined $v;
    return undef unless $expr =~ s/^\)//;
  } elsif ($t eq '!') {
    ($v, $expr) = expr(substr($expr, 1), 0);
    return undef unless defined $v;
    $v = 0 if $v && $v eq '\"\"';
    $v =~ s/^0+/0/ if $v;
    $v = !$v;
  } elsif ($t eq '-') {
    ($v, $expr) = expr(substr($expr, 1), 0);
    return undef unless defined $v;
    $v = -$v;
  } elsif ($expr =~ /^([0-9]+)(.*?)$/) {
    $v = $1;
    $expr = $2;
  } elsif ($expr =~ /^([a-zA-Z_0-9]+)(.*)$/) {
    $v = "\"$1\"";
    $expr = $2;
  } elsif ($expr =~ /^(\".*?\")(.*)$/) {
    $v = $1;
    $expr = $2;
  } else {
    return;
  }
  while (1) {
    $expr =~ s/^\s+//;
    if ($expr =~ /^&&/) {
      return ($v, $expr) if $lev > 1;
      ($v2, $expr) = expr(substr($expr, 2), 1);
      return undef unless defined $v2;
      $v &&= $v2;
    } elsif ($expr =~ /^\|\|/) {
      return ($v, $expr) if $lev > 1;
      ($v2, $expr) = expr(substr($expr, 2), 1);
      return undef unless defined $v2;
      $v ||= $v2;
    } elsif ($expr =~ /^>=/) {
      return ($v, $expr) if $lev > 2;
      ($v2, $expr) = expr(substr($expr, 2), 2);
      return undef unless defined $v2;
      $v = (($v =~ /^\"/) ? $v ge $v2 : $v >= $v2) ? 1 : 0;
    } elsif ($expr =~ /^>/) {
      return ($v, $expr) if $lev > 2;
      ($v2, $expr) = expr(substr($expr, 1), 2);
      return undef unless defined $v2;
      $v = (($v =~ /^\"/) ? $v gt $v2 : $v > $v2) ? 1 : 0;
    } elsif ($expr =~ /^<=/) {
      return ($v, $expr) if $lev > 2;
      ($v2, $expr) = expr(substr($expr, 2), 2);
      return undef unless defined $v2;
      $v = (($v =~ /^\"/) ? $v le $v2 : $v <= $v2) ? 1 : 0;
    } elsif ($expr =~ /^</) {
      return ($v, $expr) if $lev > 2;
      ($v2, $expr) = expr(substr($expr, 1), 2);
      return undef unless defined $v2;
      $v = (($v =~ /^\"/) ? $v lt $v2 : $v < $v2) ? 1 : 0;
    } elsif ($expr =~ /^==/) {
      return ($v, $expr) if $lev > 2;
      ($v2, $expr) = expr(substr($expr, 2), 2);
      return undef unless defined $v2;
      $v = (($v =~ /^\"/) ? $v eq $v2 : $v == $v2) ? 1 : 0;
    } elsif ($expr =~ /^!=/) {
      return ($v, $expr) if $lev > 2;
      ($v2, $expr) = expr(substr($expr, 2), 2);
      return undef unless defined $v2;
      $v = (($v =~ /^\"/) ? $v ne $v2 : $v != $v2) ? 1 : 0;
    } elsif ($expr =~ /^\+/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr(substr($expr, 1), 3);
      return undef unless defined $v2;
      $v += $v2;
    } elsif ($expr =~ /^-/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr(substr($expr, 1), 3);
      return undef unless defined $v2;
      $v -= $v2;
    } elsif ($expr =~ /^\*/) {
      ($v2, $expr) = expr(substr($expr, 1), 4);
      return undef unless defined $v2;
      $v *= $v2;
    } elsif ($expr =~ /^\//) {
      ($v2, $expr) = expr(substr($expr, 1), 4);
      return undef unless defined $v2 && 0 + $v2;
      $v /= $v2;
    } else {
      return ($v, $expr);
    }
  }
}

sub read_spec {
  my ($config, $specfile, $xspec, $ifdeps) = @_;

  my $packname;
  my $packvers;
  my $packrel;
  my $exclarch;
  my @subpacks;
  my @packdeps;
  my $hasnfb;
  my %macros;
  my $ret = {};

  my $specdata;
  local *SPEC;
  if (ref($specfile) eq 'GLOB') {
    *SPEC = $specfile;
  } elsif (ref($specfile) eq 'ARRAY') {
    $specdata = [ @$specfile ];
  } elsif (!open(SPEC, '<', $specfile)) {
    warn("$specfile: $!\n");
    $ret->{'error'} = "open $specfile: $!";
    return $ret;
  }
  my @macros = @{$config->{'macros'}};
  my $skip = 0;
  my $main_preamble = 1;
  my $inspec = 0;
  my $hasif = 0;
  while (1) {
    my $line;
    if (@macros) {
      $line = shift @macros;
      $hasif = 0 unless @macros;
    } elsif ($specdata) {
      $inspec = 1;
      last unless @$specdata;
      $line = shift @$specdata;
      if (ref $line) {
	$line = $line->[0]; # verbatim line
        push @$xspec, $line if $xspec;
        $xspec->[-1] = [ $line, undef ] if $xspec && $skip;
	next;
      }
    } else {
      $inspec = 1;
      $line = <SPEC>;
      last unless defined $line;
      chomp $line;
    }
    push @$xspec, $line if $inspec && $xspec;
    if ($line =~ /^#\s*neededforbuild\s*(\S.*)$/) {
      next if $hasnfb;
      $hasnfb = $1;
      next;
    }
    if ($line =~ /^\s*#/) {
      next unless $line =~ /^#!BuildIgnore/;
    }
    my $expandedline = '';
    if (!$skip) {
      my $tries = 0;
      while ($line =~ /^(.*?)%(\{([^\}]+)\}|[0-9a-zA-Z_]+|%|\()(.*?)$/) {
	if ($tries++ > 1000) {
	  $line = 'MACRO';
	  last;
	}
	$expandedline .= $1;
	$line = $4;
	my $macname = defined($3) ? $3 : $2;
	my $macorig = $2;
	my $mactest = 0;
	if ($macname =~ /^\!\?/ || $macname =~ /^\?\!/) {
	  $mactest = -1;
	} elsif ($macname =~ /^\?/) {
	  $mactest = 1;
	}
	$macname =~ s/^[\!\?]+//;
	$macname =~ s/ .*//;
	my $macalt;
	($macname, $macalt) = split(':', $macname, 2);
	if ($macname eq '%') {
	  $expandedline .= '%';
	  next;
	} elsif ($macname eq '(') {
	  $line = 'MACRO';
	  last;
	} elsif ($macname eq 'define') {
	  if ($line =~ /^\s*([0-9a-zA-Z_]+)(\([^\)]*\))?\s*(.*?)$/) {
	    my $macname = $1;
	    my $macargs = $2;
	    my $macbody = $3;
	    $macbody = undef if $macargs;
	    $macros{$macname} = $macbody;
	  }
	  $line = '';
	  last;
	} elsif ($macname eq 'defined' || $macname eq 'with' || $macname eq 'undefined' || $macname eq 'without' || $macname eq 'bcond_with' || $macname eq 'bcond_without') {
	  my @args;
	  if ($macorig =~ /^\{(.*)\}$/) {
	    @args = split(' ', $1);
	    shift @args;
	  } else {
	    @args = split(' ', $line);
	    $line = '';
	  }
	  next unless @args;
	  if ($macname eq 'bcond_with') {
	    $macros{"with_$args[0]"} = 1 if exists $macros{"_with_$args[0]"};
	    next;
	  }
	  if ($macname eq 'bcond_without') {
	    $macros{"with_$args[0]"} = 1 unless exists $macros{"_without_$args[0]"};
	    next;
	  }
	  $args[0] = "with_$args[0]" if $macname eq 'with' || $macname eq 'without';
	  $line = ((exists($macros{$args[0]}) ? 1 : 0) ^ ($macname eq 'undefined' || $macname eq 'without' ? 1 : 0)).$line;
	} elsif (exists($macros{$macname})) {
	  if (!defined($macros{$macname})) {
	    $line = 'MACRO';
	    last;
	  }
	  $macalt = $macros{$macname} unless defined $macalt;
	  $macalt = '' if $mactest == -1;
	  $line = "$macalt$line";
	} elsif ($mactest) {
	  $macalt = '' if !defined($macalt) || $mactest == 1;
	  $line = "$macalt$line";
	} else {
	  $expandedline .= "%$macorig";
	}
      }
    }
    $line = $expandedline . $line;
    if ($line =~ /^\s*%else\b/) {
      $skip = 1 - $skip if $skip < 2;
      next;
    }
    if ($line =~ /^\s*%endif\b/) {
      $skip-- if $skip;
      next;
    }
    $skip++ if $skip && $line =~ /^\s*%if/;

    if ($skip) {
      $xspec->[-1] = [ $xspec->[-1], undef ] if $xspec;
      $$ifdeps = 1 if $ifdeps && ($line =~ /^(BuildRequires|BuildConflicts|\#\!BuildIgnore):\s*(\S.*)$/i);
      next;
    }

    if ($line =~ /^\s*%ifarch(.*)$/) {
      my $arch = $macros{'_target_cpu'} || 'unknown';
      my @archs = grep {$_ eq $arch} split(/\s+/, $1);
      $skip = 1 if !@archs;
      $hasif = 1;
      next;
    }
    if ($line =~ /^\s*%ifnarch(.*)$/) {
      my $arch = $macros{'_target_cpu'} || 'unknown';
      my @archs = grep {$_ eq $arch} split(/\s+/, $1);
      $skip = 1 if @archs;
      $hasif = 1;
      next;
    }
    if ($line =~ /^\s*%ifos(.*)$/) {
      my $os = $macros{'_target_os'} || 'unknown';
      my @oss = grep {$_ eq $os} split(/\s+/, $1);
      $skip = 1 if !@oss;
      $hasif = 1;
      next;
    }
    if ($line =~ /^\s*%ifnos(.*)$/) {
      my $os = $macros{'_target_os'} || 'unknown';
      my @oss = grep {$_ eq $os} split(/\s+/, $1);
      $skip = 1 if @oss;
      $hasif = 1;
      next;
    }
    if ($line =~ /^\s*%if(.*)$/) {
      my ($v, $r) = expr($1);
      $v = 0 if $v && $v eq '\"\"';
      $v =~ s/^0+/0/ if $v;
      $skip = 1 unless $v;
      $hasif = 1;
      next;
    }
    if ($main_preamble && ($line =~ /^Name:\s*(\S+)/i)) {
      $packname = $1;
      $macros{'name'} = $packname;
    }
    if ($main_preamble && ($line =~ /^Version:\s*(\S+)/i)) {
      $packvers = $1;
      $macros{'version'} = $packvers;
    }
    if ($main_preamble && ($line =~ /^Release:\s*(\S+)/i)) {
      $packrel = $1;
      $macros{'release'} = $packrel;
    }
    if ($main_preamble && ($line =~ /^ExclusiveArch:\s*(\S+)/i)) {
      $exclarch = $1;
    }
    if ($main_preamble && ($line =~ /^(BuildRequires|BuildConflicts|\#\!BuildIgnore):\s*(\S.*)$/i)) {
      my $what = $1;
      my $deps = $2;
      $$ifdeps = 1 if $ifdeps && $hasif;
      my @deps = $deps =~ /([^\s\[\(,]+)(\s+[<=>]+\s+[^\s\[,]+)?(\s+\[[^\]]+\])?[\s,]*/g;
      if (defined($hasnfb)) {
        next unless $xspec;
        if ((grep {$_ eq 'glibc' || $_ eq 'rpm' || $_ eq 'gcc' || $_ eq 'bash'} @deps) > 2) {
          # ignore old generetad BuildRequire lines.
	  $xspec->[-1] = [ $xspec->[-1], undef ];
        }
        next;
      }
      my $replace = 0;
      my @ndeps = ();
      while (@deps) {
	my ($pack, $vers, $qual) = splice(@deps, 0, 3);
	if (defined($qual)) {
          $replace = 1;
          my $arch = $macros{'_target_cpu'} || '';
          my $proj = $macros{'_target_project'} || '';
	  $qual =~ s/^\s*\[//;
	  $qual =~ s/\]$//;
	  my $isneg = 0;
	  my $bad;
	  for my $q (split('[\s,]', $qual)) {
	    $isneg = 1 if $q =~ s/^\!//;
	    $bad = 1 if !defined($bad) && !$isneg;
	    if ($isneg) {
	      if ($q eq $arch || $q eq $proj) {
		$bad = 1;
		last;
	      }
	    } elsif ($q eq $arch || $q eq $proj) {
	      $bad = 0;
	    }
	  }
	  next if $bad;
	}
	push @ndeps, $pack;
      }
      $replace = 1 if grep {/^-/} @ndeps;
      if ($what ne 'BuildRequires') {
	push @packdeps, map {"-$_"} @ndeps;
	next;
      }
      push @packdeps, @ndeps;
      next unless $xspec && $inspec;
      if ($replace) {
	my @cndeps = grep {!/^-/} @ndeps;
	if (@cndeps) {
          $xspec->[-1] = [ $xspec->[-1], "BuildRequires:  ".join(' ', @cndeps) ];
	} else {
          $xspec->[-1] = [ $xspec->[-1], ''];
	}
      }
      next;
    }

    if ($line =~ /^\s*%package\s+(-n\s+)?(\S+)/) {
      if ($1) {
	push @subpacks, $2;
      } else {
	push @subpacks, "$packname-$2" if defined $packname;
      }
    }

    if ($line =~ /^\s*%(package|prep|build|install|check|clean|preun|postun|pretrans|posttrans|pre|post|files|changelog|description|triggerpostun|triggerun|triggerin|trigger|verifyscript)/) {
      $main_preamble = 0;
    }
  }
  close SPEC unless ref $specfile;
  if (defined($hasnfb)) {
    if (!@packdeps) {
      @packdeps = split(' ', $hasnfb);
    }
  }
  unshift @subpacks, $packname;
  $ret->{'name'} = $packname;
  $ret->{'version'} = $packvers;
  $ret->{'release'} = $packrel if defined $packrel;
  $ret->{'subpacks'} = \@subpacks;
  $ret->{'exclarch'} = $exclarch if defined $exclarch;
  $ret->{'deps'} = \@packdeps;
  return $ret;
}

###########################################################################

sub read_dsc {
  my ($bconf, $fn) = @_;
  my $ret;
  my @control;
  if (ref($fn) eq 'ARRAY') {
    @control = @$fn;
  } else {
    local *F;
    if (!open(F, '<', $fn)) {
      $ret->{'error'} = "$fn: $!";
      return $ret;
    }
    @control = <F>;
    close F;
    chomp @control;
  }
  splice(@control, 0, 3) if @control > 3 && $control[0] =~ /^-----BEGIN/;
  my $name;
  my $version;
  my @deps;
  while (@control) {
    my $c = shift @control;
    last if $c eq '';   # new paragraph
    my ($tag, $data) = split(':', $c, 2);
    next unless defined $data;
    $tag = uc($tag);
    while (@control && $control[0] =~ /^\s/) {
      $data .= "\n".substr(shift @control, 1);
    }
    $data =~ s/^\s+//s;
    $data =~ s/\s+$//s;
    if ($tag eq 'VERSION') {
      $version = $data;
      $version =~ s/-[^-]+$//;
    } elsif ($tag eq 'SOURCE') {
      $name = $data;
    } elsif ($tag eq 'BUILD-DEPENDS') {
      my @d = split(/,\s*/, $data);
      s/\s.*// for @d;
      push @deps, @d;
    } elsif ($tag eq 'BUILD-CONFLICTS' || $tag eq 'BUILD-IGNORE') {
      my @d = split(/,\s*/, $data);
      s/\s.*// for @d;
      push @deps, map {"-$_"} @d;
    }
  }
  $ret->{'name'} = $name;
  $ret->{'version'} = $version;
  $ret->{'deps'} = \@deps;
  return $ret;
}

###########################################################################

sub rpmq {
  my $rpm = shift;
  my @stags = @_;
  my %stags = map {0+$_ => $_} @stags; 

  my ($magic, $sigtype, $headmagic, $cnt, $cntdata, $lead, $head, $index, $data, $tag, $type, $offset, $count);

  local *RPM;
  if (ref($rpm) eq 'GLOB') {
    *RPM = $rpm;
  } elsif (!open(RPM, '<', $rpm)) {
    warn("$rpm: $!\n");
    return ();
  }
  if (read(RPM, $lead, 96) != 96) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  ($magic, $sigtype) = unpack('N@78n', $lead);
  if ($magic != 0xedabeedb || $sigtype != 5) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  if (read(RPM, $head, 16) != 16) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  ($headmagic, $cnt, $cntdata) = unpack('N@8NN', $head);
  if ($headmagic != 0x8eade801) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  if (read(RPM, $index, $cnt * 16) != $cnt * 16) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  $cntdata = ($cntdata + 7) & ~7;
  if (read(RPM, $data, $cntdata) != $cntdata) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  if (read(RPM, $head, 16) != 16) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  ($headmagic, $cnt, $cntdata) = unpack('N@8NN', $head);
  if ($headmagic != 0x8eade801) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  if (read(RPM, $index, $cnt * 16) != $cnt * 16) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  if (read(RPM, $data, $cntdata) != $cntdata) {
    warn("Bad rpm $rpm\n");
    close RPM;
    return ();
  }
  close RPM;
  my %res = ();
  while($cnt-- > 0) {
    ($tag, $type, $offset, $count, $index) = unpack('N4a*', $index);
    $tag = 0+$tag;
    if ($stags{$tag}) {
      eval {
        my $otag = $stags{$tag};
        if ($type == 0) {
          $res{$otag} = [ '' ];
        } elsif ($type == 1) {
          $res{$otag} = [ unpack("\@${offset}c$count", $data) ];
        } elsif ($type == 2) {
          $res{$otag} = [ unpack("\@${offset}c$count", $data) ];
        } elsif ($type == 3) {
          $res{$otag} = [ unpack("\@${offset}n$count", $data) ];
        } elsif ($type == 4) {
          $res{$otag} = [ unpack("\@${offset}N$count", $data) ];
        } elsif ($type == 5) {
          $res{$otag} = [ undef ];
        } elsif ($type == 6) {
          $res{$otag} = [ unpack("\@${offset}Z*", $data) ];
        } elsif ($type == 7) {
          $res{$otag} = [ unpack("\@${offset}a$count", $data) ];
        } elsif ($type == 8 || $type == 9) {
          my $d = unpack("\@${offset}a*", $data);
          my @res = split("\0", $d, $count + 1);
          $res{$otag} = [ splice @res, 0, $count ];
        } else {
          $res{$otag} = [ undef ];
        }
      };
      if ($@) {
        warn("Bad rpm $rpm: $@\n");
        return ();
      }
    }
  }
  return %res;
}

sub rpmq_add_flagsvers {
  my $res = shift;
  my $name = shift;
  my $flags = shift;
  my $vers = shift;

  return unless $res;
  my @flags = @{$res->{$flags} || []};
  my @vers = @{$res->{$vers} || []};
  for (@{$res->{$name}}) {
    if (@flags && ($flags[0] & 0xe) && @vers) {
      $_ .= ' ';
      $_ .= '<' if $flags[0] & 2;
      $_ .= '>' if $flags[0] & 4;
      $_ .= '=' if $flags[0] & 8;
      $_ .= " $vers[0]";
    }
    shift @flags;
    shift @vers;
  }
}

sub rpm_verscmp_part {
  my ($s1, $s2) = @_;
  if (!defined($s1)) {
    return defined($s2) ? -1 : 0;
  }
  return 1 if !defined $s2;
  return 0 if $s1 eq $s2;
  while (1) {
    $s1 =~ s/^[^a-zA-Z0-9]+//;
    $s2 =~ s/^[^a-zA-Z0-9]+//;
    my ($x1, $x2, $r);
    if ($s1 =~ /^([0-9]+)(.*?)$/) {
      $x1 = $1;
      $s1 = $2;
      $s2 =~ /^([0-9]*)(.*?)$/;
      $x2 = $1;
      $s2 = $2;
      return 1 if $x2 eq '';
      $x1 =~ s/^0+//;
      $x2 =~ s/^0+//;
      $r = length($x1) - length($x2) || $x1 cmp $x2;
    } elsif ($s1 ne '' && $s2 ne '') {
      $s1 =~ /^([a-zA-Z]*)(.*?)$/;
      $x1 = $1;
      $s1 = $2;
      $s2 =~ /^([a-zA-Z]*)(.*?)$/;
      $x2 = $1;
      $s2 = $2;
      return -1 if $x1 eq '' || $x2 eq '';
      $r = $x1 cmp $x2;
    }
    return $r if $r;
    if ($s1 eq '') {
      return $s2 eq '' ? 0 : -1;
    }
    return 1 if $s2 eq ''
  }
}

sub rpm_verscmp {
  my ($s1, $s2) = @_;

  return 0 if $s1 eq $s2;
  my ($e1, $v1, $r1) = $s1 =~ /^(?:(\d+):)?(.*?)(?:-([^-]*))?$/s;
  $e1 = 0 unless defined $e1;
  $r1 = '' unless defined $r1;
  my ($e2, $v2, $r2) = $s2 =~ /^(?:(\d+):)?(.*?)(?:-([^-]*))?$/s;
  $e2 = 0 unless defined $e2;
  $r2 = '' unless defined $r2;
  if ($e1 ne $e2) {
    my $r = rpm_verscmp_part($e1, $e2);
    return $r if $r;
  }
  if ($v1 ne $v2) {
    my $r = rpm_verscmp_part($v1, $v2);
    return $r if $r;
  }
  if ($r1 ne $r2) {
    return rpm_verscmp_part($r1, $r2);
  }
  return 0;
}

###########################################################################

my $have_zlib;
eval {
  require Compress::Zlib;
  $have_zlib = 1;
};

sub ungzip {
  my $data = shift;
  local (*TMP, *TMP2);
  open(TMP, "+>", undef) or die("could not open tmpfile\n");
  syswrite TMP, $data;
  sysseek(TMP, 0, 0);
  my $pid = open(TMP2, "-|");
  die("fork: $!\n") unless defined $pid;
  if (!$pid) {
    open(STDIN, "<&TMP");
    exec 'gunzip';
    die("gunzip: $!\n");
  }
  close(TMP);
  $data = '';
  1 while sysread(TMP2, $data, 1024, length($data)) > 0;
  close(TMP2) || die("gunzip error");
  return $data;
}

sub debq {
  my ($fn) = @_;

  local *F;
  if (ref($fn) eq 'GLOB') {
      *F = $fn;
  } elsif (!open(F, '<', $fn)) {
    warn("$fn: $!\n");
    return ();
  }
  my $data = '';
  sysread(F, $data, 4096);
  if (length($data) < 8+60) {
    warn("$fn: not a debian package\n");
    close F unless ref $fn;
    return ();
  }
  if (substr($data, 0, 8+16) ne "!<arch>\ndebian-binary   ") {
    close F unless ref $fn;
    return ();
  }
  my $len = substr($data, 8+48, 10);
  $len += $len & 1;
  if (length($data) < 8+60+$len+60) {
    my $r = 8+60+$len+60 - length($data);
    $r -= length($data);
    if ((sysread(F, $data, $r < 4096 ? 4096 : $r, length($data)) || 0) < $r) {
      warn("$fn: unexpected EOF\n");
      close F unless ref $fn;
      return ();
    }
  }
  $data = substr($data, 8 + 60 + $len);
  if (substr($data, 0, 16) ne 'control.tar.gz  ') {
    warn("$fn: control.tar.gz is not second ar entry\n");
    close F unless ref $fn;
    return ();
  }
  $len = substr($data, 48, 10);
  if (length($data) < 60+$len) {
    my $r = 60+$len - length($data);
    if ((sysread(F, $data, $r, length($data)) || 0) < $r) {
      warn("$fn: unexpected EOF\n");
      close F unless ref $fn;
      return ();
    }
  }
  close F;
  $data = substr($data, 60, $len);
  if ($have_zlib) {
    $data = Compress::Zlib::memGunzip($data);
  } else {
    $data = ungzip($data);
  }
  if (!$data) {
    warn("$fn: corrupt control.tar.gz file\n");
    return ();
  }
  my $control;
  while (length($data) >= 512) {
    my $n = substr($data, 0, 100);
    $n =~ s/\0.*//s;
    my $len = oct('00'.substr($data, 124,12));
    my $blen = ($len + 1023) & ~511;
    if (length($data) < $blen) {
      warn("$fn: corrupt control.tar.gz file\n");
      return ();
    }
    if ($n eq './control') {
      $control = substr($data, 512, $len);
      last;
    }
    $data = substr($data, $blen);
  }
  my %res;
  my @control = split("\n", $control);
  while (@control) {
    my $c = shift @control;
    last if $c eq '';   # new paragraph
    my ($tag, $data) = split(':', $c, 2);
    next unless defined $data;
    $tag = uc($tag);
    while (@control && $control[0] =~ /^\s/) {
      $data .= "\n".substr(shift @control, 1);
    }
    $data =~ s/^\s+//s;
    $data =~ s/\s+$//s;
    $res{$tag} = $data;
  }
  return %res;
}

1;

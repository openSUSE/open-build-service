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

package BSSched::BuildJob::Package;

use strict;
use warnings;

use Digest::MD5 ();

use BSOBS;
use Build;		# for get_deps
use BSBuild;		# for add_meta
use BSSolv;		# for add_meta/gen_meta
use BSSched::BuildJob;

my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

=head1 NAME

BSSched::BuildJob::Package - A Class to handle standard package builds

=head1 SYNOPSIS

my $h = BSSched::BuildJob::Package->new()

$h->check();

$h->expand();

$h->rebuild();

=cut

=head2 new - TODO: add summary

 TODO: add description

=cut

sub new {
  return bless({}, $_[0]);
}

=head2 expand - TODO: add summary

 TODO: add description

=cut

sub expand {
  shift;
  goto &Build::get_deps;
}

=head2 check - check if a package needs to be rebuilt

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info, $buildtype, $edeps) = @_;
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $repo = $ctx->{'repo'};
  my $prp = $ctx->{'prp'};
  my $notready = $ctx->{'notready'};
  my $dep2src = $ctx->{'dep2src'};
  my $depislocal = $ctx->{'depislocal'};
  my $gdst = $ctx->{'gdst'};
  my $gctx = $ctx->{'gctx'};
  my $reporoot = $gctx->{'reporoot'};
  my $myarch = $gctx->{'arch'};

  # shortcut for buildinfo queries
  # it is not a problem that we use undef for hdeps, as it is only used to set the "notmeta" flag in the job
  return ('scheduled', [ {'explain' => 'buildinfo generation'}, undef, $edeps ]) if $ctx->{'isreposerver'};

  # check for localdep repos
  if (exists($pdata->{'originproject'})) {
    if ($repo->{'linkedbuild'} && $repo->{'linkedbuild'} eq 'localdep') {
      if (!grep {$depislocal->{$_}} @$edeps) {
        return ('excluded', 'project link, only depends on non-local packages');
      }
    }
  }

  my $rebuildmethod = $repo->{'rebuild'} || 'transitive';

  # calculate if we're blocked
  my $incycle = $ctx->{'incycle'} || 0;
  my @blocked = grep {$notready->{$dep2src->{$_}}} @$edeps;
  @blocked = () if $repo->{'block'} && $repo->{'block'} eq 'never';
  # prune cycle packages from blocked
  if (@blocked && $incycle > 1) {
    my $cyclevel = $ctx->{'cyclevel'};
    my $pkg2src = $ctx->{'pkg2src'} || {};
    my $level = $cyclevel->{$packid};
    if ($level) {
      my %cycs = map {($pkg2src->{$_} || $_) => ($cyclevel->{$_} || 1)} @{$ctx->{'cychash'}->{$packid}};
      @blocked = grep {($cycs{$dep2src->{$_}} || 0) < $level} @blocked;
    }
  }
  # if the rebuildmethod is local we postpone the blocked check, see below
  if (@blocked && ($rebuildmethod ne 'local' || $ctx->{'conf_host'})) {
    # print "      - $packid ($buildtype)\n";
    # print "        blocked\n";
    splice(@blocked, 10, scalar(@blocked), '...') if @blocked > 10;
    return ('blocked', join(', ', @blocked));
  }

  # expand host deps
  my $hdeps;
  if ($ctx->{'conf_host'}) {
    my $split_hostdeps = $info->{'split_hostdeps'};
    $split_hostdeps ||= ($ctx->{'split_hostdeps'} || {})->{$packid} if $packid;
    return ('broken', 'missing split_hostdeps entry') unless $split_hostdeps;
    my $subpacks = $ctx->{'subpacks'};
    $hdeps = [ @{$split_hostdeps->[1]}, @{$split_hostdeps->[2] || []} ];
    my $xp = BSSolv::expander->new($ctx->{'pool_host'}, $ctx->{'conf_host'});
    no warnings 'redefine';
    local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
    use warnings 'redefine';
    @$hdeps = Build::get_deps($ctx->{'conf_host'}, $subpacks->{$info->{'name'}}, @$hdeps);
    return ('unresolvable', 'host: '.join(', ', @$hdeps)) unless shift @$hdeps;
  }

  my $reason;
  my @meta_s = stat("$gdst/:meta/$packid");
  # we store the lastcheck data in one string instead of an array
  # with 4 elements to save precious memory
  # srcmd5.metamd5.hdrmetamd5.statdata (32+32+32+x)
  my $lastcheck = $ctx->{'lastcheck'};
  my $mylastcheck = $lastcheck->{$packid};
  my @meta;
  if (!@meta_s || !$mylastcheck || substr($mylastcheck, 96) ne "$meta_s[9]/$meta_s[7]/$meta_s[1]") {
    if (open(F, '<', "$gdst/:meta/$packid")) {
      @meta_s = stat F;
      @meta = <F>;
      close F;
      chomp @meta;
      $mylastcheck = substr($meta[0], 0, 32);
      if (@meta == 2 && $meta[1] =~ /^fake/) {
        $mylastcheck .= 'fakefakefakefakefakefakefakefake';
      } else {
        $mylastcheck .= Digest::MD5::md5_hex(join("\n", @meta));
      }
      $mylastcheck .= 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';	# fake hdrmetamd5
      $mylastcheck .= "$meta_s[9]/$meta_s[7]/$meta_s[1]";
      $lastcheck->{$packid} = $mylastcheck;
    } else {
      delete $lastcheck->{$packid};
      undef $mylastcheck;
    }
  }

  if (@blocked) {
    # ignore blocked if the rebuildmethod is local and we have a successful build
    if ($rebuildmethod eq 'local' && $mylastcheck && substr($mylastcheck, 0, 32) eq ($pdata->{'verifymd5'} || $pdata->{'srcmd5'}) && substr($mylastcheck, 32, 32) ne 'fakefakefakefakefakefakefakefake' && !$ctx->{'relsynctrigger'}->{$packid}) {
      return ('done');
    }
    # print "      - $packid ($buildtype)\n";
    # print "        blocked\n";
    splice(@blocked, 10, scalar(@blocked), '...') if @blocked > 10;
    return ('blocked', join(', ', @blocked));
  }

  if (!$mylastcheck) {
    if ($ctx->{'verbose'}) {
      print "      - $packid ($buildtype)\n";
      print "        no meta, start build\n";
    }
    return ('scheduled', [ { 'explain' => 'new build' }, $hdeps, $edeps ]);
  } elsif (substr($mylastcheck, 0, 32) ne ($pdata->{'verifymd5'} || $pdata->{'srcmd5'})) {
    if ($ctx->{'verbose'}) {
      print "      - $packid ($buildtype)\n";
      print "        src change, start build\n";
    }
    return ('scheduled', [ { 'explain' => 'source change', 'oldsource' => substr($mylastcheck, 0, 32) }, $hdeps, $edeps ]);
  } elsif (substr($mylastcheck, 32, 32) eq 'fakefakefakefakefakefakefakefake') {
    my @s = stat("$gdst/:meta/$packid");
    if (!@s || $s[9] + 14400 > time()) {
      if ($ctx->{'verbose'}) {
        print "      - $packid ($buildtype)\n";
        print "        buildsystem setup failure\n";
      }
      return ('failed')
    }
    if ($ctx->{'verbose'}) {
      print "      - $packid ($buildtype)\n";
      print "        retrying bad build\n";
    }
    return ('scheduled', [ { 'explain' => 'retrying bad build' }, $hdeps, $edeps ]);
  } else {
    my $forcebinaryidmeta = $ctx->{'forcebinaryidmeta'};
    if ($rebuildmethod eq 'local' || $pdata->{'hasbuildenv'} || $info->{'hasbuildenv'}) {
      # rebuild on src changes only
      goto relsynccheck;
    }
    # more work, check if dep rpm changed
    my $check = substr($mylastcheck, 32, 32);	# metamd5
    my $pool = $ctx->{'pool'};
    my $pool_host = $ctx->{'pool_host'};
    my $dep2pkg = $ctx->{'dep2pkg'};
    my $dep2pkg_host = $ctx->{'dep2pkg_host'};
    $check .= $ctx->{'genmetaalgo'} if $ctx->{'genmetaalgo'};
    $check .= 'forcebinaryidmeta' if $ctx->{'forcebinaryidmeta'};
    $check .= $ctx->{'modularity_meta'} if $ctx->{'modularity_meta'};
    $check .= $rebuildmethod;
    $check .= $pool->pkg2pkgid($dep2pkg->{$_}) for sort @$edeps;
    $check .= $pool_host->pkg2pkgid($dep2pkg_host->{$_}) for sort @{$hdeps || []};
    $check = Digest::MD5::md5_hex($check);
    if ($check eq substr($mylastcheck, 64, 32)) {
      # print "      - $packid ($buildtype)\n";
      # print "        nothing changed\n";
      goto relsynccheck;
    }
    substr($mylastcheck, 64, 32) = $check;	# substitute new hdrmetamd5
    # even more work, generate new meta, check if it changed
    my @new_meta;
    my $repodatas = $gctx->{'repodatas'};
    my $dep2meta = $repodatas->{"$prp/$myarch"}->{'meta'};
    $repodatas->{"$prp/$myarch"}->{'meta'} = $dep2meta = {} unless $dep2meta;
    my $addmeta = defined(&BSSolv::add_meta) ? \&BSSolv::add_meta : \&BSBuild::add_meta;
    for my $bin (@$edeps) {
      my $pkg = $dep2pkg->{$bin};
      my $path = $forcebinaryidmeta ? undef : $pool->pkg2fullpath($pkg, $myarch);
      if ($depislocal->{$bin} && $path) {
	my $m = $dep2meta->{$bin};
	if (!$m) {
	  # meta file is not in cache, read it from the full tree
	  # the next line works for deb and rpm 
	  my $mf = substr("$reporoot/$path", 0, -4);
	  if (-e "$mf.meta") {
	    my @s = stat(_);
	    $m = $dep2meta->{"/$s[9]/$s[7]/$s[1]"};
	  } else {
	    # the generic version
	    $mf = "$reporoot/$path";
	    $mf =~ s/\.(?:$binsufsre)$//;
	    if (-e "$mf.meta" || -e "$mf-MD5SUMS.meta") {
	      my @s = stat(_);
	      $m = $dep2meta->{"/$s[9]/$s[7]/$s[1]"};
	    }
	  }
	  if (!$m) {
	    if (open(F, '<', "$mf.meta") || open(F, '<', "$mf-MD5SUMS.meta")) {
	      my @s = stat(F);
	      local $/ = undef;
	      $m = [ scalar <F>, "/$s[9]/$s[7]/$s[1]" ];
	      close F;
	      if ($m->[0]) {
	        $dep2meta->{$m->[1]} = $m;
	      } else {
		undef $m;
	      }
	    }
	    $m ||= [ $pool->pkg2pkgid($pkg)."  $bin\n" ];	# fall back to hdrmd5
	  }
	  $dep2meta->{$bin} = $m;
	}
	# append meta file to new_meta
	$addmeta->(\@new_meta, $m, $bin, $packid);
      } else {
	# use the hdrmd5 for non-local packages
	push @new_meta, ($pool->pkg2pkgid($pkg)."  $bin");
      }
    }
    if ($hdeps) {
      my $hostarch = $ctx->{'conf_host'}->{'hostarch'};
      for my $bin (@$hdeps) {
	push @new_meta, ($pool_host->pkg2pkgid($dep2pkg_host->{$bin})."  $hostarch:$bin");
      }
    }
    unshift @new_meta, $ctx->{'modularity_meta'} if $ctx->{'modularity_meta'};
    @new_meta = BSSolv::gen_meta($ctx->{'subpacks'}->{$info->{'name'}} || [], @new_meta);
    unshift @new_meta, ($pdata->{'verifymd5'} || $pdata->{'srcmd5'})."  $packid";
    if (Digest::MD5::md5_hex(join("\n", @new_meta)) eq substr($mylastcheck, 32, 32)) {
      # print "      - $packid ($buildtype)\n";
      # print "        nothing changed (looked harder)\n";
      $ctx->{'nharder'}++;
      $lastcheck->{$packid} = $mylastcheck;
      goto relsynccheck;
    }
    # something changed, read in old meta (if not already done)
    if (!@meta && open(F, '<', "$gdst/:meta/$packid")) {
      @meta = <F>;
      close F;
      chomp @meta;
    }
    if ($incycle == 1) {
      # calculate cyclevel
      my $level;
      if (defined &BSSolv::diffdepth_meta) {
	$level = BSSolv::diffdepth_meta(\@new_meta, \@meta);
      } else {
        $level = BSBuild::diffdepth(\@new_meta, \@meta);
      }
      $ctx->{'cyclevel'}->{$packid} = $level;
      if ($level > 1) {
        # print "      - $packid ($buildtype)\n";
        # print "        in cycle, no source change...\n";
        return ('done');	# postpone till phase 2
      }
    }
    if ($rebuildmethod eq 'direct') {
      @meta = grep {!/\//} @meta;
      @new_meta = grep {!/\//} @new_meta;
    }
    if (@meta == @new_meta && join('\n', @meta) eq join('\n', @new_meta)) {
      # print "      - $packid ($buildtype)\n";
      # print "        nothing changed (looked harder)\n";
      $ctx->{'nharder'}++;
      if ($rebuildmethod eq 'direct') {
        $lastcheck->{$packid} = $mylastcheck;
      } else {
        # should not happen, delete lastcheck cache
        delete $lastcheck->{$packid};
      }
      goto relsynccheck;
    }
    my @diff = BSSched::BuildJob::diffsortedmd5(\@meta, \@new_meta);
    my $reason = BSSched::BuildJob::sortedmd5toreason(@diff);
    my $levelstr = $ctx->{'cyclevel'}->{$packid} ? " (cyclevel $ctx->{'cyclevel'}->{$packid})" : '';
    if ($ctx->{'verbose'}) {
      print "      - $packid ($buildtype)\n";
      print "        $_\n" for @diff;
      print "        meta change, start build$levelstr\n";
    }
    return ('scheduled', [ { 'explain' => 'meta change', 'packagechange' => $reason }, $hdeps, $edeps ] );
  }
relsynccheck:
  if ($ctx->{'relsynctrigger'}->{$packid}) {
    if ($ctx->{'verbose'}) {
      print "      - $packid ($buildtype)\n";
      print "        rebuild counter sync, start build\n";
    }
    return ('scheduled', [ { 'explain' => 'rebuild counter sync' }, $hdeps, $edeps ] );
  }
  return ('done');
}

=head2 build - create a package build job

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my ($reason, $hdeps, $edeps) = @$data;

  my $needed = 0;
  if ($packid && !$ctx->{'isreposerver'}) {
    $ctx->create_rebuildpackage_needed() unless $ctx->{'rebuildpackage_needed'};
    $needed = $ctx->{'rebuildpackage_needed'}->{$packid} || 0;
  }

  my $subpacks = $ctx->{'subpacks'}->{$info->{'name'}} || [];

  my $nounchanged;
  #$nounchanged = 1 if $packid && $ctx->{'cychash'}->{$packid} && !$ctx->{'forcebinaryidmeta'};

  if ($ctx->{'conf_host'}) {
    # add all sysdeps as extrabdeps
    my $dobuildinfo = $ctx->{'dobuildinfo'};
    my @bdeps;
    for (@$edeps) {
      my $bdep = {'name' => $_, 'sysroot' => 1};
      if ($dobuildinfo) {
	my $p = $ctx->{'dep2pkg'}->{$_};
        my $prp = $ctx->{'pool'}->pkg2reponame($p);
        ($bdep->{'project'}, $bdep->{'repository'}) = split('/', $prp, 2) if $prp;
	my $d = $ctx->{'pool'}->pkg2data($p);
	$bdep->{'epoch'}      = $d->{'epoch'} if $d->{'epoch'};
	$bdep->{'version'}    = $d->{'version'};
	$bdep->{'release'}    = $d->{'release'} if defined $d->{'release'};
	$bdep->{'arch'}       = $d->{'arch'} if $d->{'arch'};
      }
      push @bdeps, $bdep;
    }

    # limit build dependencies to host dependencies
    my $split_hostdeps = $info->{'split_hostdeps'};
    $split_hostdeps ||= ($ctx->{'split_hostdeps'} || {})->{$packid} if $packid;
    return ('broken', 'missing split_hostdeps entry') unless $split_hostdeps;
    $info = { %$info, 'dep' => [ @{$split_hostdeps->[1]}, @{$split_hostdeps->[2] || []} ] };

    # create the job
    my $xp = BSSolv::expander->new($ctx->{'pool_host'}, $ctx->{'conf_host'});
    no warnings 'redefine';
    local *Build::expand = sub { $_[0] = $xp; goto &BSSolv::expander::expand; };
    use warnings 'redefine';
    $ctx = bless { %$ctx, 'conf' => $ctx->{'conf_host'}, 'pool' => $ctx->{'pool_host'}, 'dep2pkg' => $ctx->{'dep2pkg_host'}, 'realctx' => $ctx, 'expander' => $xp, 'crossmode' => 1}, ref($ctx);
    $ctx->{'extrabdeps'} = \@bdeps;
    $info->{'nounchanged'} = 1 if $nounchanged;
    my ($state, $job) = BSSched::BuildJob::create($ctx, $packid, $pdata, $info, $subpacks, $hdeps || [], $reason, $needed);
    delete $info->{'nounchanged'};
    return ($state, $job);
  }

  $info->{'nounchanged'} = 1 if $nounchanged;
  my ($state, $job) = BSSched::BuildJob::create($ctx, $packid, $pdata, $info, $subpacks, $edeps, $reason, $needed);
  delete $info->{'nounchanged'};
  return ($state, $job);
}

# split dependencies into (\@sysroot, \@native)
sub split_hostdeps {
  my ($bconf, $info) = @_;
  my $dep = $info->{'dep'} || [];
  return ($dep, []) unless @$dep;
  my %onlynative = map {$_ => 1} @{$bconf->{'onlynative'} || []};
  my %alsonative = map {$_ => 1} @{$bconf->{'alsonative'} || []};
  for (@{$info->{'onlynative'} || []}) {
    if (/^!(.*)/) {
      delete $onlynative{$1};
    } else {
      $onlynative{$_} = 1;
    }   
  }
  for (@{$info->{'alsonative'} || []}) {
    if (/^!(.*)/) {
      delete $alsonative{$1};
    } else {
      $alsonative{$_} = 1;
    }   
  }
  return ($dep, []) unless %onlynative || %alsonative;
  my @hdep = grep {$onlynative{$_} || $alsonative{$_}} @$dep;
  return ($dep, \@hdep) if !@hdep || !%onlynative;
  return ([ grep {!$onlynative{$_}} @$dep ], \@hdep)
}

# split build dependencies and expand the sysroot
# store extracted native packages in $splitdeps[2] if there are any
sub expand_sysroot {
  my ($bconf, $subpacks, $info) = @_;
  my @splitdeps = split_hostdeps($bconf, $info);
  my @n; 
  my @edeps;
  if ($bconf->{'binarytype'} eq 'deb') {
    @edeps = Build::get_sysroot($bconf, $subpacks, '--extractnative--', \@n, @{$splitdeps[0]});
  } else {
    @edeps = Build::get_sysroot($bconf, $subpacks, @{$splitdeps[0]});
  }   
  $splitdeps[2] = \@n if @n; 
  return \@splitdeps, @edeps;
}

1;

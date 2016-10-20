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
package BSSrcServer::Link;

use strict;
use warnings;

use Digest::MD5 ();

use BSConfiguration;
use BSSrcrep;
use BSRevision;
use BSUtil;
use BSVerify;

use BSSrcServer::Access;
use BSSrcServer::Local;

my $srcrep = "$BSConfig::bsdir/sources";
my $uploaddir = "$srcrep/:upload";


# this is what's used to get the next hop
our $getrev = \&BSSrcServer::Local::getrev;

our $lsrev_linktarget = sub {
  return BSRevision::lsrev($_[0], $_[1] || {})
};


sub isascii {
  my ($file) = @_;
  return 0 if $file =~ /\.obscpio$/;
  local *F;
  open(F, '<', $file) || die("$file: $!\n");
  my $buf = '';
  sysread(F, $buf, 4096);
  close F;
  return 1 unless $buf =~ /[\000-\010\016-\037]/s;
  return 0;
}

sub patchspec {
  my ($p, $dir, $spec) = @_;
  local *F;
  open(F, '<', "$dir/$spec") || die("$dir/$spec: $!\n");
  my @preamble;
  while(<F>) {
    chomp;
    push @preamble, $_;
    last if /^\s*%(package|prep|build|install|check|clean|preun|postun|pretrans|posttrans|pre|post|files|changelog|description|triggerpostun|triggerun|triggerin|trigger|verifyscript)(\s|$)/;
  }
  my %patches;
  for (@preamble) {
    next unless /^patch(\d*)\s*:/i;  
    $patches{0 + ($1 eq '' ? 0 : $1)} = $_;
  }
  my @patches = sort {$a <=> $b} keys %patches;
  my $nr = 0;
  if (exists $p->{'after'}) {
    $nr = 0 + $p->{'after'};
    $nr++ while $patches{$nr};
  } else {
    $nr = $patches[-1] + 1 if @patches;
  }
  my @after;
  @after = map {$patches{$_}} grep {$_ < $nr} @patches if @patches;
  @after = grep {/^source(\d*)\s*:/i} @preamble if !@after;
  @after = grep {/^name(\d*)\s*:/i} @preamble if !@after;
  @after = $preamble[-2] if @preamble > 1 && !@after;
  return "could not find a place to insert the patch" if !@after;
  my $nrx = $nr;
  $nrx = '' if $nrx == 0;
  local *O;
  open(O, '>', "$dir/.patchspec$$") || die("$dir/.patchspec$$: $!\n");
  for (@preamble) {
    print O "$_\n";
    next unless @after && $_ eq $after[-1];
    print O "Patch$nrx: $p->{'name'}\n";
    @after = ();
  }
  if ($preamble[-1] !~ /^\s*%prep(\s|$)/) {
    while (1) {
      my $l = <F>;
      return "specfile has no %prep section" if !defined $l;
      chomp $l;
      print O "$l\n";
      last if $l =~ /^\s*%prep(\s|$)/;
    }
  }
  my @prep;
  while(<F>) {
    chomp;
    push @prep, $_;
    last if /^\s*%(package|prep|build|install|check|clean|preun|postun|pretrans|posttrans|pre|post|files|changelog|description|triggerpostun|triggerun|triggerin|trigger|verifyscript)(\s|$)/;
  }
  %patches = ();
  my $ln = -1;
  # find outmost pushd/popd calls and insert new patches after a pushd/popd block
  # $blevel == 0 indicates the outmost block
  my %bend = ();
  my $bln = undef;
  $$bln = $ln;
  my $blevel = -1;
  for (@prep) {
    $ln++;
    $blevel++ if /^pushd/;
    if (/^popd/) {
      unless ($blevel) {
        $$bln = $ln;
        undef $bln;
        $$bln = $ln;
      }
      $blevel--;
    }
    next unless /%patch(\d*)(.*)/;
    if ($1 ne '') {
      $patches{0 + $1} = $ln;
      $bend{0 + $1} = $bln if $blevel >= 0;
      next;
    }
    my $pnum = 0;
    my @a = split(' ', $2);
    if (! grep {$_ eq '-P'} @a) {
      $patches{$pnum} = $ln;
    } else {
      while (@a) {
        next if shift(@a) ne '-P';
        next if !@a || $a[0] !~ /^\d+$/;
        $pnum = 0 + shift(@a);
        $patches{$pnum} = $ln;
      }
    }
    $bend{$pnum} = $bln if $blevel >= 0;
  }
  return "specfile has broken %prep section" unless $blevel == -1;
  @patches = sort {$a <=> $b} keys %patches;
  $nr = 1 + $p->{'after'} if exists $p->{'after'};
  %patches = map { $_ => exists $bend{$_} ? ${$bend{$_}} : $patches{$_} } @patches;
  @after = map {$patches{$_}} grep {$_ < $nr} @patches if @patches;
  @after = ($patches[0] - 1) if !@after && @patches;
  @after = (@prep - 2) if !@after;
  my $after = $after[-1];
  $after = -1 if $after < -1;
  $ln = -1;
  push @prep, '' if $after >= @prep;
  #print "insert %patch after line $after\n";
  for (@prep) {
    if (defined($after) && $ln == $after) {
      print O "pushd $p->{'dir'}\n" if exists $p->{'dir'};
      if ($p->{'popt'}) {
        print O "%patch$nrx -p$p->{'popt'}\n";
      } else {
        print O "%patch$nrx\n";
      }
      print O "popd\n" if exists $p->{'dir'};
      undef $after;
    }
    print O "$_\n";
    $ln++;
  }
  while(<F>) {
    chomp;
    print O "$_\n";
  }
  close(O) || die("close: $!\n");
  rename("$dir/.patchspec$$", "$dir/$spec") || die("rename $dir/.patchspec$$ $dir/$spec: $!\n");
  return '';
}
# " Make emacs wired syntax highlighting happy

sub topaddspec {
  my ($p, $dir, $spec) = @_;
  local (*F, *O);
  open(F, '<', "$dir/$spec") || die("$dir/$spec: $!\n");
  open(O, '>', "$dir/.topaddspec$$") || die("$dir/.topaddspec$$: $!\n");
  my $text = $p->{'text'};
  $text = '' if !defined $text;
  $text .= "\n" if $text ne '' && substr($text, -1, 1) ne "\n";
  print O $text;
  while(<F>) {
    chomp;
    print O "$_\n";
  }
  close(O) || die("close: $!\n");
  rename("$dir/.topaddspec$$", "$dir/$spec") || die("rename $dir/.topaddspec$$ $dir/$spec: $!\n");
}

#
# apply a single link step
# store the result under the identifier "$md5"
#
# hack: if "$md5" is not set, store the result in "$uploaddir/applylink$$"
#
sub applylink {
  my ($md5, $lsrc, $llnk) = @_;
  # no need to do all the work again if we already have an error result...
  if ($md5) {
    my $lerror = BSSrcrep::getlinkerror($llnk->{'project'}, $llnk->{'package'}, $md5);
    return $lerror if $lerror;
  }
  my $flnk = BSRevision::lsrev($llnk);
  my $fsrc = BSRevision::lsrev($lsrc);
  my $l = $llnk->{'link'};
  my $patches = $l->{'patches'} || {};
  my @patches = ();
  my $simple = 1;
  my @simple_delete;
  my $isbranch;
  if ($l->{'patches'}) {
    for (@{$l->{'patches'}->{''} || []}) {
      my $type = (keys %$_)[0];
      if (!$type) {
	$simple = 0;
	next;
      }
      if ($type eq 'topadd') {
        push @patches, { 'type' => $type, 'text' => $_->{$type}};
	$simple = 0;
      } elsif ($type eq 'delete') {
        push @patches, { 'type' => $type, %{$_->{$type} || {}}};
	push @simple_delete, $patches[-1]->{'name'};
      } else {
        push @patches, { 'type' => $type, %{$_->{$type} || {}}};
	$simple = 0;
	$isbranch = 1 if $type eq 'branch';
      }
    }
  }
  $simple = 0 unless $md5;
  if ($simple) {
    # simple source link with no patching
    # copy all files but the ones we have locally
    BSSrcrep::copyfiles($llnk->{'project'}, $llnk->{'package'}, $lsrc->{'project'}, $lsrc->{'package'}, $fsrc, $flnk);
    # calculate meta
    my $newf = { %$fsrc };
    for my $f (sort keys %$flnk) {
      $newf->{$f} = $flnk->{$f} unless $f eq '_link';
    }
    delete $newf->{$_} for @simple_delete;
    # store filelist in md5
    my $linkinfo = {
      'srcmd5'  => $lsrc->{'srcmd5'},
      'lsrcmd5' => $llnk->{'srcmd5'},
    };
    BSSrcrep::addmeta_link($llnk->{'project'}, $llnk->{'package'}, $newf, $md5, $linkinfo);
    return '';
  }

  # sanity checking...
  for my $p (@patches) {
    return "patch has no type" unless exists $p->{'type'};
    return "patch has illegal type \'$p->{'type'}\'" unless $p->{'type'} eq 'apply' || $p->{'type'} eq 'add' || $p->{'type'} eq 'topadd' || $p->{'type'} eq 'delete' || $p->{'type'} eq 'branch';
    if ($p->{'type'} ne 'topadd' && $p->{'type'} ne 'delete' && $p->{'type'} ne 'branch') {
      return "patch has no patchfile" unless exists $p->{'name'};
      return "patch \'$p->{'name'}\' does not exist" unless $flnk->{$p->{'name'}};
    }
  }
  my $tmpdir = "$uploaddir/applylink$$";
  mkdir_p($tmpdir);
  die("$tmpdir: $!\n") unless -d $tmpdir;
  unlink("$tmpdir/$_") for ls($tmpdir);	# remove old stuff
  my %apply = map {$_->{'name'} => 1} grep {$_->{'type'} eq 'apply'} @patches;
  $apply{$_} = 1 for keys %{$llnk->{'ignore'} || {}};	# also ignore those files, used in keeplink
  my %fl;	# file origins
  if (!$isbranch) {
    for my $f (sort keys %$fsrc) {
      next if $flnk->{$f} && !$apply{$f};
      BSSrcrep::copyonefile_tmp($lsrc->{'project'}, $lsrc->{'package'}, $f, $fsrc->{$f}, "$tmpdir/$f");
      $fl{$f} = BSRevision::revfilename($lsrc, $f, $fsrc->{$f});
    }
    for my $f (sort keys %$flnk) {
      next if $apply{$f} || $f eq '_link';
      BSSrcrep::copyonefile_tmp($llnk->{'project'}, $llnk->{'package'}, $f, $flnk->{$f}, "$tmpdir/$f");
      $fl{$f} = BSRevision::revfilename($llnk, $f, $flnk->{$f});
    }
  }
  my $failed;
  for my $p (@patches) {
    my $pn = $p->{'name'};
    if ($p->{'type'} eq 'delete') {
      unlink("$tmpdir/$pn");
      next;
    }
    if ($p->{'type'} eq 'branch') {
      # flnk: mine
      # fbas: old
      # fsrc: new
      my $baserev = $l->{'baserev'};
      return "no baserev in branch patch" unless $baserev;
      return "baserev is not srcmd5" unless $baserev =~ /^[0-9a-f]{32}$/s;
      my %brev = (%$lsrc, 'srcmd5' => $baserev);
      my $fbas;
      eval {
        $fbas = BSRevision::lsrev(\%brev);
      };
      return "baserev $baserev does not exist" unless $fbas;
      return "baserev is link" if $fbas->{'_link'};

      # ignore linked generated service files if our link contains service files
      if (grep {/^_service/} keys %$flnk) {
	delete $fbas->{$_} for grep {/^_service[:_]/} keys %$fbas;
	delete $fsrc->{$_} for grep {/^_service[:_]/} keys %$fsrc;
      }
      # do 3-way merge
      my %destnames = (%$fsrc, %$flnk);
      delete $destnames{'_link'};
      for my $f (sort {length($a) <=> length($b) || $a cmp $b} keys %destnames) {
	my $mbas = $fbas->{$f} || '';
	my $msrc = $fsrc->{$f} || '';
	my $mlnk = $flnk->{$f} || '';
	if ($mbas eq $mlnk) {
	  next if $msrc eq '';
	  BSSrcrep::copyonefile_tmp($lsrc->{'project'}, $lsrc->{'package'}, $f, $fsrc->{$f}, "$tmpdir/$f");
	  $fl{$f} = BSRevision::revfilename($lsrc, $f, $fsrc->{$f});
	  next;
	}
	if ($mbas eq $msrc || $mlnk eq $msrc) {
	  next if $mlnk eq '';
	  BSSrcrep::copyonefile_tmp($llnk->{'project'}, $llnk->{'package'}, $f, $flnk->{$f}, "$tmpdir/$f");
	  $fl{$f} = BSRevision::revfilename($llnk, $f, $flnk->{$f});
	  next;
	}
	if ($mbas eq '' || $msrc eq '' || $mlnk eq '') {
	  $failed = "conflict in file $f";
	  last;
	}
	if ($f =~ /\.obscpio$/s) {
	  $failed = "conflict in file $f";
	  last;
	}
        # run merge tools
        BSSrcrep::copyonefile_tmp($lsrc->{'project'}, $lsrc->{'package'}, $f, $fsrc->{$f}, "$tmpdir/$f.new");
        BSSrcrep::copyonefile_tmp($lsrc->{'project'}, $lsrc->{'package'}, $f, $fbas->{$f}, "$tmpdir/$f.old");
        BSSrcrep::copyonefile_tmp($llnk->{'project'}, $llnk->{'package'}, $f, $flnk->{$f}, "$tmpdir/$f.mine");
	if (!isascii("$tmpdir/$f.new") || !isascii("$tmpdir/$f.old") || !isascii("$tmpdir/$f.mine")) {
	  $failed = "conflict in file $f";
	  last;
	}
	my $pid;
        if ( $f =~ /\.changes$/ ) {
          # try our changelog merge tool first
  	  if (!($pid = xfork())) {
	    delete $SIG{'__DIE__'};
	    open(STDERR, '>>', "$tmpdir/.log") || die(".log: $!\n");
	    open(STDOUT, '>', "$tmpdir/$f") || die("$f: $!\n");
            print STDERR "running merge tool on $f\n";
	    exec('./bs_mergechanges', "$tmpdir/$f.old", "$tmpdir/$f.new", "$tmpdir/$f.mine");
	    die("./bs_mergechanges: $!\n");
	  }
  	  waitpid($pid, 0) == $pid || die("waitpid $pid: $!\n");
	  $pid = undef if $?;
        }
	if (!$pid) {
          # default diff3 merge tool. always using as fallback
	  if (!($pid = xfork())) {
	    delete $SIG{'__DIE__'};
	    chdir($tmpdir) || die("$tmpdir: $!\n");
	    open(STDERR, '>>', ".log") || die(".log: $!\n");
	    open(STDOUT, '>', $f) || die("$f: $!\n");
            print STDERR "running diff3 on $f\n";
	    exec('/usr/bin/diff3', '-m', '-E', "$f.mine", "$f.old", "$f.new");
	    die("/usr/bin/diff3: $!\n");
	  }
	  waitpid($pid, 0) == $pid || die("waitpid $pid: $!\n");
	  if ($?) {
	    $failed = "conflict in file $f";
	    last;
	  }
	}
	unlink("$tmpdir/$f.old");
	unlink("$tmpdir/$f.new");
	unlink("$tmpdir/$f.mine");
      }
      last if $failed;
      next;
    }
    if ($p->{'type'} eq 'add') {
      for my $spec (grep {/\.spec$/} ls($tmpdir)) {
	local *F;
	open(F, '>>', "$tmpdir/.log") || die("$tmpdir/.log: $!\n");
	print F "adding patch $pn to $spec\n";
	close F;
        my $err = patchspec($p, $tmpdir, $spec);
        if ($err) {
	  open(F, '>>', "$tmpdir/.log") || die("$tmpdir/.log: $!\n");
	  print F "error: $err\n";
	  close F;
	  $failed = "could not add patch '$pn'";
	  last;
	  unlink("$tmpdir/$_") for ls($tmpdir);
	  rmdir($tmpdir);
	  return "could not add patch '$pn'";
	}
        delete $fl{$spec};
      }
      last if $failed;
      next;
    }
    if ($p->{'type'} eq 'topadd') {
      for my $spec (grep {/\.spec$/} ls($tmpdir)) {
	local *F;
	open(F, '>>', "$tmpdir/.log") || die("$tmpdir/.log: $!\n");
	print F "adding text at top of $spec\n";
	close F;
        topaddspec($p, $tmpdir, $spec);
        delete $fl{$spec};
      }
      next;
    }
    next unless $p->{'type'} eq 'apply';
    my $pid;
    if (!($pid = xfork())) {
      delete $SIG{'__DIE__'};
      chdir($tmpdir) || die("$tmpdir: $!\n");
      my $pnfile = BSRevision::revfilename($llnk, $pn, $flnk->{$pn});
      open(STDIN, '<', $pnfile) || die("$pnfile: $!\n");
      open(STDOUT, '>>', ".log") || die(".log: $!\n");
      open(STDERR, '>&STDOUT');
      $| = 1;
      print "applying patch $pn\n";
      $::ENV{'TMPDIR'} = '.';
      # Old patch command still supported --unified-reject-files and --global-reject-file.
      # exec('/usr/bin/patch', '--no-backup-if-mismatch', '--unified-reject-files', '--global-reject-file=.rejects', '-g', '0', '-f');
      exec('/usr/bin/patch', '--no-backup-if-mismatch', '-g', '0', '-f');
      die("/usr/bin/patch: $!\n");
    }
    waitpid($pid, 0) == $pid || die("waitpid $pid: $!\n");
    $failed = "could not apply patch '$pn'" if $?;
    # clean up patch fallout...
    for my $f (ls($tmpdir)) {
      my @s = lstat("$tmpdir/$f");
      die("$tmpdir/$f: $!\n") unless @s;
      if (-l _ || ! -f _) {
        unlink("$tmpdir/$f");
	$failed = "patch created a non-file";
	next;
      }
      eval {
	die("cannot create a link from a patch") if $f eq '_link';
	BSVerify::verify_filename($f) unless $f eq '.log';
      };
      if ($@) {
        unlink("$tmpdir/$f");
	$failed = "patch created an illegal file";
	next;
      }
      chmod(($s[2] & 077) | 0600, "$tmpdir/$f") if ($s[2] & 07700) != 0600;
    }
    last if $failed;
  }
  if ($failed) {
    BSUtil::appendstr("$tmpdir/.log", "\n$failed\n");
    # save link error log
    BSSrcrep::addmeta_linkerror($llnk->{'project'}, $llnk->{'package'}, $md5, "$tmpdir/.log") if $md5;
    BSUtil::cleandir($tmpdir);
    rmdir($tmpdir);
    return str2utf8xml($failed);
  }
  my @newf = grep {!/^\./} ls($tmpdir);
  my $newf = {};
  local *F;
  for my $f (@newf) {
    my @s = stat "$tmpdir/$f";
    die("$tmpdir/$f: $!\n") unless @s;
    if ($s[3] > 1 && $fl{$f}) {
      my @s2 = stat($fl{$f});
      die("$fl{$f}: $!\n") unless @s2;
      if ("$s[0]/$s[1]" eq "$s2[0]/$s2[1]") {
        $newf->{$f} = $fl{$f};
        $newf->{$f} =~ s/.*\///;
        $newf->{$f} = substr($newf->{$f}, 0, 32);
	next;
      }
    }
    open(F, '<', "$tmpdir/$f") || die("$tmpdir/$f: $!\n");
    my $ctx = Digest::MD5->new;
    $ctx->addfile(*F);
    close F;
    $newf->{$f} = $ctx->hexdigest();
  }

  # if we just want the patched files we're finished
  if (!$md5) {
    # rename into md5 form, sort so that there's no collision
    for my $f (sort {length($b) <=> length($a) || $a cmp $b} @newf) {
      rename("$tmpdir/$f", "$tmpdir/$newf->{$f}-$f");
    }
    return $newf;
  }

  # otherwise link everything over
  for my $f (@newf) {
    BSSrcrep::addfile($llnk->{'project'}, $llnk->{'package'}, "$tmpdir/$f", $f, $newf->{$f});
  }
  # clean up tmpdir
  BSUtil::cleandir($tmpdir);
  rmdir($tmpdir);
  # store filelist
  my $linkinfo = {
    'srcmd5'  => $lsrc->{'srcmd5'},
    'lsrcmd5' => $llnk->{'srcmd5'},
  };
  BSSrcrep::addmeta_link($llnk->{'project'}, $llnk->{'package'}, $newf, $md5, $linkinfo);
  return '';
}

#
# expand a source link
# - returns expanded file list
# - side effects:
#   modifies $rev->{'srcmd5'}, $rev->{'vrev'}, $rev->{'linkrev'}
#   modifies $li->{'srcmd5'}, $li->{'lsrcmd5'}
#   modifies $li->{'linked'} if exists
#
sub handlelinks {
  my ($rev, $files, $li) = @_;

  my @linkinfo;
  my %seen;
  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
  my $linkrev = $rev->{'linkrev'};
  push @linkinfo, {'project' => $projid, 'package' => $packid, 'srcmd5' => $rev->{'srcmd5'}, 'rev' => $rev->{'rev'}};
  delete $rev->{'srcmd5'};
  delete $rev->{'linkrev'};
  my $oldvrev = 0;
  my $vrevdone;
  my $lrev = $rev;
  while ($files->{'_link'}) {
    my $l = BSRevision::revreadxml($lrev, '_link', $files->{'_link'}, $BSXML::link, 1);
    return '_link is bad' unless $l;
    my $cicount = $l->{'cicount'} || 'add';
    eval {
      BSVerify::verify_link($l);
      die("illegal cicount\n") unless $cicount eq 'copy' || $cicount eq 'add' || $cicount eq 'local';
      if (!exists($l->{'package'}) && exists($l->{'project'}) && $l->{'project'} ne $linkinfo[-1]->{'project'}) {
        # be extra careful if the package attribute doesn't exist, but the
        # link points to some other project
        BSSrcServer::Access::checksourceaccess($l->{'project'}, $linkinfo[-1]->{'package'});
      }
    };
    if ($@) {
      my $err = $@;
      $err =~ s/\n$//s;
      return "_link is bad: $err" if @linkinfo == 1;
      return "$lrev->{'project'}/$lrev->{'package'}: _link is bad: $err";
    }
    if (exists $l->{'package'}) {
      # just in case, we want all links to point to real packages...
      return "link points to illegal package name '$l->{'package'}'" if $l->{'package'} =~ /(?<!^_product)(?<!^_patchinfo):./;
    }
    $l->{'project'} = $linkinfo[-1]->{'project'} unless exists $l->{'project'};
    $l->{'package'} = $linkinfo[-1]->{'package'} unless exists $l->{'package'};
    $linkrev = $l->{'baserev'} if $linkrev && $linkrev eq 'base';
    ($l->{'rev'}, $linkrev) = ($linkrev, undef) if $linkrev;
    $linkinfo[-1]->{'link'} = $l;
    $projid = $l->{'project'};
    $packid = $l->{'package'};
    $lrev = $l->{'rev'} || '';
    return 'circular package link' if $seen{"$projid/$packid/$lrev"};
    $seen{"$projid/$packid/$lrev"} = 1;
    # record link target for projpack
    push @{$li->{'linked'}}, {'project' => $projid, 'package' => $packid} if $li && $li->{'linked'}; 
    eval {
      if ($l->{'missingok'}) {
        # be careful with 'missingok' pointing to protected packages
        BSSrcServer::Access::checksourceaccess($projid, $packid);
      }
      $lrev = $getrev->($projid, $packid, $l->{'rev'}, $li ? $li->{'linked'} : undef, $l->{'missingok'} ? 1 : 0);
    };
    if ($@) {
      my $error = $@;
      chomp $error;
      $error = $2 if $error =~ /^(\d+) +(.*?)$/s;
      return "$projid/$packid: $error";
    }
    return "linked package '$packid' does not exist in project '$projid'" unless $lrev;
    return "linked package '$packid' is empty" if $lrev->{'srcmd5'} eq 'empty';
    return "linked package '$packid' is strange" unless $lrev->{'srcmd5'} =~ /^[0-9a-f]{32}$/;
    $lrev->{'vrev'} = $l->{'vrev'} if defined $l->{'vrev'};
    undef $files;
    eval {
      # links point to expanded services
      $files = $lsrev_linktarget->($lrev);
    };
    if ($@) {
      my $error = $@;
      chomp $error;
      return "$projid/$packid: $error";
    }
    $rev->{'vrev'} = $oldvrev if $cicount eq 'copy';
    $oldvrev = $rev->{'vrev'};
    $vrevdone = 1 if $cicount eq 'local';
    if (!$vrevdone) {
      my $v = $rev->{'vrev'} || 0;
      $v =~ s/^.*\D//;
      $rev->{'vrev'} = $lrev->{'vrev'} || 0;
      $rev->{'vrev'} =~ s/(\d+)$/$1+$v/e;
    }
    if (defined $l->{'vrev'}) {
      $oldvrev = $rev->{'vrev'};
      $vrevdone = 1;
    }

    push @linkinfo, {'project' => $projid, 'package' => $packid, 'srcmd5' => $lrev->{'srcmd5'}, 'rev' => $lrev->{'rev'}};
  }
  my $md5;
  my $oldl;
  for my $l (reverse @linkinfo) {
    if (!$md5) {
      $md5 = $l->{'srcmd5'};
      $oldl = $l;
      next;
    }
    my $md5c = "$md5  /LINK\n$l->{'srcmd5'}  /LOCAL\n";
    $md5 = Digest::MD5::md5_hex($md5c);
    if (!BSSrcrep::existstree_nocompat($l->{'project'}, $l->{'package'}, $md5)) {
      my $error = applylink($md5, $oldl, $l);
      if ($error) {
        $rev->{'srcmd5'} = $md5 if $l == $linkinfo[0];
	$error = "$l->{'project'}/$l->{'package'}: $error" if $l != $linkinfo[0];
        return $error;
      }
    }
    $l->{'srcmd5'} = $md5;
    $oldl = $l;
  }
  $rev->{'srcmd5'} = $md5;
  return BSRevision::lsrev($rev, $li);
}

sub rundiff {
  my ($file1, $file2, $label, $outfile) = @_;
  my $pid;
  if (!($pid = xfork())) {
    if (!open(STDOUT, '>>', $outfile)) {
      print STDERR "$outfile: $!\n";
      exit(2);
    }
    exec('diff', '-up', '--label', "$label.orig", '--label', $label, $file1, $file2);
    exit(2);
  }
  waitpid($pid, 0) == $pid || die("waitpid $pid: $!\n");
  my $status = $?;
  return 1 if $status == 0 || $status == 0x100;
  return undef;
}

sub findprojectpatchname {
  my ($files) = @_;

  my $i = "";
  while ($files->{"project$i.diff"}) {
    $i = '0' unless $i;
    $i++;
  }
  return "project$i.diff";
}

#
# we are going to commit files to projid/packid, all data is already present
# in the src repository.
# if it was a link before, try to keep this link
# files: expanded file set
# orev: old revision with the link to keep
#
sub keeplink {
  my ($cgi, $projid, $packid, $files, $orev) = @_;

  my $repair = $cgi->{'repairlink'};
  return $files if !defined($files) || !%$files;
  return $files if $files->{'_link'};
  $orev ||= $getrev->($projid, $packid, 'latest');
  my $ofilesl = BSRevision::lsrev($orev);
  return $files unless $ofilesl && $ofilesl->{'_link'};
  my $l = BSRevision::revreadxml($orev, '_link', $ofilesl->{'_link'}, $BSXML::link);
  my $changedlink = 0;
  my %lignore;
  my $isbranch;

  if (@{$l->{'patches'}->{''} || []} == 1) {
    my $type = (keys %{$l->{'patches'}->{''}->[0]})[0];
    if ($type eq 'branch') {
      $isbranch = 1;
    }
  }
  undef $isbranch if $cgi->{'convertbranchtopatch'};

  if (!$isbranch && $l->{'patches'}) {
    if ($repair) {
      for (@{$l->{'patches'}->{''} || []}) {
        my $type = (keys %$_)[0];
        if ($type eq 'apply' || $type eq 'delete' || $changedlink) {
          $lignore{$_->{$type}->{'name'}} = 1 if $type ne 'topadd' && $type ne 'delete';
	  $_ = undef;
	  $changedlink = 1;
	}
      }
    } else {
      for (reverse @{$l->{'patches'}->{''} || []}) {
        my $type = (keys %$_)[0];
        if ($type eq 'apply' || $type eq 'delete' || $type eq 'branch') {
          $lignore{$_->{$type}->{'name'}} = 1 if $type eq 'apply';
	  $_ = undef;
	  $changedlink = 1;
	  next;
	}
	last;
      }
    }
    $l->{'patches'}->{''} = [ grep {defined($_)} @{$l->{'patches'}->{''}} ];
  }

  my $linkrev = $cgi->{'linkrev'};
  $linkrev = $l->{'baserev'} if $linkrev && $linkrev eq 'base';

  my $ltgtsrcmd5;
  my $ofiles;
  my %ofilesfn;		# file names
  if (!$repair) {
    # expand old link
    my %olrev = %$orev;
    my %li;
    $olrev{'linkrev'} = $linkrev if $linkrev;
    $ofiles = handlelinks(\%olrev, $ofilesl, \%li);
    die("bad link: $ofiles\n") unless ref $ofiles;
    $ltgtsrcmd5 = $li{'srcmd5'};
    $ofilesfn{$_} = BSRevision::revfilename(\%olrev, $_, $ofiles->{$_}) for keys %$ofiles;
  }

  # get link target file list
  my $ltgtprojid = defined($l->{'project'}) ? $l->{'project'} : $projid;
  my $ltgtpackid = defined($l->{'package'}) ? $l->{'package'} : $packid;
  my $ltgtrev;
  my $ltgtfiles;
  if ($ltgtsrcmd5) {
    $ltgtrev = {'project' => $ltgtprojid, 'package' => $ltgtpackid, 'srcmd5' => $ltgtsrcmd5};
    $ltgtfiles = BSRevision::lsrev($ltgtrev);
  } else {
    $ltgtrev = $getrev->($ltgtprojid, $ltgtpackid, $linkrev || $l->{'rev'});
    $ltgtfiles = lsrev_expanded($ltgtrev);
    $ltgtsrcmd5 = $ltgtrev->{'srcmd5'};
  }

  if ($l->{'missingok'} && $ltgtfiles->{'srcmd5'} ne $BSSrcrep::emptysrcmd5) {
    # delete missingok flag as it's no longer needed
    eval {
      BSSrcServer::Access::checksourceaccess($ltgtprojid, $ltgtpackid);
      delete $l->{'missingok'};
    };
  }
  # easy for branches: just copy file list and update baserev
  if ($isbranch) {
    my $nfiles = { %$files };
    $nfiles->{'_link'} = $ofilesl->{'_link'};
    my $lchanged;
    my $baserev = $linkrev || $ltgtsrcmd5;
    if (($l->{'baserev'} || '') ne $baserev) {
      $l->{'baserev'} = $baserev;
      $lchanged = 1;
    }
    $cgi->{'setrev'} = $baserev if $cgi->{'setrev'} && $cgi->{'setrev'} eq 'base';
    if ($cgi->{'setrev'} && ($l->{'rev'} || '') ne $cgi->{'setrev'}) {
      $l->{'rev'} = $cgi->{'setrev'};
      $lchanged = 1;
    }
    if ($lchanged) {
      $l->{'patches'}->{''} = [ { 'branch' => undef} ]; # work around xml problem
      mkdir_p($uploaddir);
      writexml("$uploaddir/$$", undef, $l, $BSXML::link);
      $nfiles->{'_link'} = BSSrcrep::addfile($projid, $packid, "$uploaddir/$$", '_link')
    }
    return $nfiles;
  }

  my $applylinkcalled;
  if ($cgi->{'convertbranchtopatch'}) {
    $ofilesl = {};
    $ofiles = $ltgtfiles;
    $ofilesfn{$_} = BSRevision::revfilename($ltgtrev, $_, $ofiles->{$_}) for keys %$ofiles;
  } elsif ($repair || $changedlink) {
    # apply changed link
    my $frominfo = {'project' => $ltgtprojid, 'package' => $ltgtpackid, 'srcmd5' => $ltgtsrcmd5};
    my $linkinfo = {'project' => $projid, 'package' => $packid, 'srcmd5' => $orev->{'srcmd5'}, 'link' => $l};
    $linkinfo->{'ignore'} = \%lignore;
    $ofiles = applylink(undef, $frominfo, $linkinfo);
    die("bad link: $ofiles\n") unless ref $ofiles;
    $applylinkcalled = 1;
    $ofilesfn{$_} = "$uploaddir/applylink$$/$ofiles->{$_}-$_"  for keys %$ofiles;
  }

  # drop service generated files
  delete $ofiles->{$_} for grep {/^_service[_:]/} keys %$ofiles;

  #print "-- ofilesl:\n";
  #print "  $ofilesl->{$_}  $_\n" for sort keys %$ofilesl;
  #print "-- ofiles:\n";
  #print "  $ofiles->{$_}  $_ [$ofilesfn{$_}]\n" for sort keys %$ofiles;
  #print "-- files:\n";
  #print "  $files->{$_}  $_\n" for sort keys %$files;

  # now create diff between old $ofiles and $files
  my $nfiles = { %$ofilesl };
  delete $nfiles->{$_} for keys %lignore;	# no longer used in link
  mkdir_p($uploaddir);
  unlink("$uploaddir/$$");
  my @dfiles;
  for my $file (sort keys %{{%$files, %$ofiles}}) {
    if ($ofiles->{$file}) {
      if (!$files->{$file}) {
	if (!$ltgtfiles->{$file} && $ofilesl->{$file} && $ofilesl->{$file} eq ($ofiles->{$file} || '')) {
	  # local file no longer needed
	  delete $nfiles->{$file};
	  next;
	}
	push @dfiles, $file;
	delete $nfiles->{$file};
	next;
      }
      if ($ofiles->{$file} eq $files->{$file}) {
	next;
      }
      if (!isascii(BSRevision::revfilename($orev, $file, $files->{$file})) || !isascii($ofilesfn{$file})) {
	$nfiles->{$file} = $files->{$file};
	next;
      }
    } else {
      if (!isascii(BSRevision::revfilename($orev, $file, $files->{$file}))) {
	$nfiles->{$file} = $files->{$file};
	next;
      }
    }
    if (($ofilesl->{$file} || '') eq ($ofiles->{$file} || '')) {
      # link did not change file, just record new content
      if ($files->{$file} eq ($ltgtfiles->{$file} || '')) {
	# local overwrite already in link target
	delete $nfiles->{$file};
	next;
      }
      $nfiles->{$file} = $files->{$file};
      next;
    }
    # both are ascii, create diff
    mkdir_p($uploaddir);
    if (!rundiff($ofiles->{$file} ? $ofilesfn{$file} : '/dev/null', BSRevision::revfilename($orev, $file, $files->{$file}), $file, "$uploaddir/$$")) {
      $nfiles->{$file} = $files->{$file};
    }
  }
  my $lchanged;
  $lchanged = 1 if $changedlink;
  for (@dfiles) {
    push @{$l->{'patches'}->{''}}, {'delete' => {'name' => $_}};
    $lchanged = 1;
  }
  if (-s "$uploaddir/$$") {
    my $ppatch = findprojectpatchname($nfiles);
    $nfiles->{$ppatch} = BSSrcrep::addfile($projid, $packid, "$uploaddir/$$", $ppatch);
    push @{$l->{'patches'}->{''}}, {'apply' => {'name' => $ppatch}};
    $lchanged = 1;
  } else {
    unlink("$uploaddir/$$");
  }
  my $baserev = $linkrev || $ltgtsrcmd5;
  if (($l->{'baserev'} || '') ne $baserev) {
    $l->{'baserev'} = $baserev;
    $lchanged = 1;
  }
  $cgi->{'setrev'} = $baserev if $cgi->{'setrev'} && $cgi->{'setrev'} eq 'base';
  if ($cgi->{'setrev'} && ($l->{'rev'} || '') ne $cgi->{'setrev'}) {
    $l->{'rev'} = $cgi->{'setrev'};
    $lchanged = 1;
  }
  if ($lchanged) {
    writexml("$uploaddir/$$", undef, $l, $BSXML::link);
    $nfiles->{'_link'} = BSSrcrep::addfile($projid, $packid, "$uploaddir/$$", '_link')
  }
  if ($applylinkcalled) {
    BSUtil::cleandir("$uploaddir/applylink$$");
    rmdir("$uploaddir/applylink$$");
  }
  return $nfiles;
}

# integrate link from opackid to packid into packid
sub integratelink {
  my ($files, $projid, $packid, $rev, $ofiles, $oprojid, $opackid, $l, $orev) = @_;

  # append patches from link l to link nl
  my $nl = BSRevision::revreadxml($rev, '_link', $files->{'_link'}, $BSXML::link);

  # FIXME: remove hunks from patches that deal with replaced/deleted files
  my $nlchanged;
  my %dontcopy;
  $dontcopy{'_link'} = 1;
  my $nlisbranch;
  if ($nl->{'patches'}) {
    for (@{$nl->{'patches'}->{''} || []}) {
      my $type = (keys %$_)[0];
      if ($type eq 'add' || $type eq 'apply') {
	$dontcopy{$_->{$type}->{'name'}} = 1;
      }
      $nlisbranch = 1 if $type eq 'branch';
    }
  }
  my $lisbranch;
  if ($l->{'patches'}) {
    for (@{$l->{'patches'}->{''} || []}) {
      my $type = (keys %$_)[0];
      $lisbranch = 1 if $type eq 'branch';
    }
  }

  if ($nlisbranch) {
    # we linked/branched a branch. expand.
    #my %xrev = (%$rev, 'linkrev' => 'base');
    my %xrev = %$rev;
    my $linkinfo = {};
    lsrev_expanded(\%xrev, $linkinfo);
    my %oxrev = (%$orev, 'linkrev' => $xrev{'srcmd5'});
    $ofiles = lsrev_expanded(\%oxrev);
    BSSrcrep::copyfiles($projid, $packid, $oprojid, $opackid, $ofiles);
    # find new base
    if ($linkinfo->{'srcmd5'} ne $nl->{'baserev'}) {
      # update base rev
      $nl->{'baserev'} = $linkinfo->{'srcmd5'};
      $nlchanged = 1;
    }
    # delete everything but the link
    delete $files->{$_} for grep {$_ ne '_link'} keys %$files;
  }

  if ($lisbranch && !$nlisbranch) {
    # we branched a link. convert branch to link
    # and integrate
    delete $ofiles->{'_link'};
    $ofiles = keeplink({'convertbranchtopatch' => 1, 'linkrev' => 'base'}, $oprojid, $opackid, $ofiles, $orev);
    $l = BSRevision::revreadxml($orev, '_link', $ofiles->{'_link'}, $BSXML::link);
  }

  if (!$nlisbranch && $l->{'patches'}) {
    for (@{$l->{'patches'}->{''} || []}) {
      my $type = (keys %$_)[0];
      if ($type eq 'delete' && $files->{$_->{'delete'}->{'name'}} && !$dontcopy{$_->{'delete'}->{'name'}}) {
	delete $files->{$_->{'delete'}->{'name'}};
      } else {
	$nlchanged = 1;
	$nl->{'patches'} ||= {};
	if ($type eq 'apply') {
	  my $oppatch = $_->{'apply'}->{'name'};
	  if ($files->{$oppatch}) {
	    $dontcopy{$oppatch} = 1;
	    # argh, patch file already exists, rename...
	    my $ppatch = findprojectpatchname($files);
	    mkdir_p($uploaddir);
	    unlink("$uploaddir/$$");
	    BSSrcrep::copyonefile_tmp($oprojid, $opackid, $oppatch, $ofiles->{$oppatch}, "$uploaddir/$$");
	    $files->{$ppatch} = BSSrcrep::addfile($projid, $packid, "$uploaddir/$$", $ppatch);
	    push @{$nl->{'patches'}->{''}}, {'apply' => {'name' => $ppatch}};
	    next;
	  }
	}
	if ($type eq 'add') {
	  my $oppatch = $_->{'add'}->{'name'};
	  die("cannot apply patch $oppatch twice\n") if $dontcopy{$oppatch};
	}
        push @{$nl->{'patches'}->{''}}, $_;
      }
    }
  }
  if ($nlchanged) {
    mkdir_p($uploaddir);
    writexml("$uploaddir/$$", undef, $nl, $BSXML::link);
    $files->{'_link'} = BSSrcrep::addfile($projid, $packid, "$uploaddir/$$", '_link');
  }
  for (sort keys %$ofiles) {
    next if $dontcopy{$_};
    $files->{$_} = $ofiles->{$_};
  }
  return $files;
}

# add missing target information to linkinfo
sub linkinfo_addtarget {
  my ($rev, $linkinfo) = @_;
  my %lrev = %$rev;
  $lrev{'srcmd5'} = $linkinfo->{'lsrcmd5'} if $linkinfo->{'lsrcmd5'};
  my $files = BSRevision::lsrev(\%lrev);
  die("linkinfo_addtarget: not a link?\n") unless $files->{'_link'};
  my $l = BSRevision::revreadxml(\%lrev, '_link', $files->{'_link'}, $BSXML::link, 1);
  if ($l) {
    $linkinfo->{'project'} = defined($l->{'project'}) ? $l->{'project'} : $lrev{'project'};
    $linkinfo->{'package'} = defined($l->{'package'}) ? $l->{'package'} : $lrev{'package'};
    $linkinfo->{'missingok'} = "true" if $l->{'missingok'};
    $linkinfo->{'rev'} = $l->{'rev'} if $l->{'rev'};
    $linkinfo->{'baserev'} = $l->{'baserev'} if $l->{'baserev'};
  }
}

sub findlastworkinglink {
  my ($rev) = @_;

  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
  my @cand = BSSrcrep::knowntrees($projid, $packid);
  my %cand;
  for my $cand (@cand) {
    my $candrev = {'project' => $projid, 'package' => $packid, 'srcmd5' => $cand};
    my %li;
    my $files = BSRevision::lsrev($candrev, \%li);
    next unless $li{'lsrcmd5'} && $li{'lsrcmd5'} eq $rev->{'srcmd5'};
    $cand{$cand} = $li{'srcmd5'};
  }
  return undef unless %cand;
  @cand = sort keys %cand;
  return $cand[0] if @cand == 1;

  while (1) {
    my $lrev = {'project' => $projid, 'package' => $packid, 'srcmd5' => $rev->{'srcmd5'}};
    my $lfiles = BSRevision::lsrev($lrev);
    return undef unless $lfiles;
    my $l = BSRevision::revreadxml($lrev, '_link', $lfiles->{'_link'}, $BSXML::link, 1);
    return undef unless $l;
    $projid = $l->{'project'} if exists $l->{'project'};
    $packid = $l->{'package'} if exists $l->{'package'};
    my $lastcand;
    for my $cand (splice @cand) {
      next unless $cand{$cand};
      my %li;
      my $candrev = {'project' => $projid, 'package' => $packid, 'srcmd5' => $cand{$cand}};
      BSRevision::lsrev($candrev, \%li);
      $candrev->{'srcmd5'} = $li{'lsrcmd5'} if $li{'lsrcmd5'};
      $candrev = BSRevision::findlastrev($candrev);
      next unless $candrev;
      next if $lastcand && $lastcand->{'rev'} > $candrev->{'rev'};
      $cand{$cand} = $li{'srcmd5'} ? $li{'srcmd5'} : undef;
      if ($lastcand && $lastcand->{'rev'} == $candrev->{'rev'}) {
        push @cand, $cand;
        next;
      }
      @cand = ($cand);
      $lastcand = $candrev;
    }
    return undef unless @cand;
    return $cand[0] if @cand == 1;
    $rev = $lastcand;
  }
}

sub lsrev_expanded {
  my ($rev, $linkinfo) = @_;
  my $files = $lsrev_linktarget->($rev, $linkinfo);
  return $files unless $files->{'_link'};
  $files = handlelinks($rev, $files, $linkinfo);
  die("$files\n") unless ref $files;
  return $files;
}

1;

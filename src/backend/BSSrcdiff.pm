#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
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
################################################################
#
# create a diff between two source trees
#

package BSSrcdiff;

use Digest::MD5;
use Fcntl;

use strict;

sub listtar {
  my ($tar) = @_;
  local *F;
  open(F, '-|', 'tar', '--numeric-owner', '-tvf', $tar) || die("tar: $!\n");
  my @c;
  my $fc = 0;
  while(<F>) {
    next unless /^([-dlbcp])(.........)\s+\d+\/\d+\s+(\S+) \d\d\d\d-\d\d-\d\d \d\d:\d\d(?::\d\d)? (.*)$/;
    my $type = $1;
    my $mode = $2;
    my $size = $3;
    my $name = $4;
    my $info;
    if ($type eq 'l') {
      next unless $name =~ /^(.*) -> (.*)$/;
      $name = $1;
      $info = $2;
    } elsif ($type eq 'b' || $type eq 'c') {
      $info = $size;
      $size = 0;
    } elsif ($type eq 'd') {
      $name =~ s/\/$//;
    } elsif ($type eq '-') {
      if ($size == 0) {
        $info = 'd41d8cd98f00b204e9800998ecf8427e';
      } else {
        $fc++;
      }
    }
    push @c, {'type' => $type, 'name' => $name, 'size' => $size, 'mode' => $mode};
    $c[-1]->{'info'} = $info if defined $info;
  }
  close(F) || die("tar: $!\n");
  if ($fc) {
    open(F, '-|', 'tar', '-xOf', $tar) || die("tar: $!\n");
    for my $c (@c) {
      next unless $c->{'type'} eq '-' && $c->{'size'};
      my $ctx = Digest::MD5->new;
      my $s = $c->{'size'};
      while ($s > 0) {
        my $b;
        my $l = $s > 16384 ? 16384 : $s;
        $l = sysread(F, $b, $l);
        die("tar read error\n") unless $l;
        $ctx->add($b);
        $s -= $l;
      }
      $c->{'info'} = $ctx->hexdigest();
    }
    close(F) || die("tar: $!\n");
  }
  return @c;
}

sub extracttar {
  my ($tar, $cp) = @_;

  local *F;
  local *G;
  open(F, '-|', 'tar', '-xOf', $tar) || die("tar: $!\n");
  for my $c (@$cp) {
    next unless $c->{'type'} eq '-';
    if (exists $c->{'extract'}) {
      open(G, '>', $c->{'extract'}) || die("$c->{'extract'}: $!\n");
      my $s = $c->{'size'};
      while ($s > 0) {
        my $b;
        my $l = $s > 16384 ? 16384 : $s;
        $l = sysread(F, $b, $l);
        die("tar read error\n") unless $l;
        (syswrite(G, $b) || 0) == $l || die("syswrite: $!\n");
        $s -= $l;
      }
      close(G);
    } elsif ($c->{'size'}) {
      my $s = $c->{'size'};
      while ($s > 0) {
        my $b;
        my $l = $s > 16384 ? 16384 : $s;
        $l = sysread(F, $b, $l);
        die("tar read error\n") unless $l;
        $s -= $l;
      }
    }
  }
  close(F) || die("tar: $!\n");
}

sub filediff {
  my ($f1, $f2, $p1, $p2, $max, $arg, $lcntp, $noarchive) = @_;
  $arg ||= '-u';

  return unless defined($f1) || defined($f2);

  if ((!defined($f1) || ref($f1)) && (!defined($f2) || ref($f2))) {
    # no diff at all
    my $d = '';
    $d .= "--- $p1\n";
    $d .= "+++ $p2\n";
    if (defined($f1)) {
      $d .= "-$_\n" for @$f1;;
    }
    if (defined($f2)) {
      $d .= "+$_\n" for @$f2;;
    }
    $$lcntp += @{[split("\n", $d)]} if $lcntp;
    return $d;
  }
  if (!defined($f1) || !defined($f2) || ref($f1) || ref($f2)) {
    # no real diff
    my $f = defined($f1) && !ref($f1) ? $f1 : $f2;
    my $fx = defined($f1) && !ref($f1) ? '-' : '+';
    my $lcnt = 0;
    $lcnt = $$lcntp if $lcntp;
    return '' if $f =~ /\.(?:zip|tar|jar|zoo)(?:\.gz|\.bz2)?$/;
    local *F;
    if (!$noarchive) {
      if ($f =~ /\.gz$/i) {
        open(F, "-|", 'gunzip', '-dc', $f) || die("open $f: $!\n");
      } elsif ($f =~ /\.bz2$/i) {
        open(F, "-|", 'bzip2', '-dc', $f) || die("open $f: $!\n");
      }
    }
    open(F, '<', $f) || die("open $f: $!\n") if !defined(fileno(F));
    my $d = '';
    $d .= "--- $p1\n";
    $d .= "+++ $p2\n";
    $lcnt += 2;
    if (defined($f1) && ref($f1)) {
      $d .= "-$_\n" for @$f1;
      $lcnt += @$f1;
    }
    my $bintest;
    while(<F>) {
      ++$lcnt;
      if (!$bintest) {
        if (tr/\000-\037// > 3) {
          close F;
          return '';
        }
        $bintest = 1;
      }
      $d .= "$fx$_" if !defined($max) || $lcnt <= $max;
    }
    close(F);
    if (defined($max) && $lcnt > $max) {
      $d .= "(".($lcnt - $max)." more lines skipped)\n";
    }
    if (defined($f2) && ref($f2)) {
      $d .= "+$_\n" for @$f1;
      $lcnt += @$f1;
    }
    $$lcntp = $lcnt if $lcntp;
    return $d;
  }

  # the hard part: two real files
  local *D;
  my $pid = open(D, '-|');
  if (!$pid) {
    local *F1;
    local *F2;
    if (!$noarchive) {
      if ($f1 =~ /\.gz$/i) {
        open(F1, "-|", 'gunzip', '-dc', $f1) || die("open $f1: $!\n");
      } elsif ($f1 =~ /\.bz2$/i) {
        open(F1, "-|", 'bzip2', '-dc', $f1) || die("open $f1: $!\n");
      }
      if ($f2 =~ /\.gz$/i) {
        open(F2, "-|", 'gunzip', '-dc', $f2) || die("open $f2: $!\n");
      } elsif ($f2 =~ /\.bz2$/i) {
        open(F2, "-|", 'bzip2', '-dc', $f2) || die("open $f2: $!\n");
      } 
    }
    open(F1, '<', $f1) || die("open $f1: $!\n") if !defined(fileno(F1));
    open(F2, '<', $f2) || die("open $f2: $!\n") if !defined(fileno(F2));
    fcntl(F1, F_SETFD, 0);
    fcntl(F2, F_SETFD, 0);
    exec 'diff', $arg, '/dev/fd/'.fileno(F1), '/dev/fd/'.fileno(F2);
    die("diff: $!\n");
  }
  my $lcnt = 0;
  $lcnt = $$lcntp if $lcntp;
  my $d = '';
  while(<D>) {
    next if /^diff/;
    $lcnt++;
    if (!defined($max) || $lcnt <= $max) {
      s/^--- \/dev\/fd\/\d+.*/--- $p1/;
      s/^\+\+\+ \/dev\/fd\/\d+.*/+++ $p2/;
      s/^Files \/dev\/fd\/\d+ and \/dev\/fd\/\d+ differ.*/!!! $p1 and $p2 differ/;
      $d .= $_;
    }
  }
  close(D);
  if (defined($max) && $lcnt > $max) {
    $d .= "(".($lcnt - $max)." more lines skipped)\n";
  }
  $$lcntp = $lcnt if $lcntp;
  return $d;
}

sub fixup {
  my ($e) = @_;
  return (undef) unless defined $e;
  if ($e->{'type'} eq 'd') {
    return [ '(directory)' ];
  } elsif ($e->{'type'} eq 'b') {
    return [ "(block device $e->{info})" ];
  } elsif ($e->{'type'} eq 'c') {
    return [ "(character device $e->{info})" ];
  } elsif ($e->{'type'} eq 'l') {
    return [ "(symlink to $e->{info})" ];
  } elsif ($e->{'type'} eq '-') {
    return $e->{'size'} ? $e->{'extract'} : undef;
  } else {
    return [ "(unknown type $e->{type})" ];
  }
}

sub tardiff {
  my ($f1, $f2, $p1, $p2, $max, $edir) = @_;
  my @l1 = listtar($f1);
  my @l2 = listtar($f2);

  die unless $edir;
  for (@l1, @l2) {
    $_->{'sname'} = $_->{'name'};
    $_->{'sname'} =~ s/^\.\///;
    $_->{'sname'} = '' if "/$_->{'sname'}/" =~ /\/(?:CVS|\.cvsignore|\.svn|\.svnignore)\//;
  }
  if ((grep {$_->{'sname'} !~ /\//} @l1) == 1) {
    $_->{'sname'} =~ s/^[^\/]*\/?// for @l1;
  }
  if ((grep {$_->{'sname'} !~ /\//} @l2) == 1) {
    $_->{'sname'} =~ s/^[^\/]*\/?// for @l2;
  }

  my %l1 = map {$_->{'sname'} => $_} @l1;
  my %l2 = map {$_->{'sname'} => $_} @l2;
  my %l3 = (%l1, %l2);
  my @f = sort keys %l3;

  my %l1md5;
  for (@l1) {
    next unless $_->{'type'} eq '-' && $_->{'size'} && $_->{'sname'} ne '';
    $l1md5{$_->{'info'}} = $_;
  }
  my %ren;
  for my $l2 (@l2) {
    next unless $l2->{'type'} eq '-' && $l2->{'size'};
    my $f = $l2->{'sname'};
    next if $f eq '' || $l1{$f};
    my $l1 = $l1md5{$l2->{'info'}};
    next unless $l1 && !$l2{$l1->{'sname'}};
    $ren{$l1->{'sname'}} = $f;
    $ren{$f} = $l1->{'sname'};
    delete $l1md5{$l2->{'info'}};        # used up
  }

  my $e1cnt = 0;
  my $e2cnt = 0;

  for my $f (@f) {
    next if $f eq '';
    next if $ren{$f};
    if ($l1{$f} && $l2{$f}) {
      next if $l1{$f}->{'type'} ne $l2{$f}->{'type'};
      next if $l1{$f}->{'type'} ne '-';
      next if $l1{$f}->{'info'} eq $l2{$f}->{'info'};
      $l1{$f}->{'extract'} = "$edir/a$e1cnt";
      $e1cnt++;
      $l2{$f}->{'extract'} = "$edir/b$e2cnt";
      $e2cnt++;
    } elsif ($l1{$f} && $l1{$f}->{'size'}) {
      $l1{$f}->{'extract'} = "$edir/a$e1cnt";
      $e1cnt++;
    } elsif ($l2{$f} && $l2{$f}->{'size'}) {
      $l2{$f}->{'extract'} = "$edir/b$e2cnt";
      $e2cnt++;
    }
  }
  if ($e1cnt || $e2cnt) {
    if (! -d $edir) {
      mkdir($edir) || die("mkdir $edir: $!\n");
    }
    extracttar($f1, \@l1) if $e1cnt;
    extracttar($f2, \@l2) if $e2cnt;
  }
  my $lcnt = 0;
  my $d = '';
  for my $f (@f) {
    next if $f eq '';
    if ($ren{$f}) {
      $d .= "--- $f\n";
      $d .= "+++ $f\n";
      if ($l1{$f}) {
        $d .= "(renamed to $ren{$f})\n";
      } else {
        $d .= "(renamed from $ren{$f})\n";
      }
      $lcnt += 3;
      next;
    }
    if ($l1{$f} && $l2{$f}) {
      next if $l1{$f}->{'type'} eq $l2{$f}->{'type'} && (!defined($l1{$f}->{'info'}) || $l1{$f}->{'info'} eq $l2{$f}->{'info'});
      $d .= filediff(fixup($l1{$f}), fixup($l2{$f}), $f, $f, $max, undef, \$lcnt);
    } elsif ($l1{$f}) {
      $d .= filediff(fixup($l1{$f}), undef, $f, $f, $max, undef, \$lcnt);
    } elsif ($l2{$f}) {
      $d .= filediff(undef, fixup($l2{$f}), $f, $f, $max, undef, \$lcnt);
    }
  }
  if (defined($max) && $lcnt > $max) {
    $d = "$lcnt lines of diff (skipped)\n";
  }
  while ($e1cnt > 0) {
    $e1cnt--;
    unlink("$edir/a$e1cnt");
  }
  while ($e2cnt > 0) {
    $e2cnt--;
    unlink("$edir/b$e2cnt");
  }
  rmdir($edir);
  return $d;
}

my @simclasses = (
  'spec',
  'dsc',
  'changes',
  '(?:diff?|patch)(?:\.gz|\.bz2)?',
  '(?:tar|tar\.gz|tar\.bz2|tgz|tbz)',
);

sub findsim {
  my ($s, @f) = @_;

  my %s = map {$_ => 1} @$s;
  my %sim;

  my %fc;
  my %ft;

  for my $f (@f) {
    if ($s{$f}) {
      $sim{$f} = $f;
      delete $s{$f};
    }
  }

  for my $f (@f, @$s) {
    next if $sim{$f};        # trivial mapped
    next unless $f =~ /\./;
    next if exists $fc{$f};
    for my $sc (@simclasses) {
      my $fc = $f;
      if ($fc =~ s/\.$sc$//) {
        $fc{$f} = $fc;
        $ft{$f} = $sc;
        last;
      }
      $fc =~ s/\.bz2$//;
      $fc =~ s/\.gz$//;
      next if $fc =~ /\.(?:spec|dsc|changes)$/;        # no compression here!
      if ($fc =~ /^(.*)\.([^\/]+)$/) {
        $fc{$f} = $1;
        $ft{$f} = $2;
      }
    }
  }

  for my $f (grep {!exists($sim{$_})} @f) {
    my $fc = $fc{$f};
    my $ft = $ft{$f};
    next unless defined $fc;
    my @s = grep {$fc{$_} eq $fc && $ft{$_} eq $ft} sort keys %s;
    if (@s) {
      $sim{$f} = $s[0];
      delete $s{$s[0]};
    }
  }

  for my $f (grep {!exists($sim{$_})} @f) {
    my $fc = $fc{$f};
    my $ft = $ft{$f};
    next unless defined $fc;
    my @s = grep {$ft{$_} eq $ft} sort keys %s;
    my $fq = "\Q$fc\E";
    $fq =~ s/\\\././g;
    $fq =~ s/[0-9.]+/.*/g;
    @s = grep {/^$fq$/} @s;
    if (@s) {
      $sim{$f} = $s[0];
      delete $s{$s[0]};
    }
  }

  #for my $f (@f) {
  #  print "$f -> $sim{$f}\n";
  #}
  return \%sim;
}

sub srcdiff {
  my ($pold, $old, $pnew, $new, $fmax, $tmax, $edir) = @_;

  my $d = '';

  my @old = sort keys %$old;
  my @new = sort keys %$new;
  my $sim = findsim(\@old, @new);

  for my $extra ('changes', 'filelist', 'spec', 'dsc') {
    if ($extra eq 'filelist') {
      my @xold = sort keys %$old;
      my @xnew = sort keys %$new;
      my %xold = map {$_ => 1} @xold;
      my %xnew = map {$_ => 1} @xnew;
      @xnew = grep {!$xold{$_}} @xnew;
      @xold = grep {!$xnew{$_}} @xold;
      if (@xold) {
        $d .= "\n";
        $d .= "old:\n";
        $d .= "----\n";
        $d .= "  $_\n" for @xold;
      }
      if (@xnew) {
        $d .= "\n";
        $d .= "new:\n";
        $d .= "----\n";
        $d .= "  $_\n" for @xnew;
      }
      next;
    }
    my @xold = grep {/\.$extra$/} sort keys %$old;
    my @xnew = grep {/\.$extra$/} sort keys %$new;
    my %xold = map {$_ => 1} @xold;
    if (@xnew || @xold) {
      $d .= "\n";
      $d .= "$extra files:\n";
      $d .= "-------".('-' x length($extra))."\n";
    }
    for my $f (@xnew) {
      if ($xold{$f}) {
        my $of = $f;
        delete $xold{$of};
        next if $old->{$of} eq $new->{$f};
        my $arg = '-ub';
        $arg = '-U0' if $extra eq 'changes';
        $d .= filediff("$pold/$old->{$of}-$of", "$pnew/$new->{$f}-$f", $of, $f, undef, $arg);
      } else {
        $d .= "\n++++++ new $extra file:\n";
        $d .= filediff(undef, "$pnew/$new->{$f}-$f", $f, $f);
      }
    }
    if (%xold) {
      $d .= "\n++++++ deleted $extra files:\n";
      for my $f (sort keys %xold) {
        $d .= "--- $f\n";
      }
    }
    @old = grep {!/\.$extra$/} @old;
    @new = grep {!/\.$extra$/} @new;
  }

  my %oold = map {$_ => 1} @old;
  if (@new || @old) {
    $d .= "\n";
    $d .= "other changes:\n";
    $d .= "--------------\n";
  }
  for my $f (@new) {
    my $of = $sim->{$f};
    if (defined $of) {
      delete $oold{$of};
      $d .= "\n++++++ $of -> $f\n" if $of ne $f;
      next if $old->{$of} eq $new->{$f};
      $d .= "\n++++++ $f\n" if $of eq $f;
    }
    if ($f =~ /\.(?:tgz|tar\.gz|tar\.bz2|tbz)$/) {
      if (defined $of) {
        $d .= tardiff("$pold/$old->{$of}-$of", "$pnew/$new->{$f}-$f", $of, $f, $tmax, $edir);
        next;
      } else {
        $d .= "\n++++++ $f (new)\n";
        next;
      }
    }
    if (defined $of) {
      $d .= filediff("$pold/$old->{$of}-$of", "$pnew/$new->{$f}-$f", $of, $f, $fmax);
    } else {
      $d .= "\n++++++ $f (new)\n";
      $d .= filediff(undef, "$pnew/$new->{$f}-$f", $f, $f, $fmax);
    }
  }
  if (%oold) {
    $d .= "\n++++++ deleted files:\n";
    for my $f (sort keys %oold) {
      $d .= "--- $f\n";
    }
  }
  return $d;
}

sub ubeautify {
  my ($d, $f, $orev, $rev) = @_;
  $d =~ s/(--- \Q$f\E)$/$1 (revision \Q$orev\E)/m if defined $orev;
  $d =~ s/((?:\+\+\+|---) \Q$f\E)$/$1 (revision \Q$rev\E)/m if defined $rev;
  return $d;
}

sub udiff {
  my ($pold, $old, $orev, $pnew, $new, $rev, $fmax) = @_;
  my @changed;
  my @added;
  my @deleted;
  my $d = '';
  for (keys %$new) {
    if (defined($old->{$_})) {
      push @changed, $_ if $old->{$_} ne $new->{$_};
    } else {
      push @added, $_;
    } 
  }
  @deleted = grep { !defined($new->{$_}) } keys %$old;
  
  my $hdr = "Index: %s\n" . "=" x 67 . "\n";
  for my $f (@changed) {
    $d .= sprintf($hdr, $f);
    my $r .= filediff("$pold/$old->{$f}-$f", "$pnew/$new->{$f}-$f", $f, $f, $fmax, undef, undef, 1);
    $d .= ubeautify($r, $f, $orev, $rev);
  }
  for my $f (@added) {
    $d .= sprintf($hdr, $f);
    my $lcnt = -2;
    my $r = filediff(undef, "$pnew/$new->{$f}-$f", $f, $f, $fmax, undef, \$lcnt, 1);
    $r =~ s/(\Q+++ $f\E)$/$1\n@@ -0,0 +1,\Q$lcnt\E @@/m;
    $r = ubeautify($r, $f, 0, $rev);
    $d .= $r eq '' ? "Binary file $f added\n" : $r;
  }
  for my $f (@deleted) {
    $d .= sprintf($hdr, $f);
    my $lcnt = -2;
    my $r = filediff("$pold/$old->{$f}-$f", undef, $f, $f, $fmax, undef, \$lcnt, 1);
    $r =~ s/(\Q+++ $f\E)$/$1\n@@ -1,\Q$lcnt\E \+0,0 @@/m;
    $r = ubeautify($r, $f, $orev, $rev);
    $d .= $r eq '' ? "Binary file $f deleted\n" : $r if $lcnt;
  }
  return $d;
}

sub diff {
  my ($pold, $old, $orev, $pnew, $new, $rev, $fmax, $tmax, $edir, $unified) = @_;
  if ($unified) {
    return udiff($pold, $old, $orev, $pnew, $new, $rev, $fmax)
  } else {
    return srcdiff($pold, $old, $pnew, $new, $fmax, $tmax, $edir);
  }
}

1;

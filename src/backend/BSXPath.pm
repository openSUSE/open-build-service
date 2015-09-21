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
# Simple XPath query functions to search parsed XML data.
#

package BSXPath;

use Data::Dumper;

use strict;

sub boolop_eq {
  return $_[0] eq $_[1];
}
sub boolop_not {
  return !$_[0];
}

sub boolop {
  my ($cwd, $v1, $v2, $op, $negpol) = @_;
  #print Dumper($cwd).Dumper($v1).Dumper($v2);
  my @v1 = @$v1;
  my @v2 = @$v2;
  my @cwd = @$cwd;
  my @vr;
  while (@v1) {
    my $e1 = shift @v1;
    my $e2 = shift @v2;
    $e1 = '' if ref($e1) eq 'ARRAY' && !@$e1;
    $e2 = '' if ref($e2) eq 'ARRAY' && !@$e2;
    my $r = shift @cwd;
    if ($r->[4]) {
      push @vr, $r->[4]->boolop($e1, $e2, $op, $negpol);
      next;
    }
    if (ref($e1) ne '' && ref($e1) ne 'HASH' && ref($e1) ne 'ARRAY') {
      $e1 = $e1->value();
    }
    if (ref($e2) ne '' && ref($e2) ne 'HASH' && ref($e2) ne 'ARRAY') {
      $e2 = $e2->value();
    }
    if (ref($e1) eq 'HASH') {
      if (!exists($e1->{'_content'})) {
	push @vr, '';
	next;
      }
      $e1 = $e1->{'_content'};
    }
    if (ref($e2) eq 'HASH') {
      if (!exists($e2->{'_content'})) {
	push @vr, '';
	next;
      }
      $e2 = $e2->{'_content'};
    }
    if (!ref($e1) && !ref($e2)) {
      push @vr, $op->($e1, $e2) ? 'true' : '';
      next;
    }
    if (!ref($e1)) {
      push @vr, (grep {$op->($e1, $_)} @$e2) ? 'true' : '';
      next;
    }
    if (!ref($e2)) {
      push @vr, (grep {$op->($_, $e2)} @$e1) ? 'true' : '';
      next;
    }
    my $x = '';
    for my $e (@$e1) {
      next unless grep {$op->($e, $_)} @$e2;
      $x = 'true';
      last;
    }
    push @vr, $x;
  }
  # print "multop ret: ".Dumper(\@vr);
  return \@vr;
}

sub op {
  my ($cwd, $v1, $v2, $op) = @_;
  my @v1 = @$v1;
  my @v2 = @{$v2 || []};
  my @cwd = @$cwd;
  for my $vv (@v1) {
    my $vv2;
    $vv2 = shift @v2 if defined $v2;
    my $r = shift @cwd;
    if ($r->[4]) {
      $vv = $r->[4]->op($vv, $vv2, $op);
      next;
    }
    if (ref($vv) ne '' && ref($vv) ne 'HASH' && ref($vv) ne 'ARRAY') {
      $vv = $vv->value();
    }
    if (ref($vv) eq 'HASH') {
      $vv = $vv->{'_content'};
    } elsif (ref($vv) ne '') {
      $vv = '';
    }
    if ($vv2) {
      if (ref($vv2) ne '' && ref($vv2) ne 'HASH' && ref($vv2) ne 'ARRAY') {
        $vv2 = $vv2->value();
      }
      if (ref($vv2) eq 'HASH') {
        $vv2 = $vv2->{'_content'};
      } elsif (ref($vv2) ne '') {
        $vv2 = '';
      }
    }
    $vv = $op->($vv, $vv2);
  }
  return \@v1;
}

sub predicate {
  my ($cwd, $expr, $v) = @_;

  my @ncwd;
  my @r = @$cwd;
  for my $vv (@$v) {
    my $rr = shift @r;
    # flatten vv
    if (ref($vv) eq 'HASH' || ref($vv) eq '') {
      push @ncwd, [$rr->[0], $vv, 1, 1];
    } elsif (ref($vv) eq 'ARRAY') {
      my $i = 1;
      my $s = @$vv;
      push @ncwd, [$rr->[0], $_, $i++, $s] for @$vv;
    } else {
      push @ncwd, [$rr->[0], $vv, 1, 1, $vv];
      #my $vv2 = $vv->value();
      #my $i = 1;
      #my $s = @$vv2;
      #push @ncwd, [$rr->[0], $_, $i++, $s] for @$vv2;
    }
  }
  my ($v2, $nexpr) = expr(\@ncwd, $expr, 0);
  die("internal error!\n") if @$v2 != @ncwd;
  #print Dumper($v2);
  for my $vv (@$v) {
    if ($ncwd[0]->[4]) {
      my $r = shift @ncwd;
      $vv = $r->[4]->predicate(shift @$v2, $expr);
      next;
    }
    my @nvv;
    while (1) {
      my $r = shift @ncwd;
      my $b = shift @$v2;
      $b = @$b ? 'true' : '' if ref($b) eq 'ARRAY';
      if ($b =~ /^-?\d+$/) { 
        push @nvv, $r->[1] if $r->[2] == $b;
      } else {
        push @nvv, $r->[1] if $b;
      }
      last if $r->[2] == $r->[3];
    }
    $vv = \@nvv;
  }
  return ($v, $nexpr);
}

sub pathstep {
  my ($cwd, $v, $c) = @_;

  for my $vv (@$v) {
    if (ref($vv) eq 'HASH') {
      if ($c eq '*') {
        $vv = [ map {ref($vv->{$_}) eq 'ARRAY' ? @{$vv->{$_}} : $vv->{$_}} grep {$_ ne '_content'} sort keys %$vv ];
      } else {
	$vv = exists($vv->{$c}) ? $vv->{$c} : [];
      }
    } elsif (ref($vv) eq 'ARRAY') {
      if ($c eq '*') {
	my @nvv;
	for my $d (@$vv) {
          next unless ref($d) eq 'HASH';
          push @nvv, map {ref($d->{$_}) eq 'ARRAY' ? @{$d->{$_}} : $d->{$_}} grep {$_ ne '_content'} sort keys %$d;
        }
        $vv = \@nvv;
      } else {
        $vv = [ map {ref($_->{$c}) eq 'ARRAY' ? @{$_->{$c}} : $_->{$c}} grep {ref($_) eq 'HASH' && exists($_->{$c})} @$vv ];
      }
    } elsif (ref($vv) eq '') {
      $vv = [];
    } else {
      $vv = $vv->step($c);
    }
  }
  return $v;
}

sub limit {
  my ($cwd, $v) = @_;
  my @ncwd;
  my $changed;
  my @v = @$v;
  for my $r (@$cwd) {
    my $vv = $r->[1];
    my $lv = shift @v;
    if (ref($vv) ne '' && ref($vv) ne 'HASH' && ref($vv) ne 'ARRAY') {
      my $vv2 = $vv->limit($lv);
      if ($vv2 != $vv) {
        push @ncwd, [ @$r ];
        $ncwd[-1]->[1] = $vv2;
	$changed = 1;
	next;
      }
    }
    push @ncwd, $r;
  }
  return $changed ? \@ncwd : $cwd;
}

sub expr {
  my ($cwd, $expr, $lev, $negpol) = @_;

  $lev ||= 0;
  # calculate next value
  my ($v, $v2);
  $expr =~ s/^\s+//;
  my $t = substr($expr, 0, 1);
  if ($t eq '(') {
    ($v, $expr) = expr($cwd, substr($expr, 1), 0, $negpol);
    die("missing ) in expression\n") unless $expr =~ s/^\)//;
  } elsif ($t eq '-') {
    ($v, $expr) = expr($cwd, substr($expr, 1), 6, $negpol);
    $v = op($cwd, $v, undef, sub {-$_[0]});
  } elsif ($t eq "'") {
    die("missing string terminator\n") unless $expr =~ /^\'([^\']*)\'(.*)$/s;
    $v = $1;
    $expr = $2;
    while ($expr =~ /^(\'[^\']*)\'(.*)$/s) {
      $v .= $1;
      $expr = $2;
    }
    $v = [ ($v) x scalar(@$cwd) ];
  } elsif ($t eq '"') {
    die("missing string terminator\n") unless $expr =~ /^\"([^\"]*)\"(.*)$/s;
    $v = $1;
    $expr = $2;
    while ($expr =~ /^(\"[^\"]*)\"(.*)$/s) {
      $v .= $1;
      $expr = $2;
    }
    $v = [ ($v) x scalar(@$cwd) ];
  } elsif ($expr =~ /^([0-9]+(?:\.[0-9]*)?)(.*?)$/s) {
    $v = 0 + $1;
    $v = [ ($v) x scalar(@$cwd) ];
    $expr = $2;
  } elsif ($t eq '/' && $expr =~ /^\/(\/.*)$/s) {
    # unary //
    $expr = $1;
    die("unary // op not implemented yet\n");
  } elsif ($t eq '/') {
    # unary /
    $v = [ map {$_->[0]} @$cwd ];
  } elsif ($t eq '.') {
    if ($expr =~ /^\.\./) {
      die(".. op not implemented yet\n");
    } else {
      $v = [ map {$_->[1]} @$cwd ];
      $expr = substr($expr, 1);
    }
  } elsif ($expr =~ /^([-_a-zA-Z0-9]+)\s*\((.*?)$/s) {
    my $f = $1;
    $expr = $2;
    my @args;
    while ($expr !~ s/^\)//) {
      ($v, $expr) = expr($cwd, $expr, 0, $f eq 'not' ? !$negpol : $negpol);
      push @args, $v;
      last if $expr =~ s/^\)//;
      die("$f: bad argument separator\n") unless $expr =~ s/^,//;
    }
    if ($f eq 'not') {
      die("$f: one argument required\n") unless @args == 1;
      push @args, [ (1) x scalar(@$cwd) ];
      $v = boolop($cwd, @args, \&boolop_not, $negpol);
    } elsif ($f eq 'starts-with') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: one or two arguments required\n") unless @args == 2;
      $v = boolop($cwd, @args, sub {substr($_[0], 0, length($_[1])) eq $_[1]}, $negpol);
    } elsif ($f eq 'contains') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: at least two arguments required\n") unless @args >= 2;
      if (@args > 2) {
	my $arg1 = shift @args;
	for my $a (@args) {
	  die("multi arg contains only works with strings\n") if grep {ref($_) || $_ ne $a->[0]} @$a;
        }
	my $arg2 = $args[0];
	@args = map {$_->[0]} @args;
        $v = boolop($cwd, $arg1, $arg2, sub {!grep {index($_[0], $_) == -1} @args}, $negpol);
      } else {
        $v = boolop($cwd, @args, sub {index($_[0], $_[1]) != -1}, $negpol);
      }
    } elsif ($f eq 'compare') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: one or two arguments required\n") unless @args == 2;
      $v = boolop($cwd, @args, sub {$_[0] cmp $_[1]}, $negpol);
    } elsif ($f eq 'ends-with') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: one or two arguments required\n") unless @args == 2;
      $v = boolop($cwd, @args, sub {substr($_[0], -length($_[1])) eq $_[1]}, $negpol);
    } elsif ($f eq 'equals-ic') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: one or two arguments required\n") unless @args == 2;
      $v = boolop($cwd, @args, sub {lc($_[0]) eq lc($_[1])}, $negpol);
    } elsif ($f eq 'starts-with-ic') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: one or two arguments required\n") unless @args == 2;
      $v = boolop($cwd, @args, sub {substr(lc($_[0]), 0, length($_[1])) eq lc($_[1])}, $negpol);
    } elsif ($f eq 'ends-with-ic') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: one or two arguments required\n") unless @args == 2;
      $v = boolop($cwd, @args, sub {substr(lc($_[0]), -length($_[1])) eq lc($_[1])}, $negpol);
    } elsif ($f eq 'contains-ic') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: at least two arguments required\n") unless @args >= 2;
      if (@args > 2) {
	my $arg1 = shift @args;
	for my $a (@args) {
	  die("multi arg contains-ic only works with strings\n") if grep {ref($_) || $_ ne $a->[0]} @$a;
        }
	my $arg2 = $args[0];
	@args = map {lc($_->[0])} @args;
        $v = boolop($cwd, $arg1, $arg2, sub {!grep {index(lc($_[0]), $_) == -1} @args}, $negpol);
      } else {
        $v = boolop($cwd, @args, sub {index(lc($_[0]), lc($_[1])) != -1}, $negpol);
      }
    } elsif ($f eq 'position') {
      die("$f: no arguments required\n") unless @args == 0;
      $v = [ map {$_->[2]} @$cwd ];
    } elsif ($f eq 'last') {
      $v = [ map {$_->[3]} @$cwd ];
    } else {
      die("unknown function: $f\n");
    }
  } elsif ($expr =~ /^(\@?(?:[-_a-zA-Z0-9]+|\*))(.*?)$/s) {
    # path component
    my $c = $1;
    $expr = $2;
    $c =~ s/^\@//;
    $v = [ map {$_->[1]} @$cwd ];
    $v = pathstep($cwd, $v, $c);
  } else {
    die("syntax error: bad primary: $expr\n");
  }
  # got primary, now go for ops
  while (1) {
    $expr =~ s/^\s+//;
    if ($expr =~ /^or/) {
      return ($v, $expr) if $lev > 1;
      ($v2, $expr) = expr($cwd, substr($expr, 2), 1, $negpol);
      $v = boolop($cwd, $v, $v2, sub {$_[0] || $_[1]}, $negpol);
    } elsif ($expr =~ /^and/) {
      return ($v, $expr) if $lev > 2;
      my $cwd2 = limit($cwd, $v);
      ($v2, $expr) = expr($cwd2, substr($expr, 3), 2, $negpol);
      $v = boolop($cwd, $v, $v2, sub {$_[0] && $_[1]}, $negpol);
    } elsif ($expr =~ /^=/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 3, $negpol);
      $v = boolop($cwd, $v, $v2, \&boolop_eq, $negpol);
    } elsif ($expr =~ /^!=/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 2), 3, $negpol);
      $v = boolop($cwd, $v, $v2, sub {$_[0] ne $_[1]}, $negpol);
    } elsif ($expr =~ /^<=/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 2), 3, $negpol);
      $v = boolop($cwd, $v, $v2, sub {$_[0] <= $_[1]}, $negpol);
    } elsif ($expr =~ /^>=/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 2), 3, $negpol);
      $v = boolop($cwd, $v, $v2, sub {$_[0] >= $_[1]}, $negpol);
    } elsif ($expr =~ /^</) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 3, $negpol);
      $v = boolop($cwd, $v, $v2, sub {$_[0] < $_[1]}, $negpol);
    } elsif ($expr =~ /^>/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 3, $negpol);
      $v = boolop($cwd, $v, $v2, sub {$_[0] > $_[1]}, $negpol);
    } elsif ($expr =~ /^\+/) {
      return ($v, $expr) if $lev > 4;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 4, $negpol);
      $v = op($cwd, $v, $v2, sub {$_[0] + $_[1]});
    } elsif ($expr =~ /^-/) {
      return ($v, $expr) if $lev > 4;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 4, $negpol);
      $v = op($cwd, $v, $v2, sub {$_[0] - $_[1]});
    } elsif ($expr =~ /^\*/) {
      return ($v, $expr) if $lev > 5;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 5, $negpol);
      $v = op($cwd, $v, $v2, sub {$_[0] * $_[1]});
    } elsif ($expr =~ /^div/) {
      return ($v, $expr) if $lev > 5;
      ($v2, $expr) = expr($cwd, substr($expr, 3), 5, $negpol);
      $v = op($cwd, $v, $v2, sub {$_[0] / $_[1]});
    } elsif ($expr =~ /^mod/) {
      return ($v, $expr) if $lev > 5;
      ($v2, $expr) = expr($cwd, substr($expr, 3), 5, $negpol);
      $v = op($cwd, $v, $v2, sub {$_[0] % $_[1]});
    } elsif ($expr =~ /^\|/) {
      die("union op not implemented yet\n");
    } elsif ($expr =~ /^\/(\@?(?:[-_a-zA-Z0-9]+|\*))(.*?)$/s) {
      my $c = $1;
      $expr = $2;
      $c =~ s/^\@//;
      $v = pathstep($cwd, $v, $c);
      #print "following $c\n".Dumper($v);
    } elsif ($expr =~ /^\/\//s) {
      $expr = substr($expr, 1);
      die("// op not implemented yet\n");
    } elsif ($expr =~ /^\[/) {
      ($v, $expr) = predicate($cwd, substr($expr, 1), $v);
      die("missing ] in predicate\n") if $expr eq '';
      die("syntax error in predicate\n") unless $expr =~ s/^\]//;
    } else {
      return ($v, $expr);
    }
  }
}

sub select {
  my ($data, $expr) = @_;

  my $v;
  ($v, $expr) = BSXPath::expr([[$data, $data, 1, 1]], $expr);
  die("junk at and of expr: $expr\n") if $expr ne '';
  $v = $v->[0];
  if (ref($v) ne '' && ref($v) ne 'HASH' && ref($v) ne 'ARRAY') {
    $v = $v->value();
  }
  return $v;
}

sub match {
  my ($data, $expr) = @_;

  my $v;
  ($v, $expr) = predicate([[$data, $data, 1, 1]], $expr, [$data]);
  die("junk at and of expr: $expr\n") if $expr ne '';
  $v = $v->[0];
  if (ref($v) ne '' && ref($v) ne 'HASH' && ref($v) ne 'ARRAY') {
    $v = $v->value();
  }
  return $v;
}

sub valuematch {
  my ($data, $expr) = @_;

  my $v;
  ($v, $expr) = BSXPath::expr([[$data, $data, 1, 1]], $expr);
  die("junk at and of expr: $expr\n") if $expr ne '';
  my @v = @$v;
  my @r;
  while (@v) {
    $v = shift @v;
    if (ref($v) ne '' && ref($v) ne 'HASH' && ref($v) ne 'ARRAY') {
      $v = $v->value();
    }
    if (ref($v) eq '') {
      push @r, $v;
    } elsif (ref($v) eq 'HASH') {
      push @r, $v->{'_content'} if exists $v->{'_content'};
    } elsif (ref($v) eq 'ARRAY') {
      unshift @v, @$v;
    } else {
      die("illegal return type\n");
    }
  }
  return \@r;
}

1;

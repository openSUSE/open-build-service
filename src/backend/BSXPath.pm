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

sub boolop {
  my ($v1, $v2, $op) = @_;
  #print Dumper($v1).Dumper($v2);
  my @v2 = @$v2;
  my @vr;
  for my $e1 (@$v1) {
    my $e2 = shift @v2;
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

sub predicate {
  my ($cwd, $expr, $v) = @_;

  my @ncwd;
  my @r = @$cwd;
  for my $vv (@$v) {
    my $rr = shift @r;
    if (ref($vv) eq 'HASH' || ref($vv) eq '') {
      push @ncwd, [$rr->[0], $vv, 1, 1];
    } elsif (ref($vv) eq 'ARRAY') {
      my $i = 1;
      my $s = @$vv;
      push @ncwd, [$rr->[0], $_, $i++, $s] for @$vv;
    } else {
      die("illegal type for predicate\n");
    }
  }
  my $v2;
  ($v2, $expr) = expr(\@ncwd, $expr, 0);
  die("internal error!\n") if @$v2 != @ncwd;
  #print Dumper($v2);
  # boolify v2
  $_ = ref($_) eq 'ARRAY' ? (@$_ ? 'true' : '') : $_ for @$v2;
  for my $vv (@$v) {
    if (ref($vv) eq 'HASH' || ref($vv) eq '') {
      $vv = [] unless shift @$v2;
    } elsif (ref($vv) eq 'ARRAY') {
      my @nvv;
      my $i = 0;
      for (@$vv) {
	$i++;
	my $b = shift @$v2;
	#print "bool $b ($i)\n";
	if ($b =~ /^\d+$/) {
	  push @nvv, $_ if $b == $i;
        } else {
	  push @nvv, $_ if $b;
 	}
      }
      $vv = \@nvv;
    }
  }
  return ($v, $expr);
}

sub pathstep {
  my ($v, $c) = @_;

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
    } else {
      $vv = [];
    }
  }
}

sub expr {
  my ($cwd, $expr, $lev) = @_;

  $lev ||= 0;
  # calculate next value
  my ($v, $v2);
  $expr =~ s/^\s+//;
  my $t = substr($expr, 0, 1);
  if ($t eq '(') {
    ($v, $expr) = expr($cwd, substr($expr, 1), 0);
    die("missing ) in expression\n") unless $expr =~ s/^\)//;
  } elsif ($t eq '-') {
    ($v, $expr) = expr($cwd, substr($expr, 1), 0);
    die("illegal type for unary -\n") if grep {ref($_)} @$v;
    $v = [ map {-$_} @$v ];
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
  } elsif ($expr =~ /^([-a-zA-Z0-9]+)\s*\((.*?)$/s) {
    my $f = $1;
    $expr = $2;
    my @args;
    while ($expr !~ s/^\)//) {
      ($v, $expr) = expr($cwd, $expr, 0);
      push @args, $v;
      last if $expr =~ s/^\)//;
      die("$f: bad argument separator\n") unless $expr =~ s/^,//;
    }
    if ($f eq 'not') {
      die("$f: one argument required\n") unless @args == 1;
      push @args, [ (1) x scalar(@$cwd) ];
      $v = boolop(@args, sub {!$_[0]});
    } elsif ($f eq 'starts-with') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: one or two arguments required\n") unless @args == 2;
      $v = boolop(@args, sub {substr($_[0], 0, length($_[1])) eq $_[1]});
    } elsif ($f eq 'contains') {
      unshift @args, [ map {$_->[1]} @$cwd ] if @args == 1;
      die("$f: one or two arguments required\n") unless @args == 2;
      $v = boolop(@args, sub {index($_[0], $_[1]) != -1});
    } elsif ($f eq 'ends-with') {
      die("$f: one or two arguments required\n") unless @args == 2;
      $v = boolop(@args, sub {substr($_[0], -length($_[1])) eq $_[1]});
    } elsif ($f eq 'position') {
      die("$f: no arguments required\n") unless @args == 0;
      $v = [ map {$_->[2]} @$cwd ];
    } elsif ($f eq 'last') {
      $v = [ map {$_->[3]} @$cwd ];
    } else {
      die("unknown funktion: $f\n");
    }
  } elsif ($expr =~ /^(\@?(?:[-a-zA-Z0-9]+|\*))(.*?)$/s) {
    # path component
    my $c = $1;
    $expr = $2;
    $c =~ s/^\@//;
    $v = [ map {$_->[1]} @$cwd ];
    pathstep($v, $c);
  } else {
    die("syntax error: bad primary: $expr\n");
  }
  # got primary, now go for ops
  while (1) {
    $expr =~ s/^\s+//;
    if ($expr =~ /^or/) {
      return ($v, $expr) if $lev > 1;
      ($v2, $expr) = expr($cwd, substr($expr, 2), 1);
      $v = boolop($v, $v2, sub {$_[0] || $_[1]});
    } elsif ($expr =~ /^and/) {
      return ($v, $expr) if $lev > 2;
      ($v2, $expr) = expr($cwd, substr($expr, 3), 2);
      $v = boolop($v, $v2, sub {$_[0] && $_[1]});
    } elsif ($expr =~ /^=/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 3);
      $v = boolop($v, $v2, sub {$_[0] eq $_[1]});
    } elsif ($expr =~ /^!=/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 2), 3);
      $v = boolop($v, $v2, sub {$_[0] ne $_[1]});
    } elsif ($expr =~ /^<=/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 2), 3);
      $v = boolop($v, $v2, sub {$_[0] <= $_[1]});
    } elsif ($expr =~ /^>=/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 2), 3);
      $v = boolop($v, $v2, sub {$_[0] >= $_[1]});
    } elsif ($expr =~ /^</) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 3);
      $v = boolop($v, $v2, sub {$_[0] < $_[1]});
    } elsif ($expr =~ /^>/) {
      return ($v, $expr) if $lev > 3;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 3);
      $v = boolop($v, $v2, sub {$_[0] > $_[1]});
    } elsif ($expr =~ /^\+/) {
      return ($v, $expr) if $lev > 4;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 4);
      $_ = $_ + shift(@$v2) for @$v;
    } elsif ($expr =~ /^-/) {
      return ($v, $expr) if $lev > 4;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 4);
      $_ = $_ - shift(@$v2) for @$v;
    } elsif ($expr =~ /^\*/) {
      return ($v, $expr) if $lev > 5;
      ($v2, $expr) = expr($cwd, substr($expr, 1), 5);
      $_ = $_ * shift(@$v2) for @$v;
    } elsif ($expr =~ /^div/) {
      return ($v, $expr) if $lev > 5;
      ($v2, $expr) = expr($cwd, substr($expr, 3), 5);
      $_ = $_ / shift(@$v2) for @$v;
    } elsif ($expr =~ /^mod/) {
      return ($v, $expr) if $lev > 5;
      ($v2, $expr) = expr($cwd, substr($expr, 3), 5);
      $_ = $_ % shift(@$v2) for @$v;
    } elsif ($expr =~ /^\|/) {
      die("union op not implemented yet\n");
    } elsif ($expr =~ /^\/(\@?(?:[-a-zA-Z0-9]+|\*))(.*?)$/s) {
      my $c = $1;
      $expr = $2;
      $c =~ s/^\@//;
      pathstep($v, $c);
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

sub match {
  my ($data, $expr) = @_;

  my $v;
  ($v, $expr) = predicate([[$data, $data, 1, 1]], $expr, [$data]);
  die("junk at and of expr: $expr\n") if $expr ne '';
  return $v->[0];
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

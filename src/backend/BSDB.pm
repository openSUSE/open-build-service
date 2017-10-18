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
# Simple database for storing hierarchical data, uses BSDBIndex for
# storing data and indices.
# Also supports search via BSXPath/BSXPathKeys.

package BSDB;

use BSDBIndex;

sub opendb {
  my ($dbpath, $table) = @_;
  my $db = BSDBIndex::opendb($dbpath);
  if ($table eq '') {
    $db->{'table'} = 'data';
    $db->{'index'} = '';
  } else {
    $db->{'table'} = $table;
    $db->{'index'} = "$table/";
  }
  return bless $db;
}

sub fetch {
  my ($db, $key) = @_;
  if ($db->{'fetch'}) {
    return $db->{'fetch'}->($db, $key);
  }
  my @v = BSDBIndex::getvalues($db, $db->{'table'}, $key);
  return $v[0];
}

sub torel {
  my ($path, $key, $v, $rel) = @_;
  return unless defined $v;
  if (ref($v) eq '') {
    push @$rel, [$path, $v, $key, "$path\0$v"] if $v ne '';
    return;
  }
  if (ref($v) eq 'ARRAY') {
    for my $vv (@$v) {
      if (ref($vv) eq '') {
        push @$rel, [$path, $vv, $key, "$path\0$vv"] if $vv ne '';
      } else {
        torel($path, $key, $vv, $rel);
      }
    }
    return;
  }
  if (ref($v) eq 'HASH') {
    $path .= '/' if $path ne '';
    for my $vv (sort keys %$v) {
      if (ref($v->{$vv}) eq '') {
        push @$rel, ["$path$vv", $v->{$vv}, $key, "$path$vv\0$v->{$vv}"] if $v->{$vv} ne '';
      } else {
        torel("$path$vv", $key, $v->{$vv}, $rel);
      }
    }
  }
}

sub updateindex_rel {
  my ($db, $oldrel, $newrel) = @_;

  return unless @$oldrel || @$newrel;
  if (@$oldrel + @$newrel > 256) {
    while (@$oldrel) {
      my @chunk = splice(@$oldrel, 0, 256);
      BSDBIndex::modify($db, \@chunk);
    }
    while (@$newrel) {
      my @chunk = splice(@$newrel, 0, 256);
      BSDBIndex::modify($db, undef, \@chunk);
    }
  } else {
    BSDBIndex::modify($db, $oldrel, $newrel);
  }
}

sub updateindex {
  my ($db, $key, $old, $new) = @_;

  my $index = $db->{'index'};
  $index =~ s/\/$//;
  my @oldrel;
  my @newrel;
  torel($index, $key, $old, \@oldrel);
  torel($index, $key, $new, \@newrel);
  if ($db->{'noindex'}) {
    @newrel = grep {!$db->{'noindex'}->{$_->[0]}} @newrel;
  }
  # delete all entries that are both in oldrel and newrel
  my %in = map {$_->[3] => 1} @oldrel;
  %in = map {$_->[3] => 1} grep {$in{$_->[3]}} @newrel;
  @oldrel = grep {!$in{$_->[3]}} @oldrel;
  @newrel = grep {!$in{$_->[3]}} @newrel;
  return unless @oldrel || @newrel;
  updateindex_rel($db, \@oldrel, \@newrel);
}

sub store_callback {
  my ($db, $rel, $data) = @_;
  my $old = ($data || [])[0];
  my $new = $rel->[3];
  my $key = $rel->[1];
  updateindex($db, $key, $old, $new) unless $db->{'noindexatall'};
  if (defined($new)) {
    @$data = ($new);
  } else {
    @$data = ();
  }
  return 1;
}

sub store {
  my ($db, $key, $v) = @_;
  my $rel = [$db->{'table'}, $key, \&store_callback, $v];
  if ($db->{'store'}) {
    $db->{'store'}->($db, $key, $v, sub {store_callback($db, $rel, [$_[0]])});
  } else {
    BSDBIndex::modify($db, [$rel]);
  }
}

#
# Search functions
#

sub selectpath {
  my ($v, $path) = @_; 
  $v = [ $v ] unless ref($v) eq 'ARRAY';
  my @v = @$v;
  my $c; 
  while(1) {
    last if !defined($path) || $path eq ''; 
    ($c, $path) = split('/', $path, 2); 
    for my $vv (splice(@v)) {
      next unless ref($vv) eq 'HASH';
      $vv = $vv->{$c};
      next unless defined($vv);
      push @v, ref($vv) eq 'ARRAY' ? @$vv : $vv;
    }   
  }
  return @v; 
}

sub values {
  my ($db, $path, $lkeys) = @_;
  if ($db->{'indexfunc'} && $db->{'indexfunc'}->{$path}) {
    return $db->{'indexfunc'}->{$path}->($db, $path, undef, $lkeys);
  }
  if (($db->{'noindex'} && $db->{'noindex'}->{$path}) || $db->{'noindexatall'} || ($lkeys && $db->{'cheapfetch'})) {
    $lkeys = [ $db->keys() ] unless $lkeys;
    my @v;
    for my $k (@$lkeys) {
      push @v, selectpath($db->fetch($k), $path);
    }
    my %v = map {$_ => 1} @v;
    return sort keys %v;
  }
  return BSDBIndex::getkeys($db, "$db->{'index'}$path");
}

sub keys {
  my ($db, $path, $value, $lkeys) = @_;
  if (!defined($path)) {
    return @$lkeys if $lkeys;
    $path = $db->{'allkeyspath'};
    return BSDBIndex::getkeys($db, $db->{'table'}) unless defined $path;
    if ($db->{'indexfunc'} && $db->{'indexfunc'}->{$path}) {
      return $db->{'indexfunc'}->{$path}->($db);
    }
    return map {BSDBIndex::getvalues($db, "$db->{'index'}$path", $_)} BSDBIndex::getkeys($db, "$db->{'index'}$path");
  }
  if ($db->{'indexfunc'} && $db->{'indexfunc'}->{$path}) {
    return $db->{'indexfunc'}->{$path}->($db, $path, $value, $lkeys);
  }
  if (($db->{'noindex'} && $db->{'noindex'}->{$path}) || $db->{'noindexatall'}) {
    $lkeys = [ $db->keys() ] unless $lkeys;
    my @v;
    my @k;
    for my $k (@$lkeys) {
      push @k, $k if grep {$_ eq $value} selectpath($db->fetch($k), $path);
    }
    return @k;
  }
  return BSDBIndex::getvalues($db, "$db->{'index'}$path", $value);
}

1;

# Copyright (c) 2020 SUSE LLC
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
package BSSQLite;

use strict;

use DBI qw(:sql_types);
use DBD::SQLite;

sub dobinds {
  my ($sh, $start, @binds) = @_;
  $sh->bind_param($start++, @$_) for @binds;
}

sub dbdo {
  my ($h, $statement) = @_;
  $statement =~ s/^\s*//s;
  $h->do($statement) || die($h->errstr);
}

sub dbdo_bind {
  my ($h, $statement, @binds) = @_;
  $statement =~ s/^\s*//s;
  my $sh = $h->prepare($statement) || die($h->errstr);
  dobinds($sh, 1, @binds);
  $sh->execute() || die($sh->errstr);
  return $sh;
}

sub connectdb {
  my ($dbname) = @_;
  die("no dbname defined\n") unless $dbname;
  my $h = DBI->connect("dbi:SQLite:dbname=$dbname");
  $h->{AutoCommit} = 1;
  return $h;
}

sub list_tables {
  my ($h) = @_;
  my $sh = $h->table_info(undef, undef, undef, 'TABLE');
  return map {$_->[2]} @{$sh->fetchall_arrayref()};
}

sub foreignkeys {
  my ($h, $on) = @_;
  dbdo($h, 'PRAGMA foreign_keys = '.($on ? 'ON' : 'OFF'));
}

sub synchronous {
  my ($h, $on) = @_;
  dbdo($h, 'PRAGMA synchronous = '.($on ? 'ON' : 'OFF'));
}

sub begin_work {
  my ($h) = @_;
  $h->begin_work() || die($h->errstr);
}

sub commit {
  my ($h) = @_;
  $h->commit() || die($h->errstr);
}

sub selectrow {
  my ($h, $statement, @simplebinds) = @_;
  return $h->selectrow_array($statement, undef, @simplebinds);
}

sub selectcol {
  my ($h, $statement, @simplebinds) = @_;
  my $ary = $h->selectcol_arrayref($statement, undef, @simplebinds) || die($h->errstr);
  return @$ary;
}

1;

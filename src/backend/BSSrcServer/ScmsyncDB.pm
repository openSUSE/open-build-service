#
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
################################################################
#
# scmsync database handling
#

package BSSrcServer::ScmsyncDB;

use strict;

use BSConfiguration;
use BSUtil;
use BSDB;

require BSSrcServer::SQLite if $BSConfig::source_db_sqlite;

my $sourcedb = "$BSConfig::bsdir/db/source";

sub normalize_url {
  my ($url) = @_;

  require URI;
  my $uri = URI->new($url);

  my $scmsync_repo   = $uri->scheme.'://'.$uri->host.$uri->path;
  $scmsync_repo   =~ s/\.git$//;
  my $scmsync_branch = $uri->fragment;

  return ($scmsync_repo, $scmsync_branch);
}

sub storescmsync {
  my ($projid, $packid, $scmsync_url) = @_;
  return unless $BSConfig::source_db_sqlite;

  my ($scmsync_repo, $scmsync_branch) = normalize_url($scmsync_url);
  my $db = BSSrcServer::SQLite::opendb($sourcedb, 'scmsync');
  my $h = $db->{'sqlite'} || BSSrcServer::SQLite::connectdb($db);

  BSSQLite::begin_work($h);
  BSSQLite::dbdo_bind($h, 'INSERT INTO scmsync(project,package,scmsync_repo,scmsync_branch) VALUES(?,?,?,?)
                           ON CONFLICT(project,package) DO UPDATE SET
                            scmsync_repo=excluded.scmsync_repo,scmsync_branch=excluded.scmsync_branch
                            WHERE excluded.project=scmsync.project AND excluded.package=scmsync.package', [$projid], [$packid], [$scmsync_repo], [$scmsync_branch]);
  BSSQLite::commit($h);
}

sub deletescmsync {
  my ($projid, $packid) = @_;
  return unless $BSConfig::source_db_sqlite;

  my $db = BSSrcServer::SQLite::opendb($sourcedb, 'scmsync');
  my $h = $db->{'sqlite'} || BSSrcServer::SQLite::connectdb($db);

  BSSQLite::begin_work($h);
  if ($packid eq '_project') {
    BSSQLite::dbdo_bind($h, 'DELETE FROM scmsync WHERE project = ?', [$projid]);
  } else {
    BSSQLite::dbdo_bind($h, 'DELETE FROM scmsync WHERE project = ? AND package = ?', [$projid], [$packid]);
  }
  BSSQLite::commit($h);
}

sub getscmsyncpackages {
  my ($scmsync_repo, $scmsync_branch) = @_;
  return [] unless $BSConfig::source_db_sqlite;

  my $db = BSSrcServer::SQLite::opendb($sourcedb, 'scmsync');
  my $h = $db->{'sqlite'} || BSSrcServer::SQLite::connectdb($db);

  $scmsync_repo   =~ s/\.git$//;
  $scmsync_repo   = lc($scmsync_repo);

  my $sh;
  if ($scmsync_branch) {
    $sh = BSSQLite::dbdo_bind($h, 'SELECT project, package FROM scmsync WHERE LOWER(scmsync_repo) = ? AND scmsync_branch = ?', [$scmsync_repo], [$scmsync_branch]);
  } elsif ($scmsync_branch eq '') {
    # default branch only
    $sh = BSSQLite::dbdo_bind($h, 'SELECT project, package FROM scmsync WHERE LOWER(scmsync_repo) = ? AND scmsync_branch IS NULL', [$scmsync_repo]);
  } else {
    # all branches
    $sh = BSSQLite::dbdo_bind($h, 'SELECT project, package FROM scmsync WHERE LOWER(scmsync_repo) = ?', [$scmsync_repo]);
  };
  my ($project, $package);
  $sh->bind_columns(\$project, \$package);
  my @ary;
  push @ary, [$project, $package] while $sh->fetch();
  return @ary;
}


sub movescmsync {
  my ($projid, $oprojid) = @_;
  return unless $BSConfig::source_db_sqlite;

  my $db = BSSrcServer::SQLite::opendb($sourcedb, 'scmsync');
  my $h = $db->{'sqlite'} || BSSrcServer::SQLite::connectdb($db);

  BSSQLite::begin_work($h);
  BSSQLite::dbdo_bind($h, 'UPDATE scmsync SET project = ? WHERE project = ?', [$projid], [$oprojid]);
  BSSQLite::commit($h);
}

1;

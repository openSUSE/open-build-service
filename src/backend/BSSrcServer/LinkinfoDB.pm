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
# linkinfo database handling
#

package BSSrcServer::LinkinfoDB;

use strict;

use BSConfiguration;
use BSUtil;
use BSDB;

require BSSrcServer::SQLite if $BSConfig::source_db_sqlite;

my $sourcedb = "$BSConfig::bsdir/db/source";

sub openlinkinfodb {
  if ($BSConfig::source_db_sqlite) {
    return BSSrcServer::SQLite::opendb($sourcedb, 'linkinfo');
  } else {
    my $db = BSDB::opendb($sourcedb, 'linkinfo');
    $db->{'blocked'} = [ 'linkinfo' ];
    return $db;
  }
}

sub storelinkinfo {
  my ($projid, $packid, $linkinfo) = @_;
  if ($BSConfig::source_db_sqlite) {
    my $db = BSSrcServer::SQLite::opendb($sourcedb, 'linkinfo');
    $db->store_linkinfo($projid, $packid, $linkinfo);
  } else {
    mkdir_p($sourcedb) unless -d $sourcedb;
    my $db = BSDB::opendb($sourcedb, 'linkinfo');
    $db->{'blocked'} = [ 'linkinfo' ];
    $db->store("$projid/$packid", $linkinfo);
  }
}

sub getlinkpackages {
  my ($projid) = @_;
  if ($BSConfig::source_db_sqlite) {
    my $db = BSSrcServer::SQLite::opendb($sourcedb, 'linkinfo');
    return $db->getlinkpackages($projid);
  } else {
    return() unless -d $sourcedb;
    my $db = BSDB::opendb($sourcedb, 'linkinfo');
    return map {grep {s/\Q$projid\E\///} $db->keys('project', $_)} $db->values('project');
  }
}

sub getlinkers {
  my ($projid, $packid) = @_;
  if ($BSConfig::source_db_sqlite) {
    my $db = BSSrcServer::SQLite::opendb($sourcedb, 'linkinfo');
    return $db->getlinkers($projid, $packid);
  } else {
    my $db = BSDB::opendb($sourcedb, 'linkinfo');
    my @l = $db->rawkeys('package', $packid);
    return () unless @l;
    my %ll = map {$_ => 1} $db->rawkeys('project', $projid);
    return grep {$ll{$_}} @l;
  }
}

sub getlocallinks {
  my ($projid, $packid) = @_;
  if ($BSConfig::source_db_sqlite) {
    my $db = BSSrcServer::SQLite::opendb($sourcedb, 'linkinfo');
    return $db->getlocallinks($projid, $packid);
  } else {
    my $db = BSDB::opendb($sourcedb, 'linkinfo');
    my @l = grep {s/^\Q$projid\///} $db->rawkeys('package', $packid);
    return () unless @l;
    my %ll = map {$_ => 1} $db->rawkeys('project', $projid);
    return grep {$ll{"$projid/$_"}} @l;
  }
}

sub addlocallinks {
  my ($projid, @packages) = @_;

  if ($BSConfig::source_db_sqlite) {
    my $db = BSSrcServer::SQLite::opendb($sourcedb, 'linkinfo');
    for my $packid (splice @packages) {
      push @packages, $packid, $db->getlocallinks($projid, $packid);
    }
  } else {
    my $db = BSDB::opendb($sourcedb, 'linkinfo');
    my $ll;
    for my $packid (splice @packages) {
      my @l;
      @l = grep {s/^\Q$projid\///} $db->rawkeys('package', $packid) if !$ll || %$ll;
      if (@l) {
	$ll ||= { map {$_ => 1} grep {s/^\Q$projid\///} $db->rawkeys('project', $projid) };
	@l = grep {$ll->{$_}} @l;
      }
      push @packages, $packid, @l;
    }
  }
  return BSUtil::unify(@packages);
}

1;

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

require BSSrcServer::SQLite if $BSConfig::source_db_sqlite;

my $sourcedb = "$BSConfig::bsdir/db/source";
my $redisdir = "$BSConfig::bsdir/events/redis";

sub addredisjob {
  my (@job) = @_;
  $job[3] = '' if @job > 3 && !defined($job[3]);
  $job[4] = '' if @job > 4 && !defined($job[4]);
  s/([\000-\037%|=\177-\237])/sprintf("%%%02X", ord($1))/ge for @job;
  my $job = join('|', @job)."\n";
  my $file;
  mkdir_p($redisdir) unless -d $redisdir;
  BSUtil::lockopen($file, '>>', "$redisdir/queue");
  my $oldlen = -s $file;
  (syswrite($file, $job) || 0) == length($job) || die("redisdir/queue: $!\n");
  close($file);
  BSUtil::ping("$redisdir/.ping") unless $oldlen;
}

sub generate_scmsyncinfo {
  my ($scmsyncurl) = @_;

  require URI;
  my $uri = URI->new($scmsyncurl);
  my $scmsync_repo = $uri->scheme.'://'.$uri->host.$uri->path;
  $scmsync_repo =~ s/\.git$//;
  my $scmsync_branch = $uri->fragment;
  my %params = $uri->query_form;
  my $scmsyncinfo = { 'scmsync_repo' => $scmsync_repo };
  $scmsyncinfo->{'scmsync_branch'} = $scmsync_branch if $scmsync_branch;
  $scmsyncinfo->{'scmsync_trackingbranch'} = $params{'trackingbranch'} if $params{'trackingbranch'};
  return $scmsyncinfo;
}

sub generate_scmsyncurl {
  my ($scmsyncinfo) = @_;
  my $scmsyncurl = $scmsyncinfo->{'scmsync_repo'};
  $scmsyncurl .= "?trackingbranch=$scmsyncinfo->{'scmsync_trackingbranch'}" if $scmsyncinfo->{'scmsync_trackingbranch'};
  $scmsyncurl .= "#$scmsyncinfo->{'scmsync_branch'}" if $scmsyncinfo->{'scmsync_branch'};
  return $scmsyncurl;
}

sub storescmsync {
  my ($projid, $packid, $scmsyncurl) = @_;
  return unless $BSConfig::source_db_sqlite;
  return deletescmsync($projid, $packid) unless defined $scmsyncurl;
  my $scmsyncinfo = eval { generate_scmsyncinfo($scmsyncurl) };
  my $db = BSSrcServer::SQLite::opendb($sourcedb, 'scmsync');
  $db->store_scmsyncinfo($projid, $packid, $scmsyncinfo);
  if ($BSConfig::redisserver) {
    if (defined(($scmsyncinfo || {})->{'scmsync_repo'})) {
      addredisjob('updatescmsync', "$projid/$packid", $scmsyncinfo->{'scmsync_repo'}, $scmsyncinfo->{'scmsync_branch'}, $scmsyncinfo->{'scmsync_trackingbranch'});
    } else {
      addredisjob('updatescmsync', "$projid/$packid");
    }
  }
}

sub deletescmsync {
  my ($projid, $packid) = @_;
  return unless $BSConfig::source_db_sqlite;
  my $db = BSSrcServer::SQLite::opendb($sourcedb, 'scmsync');
  my @k;
  @k = grep {s/^\Q$projid\E\///} $db->rawkeys('project', $projid) if $BSConfig::redisserver && !defined($packid);
  $db->store_scmsyncinfo($projid, $packid, undef);
  if ($BSConfig::redisserver) {
    push @k, $packid if defined $packid;
    addredisjob('updatescmsync', "$projid/$_") for @k;
  }
}

sub getscmsyncpackages {
  my ($scmsync_repo, $scmsync_branch, $use_trackingbranch) = @_;
  return () unless $BSConfig::source_db_sqlite;
  my $db = BSSrcServer::SQLite::opendb($sourcedb, 'scmsync');
  $scmsync_repo =~ s/\.git$//;
  return $db->getscmsyncpackages($scmsync_repo, $scmsync_branch, $use_trackingbranch);
}

sub getscmsyncurl {
  my ($projid, $packid) = @_;
  return undef unless $BSConfig::source_db_sqlite;
  my $db = BSSrcServer::SQLite::opendb($sourcedb, 'scmsync');
  my $scmsyncinfo = $db->getscmsyncinfo($projid, $packid);
  return $scmsyncinfo ? generate_scmsyncurl($scmsyncinfo) : undef;
}

sub movescmsync {
  my ($projid, $oprojid) = @_;
  return unless $BSConfig::source_db_sqlite;
  my $db = BSSrcServer::SQLite::opendb($sourcedb, 'scmsync');
  $db->move_scmsyncinfos($projid, $oprojid);
}

1;

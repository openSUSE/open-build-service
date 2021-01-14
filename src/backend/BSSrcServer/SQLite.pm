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
package BSSrcServer::SQLite;

use strict;

use BSConfiguration;
use BSUtil;
use BSDB;
use BSSQLite;
use Data::Dumper;

use DBI qw(:sql_types);

use JSON::XS ();


my $sqlitedb = "$BSConfig::bsdir/db/sqlite";

sub dbdo {
  BSSQLite::dbdo(@_);
}

sub dbdo_bind {
  return BSSQLite::dbdo_bind(@_);
}

sub connectdb {
  my ($db) = @_;
  my $dbname = $db->{'sqlite_dbname'};
  die("no dbname defined\n") unless $dbname;
  mkdir_p($sqlitedb);
  my $h = BSSQLite::connectdb("$sqlitedb/$dbname");
  BSSQLite::foreignkeys($h, 0);
  $db->{'sqlite'} = $h;
  return $h;
}

sub init_publisheddb {
  my ($extrepodb, $onlytable) = @_;
  my $db = opendb($extrepodb, 'binary');
  my $h = $db->{'sqlite'} || connectdb($db);
  my %t = map {$_ => 1} BSSQLite::list_tables($h);
  if (!$t{'repoinfo'} || !$t{'binary'} || !$t{'pattern'}) {
    # need to create our tables. abort if there is an old database
    BSUtil::diecritical("Please convert the published database to sqlite first") if $extrepodb && -d $extrepodb;
    BSUtil::diecritical("Please convert the published binary database to sqlite first") if $onlytable && $onlytable eq 'pattern' && !$t{'repoinfo'};
    dbdo($h, <<'EOS');
CREATE TABLE IF NOT EXISTS repoinfo(
  id INTEGER PRIMARY KEY,
  path TEXT,
  json TEXT,
  project TEXT,
  UNIQUE(path)
)
EOS
    dbdo($h, <<'EOS') if !$onlytable || $onlytable eq 'binary';
CREATE TABLE IF NOT EXISTS binary(
  repoinfo INTEGER,
  name TEXT,
  path TEXT,
  package TEXT,
  FOREIGN KEY(repoinfo) REFERENCES repoinfo(id)
)
EOS
    dbdo($h, <<'EOS') if !$onlytable || $onlytable eq 'pattern';
CREATE TABLE IF NOT EXISTS pattern(
  repoinfo INTEGER,
  path TEXT,
  package TEXT,
  json TEXT,
  name TEXT,
  summary TEXT,
  description TEXT,
  type TEXT,
  FOREIGN KEY(repoinfo) REFERENCES repoinfo(id)
)
EOS
  }
  dbdo($h, 'CREATE INDEX IF NOT EXISTS repoinfo_idx_path on repoinfo(path)');
  dbdo($h, 'CREATE INDEX IF NOT EXISTS repoinfo_idx_project on repoinfo(project)');
  if (!$onlytable || $onlytable eq 'binary') {
    dbdo($h, 'CREATE INDEX IF NOT EXISTS binary_idx_name on binary(name)');
    dbdo($h, 'CREATE INDEX IF NOT EXISTS binary_idx_repoinfo on binary(repoinfo)');
  }
  if (!$onlytable || $onlytable eq 'pattern') {
    dbdo($h, 'CREATE INDEX IF NOT EXISTS pattern_idx_name on pattern(name)');
    dbdo($h, 'CREATE INDEX IF NOT EXISTS pattern_idx_repoinfo on pattern(repoinfo)');
  }
}

sub init_sourcedb {
  my ($sourcedb) = @_;
  my $db = opendb($sourcedb, 'linkinfo');
  my $h = $db->{'sqlite'} || connectdb($db);
  my %t = map {$_ => 1} BSSQLite::list_tables($h);
  if (!$t{'linkinfo'}) {
    BSUtil::diecritical("Please convert the source database to sqlite first") if $sourcedb && -d $sourcedb;
    dbdo($h, <<'EOS');
CREATE TABLE IF NOT EXISTS linkinfo(
  sourceproject TEXT,
  sourcepackage TEXT,
  project TEXT,
  package TEXT,
  rev TEXT,
  UNIQUE(sourceproject,sourcepackage)
)
EOS
  }
  dbdo($h, 'CREATE INDEX IF NOT EXISTS linkinfo_idx_sourceproject_sourcepackage on linkinfo(sourceproject,sourcepackage)');
  dbdo($h, 'CREATE INDEX IF NOT EXISTS linkinfo_idx_project_package on linkinfo(project,package)');
  dbdo($h, 'CREATE INDEX IF NOT EXISTS linkinfo_idx_package on linkinfo(package)');
}

sub asyncmode {
  my ($db) = @_;
  my $h = $db->{'sqlite'} || connectdb($db);
  BSSQLite::synchronous($h, 0);
}

my %tables = (
  'binary' => { map {$_ => 1} qw {package name} },
  'pattern' => { map {$_ => 1} qw {package name summary description type} },
  'repoinfo' => { map {$_ => 1} qw {project} },
  'linkinfo'=> { map {$_ => 1} qw {project package rev} },
);

###########################################################################

sub prpext2id {
  my ($h, $prp_ext, $repoinfo) = @_;
  if (!$repoinfo) {
    my @ary = $h->selectrow_array('SELECT id from repoinfo WHERE path = ?', undef, $prp_ext);
    return $ary[0];
  }
  my @p = split('/', $prp_ext);
  splice(@p, 0, 2, "$p[0]$p[1]") while @p > 1 && $p[0] =~ /:$/;
  my $project = shift @p;

  my %i = %$repoinfo;
  delete $i{$_} for qw{binaryorigins state code starttime endtime publishid};
  my $json = JSON::XS->new->utf8->canonical->encode(\%i);

  my @ary = $h->selectrow_array('SELECT id,json from repoinfo WHERE path = ?', undef, $prp_ext);
  if (!$ary[0]) {
    dbdo_bind($h, 'INSERT OR IGNORE INTO repoinfo(path,json,project) VALUES(?,?,?)', [ $prp_ext ], [ $json ], [ $project ]);
    @ary = $h->selectrow_array('SELECT id from repoinfo where path = ?', undef, $prp_ext);
  } elsif (!$ary[1] || $ary[1] ne $json) {
    dbdo_bind($h, 'UPDATE repoinfo SET json = ?, project = ? WHERE path = ?', [ $json ], [ $project ], [ $prp_ext ]);
  }
  die("could not insert new repoinfo '$prp_ext'\n") unless $ary[0];
  return $ary[0];
}

###########################################################################

sub binarypath2name {
  my ($path) = @_;
  $path =~ s/.*\///;
  return $1 if $path =~ /^(.*)-[^-]+-[^-]+\.[^\.]+\.rpm$/;
  return $1 if $path =~ /^(.*)_[^_]+_[^_]+\.deb$/;
  return $1 if $path =~ /^(.*)-[^-]+-[^-]+-[^-]+\.pkg\.tar\.(?:xz|gz|zst)$/;
  return undef;
}

sub updatedb_deleterepo {
  my ($db, $prp) = @_;

  my $prp_ext = $prp;
  $prp_ext =~ s/:/:\//g;
  my $h = $db->{'sqlite'} || connectdb($db);

  my $prp_ext_id = prpext2id($h, $prp_ext);
  return unless $prp_ext_id;

  BSSQLite::begin_work($h);
  dbdo_bind($h, 'DELETE FROM binary WHERE repoinfo = ?', [ $prp_ext_id, SQL_INTEGER ]);
  dbdo_bind($h, 'DELETE FROM pattern WHERE repoinfo = ?', [ $prp_ext_id, SQL_INTEGER ]);
  dbdo_bind($h, 'DELETE FROM repoinfo WHERE id = ?', [ $prp_ext_id, SQL_INTEGER ]);
  BSSQLite::commit($h);
}

sub updatedb_repoinfo {
  my ($db, $prp, $repoinfo) = @_;

  return updatedb_deleterepo($db, $prp) unless $repoinfo;

  my $prp_ext = $prp;
  $prp_ext =~ s/:/:\//g;

  my $h = $db->{'sqlite'} || connectdb($db);
  my $sh;

  my $prp_ext_id = prpext2id($h, $prp_ext, $repoinfo);
  my $binaryorigins = $repoinfo->{'binaryorigins'};
  my @bins = sort keys %{$binaryorigins || {}};

  if (!@bins) {
    BSSQLite::begin_work($h);
    dbdo_bind($h, 'DELETE FROM binary WHERE repoinfo = ?', [ $prp_ext_id, SQL_INTEGER ]);
    BSSQLite::commit($h);
    return;
  }

  # start transaction
  BSSQLite::begin_work($h);

  # get old data
  $sh = dbdo_bind($h, 'SELECT rowid,name,path FROM binary WHERE repoinfo = ?', [ $prp_ext_id, SQL_INTEGER ]);
  my ($rowid, $name, $path);
  $sh->bind_columns(\$rowid, \$name, \$path);
  my %old;
  $old{"$name/$path"} = $rowid while $sh->fetch();
  die($sh->errstr) if $sh->err();

  # add new entries
  $sh = undef;
  for my $path (@bins) {
    my $name = binarypath2name($path);
    next unless defined $name;
    if (exists($old{"$name/$path"})) {
      $old{"$name/$path"} = 0;
      next;
    }
    if (!$sh) {
      $sh = $h->prepare('INSERT INTO binary(repoinfo,name,path,package) VALUES(?,?,?,?)') || die($h->errstr);
      $sh->bind_param(1, $prp_ext_id, SQL_INTEGER);
    }
    $sh->bind_param(2, $name);
    $sh->bind_param(3, $path);
    $sh->bind_param(4, $binaryorigins->{$path});
    $sh->execute() || die($sh->errstr);
  }

  # get rid of old entries
  my @del = sort {$a <=> $b} grep {$_} values %old;
  if (@del) {
    $sh = $h->prepare('DELETE FROM binary WHERE rowid = ?') || die($h->errstr);
    for my $rowid (@del) {
      $sh->bind_param(1, $rowid, SQL_INTEGER);
      $sh->execute() || die($sh->errstr);
    }
  }

  # finish transaction
  BSSQLite::commit($h);
}

sub updatedb_patterninfo {
  my ($db, $prp, $patterninfo) = @_;

  my $prp_ext = $prp;
  $prp_ext =~ s/:/:\//g;

  my $h = $db->{'sqlite'} || connectdb($db);

  my $prp_ext_id = prpext2id($h, $prp_ext);
  return unless $prp_ext_id;

  my @pats = sort keys %{$patterninfo || {}};
  if (!@pats) {
    BSSQLite::begin_work($h);
    dbdo_bind($h, 'DELETE FROM pattern WHERE repoinfo = ?', [ $prp_ext_id, SQL_INTEGER ]);
    BSSQLite::commit($h);
    return;
  }
  # start transaction
  BSSQLite::begin_work($h);
  my $sh;

  # get old data
  $sh = dbdo_bind($h, 'SELECT rowid,path,json FROM pattern WHERE repoinfo = ?', [ $prp_ext_id, SQL_INTEGER ]);
  my ($rowid, $path, $json);
  $sh->bind_columns(\$rowid, \$path, \$json);
  my %old;
  $old{"$path/$json"} = $rowid while $sh->fetch();
  die($sh->errstr) if $sh->err();

  # add new entries
  $sh = undef;
  for my $path (@pats) {
    my $pat = $patterninfo->{$path};
    $json = JSON::XS->new->utf8->canonical->encode($pat);
    if (exists($old{"$path/$json"})) {
      $old{"$path/$json"} = 0;
      next;
    }
    if (!$sh) {
      $sh = $h->prepare('INSERT INTO pattern(repoinfo,path,package,json,name,summary,description,type) VALUES(?,?,?,?,?,?,?,?)') || die($h->errstr);
      $sh->bind_param(1, $prp_ext_id, SQL_INTEGER);
    }
    $sh->bind_param(2, $path);
    $sh->bind_param(3, $pat->{'package'} || '_pattern');
    $sh->bind_param(4, $json);
    $sh->bind_param(5, $pat->{'name'});
    $sh->bind_param(6, $pat->{'summary'});
    $sh->bind_param(7, $pat->{'description'});
    $sh->bind_param(8, $pat->{'type'});
    $sh->execute() || die($sh->errstr);
  }

  # get rid of old entries
  my @del = sort {$a <=> $b} grep {$_} values %old;
  if (@del) {
    $sh = $h->prepare('DELETE FROM pattern WHERE rowid = ?') || die($h->errstr);
    for my $rowid (@del) {
      $sh->bind_param(1, $rowid, SQL_INTEGER);
      $sh->execute() || die($sh->errstr);
    }
  }

  # finish transaction
  BSSQLite::commit($h);
}

sub store_linkinfo {
  my ($db, $projid, $packid, $linkinfo) = @_;

  my $h = $db->{'sqlite'} || connectdb($db);
  BSSQLite::begin_work($h);
  if ($linkinfo) {
    my $lprojid = $linkinfo->{'project'};
    my $lpackid = $linkinfo->{'package'};
    my $lrev = $linkinfo->{'rev'};
    my @ary = $h->selectrow_array("SELECT rowid,project,package,rev FROM linkinfo WHERE sourceproject = ? AND sourcepackage = ?", undef, $projid, $packid);
    if (!$ary[0] || $ary[1] ne $lprojid || $ary[2] ne $lpackid || (defined($ary[3]) ? $ary[3] : '') ne (defined($lrev) ? $lrev : '')) {
      dbdo_bind($h, 'DELETE FROM linkinfo WHERE rowid = ?', [ $ary[0], SQL_INTEGER ]) if $ary[0];
      dbdo_bind($h, 'INSERT INTO linkinfo(sourceproject,sourcepackage,project,package,rev) VALUES(?,?,?,?,?)', [ $projid ], [ $packid ], [ $lprojid ], [ $lpackid ], [ $lrev ])
    }
  } else {
    dbdo_bind($h, 'DELETE FROM linkinfo WHERE sourceproject = ? AND sourcepackage = ?', [ $projid ], [ $packid ]);
  }
  BSSQLite::commit($h);
}

###########################################################################
#
# Search helpers
#

sub getrepoinfo {
  my ($db, $prp_ext) = @_;
  my $h = $db->{'sqlite'} || connectdb($db);
  my @ary = $h->selectrow_array('SELECT id,json from repoinfo WHERE path = ?', undef, $prp_ext);
  return undef unless $ary[1];
  return JSON::XS::decode_json($ary[1]);
}

sub getrepoorigins {
  my ($db, $prp_ext) = @_;
  my $h = $db->{'sqlite'} || connectdb($db);
  my $prp_ext_id = prpext2id($h, $prp_ext);
  return undef unless $prp_ext_id;
  my $table = $db->{'table'};
  my %binaryorigins;
  my $sh = dbdo_bind($h, "SELECT path,package FROM $table WHERE repoinfo = ?", [ $prp_ext_id, SQL_INTEGER ]);
  my ($path, $packid) = @_;
  $sh->bind_columns(\$path, \$packid);
  $binaryorigins{$path} = $packid while $sh->fetch();
  die($sh->errstr) if $sh->err();
  return \%binaryorigins;
}

sub getprojectkeys {
  my ($db, $projid) = @_;
  my $h = $db->{'sqlite'} || connectdb($db);
  if (!$projid) {
    my $ary = $h->selectcol_arrayref("SELECT project FROM repoinfo") || die($h->errstr);
    return sort(BSUtil::unify(@$ary));
  }
  my $table = $db->{'table'};
  return map {"$projid/$_"} $db->getlinkpackages($projid) if $table eq 'linkinfo';
  return rawkeys($db, 'project', $projid) if $table eq 'repoinfo';
  my $sh = dbdo_bind($h, "SELECT repoinfo.path,$table.path,package FROM $table LEFT JOIN repoinfo ON repoinfo.id = $table.repoinfo WHERE repoinfo.project = ?", [ $projid ]);
  my ($prp_ext_path, $bin_path, $package);
  $sh->bind_columns(\$prp_ext_path, \$bin_path, \$package);
  my $key2package = $table eq 'binary' ? $db->{'key2package'} : undef;
  my @res;
  while ($sh->fetch()) {
    my $key = "$prp_ext_path/$bin_path";
    $key2package->{$key} = $package if $key2package;
    push @res, $key;
  }
  die($sh->errstr) if $sh->err();
  return sort(@res);
}

sub getrecord {
  my ($db, $prp_ext, $path) = @_;
  my $h = $db->{'sqlite'} || connectdb($db);
  my $prp_ext_id = prpext2id($h, $prp_ext);
  return undef unless $prp_ext_id;
  my $table = $db->{'table'};
  return undef if $table eq 'binary';		# no json element in binary
  my @ary = $h->selectrow_array("SELECT $table.json FROM $table LEFT JOIN repoinfo ON repoinfo.id = $table.repoinfo WHERE repoinfo.path = ? AND $table.path  = ?", undef, $prp_ext, $path);
  return $ary[0] ? JSON::XS::decode_json($ary[0]) : undef;
}

sub getlinkinfo {
  my ($db, $projid, $packid) = @_;
  my $h = $db->{'sqlite'} || connectdb($db);
  my @ary = $h->selectrow_array("SELECT project,package,rev FROM linkinfo WHERE sourceproject = ? AND sourcepackage = ?", undef, $projid, $packid);
  return undef unless @ary >= 2;
  my $linkinfo = { 'project' => $ary[0], 'package' => $ary[1] };
  $linkinfo->{'rev'} = $ary[2] if defined $ary[2];
  return $linkinfo;
}

sub getlinkpackages {
  my ($db, $projid) = @_;
  my $h = $db->{'sqlite'} || connectdb($db);
  my $ary = $h->selectcol_arrayref("SELECT sourcepackage FROM linkinfo WHERE sourceproject = ?", undef, $projid) || die($h->errstr);
  return sort(@$ary);
}

sub getlocallinks {
  my ($db, $projid, $packid) = @_;
  my $h = $db->{'sqlite'} || connectdb($db);
  my $sh = dbdo_bind($h, "SELECT sourcepackage FROM linkinfo WHERE project = ? AND package = ? AND sourceproject = ?", [ $projid ], [ $packid ] , [ $projid ]);
  my $ary = $h->selectcol_arrayref("SELECT sourcepackage FROM linkinfo WHERE project = ? AND package = ? AND sourceproject = ?", undef, $projid, $packid, $projid) || die($h->errstr);
  return sort(@$ary);
}

sub getlinkers {
  my ($db, $projid, $packid) = @_;
  my $h = $db->{'sqlite'} || connectdb($db);
  my $sh = dbdo_bind($h, "SELECT sourceproject,sourcepackage FROM linkinfo WHERE project = ? AND package = ?", [ $projid ], [ $packid ]);
  my ($sourceproject, $sourcepackage);
  $sh->bind_columns(\$sourceproject, \$sourcepackage);
  my @res;
  push @res, "$sourceproject/$sourcepackage" while $sh->fetch();
  die($sh->errstr) if $sh->err();
  return sort(@res);
}


###########################################################################
#
# BSDB query interface
#

sub opendb {
  my ($dbpath, $table) = @_;
  die("unsupported table: $table\n") unless $tables{$table};
  my $dbname = $table eq 'linkinfo' ? 'source' : 'published';
  my $db = { 'dir' => $dbpath, 'table' => $table, 'sqlite_cols' => $tables{$table}, 'sqlite_dbname' => $dbname };
  $db->{'key2package'} = {} if $table eq 'binary';
  return bless $db;
}

*fetch = \&BSDB::fetch;
*keys = \&BSDB::keys;
*values = \&BSDB::values;

sub rawfetch {
  my ($db, $key) = @_;
  my $table = $db->{'table'};
  if ($table eq 'linkinfo') {
    my ($projid, $packid) = split('/', $key, 2);
    return $db->getlinkinfo($projid, $packid);
  }
  if ($table eq 'pattern') {
    return undef unless $key =~ /^(.+?(?<!:)\/.+?)(?<!:)\/(.*)$/;
    return getrecord($db, $1, $2);
  }
  if ($table eq 'repoinfo') {
    return getrepoinfo($db, $key);
  }
  die("Cannot fetch data set for sqlite table $table\n");
}

sub store {
  my ($db, $key, $v) = @_;
  my $table = $db->{'table'};
  if ($table eq 'linkinfo') {
    my ($projid, $packid) = split('/', $key, 2);
    return $db->store_linkinfo($projid, $packid, $v);
  }
  die("Cannot store data set for sqlite table $table\n");
}

sub hint2prefixes {
  my ($hint, $hintval) = @_;
  my @prefixes;
  if ($hint eq 'starts-with') {
    push @prefixes, $1 if $hintval =~ /^([\000-\176]+)/s;
  } elsif ($hint eq 'starts-with-ic' || $hint eq 'equals-ic') {
    return () unless $hintval =~ /^([\000-\176]+)/s;
    push @prefixes, '';
    for my $c (split(//, substr($1, 0, 2))) {
      @prefixes = map {($_.lc($c), $_.uc($c))} @prefixes;
    }
    @prefixes = sort(keys %{ { map {$_ => 1} @prefixes } });
  }
  return @prefixes;
}

sub rawvalues {
  my ($db, $path, $hint, $hintval) = @_;

  my $table = $db->{'table'};
  die("unsupported path for $table table: $path\n") unless $db->{'sqlite_cols'}->{$path};

  # get all values from a table column
  my $h = $db->{'sqlite'} || connectdb($db);

  # try to limit the search to some prefixes
  my @prefixsql;
  my @prefixargs;
  if ($hint && defined($hintval)) {
    for my $p (hint2prefixes($hint, $hintval)) {
      next if $p eq '';
      push @prefixsql, "$path >= ? AND $path < ?";
      push @prefixargs, $p, substr($p, 0, -1).chr(ord(substr($p, -1, 1)) + 1);
    }
  }

  # sqlite switches to full index search when using too many ORs with DISTINCT, so use multiple selects instead
  if (@prefixsql > 1) {
    my %res;
    while (@prefixsql) {
      my $s = shift @prefixsql;
      my @a = splice(@prefixargs, 0, 2);
      my $ary = $h->selectcol_arrayref("SELECT DISTINCT $path FROM $table WHERE $s", undef, @a) || die($h->errstr);
      $res{$_} = 1 for @$ary;
    }
    return sort keys %res;
  }

  my $ary;
  if (@prefixsql) {
    $ary = $h->selectcol_arrayref("SELECT DISTINCT $path FROM $table WHERE (".join(') OR (', @prefixsql).")", undef, @prefixargs) || die($h->errstr);
  } else {
    $ary = $h->selectcol_arrayref("SELECT DISTINCT $path FROM $table") || die($h->errstr);
  }
  return sort(@$ary);
}

sub allkeys {
  my ($db) = @_;

  my $table = $db->{'table'};
  my $h = $db->{'sqlite'} || connectdb($db);
  if ($table eq 'repoinfo') {
    my $ary = $h->selectcol_arrayref("SELECT repoinfo.path FROM $table") || die($h->errstr);
    return sort @$ary;
  }
  my $sh;
  if ($table eq 'linkinfo') {
    $sh = dbdo_bind($h, "SELECT sourceproject,sourcepackage FROM $table");
  } else {
    $sh = dbdo_bind($h, "SELECT repoinfo.path,$table.path FROM $table LEFT JOIN repoinfo ON repoinfo.id = $table.repoinfo");
  }
  my ($col1, $col2);
  $sh->bind_columns(\$col1, \$col2);
  my @res;
  push @res, "$col1/$col2" while $sh->fetch();
  die($sh->errstr) if $sh->err();
  return sort(@res);
}

sub rawkeys {
  my ($db, $path, $value) = @_;

  my $table = $db->{'table'};
  return allkeys($db) unless defined $path;
  die("unsupported path for $table table: $path\n") unless $db->{'sqlite_cols'}->{$path};

  # get all keys for a table column
  my $h = $db->{'sqlite'} || connectdb($db);

  if ($table eq 'linkinfo') {
    my $sh = dbdo_bind($h, "SELECT sourceproject,sourcepackage FROM $table WHERE $path = ?", [ $value ]);
    my ($sourceproject, $sourcepackage);
    $sh->bind_columns(\$sourceproject, \$sourcepackage);
    my @res;
    push @res, "$sourceproject/$sourcepackage" while $sh->fetch();
    die($sh->errstr) if $sh->err();
    return sort(@res);
  }

  if ($table eq 'repoinfo') {
    my $ary = $h->selectcol_arrayref("SELECT repoinfo.path FROM $table WHERE $path = ?", undef, $value) || die($h->errstr);
    return @$ary;
  }

  my $sh = dbdo_bind($h, "SELECT repoinfo.path,$table.path,package FROM $table LEFT JOIN repoinfo ON repoinfo.id = $table.repoinfo WHERE $path = ?", [ $value ]);
  my ($prp_ext_path, $bin_path, $package);
  $sh->bind_columns(\$prp_ext_path, \$bin_path, \$package);
  my $key2package = $table eq 'binary' ? $db->{'key2package'} : undef;
  my @res;
  while ($sh->fetch()) {
    my $key = "$prp_ext_path/$bin_path";
    $key2package->{$key} = $package if $key2package;
    push @res, $key;
  }
  die($sh->errstr) if $sh->err();
  return sort(@res);
}

1;

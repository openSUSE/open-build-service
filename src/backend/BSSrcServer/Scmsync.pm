# Copyright (c) 2021 SUSE LLC
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
package BSSrcServer::Scmsync;

use Digest::MD5 ();

use BSConfiguration;
use BSUtil;
use BSRevision;
use BSCpio;
use BSVerify;
use BSXML;

use strict;

my $projectsdir = "$BSConfig::bsdir/projects";
my $srcrep = "$BSConfig::bsdir/sources";

my $uploaddir = "$srcrep/:upload";


our $notify = sub {};
our $notify_repservers = sub {};
our $runservice = sub {};
our $addrev = sub { die("BSSrcServer::Scmsync::addrev not implemented\n") };

#
# low level helpers
#
sub deletepackage {
  my ($cgi, $projid, $packid) = @_;
  local $cgi->{'comment'} = $cgi->{'comment'} || 'package was deleted';
  # kill upload revision
  unlink("$projectsdir/$projid.pkg/$packid.upload-MD5SUMS");
  # add delete commit to both source and meta
  BSRevision::addrev_local_replace($cgi, $projid, $packid);
  BSRevision::addrev_meta_replace($cgi, $projid, $packid);
  # now do the real delete of the package
  BSRevision::delete_rev($cgi, $projid, $packid, "$projectsdir/$projid.pkg/$packid.rev", "$projectsdir/$projid.pkg/$packid.rev.del");
  BSRevision::delete_rev($cgi, $projid, $packid, "$projectsdir/$projid.pkg/$packid.mrev", "$projectsdir/$projid.pkg/$packid.mrev.del");
  # get rid of the generated product packages as well
}

sub undeletepackage {
  my ($cgi, $projid, $packid) = @_;
  local $cgi->{'comment'} = $cgi->{'comment'} || 'package was undeleted';
  BSRevision::undelete_rev($cgi, $projid, $packid, "$projectsdir/$projid.pkg/$packid.mrev.del", "$projectsdir/$projid.pkg/$packid.mrev");
  if (-s "$projectsdir/$projid.pkg/$packid.rev.del") {
    BSRevision::undelete_rev($cgi, $projid, $packid, "$projectsdir/$projid.pkg/$packid.rev.del", "$projectsdir/$projid.pkg/$packid.rev");
  }
}

sub putpackage {
  my ($cgi, $projid, $packid, $pack) = @_;
  local $cgi->{'comment'} = $cgi->{'comment'} || 'package was updated';
  mkdir_p($uploaddir);
  writexml("$uploaddir/$$.2", undef, $pack, $BSXML::pack);
  BSRevision::addrev_meta_replace($cgi, $projid, $packid, [ "$uploaddir/$$.2", "$projectsdir/$projid.pkg/$packid.xml", '_meta' ]);
}

sub putconfig {
  my ($cgi, $projid, $config, $info) = @_;
  local $cgi->{'comment'} = $cgi->{'comment'} || 'config was updated';
  $cgi->{'comment'} .= " [info=$info]" if $info;
  if (defined($config) && $config ne '') {
    mkdir_p($uploaddir);
    writestr("$uploaddir/$$.2", undef, $config);
    BSRevision::addrev_local_replace($cgi, $projid, undef, [ "$uploaddir/$$.2", "$projectsdir/$projid.conf", '_config' ]);
  } else {
    BSRevision::addrev_local_replace($cgi, $projid, undef, [ undef, "$projectsdir/$projid.conf", '_config' ]);
  }
}

sub putprojectinfo {
  my ($cgi, $projid, $info) = @_;
  local $cgi->{'comment'} = $cgi->{'comment'} || 'projectinfo update';
  $cgi->{'comment'} .= " [info=$info]" if $info;
  BSRevision::addrev_local_replace($cgi, $projid, undef, []);
}

#
# sync functions
#
sub sync_locallink {
  my ($cgi, $projid, $packid, $link) = @_;
  my $files;
  eval {
    my $lastrev = BSRevision::getrev_local($projid, $packid);
    $files = BSSrcrep::lsfiles($projid, $packid, $lastrev->{'srcmd5'}) if $lastrev;
  };
  my $linkxml = BSUtil::toxml($link, $BSXML::link);
  return if $files && scalar(keys %$files) == 1 && $files->{'_link'} eq Digest::MD5::md5_hex($linkxml);
  local $cgi->{'comment'} = $cgi->{'comment'} || 'update _link';
  mkdir_p($uploaddir);
  writestr("$uploaddir/sync_locallink$$", undef, $linkxml);
  $files = {};
  $files->{'_link'} = BSSrcrep::addfile($projid, $packid, "$uploaddir/sync_locallink$$", '_link');
  print "scmsync: update _link in $projid/$packid\n";
  $addrev->($cgi, $projid, $packid, $files);
}

sub sync_package {
  my ($cgi, $projid, $packid, $pack, $info, $link) = @_;

  if (!$pack) {
    return unless -e "$projectsdir/$projid.pkg/$packid.xml";
    print "scmsync: delete $projid/$packid\n";
    eval { deletepackage($cgi, $projid, $packid) };
    warn($@) if $@;
    $notify_repservers->('package', $projid, $packid);
    $notify->("SRCSRV_DELETE_PACKAGE", { "project" => $projid, "package" => $packid, "sender" => ($cgi->{'user'} || "unknown"), "comment" => $cgi->{'comment'}, "requestid" => $cgi->{'requestid'} });
    return;
  }

  my $undeleted;
  if (! -e "$projectsdir/$projid.pkg/$packid.xml" && -e "$projectsdir/$projid.pkg/$packid.rev.del") {
    print "scmsync: undelete $projid/$packid\n";
    eval { undeletepackage($cgi, $projid, $packid) };
    warn($@) if $@;
    $notify->("SRCSRV_UNDELETE_PACKAGE", { "project" => $projid, "package" => $packid, "sender" => ($cgi->{'user'} || "unknown"), "comment" => $cgi->{'comment'} });
    $undeleted = 1;
  }
  my $oldpack = BSRevision::readpack_local($projid, $packid, 1);

  if ($undeleted || !$oldpack || !BSUtil::identical($pack, $oldpack, $pack->{'scmsync'} ? { 'url' => 1 } : undef)) {
    print "scmsync: update $projid/$packid\n";
    putpackage($cgi, $projid, $packid, $pack);
    my %except = map {$_ => 1} qw{title description devel person group url};
    if ($undeleted || !BSUtil::identical($oldpack, $pack, \%except)) {
      $notify_repservers->('package', $projid, $packid);
    }
    $notify->($oldpack ? "SRCSRV_UPDATE_PACKAGE" : "SRCSRV_CREATE_PACKAGE", { "project" => $projid, "package" => $packid, "sender" => ($cgi->{'user'} || "unknown")});
  }

  if ($link) {
    sync_locallink($cgi, $projid, $packid, $link);
    return;
  }

  my $needtrigger;
  $needtrigger = 1 if $pack->{'scmsync'} && (!$oldpack || $undeleted || $oldpack->{'scmsync'} ne $pack->{'scmsync'});
  if ($pack->{'scmsync'} && !$needtrigger && $info) {
    my $lastrev = eval { BSRevision::getrev_local($projid, $packid) };
    $needtrigger = 1 if $lastrev && $lastrev->{'comment'} && $lastrev->{'comment'} =~ /\[info=([0-9a-f]{1,128})\]$/ && $info ne $1;
  }
  if ($needtrigger) {
    print "scmsync: trigger $projid/$packid\n";
    $runservice->($cgi, $projid, $packid, $pack->{'scmsync'}, $pack->{'url'});
  }
}

sub sync_config {
  my ($cgi, $projid, $config, $info) = @_;

  if (!defined($config) || $config eq '') {
    return unless -e "$projectsdir/$projid.conf";
    print "scmsync: delete $projid/_config\n";
  } else {
    my $oldconfig = readstr("$projectsdir/$projid.conf", 1);
    $oldconfig = '' unless defined $oldconfig;
    return if $oldconfig eq $config;
    print "scmsync: update $projid/_config\n";
  }
  putconfig($cgi, $projid, $config, $info);
  $notify_repservers->('project', $projid);
  $notify->("SRCSRV_UPDATE_PROJECT_CONFIG", { "project" => $projid, "sender" => ($cgi->{'user'} || "unknown") });
}

sub sync_projectinfo {
  my ($cgi, $projid, $info) = @_;
  my $lastrev = eval { BSRevision::getrev_local($projid, '_project') };
  return if $lastrev && $lastrev->{'comment'} && $lastrev->{'comment'} =~ /\[info=([0-9a-f]{1,128})\]$/ && $info eq $1;
  putprojectinfo($cgi, $projid, $info);
}

sub cpio_extract {
  my ($cpiofd, $files, $fn, $maxsize) = @_;
  my $ent = $files->{$fn};
  die("$fn: not in cpio archive\n") unless $ent;
  die("$fn: size is too big\n") if $ent->{'size'} > $maxsize;
  return BSCpio::extract($cpiofd, $ent);
}

sub sync_project {
  my ($cgi, $projid, $cpiofd) = @_;

  my $proj = BSRevision::readproj_local($projid);
  die("Project $projid is not controlled by obs-scm\n") unless $proj->{'scmsync'};
  die("Project $projid is a remote project\n") if $proj->{'remoteurl'};
  $cpiofd->flush();
  seek($cpiofd, 0, 0);
  my $cpio = BSCpio::list($cpiofd);
  my %files = map {$_->{'name'} => $_}  grep {$_->{'cpiotype'} == 8} @$cpio;

  # ensure that the blocked handling sees all changes from new commit
  # at the same time
  $notify_repservers->('suspendproject', $projid, undef, 'suspend for scmsync');

  # update all packages
  for my $packid (grep {s/\.xml$//} sort keys %files) {
    my $pack;
    eval {
      BSVerify::verify_packid($packid);
      die("bad package name\n") if $packid eq '_project' || $packid eq '_product';
      die("bad package name\n") if $packid =~ /(?<!^_product)(?<!^_patchinfo):./;
      my $packxml = cpio_extract($cpiofd, \%files, "$packid.xml", 1000000);
      $pack = BSUtil::fromxml($packxml, $BSXML::pack);
      $pack->{'project'} = $projid;
      $pack->{'name'} = $packid;
      delete $pack->{'person'};
      delete $pack->{'group'};
      BSVerify::verify_pack($pack);
    };
    if ($@) {
      warn("$packid: $@");
      next;
    }
    my $link;
    if ($files{"$packid.link"}) {
      eval {
        my $linkxml =  cpio_extract($cpiofd, \%files, "$packid.link", 100000);
	$link = BSUtil::fromxml($linkxml, $BSXML::link);
	BSVerify::verify_link($link);
	die("link must not contain a project\n") if exists $link->{'project'};
      };
      if ($@) {
	warn("$packid: $@");
	undef $link;
      }
    }
    if ($link && $pack->{'scmsync'}) {
      warn("$packid: ignoring link file as the package has an scmsync element\n");
      undef $link;
    }
    my $info;
    if ($files{"$packid.info"}) {
      eval {
        $info = cpio_extract($cpiofd, \%files, "$packid.info", 100000);
	chomp $info;
	die("bad info data\n") if $info =~ /[\000-\037\177]/s;
      };
      if ($@) {
	warn("$packid: $@");
	undef $info;
      }
    }
    sync_package($cgi, $projid, $packid, $pack, $info, $link);
  }

  # delete packages that no longer exist
  for my $packid (sort(BSRevision::lspackages_local($projid))) {
    sync_package($cgi, $projid, $packid, undef) unless $files{"$packid.xml"};
  }

  my $info;
  if ($files{'_scmsync.obsinfo'}) {
    my $obsinfo = eval { cpio_extract($cpiofd, \%files, '_scmsync.obsinfo', 1000000) };
    $info = $1 if $obsinfo && $obsinfo =~ /^commit: ([0-9a-f]{1,128})$/m;
  }

  # update the project config
  my $config = '';
  if ($files{'_config'}) {
    eval {
      $config = cpio_extract($cpiofd, \%files, '_config', 1000000);
    };
    if ($@) {
      warn($@);
      undef $config;
    }
  }
  sync_config($cgi, $projid, $config, $info) if defined $config;
  sync_projectinfo($cgi, $projid, $info) if $info;

  $notify_repservers->('resumeproject', $projid, undef, 'suspend for scmsync');

  return { 'project' => $projid, 'package' => '_project', 'rev' => 'obsscm' };
}

1;

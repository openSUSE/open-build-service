# Copyright (c) 2016 SUSE LLC
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
package BSSrcServer::Service;

use strict;
use warnings;

use Digest::MD5 ();
use BSConfiguration;
use BSUtil;
use BSXML;
use BSRevision;
use BSSrcrep;
use BSVerify;
use BSSrcServer::Link;	# for link expansion

my $projectsdir = "$BSConfig::bsdir/projects";
my $eventdir = "$BSConfig::bsdir/events";
my $srcrep = "$BSConfig::bsdir/sources";
my $uploaddir = "$srcrep/:upload";

our $getrev = sub {
  my ($projid, $packid, $revid, $linked, $missingok) = @_; 
  my $rev = BSRevision::getrev_local($projid, $packid, $revid);
  return $rev if $rev;
  return {'project' => $projid, 'package' => $packid, 'srcmd5' => $BSSrcrep::emptysrcmd5} if $missingok;
  die("404 package '$packid' does not exist in project '$projid'\n");
};

our $readpackage = sub {
  my ($projid, $proj, $packid, $revid, $missingok) = @_;
  my $pack = BSRevision::readpack_local($projid, $packid, 1);
  $pack->{'project'} ||= $projid if $pack;
  die("404 package '$packid' does not exist in project '$projid'\n") if !$missingok && !$pack;
  return $pack;
};

# only used for old style services
our $addrev = sub {
  my ($cgi, $projid, $packid, $files, $target) = @_;
  die("BSSrcServer::Service::addrev not implemented\n");
};

our $notify = sub {
};

our $notify_repservers = sub {
};


# check if a service run is needed for the upcoming commit
sub genservicemark {
  my ($projid, $packid, $files, $rev, $force) = @_;
  
  return undef if $BSConfig::old_style_services;

  return undef if $packid eq '_project';	# just in case...
  return undef if defined $rev;	# don't mark if upload/repository/internal
  return undef if $packid eq '_pattern' || $packid eq '_product';	# for now...
  return undef if $files->{'/SERVICE'};	# already marked

  # check if we really need to run the service
  if (!$files->{'_service'} && !$force) {
    # XXX: getprojectservices may die!
    my $projectservices = getprojectservices($projid, $packid, undef, $files);
    return undef unless $projectservices && $projectservices->{'service'} && @{$projectservices->{'service'}};
  }

  # argh, somewhat racy. luckily we just need something unique...
  # (files is not unique enough because we want a different id
  # for each commit, even if it has the same srcmd5)
  # (maybe we should use the same time as in the upcoming rev)
  my $smd5 = "sourceservice/$projid/$packid/".time()."\n";
  eval {
    my $rev_old = BSRevision::getrev_local($projid, $packid);
    $smd5 .= "$rev_old->{'rev'}" if $rev_old->{'rev'};
  };
  $smd5 .= "$files->{$_}  $_\n" for sort keys %$files;
  $smd5 = Digest::MD5::md5_hex($smd5);

  # return the mark
  return $smd5;
}

# called from runservice when the service run is finished. it
# either does the service commit (old style), or creates the
# xsrcmd5 service revision (new style).
sub addrev_service {
  my ($cgi, $rev, $files, $error) = @_;

  if ($error) {
    chomp $error;
    $error ||= 'unknown service error';
  }
  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
  if (!$files->{'/SERVICE'}) {
    # old style, do a real commit
    if ($error) {
      mkdir_p($uploaddir);
      writestr("$uploaddir/_service_error$$", undef, "$error\n");
      $files->{'_service_error'} = BSSrcrep::addfile($projid, $packid, "$uploaddir/_service_error$$", '_service_error');
    }
    $addrev->({%{$cgi || {}}, 'user' => '_service', 'comment' => 'generated via source service', 'noservice' => 1}, $projid, $packid, $files);
    my $lockfile = "$eventdir/service/${projid}::$packid";
    unlink($lockfile);
    # addrev will notify the rep servers for us
    return;
  }
  # new style services
  if ($files->{'_service_error'} && !$error) {
    $error = BSSrcrep::repreadstr($rev, '_service_error', $files->{'_service_error'});
    chomp $error;
    $error ||= 'unknown service error';
  }
  my $srcmd5 = $files->{'/SERVICE'};
  if (!$error) {
    eval {
      BSSrcrep::addmeta_service($projid, $packid, $files, $srcmd5, $rev->{'srcmd5'});
    };
    $error = $@ if $@;
  }
  if ($error) {
    BSSrcrep::addmeta_serviceerror($projid, $packid, $srcmd5, $error);
    $error =~ s/[\r\n]+$//s;
    $error =~ s/.*[\r\n]//s;
    $error = str2utf8xml($error) || 'unknown service error';
  }
  my $user = $cgi->{'user'};
  my $comment = $cgi->{'comment'};
  my $requestid = $cgi->{'requestid'};
  $user = '' unless defined $user;
  $user = 'unknown' if $user eq '';
  $user = str2utf8xml($user);
  $comment = '' unless defined $comment;
  $comment = str2utf8xml($comment);
  my %ndata = (project => $projid, package => $packid, rev => $rev->{'rev'},
               user => $user, comment => $comment, requestid => $requestid);
  $ndata{'error'} = $error if $error;
  $notify->($error ? 'SRCSRV_SERVICE_FAIL' : 'SRCSRV_SERVICE_SUCCESS', \%ndata);
  $notify_repservers->('package', $projid, $packid);
}

# store the faked result of a service run. Note that this is done before
# the addrev call that stores the reference to the run.
# only used for new style services. no notifications sent (the following
# addrev call will notify the rep servers)
sub fake_service_run {
  my ($projid, $packid, $files, $sfiles, $servicemark) = @_;
  $files->{'/SERVICE'} = $servicemark;
  $sfiles->{'/SERVICE'} = $servicemark;
  my $nsrcmd5 = BSSrcrep::calcsrcmd5($files);
  my $rev = {'project' => $projid, 'package' => $packid, 'srcmd5' => $nsrcmd5};
  my $error;
  if ($sfiles->{'_service_error'}) {
    # hmm, die instead?
    $error = BSSrcrep::repreadstr($rev, '_service_error', $sfiles->{'_service_error'});
    chomp $error;
    $error ||= 'unknown service error';
  }
  if (!$error) {
    eval {
      BSSrcrep::addmeta_service($projid, $packid, $sfiles, $servicemark, $nsrcmd5);
    };
    $error = $@ if $@;
  }
  BSSrcrep::addmeta_serviceerror($projid, $packid, $servicemark, $error) if $error;
  delete $files->{'/SERVICE'};
  delete $sfiles->{'/SERVICE'};
}

# called *after* addrev to trigger service run
sub runservice {
  my ($cgi, $rev, $files) = @_;

  return if !$BSConfig::old_style_services && !$files->{'/SERVICE'};

  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
  die("No project defined for source update!") unless defined $projid;
  die("No package defined for source update!") unless defined $packid;
  return if $packid eq '_project';

  my $oldfiles = {};
  my $oldfilesrev;
  if ($files->{'/SERVICE'}) {
    # check serialization
    return unless BSSrcrep::addmeta_serialize_servicerun($rev->{'project'}, $rev->{'package'}, $files->{'/SERVICE'});
    # get last servicerun result into oldfiles hash
    my $revno = $rev->{'rev'};
    if (length($revno || '') >= 32) {
      # argh, find commit for that srcmd5
      $revno = (BSRevision::findlastrev($rev) || {})->{'rev'};
    }
    while ($revno && $revno > 1) {
      $revno = $revno - 1;	# get the commit before this one
      eval {
	my $linkinfo = {};
	$oldfilesrev = BSRevision::getrev_local($projid, $packid, $revno);
	$oldfiles = BSSrcrep::lsrev($oldfilesrev, $linkinfo) || {};
	$oldfiles = handleservice($oldfilesrev, $oldfiles, $linkinfo->{'xservicemd5'}) if $linkinfo->{'xservicemd5'};
      };
      if ($@) {
        warn($@);
	undef $oldfilesrev;
        next if $@ =~ /service in progress/;
      }
      $oldfiles = {} if !$oldfiles || $oldfiles->{'_service_error'};
      # strip all non-service results;
      delete $oldfiles->{$_} for grep {!/^_service:/} keys %$oldfiles;
      last;
    }
  }

  return if $packid eq '_project';
  return if $rev->{'rev'} && ($rev->{'rev'} eq 'repository' || $rev->{'rev'} eq 'upload');

  my $lockfile;		# old style service run lock
  if (!$files->{'/SERVICE'}) {
    $lockfile = "$eventdir/service/${projid}::$packid";
    # die when a source service is still running
    die("403 service still running\n") if $cgi->{'triggerservicerun'} && -e $lockfile;
  }

  my $projectservices;
  eval {
    $projectservices = getprojectservices($projid, $packid);
  };
  if ($@) {
    addrev_service($cgi, $rev, $files, $@);
    return;
  }
  undef $projectservices unless $projectservices && $projectservices->{'service'} && @{$projectservices->{'service'}};

  # collect current sources to POST them
  if (!$files->{'_service'} && !$projectservices) {
    die("404 no source service defined!\n") if $cgi->{'triggerservicerun'};
    # drop all existing service files
    my $dirty;
    for my $pfile (keys %$files) {
      if ($pfile =~ /^_service[_:]/) {
        delete $files->{$pfile};
        $dirty = 1;
      }
    }
    if ($dirty || $files->{'/SERVICE'}) {
      addrev_service($cgi, $rev, $files);
    }
    return;
  }

  my $linkfiles;
  my $linksrcmd5;
  if ($files->{'_link'}) {
    # make sure it's a branch
    my $l = BSSrcrep::repreadxml($rev, '_link', $files->{'_link'}, $BSXML::link, 1);
    if (!$l || !$l->{'patches'} || @{$l->{'patches'}->{''} || []} != 1 || (keys %{$l->{'patches'}->{''}->[0]})[0] ne 'branch') {
      #addrev_service($cgi, $rev, $files, "services only work on branches\n");
      #return;
      # uh oh, not a branch!
      $linkfiles = { %$files };
      delete $files->{'/SERVICE'};
      eval {
	my $lrev = {%$rev, 'linkrev' => 'base'};
	$files = BSSrcServer::Link::handlelinks($lrev, $files);
	die("bad link: $files\n") unless ref $files;
	$linksrcmd5 = $lrev->{'srcmd5'};
      };
      if ($@) {
	if (($@ =~ /service in progress/) && $linkfiles->{'/SERVICE'}) {
	  # delay, hope for an event. remove lock for now to re-trigger the service run.
	  BSSrcrep::addmeta_serviceerror($rev->{'project'}, $rev->{'package'}, $linkfiles->{'/SERVICE'}, undef);
	  return;
	}
        $files = $linkfiles;
        addrev_service($cgi, $rev, $files, $@);
        return;
      }
      $files->{'/SERVICE'} = $linkfiles->{'/SERVICE'} if $linkfiles->{'/SERVICE'}
    }
  }

  if ($files->{'/SERVICE'} && $BSConfig::servicedispatch) {
    my $projectservicesmd5;
    if ($projectservices) {
      mkdir_p($uploaddir);
      writestr("$uploaddir/_serviceproject$$", undef, BSUtil::toxml($projectservices, $BSXML::services));
      $projectservicesmd5 = BSSrcrep::addfile($projid, '_project', "$uploaddir/_serviceproject$$", '_serviceproject');
    }
    my $ev = {
      'type' => 'servicedispatch',
      'project' => $projid,
      'package' => $packid,
      'job' => $files->{'/SERVICE'},
      'srcmd5' => $rev->{'srcmd5'},
      'rev' => $rev->{'rev'},
    };
    $ev->{'linksrcmd5'} = $linksrcmd5 if $linksrcmd5;
    $ev->{'projectservicesmd5'} = $projectservicesmd5 if $projectservicesmd5;
    $ev->{'oldsrcmd5'} = $oldfilesrev->{'srcmd5'} if %$oldfiles && $oldfilesrev;
    mkdir_p("$eventdir/servicedispatch");
    my $evname = "servicedispatch:${projid}::${packid}::$rev->{'srcmd5'}::$files->{'/SERVICE'}";
    $evname = "servicedispatch:::".Digest::MD5::md5_hex($evname) if length($evname) > 200;
    writexml("$eventdir/servicedispatch/.$evname.$$", "$eventdir/servicedispatch/$evname", $ev, $BSXML::event);
    BSUtil::ping("$eventdir/servicedispatch/.ping");
    return;
  }

  return unless $BSConfig::serviceserver;

  if ($lockfile) {
    mkdir_p("$eventdir/service");
    BSUtil::touch($lockfile);
  }

  my @send = map {BSSrcrep::repcpiofile($rev, $_, $files->{$_})} grep {$_ ne '/SERVICE'} sort(keys %$files);
  push @send, {'name' => '_serviceproject', 'data' => BSUtil::toxml($projectservices, $BSXML::services)} if $projectservices;
  push @send, map {BSSrcrep::repcpiofile($rev, $_, $oldfiles->{$_})} grep {!$files->{$_}} sort(keys %$oldfiles);

  # run the source update in own process (do not wait for it)
  my $pid = xfork();
  return if $pid;

  # child continues...
  my $odir = "$uploaddir/runservice$$";
  BSUtil::cleandir($odir) if -d $odir;
  mkdir_p($odir);
  my $receive;
  eval {
    $receive = BSRPC::rpc({
      'uri'       => "$BSConfig::serviceserver/sourceupdate/$projid/$packid",
      'request'   => 'POST',
      'headers'   => [ 'Content-Type: application/x-cpio' ],
      'chunked'   => 1,
      'data'      => \&BSHTTP::cpio_sender,
      'cpiofiles' => \@send,
      'directory' => $odir,
      'timeout'   => 3600,
      'withmd5'   => 1,
      'receiver' => \&BSHTTP::cpio_receiver,
    }, undef);
  };

  my $error = $@;
  
  if (!$files->{'/SERVICE'}) {
    # make sure that there was no other commit in the meantime, old style only
    my $newrev = BSRevision::getrev_local($projid, $packid);
    if ($newrev && $newrev->{'rev'} ne $rev->{'rev'}) {
      unlink($lockfile) if $lockfile;
      exit(1);
    }
  }

  # and update source repository with the result
  if ($receive) {
    # drop all existing service files
    for my $pfile (keys %$files) {
      delete $files->{$pfile} if $pfile =~ /^_service[_:]/;
    }
    # add new service files
    eval {
      for my $pfile (ls($odir)) {
        if ($pfile eq '.errors') {
          my $e = readstr("$odir/.errors");
          $e ||= 'empty .errors file';
          die($e);
        }
	unless ($pfile =~ /^_service[_:]/) {
	  die("service returned a non-_service file: $pfile\n");
	}
	BSVerify::verify_filename($pfile);
	$files->{$pfile} = BSSrcrep::addfile($projid, $packid, "$odir/$pfile", $pfile);
      }
    };
    $error = $@ if $@;
  } else {
    $error ||= 'error';
    $error = "service daemon error:\n $error";
  }
  BSUtil::cleandir($odir);
  rmdir($odir);
  if ($linkfiles) {
    # argh, a link! put service run result in old filelist
    if (!$error) {
      $linkfiles->{$_} = $files->{$_} for grep {/^_service[_:]/} keys %$files;
    }
    $files = $linkfiles;
  }
  addrev_service($cgi, $rev, $files, $error);
  exit(0);
}

# ugly hack to support 'noservice' uploads. we fake a service run
# result and strip all files from the commit that look like they
# were generated by a service run.
sub servicemark_noservice {
  my ($cgi, $projid, $packid, $files, $target, $oldservicemark) = @_;

  my $servicemark;
  if (exists($cgi->{'servicemark'})) {
    $servicemark = $cgi->{'servicemark'};
  } else {
    # if not given via cgi, autodetect
    if ($oldservicemark && BSSrcrep::can_reuse_oldservicemark($projid, $packid, $files, $oldservicemark)) {
      $servicemark = $oldservicemark;
    } else {
      if ($files->{'_service'} || grep {/^_service[:_]/} keys %$files) {
        $servicemark = genservicemark($projid, $packid, $files, $target, 1);
      }
    }
  }
  return (undef, $files) unless $servicemark;

  # ok, fake a service run
  my $nfiles = { %$files };
  delete $nfiles->{$_} for grep {/^_service[:_]/} keys %$nfiles;
  fake_service_run($projid, $packid, $nfiles, $files, $servicemark);
  return ($servicemark, $nfiles);
}

# - returns expanded file list
# - side effects:
#   modifies $rev->{'srcmd5'}
sub handleservice {
  my ($rev, $files, $servicemark) = @_;

  my $lsrcmd5 = $rev->{'srcmd5'};
  $rev->{'srcmd5'} = $servicemark;

  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
  my $sfiles;
  if (BSSrcrep::existstree($projid, $packid, $servicemark)) {
    $sfiles = BSSrcrep::lsrev($rev);
  } elsif (! -e "$projectsdir/$projid.pkg/$packid.xml") {
    # not our own package (project link, remote...)
    # don't run service. try getrev/lsrev instead.
    my $rrev = $getrev->($rev->{'project'}, $rev->{'package'}, $servicemark);
    $sfiles = BSSrcrep::lsrev($rrev);
    if ($sfiles->{'_serviceerror'}) {
      my $serror = BSSrcrep::getserviceerror($rev->{'project'}, $rev->{'package'}, $servicemark) || 'unknown service error';
      die("$serror\n");
    }
  }
  if ($sfiles) {
    # tree is available, i.e. the service has finished
    if ($sfiles->{'_service_error'}) {
      # old style...
      my $error = BSSrcrep::repreadstr($rev, '_service_error', $sfiles->{'_service_error'});
      $error =~ s/[\r\n]+$//s;
      $error =~ s/.*[\r\n]//s;
      die(str2utf8xml($error ? "$error\n" : "unknown service error\n"));
    }
    return $sfiles;
  }
  # don't have the tree yet
  my $serror = BSSrcrep::getserviceerror($rev->{'project'}, $rev->{'package'}, $servicemark);
  die("$serror\n") if $serror;
  my %nfiles = %$files;
  $nfiles{'/SERVICE'} = $servicemark;
  $rev->{'srcmd5'} = $lsrcmd5;	# put it back so that runservice can put it in /LSRCMD5
  runservice({}, $rev, \%nfiles);
  $rev->{'srcmd5'} = $servicemark;
  die("service in progress\n");
}


# collect all global source services via all package and project links
sub getprojectservices {
  my ($projid, $packid, $revid, $packagefiles, $projectloop) = @_;
  my $services = {};

  # protection against loops and double matches
  $projectloop ||= {};
  return {} if $projectloop->{$projid};
  $projectloop->{$projid} = 1;

  # get source services from this project
  my $projectrev = $getrev->($projid, '_project');
  my $projectfiles = BSSrcrep::lsrev($projectrev);
  if ($projectfiles->{'_service'}) {
    $services = BSSrcrep::repreadxml($projectrev, '_service', $projectfiles->{'_service'}, $BSXML::services, 1) || {};
  }

  # find further projects via project link
  my $proj = BSRevision::readproj_local($projid, 1);
  for my $lprojid (map {$_->{'project'}} @{$proj->{'link'} || []}) {
    my ($lproj, $lpack);
    eval {
      $lproj = BSRevision::readproj_local($lprojid, 1);
      $lpack = $readpackage->($lprojid, $lproj, $packid, undef, 1);
    };
    if ($lpack) {
      my $as = getprojectservices($lprojid, $packid, $revid, undef, $projectloop);
      push @{$services->{'service'}}, @{$as->{'service'}} if $as && $as->{'service'};
    }
  }

  # find further projects via package link
  my $packagerev;
  if ($packagefiles) {
    # fake rev so that repreadxml works. packagefiles is set when called from addrev/genservicemark
    $packagerev = {'project' => $projid, 'package' => $packid};
  } else {
    eval {
       $packagerev = $getrev->($projid, $packid, $revid);
       $packagefiles = BSSrcrep::lsrev($packagerev);
    };
  }

  if ($packagerev && $packagefiles && $packagefiles->{'_link'}) {
    my $l = BSSrcrep::repreadxml($packagerev, '_link', $packagefiles->{'_link'}, $BSXML::link, 1);
    if ($l) {
      my $lprojid = defined($l->{'project'}) ? $l->{'project'} : $projid;
      my $lpackid = defined($l->{'package'}) ? $l->{'package'} : $packid;
      # honor project links
      my ($lproj, $lpack);
      eval {
	$lproj = BSRevision::readproj_local($lprojid, 1);
	$lpack = $readpackage->($lprojid, $lproj, $lpackid, undef, 1);
      };
      if ($lpack) {
	my $as = getprojectservices($lprojid, $lpackid, $l->{'rev'}, undef, $projectloop);
	push @{$services->{'service'}}, @{$as->{'service'}} if $as && $as->{'service'};
      }
    }
  }

  return $services;
}

1;

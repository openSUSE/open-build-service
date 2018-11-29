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
  my ($rev, $servicemark, $files, $error) = @_;

  if ($error) {
    chomp $error;
    $error ||= 'unknown service error';
  }
  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
  if (!$servicemark) {
    # old style, do a real commit
    if ($error) {
      mkdir_p($uploaddir);
      writestr("$uploaddir/_service_error$$", undef, "$error\n");
      $files->{'_service_error'} = BSSrcrep::addfile($projid, $packid, "$uploaddir/_service_error$$", '_service_error');
    }
    $addrev->({'user' => '_service', 'comment' => 'generated via source service', 'noservice' => 1}, $projid, $packid, $files);
    my $lockfile = "$eventdir/service/${projid}::$packid";
    unlink($lockfile);
    # addrev will notify the rep servers for us
    return;
  }
  # new style services
  if ($files->{'_service_error'} && !$error) {
    $error = BSRevision::revreadstr($rev, '_service_error', $files->{'_service_error'});
    chomp $error;
    $error ||= 'unknown service error';
  }
  if (!$error) {
    eval {
      BSSrcrep::addmeta_service($projid, $packid, $files, $servicemark, $rev->{'srcmd5'});
    };
    $error = $@ if $@;
  }
  if ($error) {
    BSSrcrep::addmeta_serviceerror($projid, $packid, $servicemark, $error);
    $error =~ s/[\r\n]+$//s;
    $error =~ s/.*[\r\n]//s;
    $error = str2utf8xml($error) || 'unknown service error';
  }
  my $user = $rev->{'user'};
  my $comment = $rev->{'comment'};
  my $requestid = $rev->{'requestid'};
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
    $error = BSRevision::revreadstr($rev, '_service_error', $sfiles->{'_service_error'});
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

  my $servicemark = delete $files->{'/SERVICE'};
  return if !$BSConfig::old_style_services && !$servicemark;

  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
  die("No project defined for source update!") unless defined $projid;
  die("No package defined for source update!") unless defined $packid;
  return if $packid eq '_project';
  return if $rev->{'rev'} && ($rev->{'rev'} eq 'repository' || $rev->{'rev'} eq 'upload');

  # check serialization
  return if $servicemark && !BSSrcrep::addmeta_serialize_servicerun($rev->{'project'}, $rev->{'package'}, $servicemark);

  # get last servicerun result into oldfiles hash
  my $oldfiles = {};
  my $oldfilesrev;
  if ($servicemark) {
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
	$oldfiles = BSRevision::lsrev($oldfilesrev, $linkinfo) || {};
	$oldfiles = handleservice($oldfilesrev, $oldfiles, $linkinfo->{'xservicemd5'}) if $linkinfo->{'xservicemd5'};
      };
      if ($@) {
        warn($@);
	undef $oldfiles;
	undef $oldfilesrev;
        next if $@ =~ /service in progress/;
      }
      $oldfiles = {} if !$oldfiles || $oldfiles->{'_service_error'};
      # strip all non-service results;
      delete $oldfiles->{$_} for grep {!/^_service:/} keys %$oldfiles;
      last;
    }
  }

  my $lockfile;		# old style service run lock
  if (!$servicemark) {
    $lockfile = "$eventdir/service/${projid}::$packid";
    # die when a source service is still running
    die("403 service still running\n") if $cgi->{'triggerservicerun'} && -e $lockfile;
  }

  my $projectservices;
  eval {
    $projectservices = getprojectservices($projid, $packid);
  };
  if ($@) {
    addrev_service($rev, $servicemark, $files, $@);
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
    addrev_service($rev, $servicemark, $files) if $dirty || $servicemark;
    return;
  }

  my $sendfiles = $files;	# files we send to the service daemon

  # expand links
  my $sendsrcmd5;
  if ($files->{'_link'}) {
    $sendfiles = { %$files };
    eval {
      my $lrev = {%$rev, 'ignoreserviceerrors' => 1};
      $sendfiles = BSSrcServer::Link::handlelinks($lrev, $sendfiles);
      die("bad link: $sendfiles\n") unless ref $sendfiles;
      $sendsrcmd5 = $lrev->{'srcmd5'};
    };
    if ($@) {
      addrev_service($rev, $servicemark, $files, $@);
      return;
    }
    # drop all sevice files
    delete $sendfiles->{$_} for grep {/^_service:/} keys %$sendfiles;
  }

  # handoff to dispatcher if configured
  if ($servicemark && $BSConfig::servicedispatch) {
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
      'job' => $servicemark,
      'srcmd5' => $rev->{'srcmd5'},
      'rev' => $rev->{'rev'},
    };
    $ev->{'linksrcmd5'} = $sendsrcmd5 if $sendsrcmd5;
    $ev->{'projectservicesmd5'} = $projectservicesmd5 if $projectservicesmd5;
    $ev->{'oldsrcmd5'} = $oldfilesrev->{'srcmd5'} if %$oldfiles && $oldfilesrev;
    mkdir_p("$eventdir/servicedispatch");
    my $evname = "servicedispatch:${projid}::${packid}::$rev->{'srcmd5'}::$servicemark";
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

  my @send = map {BSRevision::revcpiofile($rev, $_, $sendfiles->{$_})} sort(keys %$sendfiles);
  push @send, {'name' => '_serviceproject', 'data' => BSUtil::toxml($projectservices, $BSXML::services)} if $projectservices;
  push @send, map {BSRevision::revcpiofile($rev, $_, $oldfiles->{$_})} grep {!$sendfiles->{$_}} sort(keys %$oldfiles);

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
  
  if (!$servicemark) {
    # make sure that there was no other commit in the meantime, for old style only
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
          die($e || "empty .errors file\n");
        }
	die("service returned a non-_service file: $pfile\n") unless $pfile =~ /^_service[_:]/;
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
  addrev_service($rev, $servicemark, $files, $error);
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
    $sfiles = BSRevision::lsrev($rev);
  } elsif (! -e "$projectsdir/$projid.pkg/$packid.xml") {
    # not our own package (project link, remote...)
    # don't run service. try getrev/lsrev instead.
    my $rrev = $getrev->($rev->{'project'}, $rev->{'package'}, $servicemark);
    $sfiles = BSRevision::lsrev($rrev);
    if ($sfiles->{'_serviceerror'}) {
      my $serror = BSSrcrep::getserviceerror($rev->{'project'}, $rev->{'package'}, $servicemark) || 'unknown service error';
      die($serror eq 'service in progress' ? "$serror\n" : "service error: $serror\n");
    }
  }
  if ($sfiles) {
    # tree is available, i.e. the service has finished
    if ($sfiles->{'_service_error'}) {
      # old style...
      my $error = BSRevision::revreadstr($rev, '_service_error', $sfiles->{'_service_error'});
      $error =~ s/[\r\n]+$//s;
      $error =~ s/.*[\r\n]//s;
      die(str2utf8xml($error ? "service error: $error\n" : "unknown service error\n"));
    }
    return $sfiles;
  }
  # don't have the tree yet
  my $serror = BSSrcrep::getserviceerror($rev->{'project'}, $rev->{'package'}, $servicemark);
  if ($serror) {
    die($serror eq 'service in progress' ? "$serror\n" : "service error: $serror\n");
  }
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
  my $projectfiles = BSRevision::lsrev($projectrev);
  if ($projectfiles->{'_service'}) {
    $services = BSRevision::revreadxml($projectrev, '_service', $projectfiles->{'_service'}, $BSXML::services, 1) || {};
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
       $packagefiles = BSRevision::lsrev($packagerev);
    };
  }

  if ($packagerev && $packagefiles && $packagefiles->{'_link'}) {
    my $l = BSRevision::revreadxml($packagerev, '_link', $packagefiles->{'_link'}, $BSXML::link, 1);
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

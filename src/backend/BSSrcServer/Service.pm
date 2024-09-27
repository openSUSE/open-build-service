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
use BSRPC ':https';
use BSUtil;
use BSXML;
use BSRevision;
use BSSrcrep;
use BSVerify;
use BSCpio;

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

# used for old style services and obsscm commits
our $addrev = sub {
  die("BSSrcServer::Service::addrev not implemented\n");
};

our $addrev_obsscmproject = sub {
  die("BSSrcServer::Service::addrev_obsscmproject not implemented\n");
};

our $notify = sub {
};

our $notify_repservers = sub {
};

our $handlelinks = sub {
  die("BSSrcServer::Service::handlelinks not implemented\n");
};

our $commitobsscm = \&commitobsscm;


# check if a service run is needed for the upcoming commit
sub genservicemark {
  my ($projid, $packid, $files, $rev, $force) = @_;
  
  return undef if $BSConfig::old_style_services;

  return undef if $packid eq '_project';	# just in case...
  return undef if defined $rev;	# don't mark if upload/repository/internal
  return undef if $packid eq '_pattern' || $packid eq '_product';	# for now...
  return undef if $files->{'/SERVICE'};	# already marked

  # check if we really need to run the service
  my $projectservices = getprojectservices($projid, $packid, undef, $files);

  # Validate that at least one service is active server side
  my $active_service_found;
  for my $se (@{$projectservices->{'service'}||[]}) {
    $active_service_found = 1 if !defined($se->{'mode'}) || ($se->{'mode'} ne 'localonly' && $se->{'mode'} ne 'disabled' && $se->{'mode'} ne 'manual' && $se->{'mode'} ne 'buildtime');
  }
  if (!$active_service_found && $files->{'_service'}) {
    my $packagerev = {'project' => $projid, 'package' => $packid};
    my $services = BSRevision::revreadxml($packagerev, '_service', $files->{'_service'}, $BSXML::services, 1) || {};
    for my $se (@{$services->{'service'}||[]}) {
      $active_service_found = 1 if !defined($se->{'mode'}) || ($se->{'mode'} ne 'localonly' && $se->{'mode'} ne 'disabled' && $se->{'mode'} ne 'manual' && $se->{'mode'} ne 'buildtime');
    }
  }
  return undef unless defined($active_service_found);

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

#
# Send a notification of the service run result
#
sub notify_serviceresult {
  my ($rev, $error) = @_;
  if ($error) {
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
  my %ndata = (project => $rev->{'project'}, package => $rev->{'package'}, rev => $rev->{'rev'},
               user => $user, comment => $comment, requestid => $requestid);
  $ndata{'error'} = $error if $error;
  $notify->($error ? 'SRCSRV_SERVICE_FAIL' : 'SRCSRV_SERVICE_SUCCESS', \%ndata);
}

sub commitobsscm {
  my ($projid, $packid, $servicemark, $rev, $files) = @_;
  die("obs_scm_bridge must not return _service files\n") if grep {$_ eq '_serviceerror' || /^_service[:_]/} keys %$files;
  my $fd = BSSrcrep::lockobsscmfile($projid, $packid, $servicemark);
  my $data = BSSrcrep::readobsscmdata($projid, $packid, $servicemark);
  if (!$data || $data->{'run'} ne $rev->{'run'}) {
    close $fd;
    return undef;	# obsolete run
  }
  my $cgi = {};
  $cgi->{'user'} = $rev->{'user'} || $data->{'user'};
  $cgi->{'comment'} = $rev->{'comment'} || $data->{'comment'};
  $cgi->{'commitobsscm'} = 1;   # Hack
  my $info = $rev->{'_service_info'};
  chomp $info if $info;
  if ($info && $info =~ /\A[0-9a-f]{1,128}\z/s) {
    $cgi->{'comment'} = $cgi->{'comment'} ? "$cgi->{'comment'} " : '';
    $cgi->{'comment'} .= "[info=$rev->{'_service_info'}]";
  }
  my $newrev;
  if ($packid eq '_project') {
    $newrev = $addrev_obsscmproject->($cgi, $projid, $rev->{'cpiofd'});
  } else {
    $newrev = $addrev->($cgi, $projid, $packid, $files);
  }
  BSSrcrep::writeobsscmdata($projid, $packid, $servicemark, undef);	# frees lock
  if ($packid eq '_project') {
    $notify_repservers->('project', $projid);
  } else {
    $notify_repservers->('package', $projid, $packid);
  }
  return $newrev;
}

sub addrev_service_oldstyle {
  my ($projid, $packid, $files, $error) = @_;
  # old style, do a real commit
  if ($error) {
    mkdir_p($uploaddir);
    writestr("$uploaddir/_service_error$$", undef, "$error\n");
    $files->{'_service_error'} = BSSrcrep::addfile($projid, $packid, "$uploaddir/_service_error$$", '_service_error');
  }
  # addrev will notify the rep servers for us
  $addrev->({'user' => '_service', 'comment' => 'generated via source service', 'noservice' => 1}, $projid, $packid, $files);
  my $lockfile = "$eventdir/service/${projid}::$packid";
  unlink($lockfile);
}

# called from runservice when the service run is finished. it
# either does the service commit (old style), or creates the
# xsrcmd5 service revision (new style).
sub addrev_service {
  my ($rev, $servicemark, $files, $error, $lxservicemd5) = @_;

  if ($error) {
    chomp $error;
    $error ||= 'unknown service error';
  }
  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
  if (!$servicemark) {
    addrev_service_oldstyle($projid, $packid, $files, $error);
    return;
  }
  if ($files->{'_service_error'} && !$error) {
    $error = BSRevision::revreadstr($rev, '_service_error', $files->{'_service_error'});
    chomp $error;
    $error ||= 'unknown service error';
  }
  if (!$error) {
    eval {
      if ($rev->{'rev'} eq 'obsscm') {
	$commitobsscm->($projid, $packid, $servicemark, $rev, $files);
      } else {
	BSSrcrep::addmeta_service($projid, $packid, $files, $servicemark, $rev->{'srcmd5'}, $lxservicemd5);
      }
    };
    $error = $@ if $@;
  }
  BSSrcrep::addmeta_serviceerror($projid, $packid, $servicemark, $error) if $error;
  notify_serviceresult($rev, $error);
  if ($packid eq '_project') {
    $notify_repservers->('project', $projid) if $rev->{'rev'} ne 'obsscm' || $error;
  } else {
    $notify_repservers->('package', $projid, $packid) if $rev->{'rev'} ne 'obsscm' || $error;
  }
}

# store the faked result of a service run. Note that this is done before
# the addrev call that stores the reference to the run.
# only used for new style services. no notifications sent (the following
# addrev call will notify the rep servers)
sub fake_service_run {
  my ($projid, $packid, $files, $sfiles, $servicemark, $lxservicemd5) = @_;
  $files->{'/SERVICE'} = $servicemark;
  my $lsrcmd5 = BSSrcrep::calcsrcmd5($files);
  delete $files->{'/SERVICE'};
  my $error;
  if ($sfiles->{'_service_error'}) {
    # hmm, die instead?
    my $rev = { 'project' => $projid, 'package' => $packid, 'srcmd5' => $lsrcmd5 };
    $error = BSRevision::revreadstr($rev, '_service_error', $sfiles->{'_service_error'});
    chomp $error;
    $error ||= 'unknown service error';
  }
  if (!$error) {
    eval {
      BSSrcrep::addmeta_service($projid, $packid, $sfiles, $servicemark, $lsrcmd5, $lxservicemd5);
    };
    $error = $@ if $@;
  }
  BSSrcrep::addmeta_serviceerror($projid, $packid, $servicemark, $error) if $error;
}

sub genservicemark_obsscm {
  my ($projid, $packid) = @_;
  return Digest::MD5::md5_hex("obsscm/$projid/$packid");
}

sub generate_obs_scm_bridge_service {
  my ($data) = @_;
  die("bad obs_scm_bridge data\n") unless $data->{'name'} eq 'obs_scm_bridge' && $data->{'url'};
  my @params;
  push @params, { 'name' => 'url', '_content' => $data->{'url'} };
  push @params, { 'name' => 'projectmode', '_content' => '1' } if $data->{'projectmode'};
  push @params, { 'name' => 'projectscmsync', '_content' => $data->{'projectscmsync'} } if $data->{'projectscmsync'};
  my $services = { 
    'service' => [ { 'name' => 'obs_scm_bridge', 'param' => \@params } ],
  };
  return BSUtil::toxml($services, $BSXML::services);
}

# generate a pseudo revision for obsscm services
sub generate_obsscm_rev {
  my ($projid, $packid, $data) = @_;
  my $rev = { 'project' => $projid, 'package' => $packid, 'rev' => 'obsscm', 'run' => $data->{'run'}, 'user' => $data->{'user'}, 'comment' => $data->{'comment'}, '_service_info' => undef };
  return $rev;
}

sub runservice_obsscm {
  my ($cgi, $projid, $packid, $scmurl, $projectscmsync) = @_;
  die("Cannot use the scm bridge with old style services\n") if $BSConfig::old_style_services;
  my $servicemark = genservicemark_obsscm($projid, $packid);
  # generate random run id, store "in progress" marker with the run id
  my $run = Digest::MD5::md5_hex("obsscm/$projid/$packid/".time()."/$$\n");
  my $data = { 'name' => 'obs_scm_bridge', 'run' => $run, 'url' => $scmurl };
  $data->{'user'} = $cgi->{'user'} if $cgi->{'user'};
  $data->{'commit'} = $cgi->{'comment'} if $cgi->{'comment'};
  $data->{'projectmode'} = 1 if $packid eq '_project';
  $data->{'projectscmsync'} = $projectscmsync if $projectscmsync;
  my $fd = BSSrcrep::lockobsscmfile($projid, $packid, $servicemark);
  BSSrcrep::writeobsscmdata($projid, $packid, $servicemark, $data);
  close($fd);
  my $rev = generate_obsscm_rev($projid, $packid, $data);
  if ($BSConfig::servicedispatch) {
    writeservicedispatchevent($projid, $packid, $servicemark, $rev);
    return;
  }
  my $pid = xfork();
  return if $pid;
  # run the service
  my @send;
  push @send, { 'name' => '_service', 'data' => generate_obs_scm_bridge_service($data) };
  my $files = {};
  my $error = eval { doservicerpc($rev, $files, \@send, 1) };
  $error = $@ if $@;
  # commit the service run result
  addrev_service($rev, $servicemark, $files, $error);
  exit(0);
}

sub writeservicedispatchevent {
  my ($projid, $packid, $servicemark, $rev, $projectservices, $lxservicemd5, $oldfilesrev) = @_;
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
    'srcmd5' => $rev->{'rev'} eq 'obsscm' ? $rev->{'run'} : $rev->{'srcmd5'},
    'rev' => $rev->{'rev'},
    'time' => time(),
  };
  $ev->{'linksrcmd5'} = $lxservicemd5 if $lxservicemd5;
  $ev->{'projectservicesmd5'} = $projectservicesmd5 if $projectservicesmd5;
  $ev->{'oldsrcmd5'} = $oldfilesrev->{'srcmd5'} if $oldfilesrev;
  mkdir_p("$eventdir/servicedispatch");
  my $evname = "servicedispatch:${projid}::${packid}::$ev->{'srcmd5'}::$servicemark";
  $evname = "servicedispatch:::".Digest::MD5::md5_hex($evname) if length($evname) > 200;
  writexml("$eventdir/servicedispatch/.$evname.$$", "$eventdir/servicedispatch/$evname", $ev, $BSXML::event);
  BSUtil::ping("$eventdir/servicedispatch/.ping");
}

# create a cpio file from the service run result
sub writeresultascpio {
  my ($rev, $newfiles) = @_;
  mkdir_p($uploaddir);
  unlink("$uploaddir/obsscm.$$");
  my $cpiofd;
  open($cpiofd, '+>', "$uploaddir/obsscm.$$") || die("$uploaddir/obsscm.$$: $!\n");
  unlink("$uploaddir/obsscm.$$");
  $rev->{'cpiofd'} = $cpiofd;
  my @cpio;
  push @cpio, { 'name' => $_, 'file' => $newfiles->{$_}} for sort keys %$newfiles;
  BSCpio::writecpio($cpiofd, \@cpio);
  $cpiofd->flush();
}

# send the request to the service deamon and collect the result
# modifies the files hash
sub doservicerpc {
  my ($rev, $files, $send, $noprefix) = @_;

  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
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
      'cpiofiles' => $send,
      'directory' => $odir,
      'timeout'   => $BSConfig::service_timeout,
      'withmd5'   => 1,
      'receiver' => \&BSHTTP::cpio_receiver,
    }, undef, "timeout=$BSConfig::service_timeout");
  };

  if ($@ || !$receive) {
    BSUtil::cleandir($odir);
    rmdir($odir);
    my $error = $@ || 'error';
    die("Transient error for $projid/$packid: $error") if $error =~ /^5/;
    die("RPC error for $projid/$packid: $error") if $error !~ /^\d/;
    $error = "service daemon error:\n $error";
    return $error;
  }

  # update source repository with the result
  # drop all existing service files
  for (keys %$files) {
    delete $files->{$_} if /^_service[_:]/;
  }
  # find new service files
  my %newfiles;
  eval {
    die(readstr("$odir/.errors") || "empty .errors file\n") if -e "$odir/.errors";
    for my $pfile (sort(ls($odir))) {
      my $qfile = $pfile;
      if ($noprefix) {
	$qfile = $1 if $qfile =~ /^_service:.*:(.*?)$/s;
	next if $files->{$qfile};
	if ($qfile ne '_service_error' && $qfile =~ /^_service_/) {
	  if (exists($rev->{$qfile}) && -s "$odir/$pfile" < 100000) {
	    $rev->{$qfile} = readstr("$odir/$pfile");
	    next;
	  }
	  die("service returned forbidden file: $qfile\n");
	}
	die("service returned forbidden file: $qfile\n") if $qfile eq '_link' || $qfile eq '_meta';
      } else {
        die("service returned a non-_service file: $qfile\n") if $qfile !~ /^_service[_:]/;
      }
      BSVerify::verify_filename($qfile);
      $newfiles{$qfile} = "$odir/$pfile";
    }
  };
  my $error = $@;
  # get the error right away for obsscm runs
  if (!$error && $rev->{'rev'} eq 'obsscm' && $newfiles{'_service_error'}) {
    $error = readstr($newfiles{'_service_error'});
    chomp $error;
    $error ||= 'unknown service error';
  }
  # create cpio archive from new service files for project obsscm service runs
  if (!$error && $rev->{'rev'} eq 'obsscm' && $packid eq '_project') {
    writeresultascpio($rev, \%newfiles);
  }
  # add new service files to file list
  if (!$error && !$rev->{'cpiofd'}) {
    $files->{$_} = BSSrcrep::addfile($projid, $packid, $newfiles{$_}, $_) for sort keys %newfiles;
  }
  BSUtil::cleandir($odir);
  rmdir($odir);
  return $error;
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
  my $oldfiles;
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
      last;
    }
  }
  $oldfiles = {} if !$oldfiles || $oldfiles->{'_service_error'};
  # strip all non-service results;
  delete $oldfiles->{$_} for grep {!/^_service:/} keys %$oldfiles;

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
  my $lxservicemd5;
  if ($files->{'_link'}) {
    $sendfiles = { %$files };
    eval {
      my $lrev = {%$rev, 'ignoreserviceerrors' => 1};
      $sendfiles = $handlelinks->($lrev, $sendfiles);
      die("bad link: $sendfiles\n") unless ref $sendfiles;
      $lxservicemd5 = $lrev->{'srcmd5'};
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
    $oldfilesrev = undef if $oldfilesrev && !%$oldfiles;
    writeservicedispatchevent($projid, $packid, $servicemark, $rev, $projectservices, $lxservicemd5, $oldfilesrev);
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
  my $error = eval { doservicerpc($rev, $files, \@send) };
  $error = $@ if $@;
  
  if (!$servicemark) {
    # make sure that there was no other commit in the meantime, for old style only
    my $newrev = BSRevision::getrev_local($projid, $packid);
    if ($newrev && $newrev->{'rev'} ne $rev->{'rev'}) {
      unlink($lockfile) if $lockfile;
      exit(1);
    }
  }

  # commit the service run result
  addrev_service($rev, $servicemark, $files, $error, $lxservicemd5);
  exit(0);
}

# ugly hack to support 'noservice' uploads. we fake a service run
# result and strip all files from the commit that look like they
# were generated by a service run. There needs to be an addmeta
# call after this.
sub servicemark_noservice {
  my ($cgi, $projid, $packid, $files, $target, $oldservicemark, $lxservicemd5) = @_;

  my $servicemark;
  if (exists($cgi->{'servicemark'})) {
    $servicemark = $cgi->{'servicemark'};	# good luck!
  } else {
    # if not given via cgi, autodetect
    if ($oldservicemark && BSSrcrep::can_reuse_oldservicemark($projid, $packid, $files, $oldservicemark, $lxservicemd5)) {
      $servicemark = $oldservicemark;
    } else {
      if ($files->{'_service'} || grep {/^_service[:_]/} keys %$files) {
        $servicemark = genservicemark($projid, $packid, $files, $target, 1);
      }
    }
  }
  return (undef, $files) unless $servicemark;

  # ok, fake a service run
  my $lfiles = { %$files };
  delete $lfiles->{$_} for grep {/^_service[:_]/} keys %$lfiles;
  fake_service_run($projid, $packid, $lfiles, $files, $servicemark, $lxservicemd5);
  return ($servicemark, $lfiles);
}

# - returns expanded file list
# - side effects:
#   modifies $rev->{'srcmd5'}
sub handleservice {
  my ($rev, $files, $servicemark, $linkinfo) = @_;

  my $lsrcmd5 = $rev->{'srcmd5'};
  $rev->{'srcmd5'} = $servicemark;

  my $projid = $rev->{'project'};
  my $packid = $rev->{'package'};
  my $sfiles;
  if (BSSrcrep::existstree($projid, $packid, $servicemark)) {
    $sfiles = BSRevision::lsrev($rev, $linkinfo);
  } elsif (! -e "$projectsdir/$projid.pkg/$packid.xml") {
    # not our own package (project link, remote...)
    # don't run service. try getrev/lsrev instead.
    my $rrev = $getrev->($rev->{'project'}, $rev->{'package'}, $servicemark);
    $sfiles = BSRevision::lsrev($rrev, $linkinfo);
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

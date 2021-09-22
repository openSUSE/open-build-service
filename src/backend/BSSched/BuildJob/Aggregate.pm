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

package BSSched::BuildJob::Aggregate;

use strict;
use warnings;

use Digest::MD5 ();
use JSON::XS ();		# for containerinfo reading/writing

use BSUtil;
use BSXML;
use BSRPC;			# FIXME: only async calls, please
use Build;			# for query
use BSConfiguration;		# for $BSConfig::sign
use BSSched::BuildJob;
use BSSched::RPC;		# for is_transient_error
use BSSched::ProjPacks;		# for orderpackids
use BSVerify;			# for verify_nevraquery

my @binsufs = qw{rpm deb pkg.tar.gz pkg.tar.xz pkg.tar.zst};
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

my @binsufs_sign = qw{rpm pkg.tar.gz pkg.tar.xz pkg.tar.zst};
my $binsufsre_sign = join('|', map {"\Q$_\E"} @binsufs_sign);

=head1 NAME

BSSched::BuildJob::Aggregate - A Class to handle Aggregate

=head1 SYNOPSIS

my $h = BSSched::BuildJob::Aggregate->new()

$h->check();

$h->expand();

$h->rebuild();

=cut


=head2 new - TODO: add summary

 TODO: add description

=cut

sub new {
  return bless({}, $_[0]);
}

=head2 expand - TODO: add summary

 TODO: add description

=cut

sub expand {
  return 1, splice(@_, 3);
}


sub get_modulemd {
  my ($ctx) = @_;
  require Build::Modulemd;
  # we need to get the modularity data from the src server ;-(
  my @args;
  push @args, "project=$ctx->{'project'}", "package=$ctx->{'modularity_package'}", "srcmd5=$ctx->{'modularity_srcmd5'}", "arch=$ctx->{'gctx'}->{'arch'}";
  push @args, map {"module=$_"} @{$ctx->{'conf'}->{'modules'} || []};
  push @args, "modularityplatform=$ctx->{'modularity_platform'}";
  push @args, "modularitylabel=$ctx->{'modularity_label'}";
  my $param = {
    'uri' => "$BSConfig::srcserver/getmodulemd", 
    'timeout' => 300,
  };
  my $modulemd = BSRPC::rpc($param, \&BSUtil::fromstorable, @args);
  my @mds_good = grep {$_->{'document'} eq 'modulemd'} @$modulemd;
  die("need exactly one modulemd document\n") unless @mds_good == 1;
  my $mdd = $mds_good[0]->{'data'};
  die("no data element in modulemd\n") unless $mdd;
  delete $mdd->{'artifacts'};
  delete $mdd->{'license'}->{'content'} if $mdd->{'license'} && $mdd->{'license'}->{'content'};
  die("modulemd has no name\n") unless defined $mdd->{'name'};
  die("modulemd has no stream\n") unless defined $mdd->{'stream'};
  return $modulemd;
}

sub add_modulemd_artifact {
  my ($modulemd, $rpm) = @_;
  my $r = eval { Build::Rpm::query($rpm, 'evra' => 1, 'license' => 1, 'modularitylabel' => 1) };
  if ($@) {
    warn($@);
    return undef;
  }
  return undef unless $r->{'modularitylabel'};
  my @ml = split(':', $r->{'modularitylabel'});
  my $mdd = ((grep {$_->{'document'} eq 'modulemd'} @$modulemd)[0])->{'data'};
  # also check context?
  return undef unless $ml[0] eq $mdd->{'name'} && $ml[1] eq $mdd->{'stream'};
  $r->{'epoch'} ||= 0;
  my $nevra = "$r->{'name'}-$r->{'epoch'}:$r->{'version'}-$r->{'release'}.$r->{'arch'}";
  push  @{$mdd->{'artifacts'}->{'rpms'}}, $nevra unless grep {$_ eq $nevra} @{($mdd->{'artifacts'} || {})->{'rpms'} || []};
  my $license = $r->{'license'};
  if ($license) {
    my %licenses = map {$_ => 1} @{$mdd->{'license'}->{'content'} || []};
    if (!$licenses{$license}) {
      $licenses{$license} = 1;
      $mdd->{'license'}->{'content'} = [ sort keys %licenses ];
    }
  }
  return 1;
}

sub write_modulemd {
  my ($modulemd, $file) = @_;
  my $yaml = '';
  $yaml .= Build::Modulemd::mdtoyaml($_) for @$modulemd;
  writestr($file, undef, $yaml);
}

=head2 check - check if an aggregate needs to be rebuilt

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info) = @_;

  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $reporoot = $gctx->{'reporoot'};
  # clone it as we may patch the 'packages' array below
  my $aggregates = BSUtil::clone($pdata->{'aggregatelist'}->{'aggregate'} || []);
  my @broken;
  my @blocked;
  my $prpfinished = $gctx->{'prpfinished'};
  my $delayed;
  my %gbininfos;
  my $projpacks = $gctx->{'projpacks'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  for my $aggregate (@$aggregates) {
    my $aprojid = $aggregate->{'project'};
    my $proj = $remoteprojs->{$aprojid} || $projpacks->{$aprojid};
    if (!$proj) {
      push @broken, $aprojid;
      next;
    }
    if ($proj->{'error'}) {
      if (BSSched::RPC::is_transient_error($proj->{'error'})) {
	# XXX: hmm, there's already a project retryevent on $aprojid
	$gctx->{'retryevents'}->addretryevent({'type' => 'package', 'project' => $projid, 'package' => $packid});
	$delayed = 1;
      }
      push @broken, $aprojid;
      next;
    }
    if (!$ctx->checkprojectaccess($aprojid)) {
      push @broken, $aprojid;
      next;
    }
    my @arepoids = grep {!exists($_->{'target'}) || $_->{'target'} eq $repoid} @{$aggregate->{'repository'} || []};
    if (@arepoids) {
      @arepoids = map {$_->{'source'}} grep {exists($_->{'source'})} @arepoids;
    } else {
      @arepoids = ($repoid);
    }
    my @apackids = @{$aggregate->{'package'} || []};
    my $abinfilter;
    $abinfilter = { map {$_ => 1} @{$aggregate->{'binary'}} } if $aggregate->{'binary'};
    for my $arepoid (@arepoids) {
      my $aprp = "$aprojid/$arepoid";
      my $arepo = (grep {$_->{'name'} eq $arepoid} @{$proj->{'repository'} || []})[0];
      if (!$arepo || !grep {$_ eq $myarch} @{$arepo->{'arch'} || []}) {
	push @broken, $aprp;
	next;
      }
      next if !$remoteprojs->{$aprojid} && $prpfinished->{$aprp} && $aggregate->{'package'};    # no need to check blocked state
      # notready/prpnotready is indexed with source binary names, so we cannot use it here...
      my $ps = BSUtil::retrieve("$reporoot/$aprp/$myarch/:packstatus", 1);
      if (!$ps) {
	$ps = (readxml("$reporoot/$aprp/$myarch/:packstatus", $BSXML::packstatuslist, 1) || {})->{'packstatus'} || [];
	$ps = { 'packstatus' => { map {$_->{'name'} => $_->{'status'}} @$ps } };
      }
      $ps = ($ps || {})->{'packstatus'} || {};

      # for remote projects we always need the gbininfo
      if ($remoteprojs->{$aprojid}) {
	my $gbininfo = $ctx->read_gbininfo($aprp, $myarch, $ps);
	$gbininfos{"$aprp/$myarch"} = $gbininfo;
	if (!$gbininfo) {
	  $delayed = 1 if defined $gbininfo;
	  push @broken, $aprp;
	  next;
	}
      }

      if (!$aggregate->{'package'}) {
	# calculate apackids using the gbininfo file
	my $gbininfo;
	if ($remoteprojs->{$aprojid}) {
	  $gbininfo = $gbininfos{"$aprp/$myarch"};
	} else {
	  $gbininfo = $ctx->read_gbininfo($aprp);
	}
	if (!$gbininfo) {
	  push @broken, $aprp;
	  next;
	}
	for my $apackid (keys %$gbininfo) {
	  next if $apackid eq '_volatile';
	  my $bininfo = $gbininfo->{$apackid};
	  if ($abinfilter) {
	    next unless grep {defined($_->{'name'}) && $abinfilter->{$_->{'name'}}} values %$bininfo;
	  }
	  push @apackids, $apackid;
	}
	@apackids = BSUtil::unify(sort(@apackids));
	@apackids = BSSched::ProjPacks::orderpackids($proj, @apackids) if ($proj->{'kind'} || '') eq 'maintenance_release';
      }

      for my $apackid (@apackids) {
	if ($apackid eq '_repository') {
	  return ('broken', 'aggregating from a remote _repository is not implemented yet') if $remoteprojs->{$aprojid};
	  push @blocked, "$aprp/$apackid";	# see prpfinished check above
	  next;
	}
	my $code = $ps->{$apackid} || 'unknown';
	if ($code eq 'scheduled' || $code eq 'blocked' || $code eq 'finished') {
	  next if $aprojid eq $projid && $arepoid eq $repoid && $apackid eq $packid;
	  push @blocked, "$aprp/$apackid";
	}
      }
    }
    # patch in calculated package list
    $aggregate->{'package'} ||= \@apackids;
  }
  if (@broken) {
    my $error = 'missing repositories: '.join(', ', @broken);
    print "      - $packid (aggregate)\n";
    print "        broken ($error)\n";
    print "        (delayed)\n" if $delayed;
    return ('delayed', $error) if $delayed;
    return ('broken', $error);
  }
  if (@blocked) {
    splice(@blocked, 10, scalar(@blocked), '...') if @blocked > 10;
    print "      - $packid (aggregate)\n";
    print "        blocked (@blocked)\n";
    return ('blocked', join(', ', @blocked));
  }
  my @new_meta;
  for my $aggregate (@$aggregates) {
    my $aprojid = $aggregate->{'project'};
    my @apackids = @{$aggregate->{'package'} || []};
    my @arepoids = grep {!exists($_->{'target'}) || $_->{'target'} eq $repoid} @{$aggregate->{'repository'} || []};
    if (@arepoids) {
      @arepoids = map {$_->{'source'}} grep {exists($_->{'source'})} @arepoids;
    } else {
      @arepoids = ($repoid);
    }
    for my $arepoid (@arepoids) {
      for my $apackid (@apackids) {
        next if $aprojid eq $projid && $arepoid eq $repoid && $apackid eq $packid;
	return ('broken', 'cannot aggregate from our own repository') if $aprojid eq $projid && $arepoid eq $repoid && $apackid eq '_repository';
	my $m = '';
        my $havecontainer;
	if ($remoteprojs->{$aprojid}) {
	  my $bininfo = ($gbininfos{"$aprojid/$arepoid/$myarch"} || {})->{$apackid} || {};
	  for my $bin (sort {$a->{'filename'} cmp $b->{'filename'}} values %$bininfo) {
	    my $filename = $bin->{'filename'};
	    next unless $filename;
	    next unless $filename eq 'updateinfo.xml' || $filename =~ /\.(?:$binsufsre)$/ || $filename =~ /\.obsbinlnk$/;
	    $havecontainer = 1 if $filename =~ /\.obsbinlnk$/;
	    $m .= $bin->{'hdrmd5'} || $bin->{'md5sum'} || '';
	  }
	} else {
	  my $d = "$reporoot/$aprojid/$arepoid/$myarch/$apackid";
	  $d = "$reporoot/$aprojid/$arepoid/$myarch/:full" if $apackid eq '_repository';
	  my @d = grep {$_ eq 'updateinfo.xml' || /\.(?:$binsufsre)$/} ls($d);
	  for my $filename (sort @d) {
	    next unless $filename eq 'updateinfo.xml' || $filename =~ /\.(?:$binsufsre)$/ || $filename =~ /\.obsbinlnk$/;
	    $havecontainer = 1 if $filename =~ /\.obsbinlnk$/;
	    my @s = stat("$d/$filename");
	    $m .= "$filename\0$s[9]/$s[7]/$s[1]\0" if @s;
	  }
	}
	if ($havecontainer) {
	  # add state of tag
	  my $bconf = $ctx->{'conf'};
	  if ($bconf->{'substitute'}->{"aggregate-container-add-tag:$packid"}) {
	    $m .= "\0\0aggregate-container-add-tag\0".join("\0", @{$bconf->{'substitute'}->{"aggregate-container-add-tag:$packid"}});
	  }
	}
	$m = Digest::MD5::md5_hex($m)."  $aprojid/$arepoid/$myarch/$apackid";
	push @new_meta, $m;
      }
    }
  }
  my @meta;
  if (open(F, '<', "$reporoot/$projid/$repoid/$myarch/:meta/$packid")) {
    @meta = <F>;
    close F;
    chomp @meta;
  }
  if (join('\n', @meta) eq join('\n', @new_meta)) {
    print "      - $packid (aggregate)\n";
    print "        nothing changed\n";
    return ('done');
  }
  my @diff = BSSched::BuildJob::diffsortedmd5(\@meta, \@new_meta);
  print "      - $packid (aggregate)\n";
  print "        $_\n" for @diff;
  my $new_meta = join('', map {"$_\n"} @new_meta);
  return ('scheduled', [ $new_meta, $aggregates ]);
}

=head2 build - start an aggregate build

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;

  my $new_meta = $data->[0];
  my $aggregates = $data->[1];
  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $prp = "$projid/$repoid";
  my $job = BSSched::BuildJob::jobname($prp, $packid);
  my $myjobsdir = $gctx->{'myjobsdir'};
  return ('scheduled', $job) if -s "$myjobsdir/$job";
  my $reporoot = $gctx->{'reporoot'};
  my $remoteprojs = $gctx->{'remoteprojs'};
  my $jobdatadir = "$myjobsdir/$job:dir";
  unlink "$jobdatadir/$_" for ls($jobdatadir);
  mkdir_p($jobdatadir);
  my $jobrepo = {};
  my %jobbins;
  my $error;
  my $modulemd;
  my $have_modulemd_artifacts;
  if ($ctx->{'modularity_label'}) {
    $modulemd = eval { get_modulemd($ctx) };
    if ($@) {
      warn($@);
      chomp $@;
      return ('broken', $@);
    }
  }
  for my $aggregate (@$aggregates) {
    my $aprojid = $aggregate->{'project'};
    my @arepoids = grep {!exists($_->{'target'}) || $_->{'target'} eq $repoid} @{$aggregate->{'repository'} || []};
    if (@arepoids) {
      @arepoids = map {$_->{'source'}} grep {exists($_->{'source'})} @arepoids;
    } else {
      @arepoids = ($repoid);
    }
    my @apackids = @{$aggregate->{'package'} || []};
    my $abinfilter;
    $abinfilter = { map {$_ => 1} @{$aggregate->{'binary'}} } if $aggregate->{'binary'};
    for my $arepoid (reverse @arepoids) {
      for my $apackid (@apackids) {
        next if $aprojid eq $projid && $arepoid eq $repoid && $apackid eq $packid;
	my @d;
	my $cpio;
	my $nosource = exists($aggregate->{'nosources'}) ? 1 : 0;
	my $updateinfo;
	if ($remoteprojs->{$aprojid}) {
	  my $param = {
	    'uri' => "$remoteprojs->{$aprojid}->{'remoteurl'}/build/$remoteprojs->{$aprojid}->{'remoteproject'}/$arepoid/$myarch/$apackid",
	    'receiver' => \&BSHTTP::cpio_receiver,
	    'directory' => $jobdatadir,
	    'map' => "upload:",
	    'timeout' => 300,
	    'proxy' => $gctx->{'remoteproxy'},
	  };
	  my $done;
	  if ($nosource) {
	    eval {
	      $cpio = BSRPC::rpc($param, undef, "view=cpio", "nosource=1");
	    };
	    $done = 1 if !$@ || $@ !~ /nosource/;
	  }
	  eval {
	    $cpio = BSRPC::rpc($param, undef, "view=cpio");
	  } unless $done;
	  if ($@) {
	    warn($@);
	    $error = $@;
	    chomp $error;
	    $gctx->{'retryevents'}->addretryevent({'type' => 'repository', 'project' => $aprojid, 'repository' => $arepoid, 'arch' => $myarch}) if BSSched::RPC::is_transient_error($error);
	    last;
	  }
	  @d = map {"$jobdatadir/$_->{'name'}"} @{$cpio || []};
	  $nosource = 1 if -e "$jobdatadir/upload:.nosourceaccess";
	} else {
	  my $dir = "$reporoot/$aprojid/$arepoid/$myarch/$apackid";
	  $dir = "$reporoot/$aprojid/$arepoid/$myarch/:full" if $apackid eq '_repository';
	  @d = map {"$dir/$_"} sort(ls($dir));
	  $nosource = 1 if -e "$dir/.nosourceaccess";
	}

	my $copysources;
	my @sources;
	for my $d (@d) {
	  my @s = stat($d);
	  next unless @s;
	  my $filename = $d;
	  $filename =~ s/.*\///;
	  $filename =~ s/^upload:// if $cpio;
	  if ($filename eq 'updateinfo.xml') {
	    next if $abinfilter && !$abinfilter->{$filename};
	    next if $jobbins{$filename};  # first one wins
	    $jobbins{$filename} = 1;
	    BSUtil::cp($d, "$jobdatadir/$filename");
	    next;
	  }
          if ($filename =~ /\.obsbinlnk$/) {
	    my $r = BSUtil::retrieve($d, 1);
	    next unless $r;
	    next if $abinfilter && !$abinfilter->{$r->{'name'}};
	    next if $jobbins{$filename};  # first one wins
	    next unless $r->{'name'} =~ /^container:/;

	    my $dir = $d;
	    $dir =~ s/\/[^\/]*$//;
	    my $containerinfofile = $filename;
	    $containerinfofile =~ s/\.obsbinlnk$/\.containerinfo/;
	    next if $jobbins{$containerinfofile};  # oops?
	    my $prefix = $cpio ? 'upload:' : '';
	    my $containerinfo = readcontainerinfo($dir, "$prefix$containerinfofile");
	    next unless $containerinfo;
	    for my $blobid (@{$containerinfo->{'tar_blobids'} || []}) {
	      if (-e "$dir/${prefix}_blob.$blobid") {
		next if $jobbins{"_blob.$blobid"};	# already have that blob
		link("$dir/${prefix}_blob.$blobid", "$jobdatadir/_blob.$blobid") || die("link $dir/${prefix}_blob.$blobid $jobdatadir/_blob.$blobid: $!\n");
	        $jobbins{"_blob.$blobid"} = 1;
	      }
	    }
	    my $containerfile = $containerinfo->{'file'};
	    # do we need to copy the container file?
	    if (!$containerinfo->{'tar_blobids'} || grep {!$jobbins{"_blob.$_"}} @{$containerinfo->{'tar_blobids'}}) {
	      if (-e "$dir/$prefix$containerfile") {
	        BSUtil::cp("$dir/$prefix$containerfile", "$jobdatadir/$containerfile");
	        $jobbins{$containerfile} = 1;
	      }
	      if (-e "$dir/$prefix$containerfile.sha256") {
	        BSUtil::cp("$dir/$prefix$containerfile.sha256", "$jobdatadir/$containerfile.sha256");
	        $jobbins{"$containerinfofile.sha256"} = 1;
	      }
	    }
	    # hack to add a container tag with the attribute
	    my $bconf = $ctx->{'conf'};
	    if ($bconf->{'substitute'}->{"aggregate-container-add-tag:$packid"}) {
	      my @regtags = @{$bconf->{'substitute'}->{"aggregate-container-add-tag:$packid"}};
	      for my $tag (@regtags) {
		$tag = "$tag:latest" unless $tag =~ /:[^:\/]+$/s;
		push @{$r->{'provides'}}, "container:$tag" unless grep {$_ eq "container:$tag"} @{$r->{'provides'} || []};
		push @{$containerinfo->{'tags'}}, $tag unless grep {$_ eq $tag} @{$containerinfo->{'tags'} || []};
	      }
	    }
	    writecontainerinfo("$jobdatadir/$containerinfofile", undef, $containerinfo);
	    $jobbins{$containerinfofile} = 1;
	    $r->{'path'} = "../$packid/$containerfile";
	    BSUtil::store("$jobdatadir/$filename", undef, $r);
	    $jobbins{$filename} = 1;
	    next;
	  }
	  next unless $filename =~ /\.(?:$binsufsre)$/;
	  $filename =~ s/^::import::.*?:://;
	  my $r;
	  eval {
	    $r = Build::query($d, 'evra' => 1);
	    BSVerify::verify_nevraquery($r) if $r;
	    $r->{'id'} = "$s[9]/$s[7]/$s[1]";
	  };
	  next unless $r;
	  next if $abinfilter && !$abinfilter->{$r->{'name'}};
	  if (!$r->{'source'}) {
	    # this is a source binary
	    push @sources, [ $d, $r, $filename ];
	    next;
	  }
	  next unless $r->{'source'};
	  # FIXME: How is debian handling debug packages ?
	  next if $nosource && ($r->{'name'} =~ /-debug(:?info|source)?$/);
	  next if $jobbins{$filename};  # first one wins
	  next if $modulemd && !add_modulemd_artifact($modulemd, $d);
	  $have_modulemd_artifacts = 1 if $modulemd;
	  $jobbins{$filename} = 1;
	  BSUtil::cp($d, "$jobdatadir/$filename");
	  $jobrepo->{"$jobdatadir/$filename"} = $r;
	  $copysources = 1 unless $nosource;
	}
	@sources = () unless $copysources;
	for my $d (@sources) {
	  my $r = $d->[1];
	  my $filename = $d->[2];
	  $d = $d->[0];
	  next if $jobbins{$filename};  # first one wins
	  $jobbins{$filename} = 1;
	  BSUtil::cp($d, "$jobdatadir/$filename");
	  $jobrepo->{"$jobdatadir/$filename"} = $r;
	}
	# delete upload files
	unlink("$jobdatadir/$_->{'name'}") for @{$cpio || []};
      }
      last if $error;
    }
    last if $error;
  }
  if ($error) {
    print "        $error\n";
    BSUtil::cleandir($jobdatadir);
    rmdir($jobdatadir);
    return ('failed', $error);
  }
  write_modulemd($modulemd, "$jobdatadir/_modulemd.yaml") if $modulemd && $have_modulemd_artifacts;
  writestr("$jobdatadir/meta", undef, $new_meta);
  my $needsign;
  $needsign = 1 if $BSConfig::sign && grep {/\.(?:$binsufsre_sign)$/} keys %$jobrepo;
  BSSched::BuildJob::fakejobfinished($ctx, $packid, $job, 'succeeded', { 'file' => '_aggregate' }, $needsign);
  print "        scheduled\n";
  return ('scheduled', $job);
}

=head2 jobfinished - job finished event handler for aggregates

 TODO: add description

=cut

sub jobfinished {
  my ($ectx, $job, $info, $js) = @_;

  my $gctx = $ectx->{'gctx'};

  my $changed = $gctx->{'changed_med'};
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $myarch = $gctx->{'arch'};
  my $jobdatadir = "$myjobsdir/$job:dir";
  if (! -d $jobdatadir) {
    print "  - $job has no data dir\n";
    return;
  }
  my $projid = $info->{'project'};
  my $repoid = $info->{'repository'};
  my $packid = $info->{'package'};
  my $projpacks = $gctx->{'projpacks'};
  if (!$projpacks->{$projid}) {
    print "  - $job belongs to an unknown project\n";
    return;
  }
  my $pdata = ($projpacks->{$projid}->{'package'} || {})->{$packid};
  if (!$pdata) {
    print "  - $job belongs to an unknown package, discard\n";
    return;
  }

  my $prp = "$projid/$repoid";
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  my $dst = "$gdst/$packid";
  mkdir_p($dst);
  print "  - $prp: $packid aggregate built\n";
  my $useforbuildenabled = 1;
  $useforbuildenabled = BSUtil::enabled($repoid, $projpacks->{$projid}->{'useforbuild'}, $useforbuildenabled, $myarch);
  $useforbuildenabled = BSUtil::enabled($repoid, $pdata->{'useforbuild'}, $useforbuildenabled, $myarch);
  my $prpsearchpath = $gctx->{'prpsearchpath'}->{$prp};
  my $dstcache = $ectx->{'dstcache'};
  BSSched::BuildResult::update_dst_full($gctx, $prp, $packid, $jobdatadir, undef, $useforbuildenabled, $prpsearchpath, $dstcache);
  $changed->{$prp} = 2 if $useforbuildenabled;
  my $repounchanged = $gctx->{'repounchanged'};
  delete $repounchanged->{$prp} if $useforbuildenabled;
  $repounchanged->{$prp} = 2 if $repounchanged->{$prp};
  $changed->{$prp} ||= 1;
  unlink("$gdst/:repodone");
  # no logfile/status for aggregates
  unlink("$gdst/:logfiles.fail/$packid");
  unlink("$gdst/:logfiles.success/$packid");
  unlink("$dst/logfile");
  unlink("$dst/status");
  # update meta
  mkdir_p("$gdst/:meta");
  rename("$jobdatadir/meta", "$gdst/:meta/$packid") || die("rename $jobdatadir/meta $gdst/:meta/$packid: $!\n");
  BSSched::BuildJob::patchpackstatus($gctx, $prp, $packid, 'succeeded', $job);
  $info->{'packstatus_patched'} = 1;
}

sub readcontainerinfo {
  my ($dir, $containerinfo) = @_;
  return undef unless -e "$dir/$containerinfo";
  return undef unless (-s _) < 100000;
  my $m = readstr("$dir/$containerinfo");
  my $d;
  eval { $d = JSON::XS::decode_json($m); };
  return undef unless $d && ref($d) eq 'HASH';
  return $d;
}

sub writecontainerinfo {
  my ($fn, $fnf, $containerinfo) = @_;
  my $containerinfo_json = JSON::XS->new->utf8->canonical->pretty->encode($containerinfo);
  writestr($fn, $fnf, $containerinfo_json);
}


1;

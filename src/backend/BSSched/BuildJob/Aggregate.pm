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

use Storable;		# for dclone
use Digest::MD5 ();

use BSUtil;
use BSXML;
use BSRPC;			# FIXME: only async calls, please
use BSSched::BuildJob;
use BSSched::RPC;
use BSConfiguration;		# for $BSConfig::sign
use BSVerify;			# for verify_nevraquery
use Build;			# for query

my @binsufs = qw{rpm deb pkg.tar.gz pkg.tar.xz AppImage};
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

my @binsufs_sign = qw{rpm pkg.tar.gz pkg.tar.xz AppImage};
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
  my $aggregates = Storable::dclone($pdata->{'aggregatelist'}->{'aggregate'} || []);
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
      }

      for my $apackid (@apackids) {
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
    print "      - $packid (aggregate)\n";
    if (@blocked < 11) {
      print "        blocked (@blocked)\n";
    } else {
      print "        blocked (@blocked[0..9] ...)\n";
    }
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
	my $m = '';
	if ($remoteprojs->{$aprojid}) {
	  my $bininfo = ($gbininfos{"$aprojid/$arepoid/$myarch"} || {})->{$apackid} || {};
	  for my $b (sort {$a->{'filename'} cmp $b->{'filename'}} values %$bininfo) {
	    next unless $b->{'filename'} && ($b->{'filename'} eq 'updateinfo.xml' || $b->{'filename'} =~ /\.(?:$binsufsre)$/);
	    $m .= $b->{'hdrmd5'} || $b->{'md5sum'} || '';
	  }
	} else {
	  next if $aprojid eq $projid && $arepoid eq $repoid && $apackid eq $packid;
	  my $d = "$reporoot/$aprojid/$arepoid/$myarch/$apackid";
	  my @d = grep {$_ eq 'updateinfo.xml' || /\.(?:$binsufsre)$/} ls($d);
	  for my $b (sort @d) {
	    my @s = stat("$d/$b");
	    next unless @s;
	    $m .= "$b\0$s[9]/$s[7]/$s[1]\0";
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
	  for my $bin (@{$cpio || []}) {
	    $updateinfo = "$jobdatadir/$bin->{'name'}" if $bin->{'name'} eq 'upload:updateinfo.xml';
	    push @d, "$jobdatadir/$bin->{'name'}";
	  }
	} else {
	  next if $aprojid eq $projid && $arepoid eq $repoid && $apackid eq $packid;
	  my $d = "$reporoot/$aprojid/$arepoid/$myarch/$apackid";
	  $updateinfo = "$d/updateinfo.xml" if -f "$d/updateinfo.xml";
	  @d = grep {/\.(?:$binsufsre)$/} ls($d);
	  @d = map {"$d/$_"} sort(@d);
	  $nosource = 1 if -e "$d/.nosourceaccess";
	}
	my $ajobrepo = bins2repo(@d);
	my $copysources;
	for my $abin (sort keys %$ajobrepo) {
	  my $r = $ajobrepo->{$abin};
	  next unless $r->{'source'};
	  next if $abinfilter && !$abinfilter->{$r->{'name'}};
	  # FIXME: How is debian handling debug packages ?
	  next if $nosource && ($r->{'name'} =~ /-debug(:?info|source)?$/);
	  my $basename = $abin;
	  $basename =~ s/.*\///;
	  $basename =~ s/^upload:// if $cpio;
	  $basename =~ s/^::import::.*?:://;
	  next if $jobbins{$basename};  # first one wins
	  $jobbins{$basename} = 1;
	  BSUtil::cp($abin, "$jobdatadir/$basename");
	  $jobrepo->{"$jobdatadir/$basename"} = $r;
	  $copysources = 1 unless $nosource;
	}
	if ($updateinfo && !($abinfilter && !$abinfilter->{'updateinfo.xml'})) {
	  BSUtil::cp($updateinfo, "$jobdatadir/updateinfo.xml");
	}
	if ($copysources) {
	  for my $abin (sort keys %$ajobrepo) {
	    my $r = $ajobrepo->{$abin};
	    next if $r->{'source'};
	    my $basename = $abin;
	    $basename =~ s/.*\///;
	    $basename =~ s/^upload:// if $cpio;
	    BSUtil::cp($abin, "$jobdatadir/$basename");
	    $jobrepo->{"$jobdatadir/$basename"} = $r;
	  }
	}
	for my $bin (@{$cpio || []}) {
	  unlink("$jobdatadir/$bin->{'name'}");
	}
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
  writestr("$jobdatadir/meta", undef, $new_meta);
  my $needsign;
  $needsign = 1 if $BSConfig::sign && grep {/\.(?:$binsufsre_sign)$/} keys %$jobrepo;
  BSSched::BuildJob::fakejobfinished($ctx, $packid, $job, 'succeeded', { 'file' => '_aggregate' }, $needsign);
  print "        scheduled\n";
  return ('scheduled', $job);
}

=head2 bins2repo - query a list of binaries

 TODO: add description

=cut

sub bins2repo {
  my (@bins) = @_;

  @bins = grep {/\.(?:$binsufsre)$/} @bins;
  my $repobins = {};
  for my $bin (@bins) {
    my @s = stat($bin);
    next unless @s;
    my $id = "$s[9]/$s[7]/$s[1]";
    my $data = Build::query($bin, 'evra' => 1);  # need arch
    next unless $data;
    eval {
      BSVerify::verify_nevraquery($data);
    };
    next if $@;
    delete $data->{'disttag'};
    $data->{'id'} = $id;
    $repobins->{$bin} = $data;
  }
  return $repobins;
}


=head2 jobfinished - job finished event handler for aggregates

 TODO: add description

=cut

sub jobfinished {
  my ($ectx, $job, $js) = @_;

  my $gctx = $ectx->{'gctx'};

  my $changed = $gctx->{'changed_med'};
  my $myjobsdir = $gctx->{'myjobsdir'};
  my $myarch = $gctx->{'arch'};
  my $info = readxml("$myjobsdir/$job", $BSXML::buildinfo, 1);
  my $jobdatadir = "$myjobsdir/$job:dir";
  if (!$info || ! -d $jobdatadir) {
    print "  - $job is bad\n";
    return;
  }
  if ($info->{'arch'} ne $myarch) {
    print "  - $job has bad arch\n";
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
  BSSched::BuildJob::patchpackstatus($gctx, $prp, $packid, 'succeeded');
}

1;

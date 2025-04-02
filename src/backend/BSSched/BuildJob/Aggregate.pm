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
use POSIX;

use BSOBS;
use BSUtil;
use BSXML;
use BSRPC;			# FIXME: only async calls, please
use Build;			# for query
use BSConfiguration;		# for $BSConfig::sign
use BSSched::BuildJob;
use BSSched::RPC;		# for is_transient_error
use BSSched::ProjPacks;		# for orderpackids
use BSVerify;			# for verify_nevraquery

my @binsufs = @BSOBS::binsufs;
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
    return 0;
  }
  return -1 unless $r->{'modularitylabel'};
  my @ml = split(':', $r->{'modularitylabel'});
  my $mdd = ((grep {$_->{'document'} eq 'modulemd'} @$modulemd)[0])->{'data'};
  # also check context?
  return 0 unless $ml[0] eq $mdd->{'name'} && $ml[1] eq $mdd->{'stream'};
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
    if (!$proj || $proj->{'error'}) {
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
      my $ps = {};

      # for remote projects we always need the gbininfo
      if ($remoteprojs->{$aprojid}) {
	my $gbininfo = $ctx->read_gbininfo($aprp, $myarch, $ps);
	$gbininfos{"$aprp/$myarch"} = $gbininfo;
	if (!$gbininfo) {
	  $delayed = 1 if defined $gbininfo;
	  push @broken, $aprp;
	  next;
	}
      } else {
        $ps = $ctx->read_packstatus($aprp, $myarch);
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
	  if ($remoteprojs->{$aprojid}) {
	    return ('broken', 'need a binary filter for remote _repository aggregates') unless @{$aggregate->{'binary'} || []};
	    for (grep {$_} values %$ps) {
	      if ($_ eq 'scheduled' || $_ eq 'blocked' || $_ eq 'finished') {
	        push @blocked, "$aprp/$apackid";
		last;
	      }
	    }
	  } else {
	    push @blocked, "$aprp/$apackid";	# see prpfinished check above
	  }
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
    if ($delayed) {
      print "        delayed ($error)\n";
      return ('delayed', $error);
    }
    print "        broken ($error)\n";
    return ('broken', $error);
  }
  if (@blocked) {
    splice(@blocked, 10, scalar(@blocked), '...') if @blocked > 10;
    print "      - $packid (aggregate)\n";
    print "        blocked (@blocked)\n";
    return ('blocked', join(', ', @blocked));
  }
  my @new_meta = ($pdata->{'verifymd5'} || $pdata->{'srcmd5'})."  $packid";
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
	  for my $bin (sort {($a->{'filename'} || '') cmp ($b->{'filename'} || '')} values %$bininfo) {
	    my $filename = $bin->{'filename'};
	    next unless $filename;
	    next unless $filename eq 'updateinfo.xml' || $filename =~ /\.(?:$binsufsre)$/ || $filename =~ /\.obsbinlnk$/;
	    $havecontainer = 1 if $filename =~ /\.obsbinlnk$/;
	    $m .= $bin->{'hdrmd5'} || $bin->{'md5sum'} || '';
	  }
	} else {
	  my $d = "$reporoot/$aprojid/$arepoid/$myarch/$apackid";
	  $d = "$reporoot/$aprojid/$arepoid/$myarch/:full" if $apackid eq '_repository';
	  for my $filename (sort(ls($d))) {
	    next unless $filename eq 'updateinfo.xml' || $filename =~ /\.(?:$binsufsre)$/ || $filename =~ /\.(?:obsbinlnk|helminfo)$/;
	    $havecontainer = 1 if $filename =~ /\.(?:obsbinlnk|helminfo)$/;
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

sub copy_provenance {
  my ($jobdatadir, $dirprefix, $d, $filename, $jobbins, $aprpap_idx) = @_;
  die unless $d =~ s/\.(?:$binsufsre|containerinfo|helminfo)$/.slsa_provenance.json/;
  my $provenance = $filename;
  die unless $provenance =~ s/\.(?:$binsufsre|containerinfo|helminfo)$/.slsa_provenance.json/;
  if (-e $d) {
    BSUtil::cp($d, "$jobdatadir/$provenance");
    $jobbins->{$provenance} = $aprpap_idx;
    return $provenance;
  } elsif (-e "${dirprefix}_slsa_provenance.json") {
    BSUtil::cp("${dirprefix}_slsa_provenance.json", "$jobdatadir/$provenance");
    $jobbins->{$provenance} = $aprpap_idx;
    return $provenance;
  }
  return undef;
}

# hack to add a container tag with the attribute
sub tweak_container_tags {
  my ($bconf, $containerinfo, $r, $packid) = @_;
  if ($bconf->{'substitute'}->{"aggregate-container-add-tag:$packid"}) {
    my @regtags = @{$bconf->{'substitute'}->{"aggregate-container-add-tag:$packid"}};
    for my $tag (@regtags) {
      $tag = "$tag:latest" unless $tag =~ /:[^:\/]+$/s;
      push @{$r->{'provides'}}, "container:$tag" if $r && !grep {$_ eq "container:$tag"} @{$r->{'provides'} || []};
      push @{$containerinfo->{'tags'}}, $tag unless grep {$_ eq $tag} @{$containerinfo->{'tags'} || []};
      # XXX we should actually update the manifest.json file so that it reflects the tag change
    }
  }
}

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;

  my ($new_meta, $aggregates) = @$data;
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
  my %jobbins;
  my $error;
  my $logfile = '';
  $logfile .= "scheduler started \"build _aggregate\" at ".POSIX::ctime(time())."\n";
  $logfile .= "Building $packid for project '$projid' repository '$repoid' arch '$myarch' srcmd5 '$pdata->{'srcmd5'}'\n\n";
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
  my %conflicts;
  my @aprpap_idx = ( undef );

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
	  my $remoteproj = $remoteprojs->{$aprojid};
	  my @args = 'view=cpio';
	  push @args, 'noajax=1' if $remoteproj->{'partition'};
	  push @args, map {"binary=$_"} @{$aggregate->{'binary'}} if $apackid eq '_repository' && $aggregate->{'binary'};
	  my $param = {
	    'uri' => "$remoteproj->{'remoteurl'}/build/$remoteproj->{'remoteproject'}/$arepoid/$myarch/$apackid",
	    'receiver' => \&BSHTTP::cpio_receiver,
	    'directory' => $jobdatadir,
	    'map' => "upload:",
	    'timeout' => 300,
	    'proxy' => $gctx->{'remoteproxy'},
	  };
	  my $done;
	  if ($nosource) {
	    eval {
	      $cpio = BSRPC::rpc($param, undef, @args, 'nosource=1');
	    };
	    $done = 1 if !$@ || $@ !~ /nosource/;
	  }
	  eval {
	    $cpio = BSRPC::rpc($param, undef, @args);
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

	my $aprpap = "$aprojid/$arepoid/$myarch/$apackid";

        # save some mem by using a number instead of a string
	my $aprpap_idx = scalar(@aprpap_idx);
	push @aprpap_idx, $aprpap;
	
	$logfile .= "$aprpap\n" if @d;

	my $copysources;
	my @sources;
	my $dirprefix = $cpio ? "$jobdatadir/upload:" : "$reporoot/$aprpap/";
	for my $d (@d) {
	  my @s = stat($d);
	  next unless @s;
	  my $filename = $d;
	  $filename =~ s/.*\///;
	  $filename =~ s/^upload:// if $cpio;
	  if ($filename eq 'updateinfo.xml') {
	    next if $abinfilter && !$abinfilter->{$filename};
	    if ($jobbins{$filename}) {
	      push @{$conflicts{$filename}}, $aprpap_idx;
	      next;  # first one wins
	    }
	    $jobbins{$filename} = $aprpap_idx;
	    BSUtil::cp($d, "$jobdatadir/$filename");
	    $logfile .= "  - $filename [$s[9]/$s[7]/$s[1]]\n";
	    next;
	  }
          if ($filename =~ /\.obsbinlnk$/) {
	    my $r = BSUtil::retrieve($d, 1);
	    next unless $r;
	    next if $abinfilter && !$abinfilter->{$r->{'name'}};
	    if ($jobbins{$filename}) {
	      push @{$conflicts{$filename}}, $aprpap_idx;
	      next;  # first one wins
	    }
	    next unless $r->{'name'} =~ /^container:/;

	    $logfile .= "  - $filename [$s[9]/$s[7]/$s[1]]\n";

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
	        $jobbins{"_blob.$blobid"} = $aprpap_idx;
	        $logfile .= "      - _blob.$blobid\n";
	      }
	    }
	    my $containerfile = $containerinfo->{'file'};
	    # do we need to copy the container tar file?
	    if (!$containerinfo->{'tar_blobids'} || grep {!$jobbins{"_blob.$_"}} @{$containerinfo->{'tar_blobids'}}) {
	      if (-e "$dir/$prefix$containerfile") {
	        BSUtil::cp("$dir/$prefix$containerfile", "$jobdatadir/$containerfile");
	        $jobbins{$containerfile} = $aprpap_idx;
	        $logfile .= "      - $containerfile\n";
	      }
	      if (-e "$dir/$prefix$containerfile.sha256") {
	        BSUtil::cp("$dir/$prefix$containerfile.sha256", "$jobdatadir/$containerfile.sha256");
	        $jobbins{"$containerinfofile.sha256"} = $aprpap_idx;
	        $logfile .= "      - $containerfile.sha256\n";
	      }
	    }
	    # copy extra data like .packages or .basepackages
	    my $extraprefix = $containerinfofile;
	    $extraprefix =~ s/\.containerinfo//;
	    my @extra = ('.spdx.json', '.cdx.json');
	    for (@d) {
	      push @extra, $1 if /(\.[^\.\/]+\.intoto.json)$/;
	    }
	    for my $extra (@extra) {
	      if (-e "$dir/$prefix$extraprefix$extra") {
		BSUtil::cp("$dir/$prefix$extraprefix$extra", "$jobdatadir/$extraprefix$extra");
		$jobbins{"$extraprefix$extra"} = $aprpap_idx;
	        $logfile .= "      - $extraprefix$extra\n";
	      }
	    }
	    $extraprefix =~ s/\.docker// unless -e "$dir/$prefix$extraprefix.packages";
	    for my $extra ('.basepackages', '.packages', '.report', '.verified') {
	      if (-e "$dir/$prefix$extraprefix$extra") {
		BSUtil::cp("$dir/$prefix$extraprefix$extra", "$jobdatadir/$extraprefix$extra");
		$jobbins{"$extraprefix$extra"} = $aprpap_idx;
	        $logfile .= "      - $extraprefix$extra\n";
	      }
	    }
	    # hack to add a container tag with the attribute
	    tweak_container_tags($ctx->{'conf'}, $containerinfo, $r, $packid);
	    # store (patched) containerinfo
	    writecontainerinfo("$jobdatadir/$containerinfofile", undef, $containerinfo);
	    $jobbins{$containerinfofile} = $aprpap_idx;
	    $logfile .= "      - $containerinfofile\n";
	    # update and store obsbinlnk
	    $r->{'path'} = "../$packid/$containerfile";
	    BSUtil::store("$jobdatadir/$filename", undef, $r);
	    $jobbins{$filename} = $aprpap_idx;
	    my $provenance = copy_provenance($jobdatadir, $dirprefix, "$dirprefix$containerinfofile", $containerinfofile, \%jobbins, $aprpap_idx);
	    $logfile .= "      - $provenance\n" if $provenance;
	    next;
	  }
          if ($filename =~ /\.helminfo$/) {
	    if ($jobbins{$filename}) {
	      push @{$conflicts{$filename}}, $aprpap_idx;
	      next;  # first one wins
	    }
	    my $helminfofile = $filename;
	    my $dir = $d;
	    $dir =~ s/\/[^\/]*$//;
	    my $prefix = $cpio ? 'upload:' : '';
	    my $helminfo = readhelminfo($dir, "$prefix$helminfofile");
	    next unless $helminfo;
	    next if $abinfilter && !$abinfilter->{"helm:$helminfo->{'name'}"};
	    my $chart = $helminfo->{'chart'};
	    next if !$chart || $chart =~ /^\./ || $chart =~ /\// || $chart !~ /\.tgz\z/s;
	    next if $jobbins{$chart};	# huh
	    next unless -e "$dirprefix$chart";
	    BSUtil::cp("$dirprefix$chart", "$jobdatadir/$chart");
	    $jobbins{$chart} = $aprpap_idx;
	    $logfile .= "      - $chart\n";
	    tweak_container_tags($ctx->{'conf'}, $helminfo, undef, $packid);
	    writehelminfo("$jobdatadir/$helminfofile", undef, $helminfo);
	    $jobbins{$filename} = $aprpap_idx;
	    $logfile .= "      - $filename\n";
	    my $provenance = copy_provenance($jobdatadir, $dirprefix, "$dirprefix$filename", $filename, \%jobbins, $aprpap_idx);
	    $logfile .= "      - $provenance\n" if $provenance;
	    next;
	  }
	  next unless $filename =~ /\.(?:$binsufsre)$/;
	  my $origfilename = $filename;
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
	    push @sources, [ $d, $r, $filename, $origfilename ];
	    next;
	  }
	  next unless $r->{'source'};
	  # FIXME: How is debian handling debug packages ?
	  next if $nosource && ($r->{'name'} =~ /-debug(:?info|source)?$/);
	  if ($jobbins{$filename}) {
	    push @{$conflicts{$filename}}, $aprpap_idx;
	    next;  # first one wins
	  }
	  if ($modulemd) {
	    my $art = add_modulemd_artifact($modulemd, $d);
	    next unless $art;
	    $have_modulemd_artifacts = 1 if $art > 0;
	  }
	  $jobbins{$filename} = $aprpap_idx;
	  BSUtil::cp($d, "$jobdatadir/$filename");
	  if ($filename ne $origfilename) {
	    $logfile .= "  - $filename [$s[9]/$s[7]/$s[1]] (from $origfilename)\n";
	  } else {
	    $logfile .= "  - $filename [$s[9]/$s[7]/$s[1]]\n";
	  }
	  $copysources = 1 unless $nosource;
	  my $provenance = copy_provenance($jobdatadir, $dirprefix, $d, $filename, \%jobbins, $aprpap_idx);
	  $logfile .= "      - $provenance\n" if $provenance;
	}
	@sources = () unless $copysources;
	for my $d (@sources) {
	  my $r = $d->[1];
	  my $filename = $d->[2];
	  my $origfilename = $d->[3];
	  $d = $d->[0];
	  if ($jobbins{$filename}) {
	    push @{$conflicts{$filename}}, $aprpap_idx;
	    next;  # first one wins
	  }
	  my @s = stat($d);
	  next unless @s;
	  if ($modulemd) {
	    my $art = add_modulemd_artifact($modulemd, $d);
	    next unless $art;
	    $have_modulemd_artifacts = 1 if $art > 0;
	  }
	  $jobbins{$filename} = $aprpap_idx;
	  BSUtil::cp($d, "$jobdatadir/$filename");
	  if ($filename ne $origfilename) {
	    $logfile .= "  - $filename [$s[9]/$s[7]/$s[1]] (from $origfilename)\n";
	  } else {
	    $logfile .= "  - $filename [$s[9]/$s[7]/$s[1]]\n";
	  }
	  my $provenance = copy_provenance($jobdatadir, $dirprefix, $d, $filename, \%jobbins, $aprpap_idx);
	  $logfile .= "      - $provenance\n" if $provenance;
	}
	# delete upload files
	unlink("$jobdatadir/$_->{'name'}") for @{$cpio || []};
      }
      last if $error;
    }
    last if $error;
  }

  if (%conflicts) {
    $logfile .= "\nFile provided by multiple origins (first one wins):\n";
    for my $filename (sort keys %conflicts) {
      $logfile .= "  - $filename:\n";
      $logfile .= "        $aprpap_idx[$jobbins{$filename}]\n";
      for my $aprpap_idx (@{$conflicts{$filename}}) {
	$logfile .= "        $aprpap_idx[$aprpap_idx]\n";
      }
    }
  }

  if ($error) {
    $logfile .= "\nError: $error\n";
    print "        $error\n";
    writestr("$jobdatadir/logfile", undef, $logfile);
    if (-e "$jobdatadir/logfile") {
      link("$jobdatadir/logfile", "$jobdatadir/logfile.dup");
      my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
      my $dst = "$gdst/$packid";
      mkdir_p("$gdst/:logfiles.fail");
      rename("$jobdatadir/logfile.dup", "$gdst/:logfiles.fail/$packid");
      mkdir_p($dst);
      rename("$jobdatadir/logfile", "$dst/logfile");
    }
    BSUtil::cleandir($jobdatadir);
    rmdir($jobdatadir);
    return ('failed', $error);
  }

  if ($modulemd && $have_modulemd_artifacts) {
    write_modulemd($modulemd, "$jobdatadir/_modulemd.yaml");
    $logfile .= "  - _modulemd.yaml\n";
  }

  $logfile .= "\nscheduler finished \"build _aggregate\" at ".POSIX::ctime(time())."\n";

  writestr("$jobdatadir/meta", undef, $new_meta);
  writestr("$jobdatadir/logfile", undef, $logfile);
  my $needsign;
  $needsign = 1 if $BSConfig::sign && grep {/\.(?:$binsufsre_sign)$/} keys %jobbins;
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
  my $code = 'succeeded';
  my $prp = "$projid/$repoid";
  my $gdst = "$gctx->{'reporoot'}/$prp/$myarch";
  my $dst = "$gdst/$packid";
  mkdir_p($dst);
  print "  - $prp: $packid aggregate built\n";
  my $dstcache = $ectx->{'dstcache'};
  my $changed_full = BSSched::BuildResult::update_dst_full($gctx, $prp, $packid, $jobdatadir, undef, $dstcache);
  $changed->{$prp} ||= 1;
  $changed->{$prp} = 2 if $changed_full;
  my $repounchanged = $gctx->{'repounchanged'};
  delete $repounchanged->{$prp} if $changed_full;
  $repounchanged->{$prp} = 2 if $repounchanged->{$prp};
  unlink("$gdst/:repodone");
  unlink("$gdst/:logfiles.fail/$packid");
  if (-e "$jobdatadir/logfile") {
    link("$jobdatadir/logfile", "$jobdatadir/logfile.dup");
    if ($code eq 'failed') {
      mkdir_p("$gdst/:logfiles.fail");
      rename("$jobdatadir/logfile.dup", "$gdst/:logfiles.fail/$packid");
    } else {
      mkdir_p("$gdst/:logfiles.success");
      rename("$jobdatadir/logfile.dup", "$gdst/:logfiles.success/$packid");
      unlink("$gdst/:logfiles.fail/$packid");
    }    
    rename("$jobdatadir/logfile", "$dst/logfile");
  } else {
    unlink("$gdst/:logfiles.success/$packid");
    unlink("$dst/logfile");
  }
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
  return undef unless !$d->{'tags'} || ref($d->{'tags'}) eq 'ARRAY';
  return $d;
}

sub writecontainerinfo {
  my ($fn, $fnf, $containerinfo) = @_;
  my $containerinfo_json = JSON::XS->new->utf8->canonical->pretty->encode($containerinfo);
  writestr($fn, $fnf, $containerinfo_json);
}

sub readhelminfo {
  my ($dir, $helminfo) = @_;
  return undef unless -e "$dir/$helminfo";
  return undef unless (-s _) < 100000;
  my $m = readstr("$dir/$helminfo");
  my $d;
  eval { $d = JSON::XS::decode_json($m); };
  return undef unless $d && ref($d) eq 'HASH';
  return undef unless $d->{'name'} && ref($d->{'name'}) eq '';
  return undef unless $d->{'version'} && ref($d->{'version'}) eq '';
  return undef unless !$d->{'tags'} || ref($d->{'tags'}) eq 'ARRAY';
  return undef unless $d->{'chart'} && ref($d->{'chart'}) eq '';
  return $d;
}

sub writehelminfo {
  my ($fn, $fnf, $helminfo) = @_;
  my $helminfo_json = JSON::XS->new->utf8->canonical->pretty->encode($helminfo);
  writestr($fn, $fnf, $helminfo_json);
}

1;

1;

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

package BSSched::BuildJob::Patchinfo;

use strict;
use warnings;

use Digest::MD5 ();

use BSUtil;
use BSSched::BuildJob;
use BSXML;
use Build;		                      # for query
use BSVerify;		                  # for verify_nevraquery
use BSSched::EventSource::Directory;  # for sendunblockedevent

=head1 NAME

BSSched::BuildJob::Patchinfo - A Class to handle Patchinfo builds

=head1 SYNOPSIS

my $h = BSSched::BuildJob::Patchinfo->new()

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

sub get_bins {
  my ($d) = @_;
  my @dd = sort(ls($d));
  my @d;
  my $havebinlink;
  for my $b (@dd) {
    next if /^::import::/;
    if ($b =~ /\.obsbinlnk$/) {
      my $binlnk = BSUtil::retrieve("$d/$b", 1);
      next unless $binlnk;
      push @d, $b;
      my $p = $binlnk->{'path'};
      $p =~ s/.*\///;
      push @d, grep {$_ ne $b && /^\Q$p\E/}  @dd;
      $havebinlink = 1;
    }
    push @d, $b if $b =~ /\.rpm$/;
  }
  @d = BSUtil::unify(@d) if $havebinlink;
  return @d;
}

=head2 check - check if a patchinfo needs to be rebuilt

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info) = @_;

  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $prp = "$projid/$repoid";
  my $repo = $ctx->{'repo'};
  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $myarch = $gctx->{'arch'};
  my @archs = @{$repo->{'arch'}};
  return ('broken', 'missing archs') unless @archs;     # can't happen
  my $buildarch = $archs[0];    # always build in first arch
  my $reporoot = $gctx->{'reporoot'};
  my $markerdir = "$reporoot/$prp/$buildarch/$packid";
  my $patchinfo = $pdata->{'patchinfo'};
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid} || {};

  if (@{$patchinfo->{'releasetarget'} || []}) {
    my $ok;
    for my $rt (@{$patchinfo->{'releasetarget'}}) {
      $ok = grep {$rt->{'project'} eq $_->{'project'} && (!defined($rt->{'repository'}) || $rt->{'repository'} eq $_->{'repository'})} @{$repo->{'releasetarget'} || []};
      last if $ok;
    }
    return ('excluded') unless $ok;
  }

  return ('broken', "patchinfo is stopped: ".$patchinfo->{'stopped'}) if $patchinfo->{'stopped'};
  return ('broken', 'patchinfo lacks category') unless $patchinfo->{'category'};

  my $ptype = 'local';
  $ptype = 'binary' if ($proj->{'kind'} || '') eq 'maintenance_incident';

  my $broken;
  # find packages
  my @packages;
  if ($patchinfo->{'package'}) {
    @packages = @{$patchinfo->{'package'}};
    my $pdatas = $proj->{'package'} || {};
    my @missing;
    for my $apackid (@packages) {
      if (!$pdatas->{$apackid}) {
        push @missing, $_;
      }
    }
    $broken = 'missing packages: '.join(', ', @missing) if @missing;
  } else {
    my $pdatas = $proj->{'package'} || {};
    @packages = grep {!$pdatas->{$_}->{'aggregatelist'} && !$pdatas->{$_}->{'patchinfo'}} sort keys %$pdatas;
  }
  if (!@packages && !$broken) {
    $broken = 'no packages found';
  }

  if ($buildarch ne $myarch) {
    # XXX wipe just in case! remove when we do that elsewhere...
    if (-d "$gdst/$packid") {
      # (patchinfo packages will not be in :full)
      unlink("$gdst/:meta/$packid");
      unlink("$gdst/:logfiles.fail/$packid");
      unlink("$gdst/:logfiles.success/$packid");
      unlink("$gdst/:logfiles.success/$packid");
      BSUtil::cleandir("$gdst/$packid");
      rmdir("$gdst/$packid");
    }
    # check if we go from blocked to unblocked
    my $blocked;
    my $packstatus = $ctx->{'packstatus'};
    for my $apackid (@packages) {
      my $code = $packstatus->{$apackid} || '';
      next if $code eq 'excluded';
      if ($code ne 'done' && $code ne 'disabled' && $code ne 'locked') {
        $blocked = 1;
        last;
      }
      if (-e "$gdst/:logfiles.fail/$apackid") {
        if (($code ne 'locked' && $code ne 'disabled') || -e "$gdst/:logfiles.success/$apackid") {
          $blocked = 1;
          last;
	}
      } elsif (! -e "$gdst/:logfiles.success/$apackid") {
        if (! -e "$gdst/$apackid/.channelinfo") {
          next if $code eq 'disabled' || $code eq 'locked';
          $blocked = 1;
          last;
        }
      }
    }
    if (!$blocked) {
      if (-e "$markerdir/.waiting_for_$myarch") {
        unlink("$markerdir/.waiting_for_$myarch");
        BSSched::EventSource::Directory::sendunblockedevent($gctx, $prp, $buildarch);
        print "      - $packid (patchinfo)\n";
        print "        unblocked\n";
      }
    }
    if ($blocked && !$broken) {
      # hmm, we should be blocked. trigger build arch check
      if (! -e "$markerdir/.waiting_for_$myarch") {
        BSUtil::touch("$reporoot/$prp/$buildarch/:schedulerstate.dirty") if -d "$reporoot/$prp/$buildarch";
        BSSched::EventSource::Directory::sendunblockedevent($gctx, $prp, $buildarch);
        print "      - $packid (patchinfo)\n";
        print "        blocked\n";
      }
    }
    return ('excluded', "is built in architecture '$buildarch'");
  }

  return ('broken', $broken) if $broken;

  my @new_meta;
  push @new_meta, ($pdata->{'verifymd5'} || $pdata->{'srcmd5'})."  $packid";

  if ($ptype eq 'local') {
    # only rebuild if patchinfo source changes
    my @meta;
    if (open(F, '<', "$gdst/:meta/$packid")) {
      @meta = <F>;
      close F;
      chomp @meta;
    }
    if (@meta == 1 && $meta[0] eq $new_meta[0]) {
      print "      - $packid (patchinfo)\n";
      print "        nothing changed\n";
      return ('done');
    }
  }

  # collect em
  my $apackstatus;
  my @blocked;
  my @tocopy;
  my %metas;
  my $empty_channel_seen;
  my $rpms_seen;
  my $enabled_seen;
  for my $arch (@archs) {
    my $agdst = "$reporoot/$prp/$arch";
    if ($arch eq $myarch) {
      $apackstatus = $ctx->{'packstatus'};
    } else {
      my $ps = BSUtil::retrieve("$agdst/:packstatus", 1);
      if (!$ps) {
        $ps = (readxml("$agdst/:packstatus", $BSXML::packstatuslist, 1) || {})->{'packstatus'} || [];
        $ps = { 'packstatus' => { map {$_->{'name'} => $_->{'status'}} @$ps } } if $ps;
      }
      $apackstatus = ($ps || {})->{'packstatus'} || {};
    }
    my $blockedarch;
    for my $apackid (@packages) {
      my $code = $apackstatus->{$apackid} || '';
      next if $code eq 'excluded';
      if ($code ne 'done' && $code ne 'disabled' && $code ne 'locked') {
        $blockedarch = 1;
        push @blocked, "$arch/$apackid";
        next;
      }
      if (-e "$agdst/:logfiles.fail/$apackid") {
        # last build failed
        if (($code ne 'locked' && $code ne 'disabled') || -e "$agdst/:logfiles.success/$apackid") {
          $blockedarch = 1;
          push @blocked, "$arch/$apackid (failed)";
          next;
        }
	next;	# locked or disabled and nothing built, nothing to pick up
      } elsif (! -e "$agdst/:logfiles.success/$apackid") {
        # package was never built yet or channel
        if (! -e "$agdst/$apackid/.channelinfo") {
          next if $code eq 'disabled' || $code eq 'locked';
          $blockedarch = 1;
          push @blocked, "$arch/$apackid (no logfiles.success)";
          next;
	}
      }
      $enabled_seen = 1 unless $code eq 'disabled';
      if ($ptype eq 'binary') {
        # like aggregates
        my $d = "$agdst/$apackid";
        my @d = get_bins($d);
        my $m = '';
        for my $b (sort @d) {
          my @s = stat("$d/$b");
          $m .= "$b\0$s[9]/$s[7]/$s[1]\0" if @s;
        }
        if (!@d) {
          # is this a channel?
          $empty_channel_seen = 1 if -e "$d/.channelinfo";
        } else {
          $rpms_seen = 1;
        }
        $metas{"$arch/$apackid"} = Digest::MD5::md5_hex($m);
      } elsif ($ptype eq 'direct' || $ptype eq 'transitive') {
        my ($ameta) = split("\n", readstr("$agdst/:meta/$apackid", 1) || '', 2);
        if (!$ameta) {
          push @blocked, "$arch/$apackid";
          $blockedarch = 1;
        } else {
          if ($metas{$apackid} && $metas{$apackid} ne $ameta) {
            push @blocked, "meta/$apackid";
            $blockedarch = 1;
          } else {
            $metas{$apackid} = $ameta;
          }
        }
      }
      push @tocopy, "$arch/$apackid";
    }
    if ($blockedarch && $arch ne $myarch) {
      mkdir_p("$gdst/$packid");
      BSUtil::touch("$markerdir/.waiting_for_$arch") unless -e "$markerdir/.waiting_for_$arch";
    } else {
      unlink("$markerdir/.waiting_for_$arch");
    }
  }

  if (@blocked) {
    print "      - $packid (patchinfo)\n";
    if (@blocked < 11) {
      print "        blocked (@blocked)\n";
    } else {
      print "        blocked (@blocked[0..9] ...)\n";
    }
    return ('blocked', join(', ', @blocked));
  }

  return ('excluded', 'no binary in channel') if ($empty_channel_seen && !$rpms_seen);
  return ('excluded', 'no package enabled') unless $enabled_seen;

  return ('broken', 'no binaries found') unless @tocopy;

  for (sort(keys %metas)) {
    push @new_meta, "$metas{$_}  $_";
  }

  # compare with stored meta
  my @meta;
  if (open(F, '<', "$gdst/:meta/$packid")) {
    @meta = <F>;
    close F;
    chomp @meta;
  }
  if (@meta == @new_meta && join("\n", @meta) eq join("\n", @new_meta)) {
    print "      - $packid (patchinfo)\n";
    print "        nothing changed\n";
    return ('done');
  }

  # now collect...
  return ('scheduled', [ \@tocopy, \%metas, $ptype]);
}


=head2 build - check if a patchinfo needs to be rebuilt

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;

  my $gctx = $ctx->{'gctx'};
  my $gdst = $ctx->{'gdst'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my @tocopy = @{$data->[0]};
  my $ckmetas = $data->[1];
  my $ptype = $data->[2];
  my $reporoot = $gctx->{'reporoot'};

  print "      - $packid (patchinfo)\n";
  print "        rebuilding\n";
  my $now = time();
  my $prp = "$projid/$repoid";
  my $job = BSSched::BuildJob::jobname($prp, $packid);
  my $myjobsdir = $gctx->{'myjobsdir'};
  return ('scheduled', $job) if -s "$myjobsdir/$job";

  my $patchinfo = $pdata->{'patchinfo'};
  my $jobdatadir = "$myjobsdir/$job:dir";
  unlink "$jobdatadir/$_" for ls($jobdatadir);
  mkdir_p($jobdatadir);
  my $jobrepo = {};
  my $error;
  my %donebins;
  my @upackages;
  my $broken;
  my %metas;
  my $bininfo = {};
  my $updateinfodata;
  my %updateinfodata_tocopy;
  my %binaryfilter = map {$_ => 1} @{$patchinfo->{'binary'} || []};
  my %filtered;

  if (-s "$gdst/$packid/.updateinfodata") {
    $updateinfodata = BSUtil::retrieve("$gdst/$packid/.updateinfodata");
    %updateinfodata_tocopy = map {$_ => 1} @{$updateinfodata->{'packages'} || []};
  }

  my %supportstatus;
  my $target;
  my $firstissued = ($updateinfodata || {})->{'firstissued'} || $now;

  for my $tocopy (@tocopy) {
    my ($arch, $apackid) = split('/', $tocopy, 2);
    my @bins;
    my $meta;
    my $from;
    my $mpackid;
    my $channelinfo;

    if ($ptype eq 'local') {
      # always reuse old packages
    } elsif ($ptype eq 'binary') {
      $mpackid = "$arch/$apackid";
    } elsif ($ptype eq 'direct' || $ptype eq 'transitive') {
      $mpackid = $apackid;
    } else {
      $broken = "illegal ptype";
      last;
    }
    if ($updateinfodata->{'filtered'} && $updateinfodata->{'filtered'}->{$tocopy}) {
      # we previously filtered packages, check if this is still true
      if (grep {!%binaryfilter || $binaryfilter{$_}} keys %{$updateinfodata->{'filtered'}->{$tocopy}}) {
        # can't reuse old packages, as the filter changed
        delete $updateinfodata_tocopy{$tocopy};
      }
    }
    if ($updateinfodata_tocopy{$tocopy} && (!defined($mpackid) || ($updateinfodata->{'metas'}->{$mpackid} || '') eq $ckmetas->{$mpackid})) {
      print "        reusing old packages for '$tocopy'\n";
      $from = "$gdst/$packid";
      @bins = grep {$updateinfodata->{'binaryorigins'}->{$_} eq $tocopy} keys(%{$updateinfodata->{'binaryorigins'}});
      if ($updateinfodata->{'supportstatus'}) {
        # fake channelinfo
        my $oldsupportstatus = $updateinfodata->{'supportstatus'};
        for (@bins) {
          next unless $oldsupportstatus->{$_};
          $channelinfo ||= {};
          $channelinfo->{$_} = { 'supportstatus' => $oldsupportstatus->{$_} };
        }
      }
      $target ||= $updateinfodata->{'target'} if $updateinfodata->{'target'};
    } else {
      $from = "$reporoot/$prp/$tocopy";
      @bins = get_bins($from);
      if (-e "$from/.channelinfo") {
        $channelinfo = BSUtil::retrieve("$from/.channelinfo");
        $target ||= $channelinfo->{'/target'} if $channelinfo->{'/target'};
      }
    }
    if (defined($mpackid)) {
      my $meta = $ckmetas->{$mpackid};
      if (!$meta) {
        $broken = "$tocopy has no meta";
        last;
      }
      $metas{$mpackid} ||= $meta;
      if ($metas{$mpackid} ne $meta) {
        $broken = "$mpackid has different sources";
        last;
      }
    }
    my $m = '';
    for my $bin (sort @bins) {
      if ($donebins{$bin}) {
        if ($ptype eq 'binary') {
          my @s = stat("$from/$bin");
          $m .= "$bin\0$s[9]/$s[7]/$s[1]\0" if @s;
        }
        next;
      }
      if (!link("$from/$bin", "$jobdatadir/$bin")) {
        my $error = "link $from/$bin $jobdatadir/$bin: $!\n";
        return ('broken', $error);
      }
      my @s = stat("$jobdatadir/$bin");
      return ('broken', "$jobdatadir/$bin: stat failed") unless @s;
      if ($ptype eq 'binary') {
        # be extra careful with em, recalculate meta
        $m .= "$bin\0$s[9]/$s[7]/$s[1]\0" if @s;
      }
      if ($bin !~ /\.rpm$/) {
        if (%binaryfilter) {
          unlink("$jobdatadir/$bin");
          next;
	}
	$donebins{$bin} = $tocopy; 
	next;
      }
      my $d;
      eval {
        $d = Build::query("$jobdatadir/$bin", 'evra' => 1, 'unstrippedsource' => 1);
        BSVerify::verify_nevraquery($d);
        my $leadsigmd5 = '';
        die("$jobdatadir/$bin: no hdrmd5\n") unless Build::queryhdrmd5("$jobdatadir/$bin", \$leadsigmd5);
        $d->{'leadsigmd5'} = $leadsigmd5 if $leadsigmd5;
      };
      if ($@ || !$d) {
        return ('broken', "$bin: bad rpm");
      }
      if (%binaryfilter && !$binaryfilter{$d->{'name'}}) {
        $filtered{$tocopy} ||= {};
        $filtered{$tocopy}->{$d->{'name'}} = 1;
        unlink("$jobdatadir/$bin");
        next;
      }
      if ($d->{'arch'} ne 'src' && $d->{'arch'} ne 'nosrc' && -e "$from/$d->{'name'}-appdata.xml") {
        unlink("$jobdatadir/$d->{'name'}-appdata.xml");
        if (!link("$from/$d->{'name'}-appdata.xml", "$jobdatadir/$d->{'name'}-appdata.xml")) {
          my $error = "link $from/$d->{'name'}-appdata.xml $jobdatadir/$d->{'name'}-appdata.xml: $!\n";
          return ('broken', $error);
        }
      }
      if ($d->{'arch'} ne 'src' && $d->{'arch'} ne 'nosrc' && -e "$from/$d->{'name'}.appdata.xml") {
        unlink("$jobdatadir/$d->{'name'}.appdata.xml");
        if (!link("$from/$d->{'name'}.appdata.xml", "$jobdatadir/$d->{'name'}.appdata.xml")) {
          my $error = "link $from/$d->{'name'}.appdata.xml $jobdatadir/$d->{'name'}.appdata.xml: $!\n";
          return ('broken', $error);
        }
      }
      $donebins{$bin} = $tocopy;
      $bininfo->{$bin} = {'name' => $d->{'name'}, 'arch' => $d->{'arch'}, 'hdrmd5' => $d->{'hdrmd5'}, 'filename' => $bin, 'id' => "$s[9]/$s[7]/$s[1]"};
      $bininfo->{$bin}->{'leadsigmd5'} = $d->{'leadsigmd5'} if $d->{'leadsigmd5'};
      $bininfo->{$bin}->{'md5sum'} = $d->{'md5sum'} if $d->{'md5sum'};
      my $upd = {
        'name' => $d->{'name'},
        'version' => $d->{'version'},
        'release' => $d->{'release'},
        'epoch' => $d->{'epoch'} || 0,
        'arch' => $d->{'arch'},
        'filename' => $bin,
        'src' => "$d->{'arch'}/$bin",   # as hopefully written by the publisher
      };
      $upd->{'reboot_suggested'} = 'True' if exists $patchinfo->{'reboot_needed'};
      $upd->{'relogin_suggested'} = 'True' if exists $patchinfo->{'relogin_needed'};
      $upd->{'restart_suggested'} = 'True' if exists $patchinfo->{'zypp_restart_needed'};
      push @upackages, $upd;
      if ($channelinfo) {
        my $ci = $channelinfo->{$bin};
        next unless $ci->{'supportstatus'};
        $upd->{'supportstatus'} = $ci->{'supportstatus'};
        $supportstatus{$bin} = $ci->{'supportstatus'};
      }
    }
    $metas{$mpackid} = Digest::MD5::md5_hex($m) if $ptype eq 'binary';
  }

  $broken ||= 'no binaries found' unless @upackages;

  my $update = {};
  $update->{'status'} = 'stable';
  $update->{'from'} = $patchinfo->{'packager'} if $patchinfo->{'packager'};
  # quick hack, to be replaced with something sane
  if ($BSConfig::updateinfo_fromoverwrite) {
    for (sort keys %$BSConfig::updateinfo_fromoverwrite) {
      $update->{'from'} = $BSConfig::updateinfo_fromoverwrite->{$_} if $projid =~ /$_/;
    }
  }
  $update->{'version'} = $patchinfo->{'version'} || '1';        # bodhi inserts its own version...
  $update->{'id'} = $patchinfo->{'incident'};
  if (!$update->{'id'}) {
    $update->{'id'} = $projid;
    $update->{'id'} =~ s/:/_/g;
  }
  if ($target && $target->{'id_template'}) {
    my $template = $target->{'id_template'};
    my @lt = localtime($firstissued);
    $broken ||= 'patchinfo name is required' if $template =~ /%N/ && !defined $patchinfo->{'name'};
    $template =~ s/%Y/$lt[5] + 1900/eg;
    $template =~ s/%M/$lt[4] + 1/eg;
    $template =~ s/%D/$lt[3]/eg;
    $template =~ s/%N/$patchinfo->{'name'}/eg if defined $patchinfo->{'name'};
    if ($template =~ /%C/) {
      $template =~ s/%C/$update->{'id'}/g;
    } else {
      $template .= "-$update->{'id'}";
    }
    $update->{'id'} = $template;
  }
  $update->{'type'} = $patchinfo->{'category'};
  $update->{'title'} = $patchinfo->{'summary'};
  $update->{'severity'} = $patchinfo->{'rating'} if defined $patchinfo->{'rating'};
  $update->{'description'} = $patchinfo->{'description'};
  $update->{'message'} = $patchinfo->{'message'} if defined $patchinfo->{'message'};
  # FIXME: do not guess the release element!
  $update->{'release'} = $repoid eq 'standard' ? $projid : $repoid;
  $update->{'release'} =~ s/_standard$//;
  $update->{'release'} =~ s/[_:]+/ /g;
  $update->{'issued'} = { 'date' => $now };

  # fetch defined issue trackers from src server. FIXME: cache this
  # XXX: this is not an async call!
  my @references;
  my $issue_trackers;
  my $param = {
    'uri' => "$BSConfig::srcserver/issue_trackers",
    'timeout' => 30,
  };
  eval {
    $issue_trackers = BSRPC::rpc($param, $BSXML::issue_trackers);
  };
  warn($@) if $@;
  if ($issue_trackers) {
    for my $b (@{$patchinfo->{'issue'} || []}) {
      my $it = (grep {$_->{'name'} eq $b->{'tracker'}} @{$issue_trackers->{'issue-tracker'} || []})[0];
      if ($it && $b->{'id'}) {
        my $trackerid = $b->{'id'};
        my $referenceid = $b->{'id'};
        if ($b->{'tracker'} eq 'cve') {
          # stay compatible with case insensitive writings and old _patchinfo files
          $trackerid =~ s/^(?:cve-)?//i;
          $referenceid =~ s/^(?:cve-)?/CVE-/i;
        }
        my $url = $it->{'show-url'};
        $url =~ s/@@@/$trackerid/g;
        my $title = $b->{'_content'};
        $title = $url unless defined($title) && $title ne '';
        push @references, {'href' => $url, 'id' => $referenceid, 'title' => $title, 'type' => $it->{'kind'}};
      }
    }
  }
  if ($target && $target->{'requires_issue'}) {
    $broken ||= 'no issue referenced' unless @references;
  }
  $update->{'references'} = { 'reference' => \@references };
  # XXX: set name and short
  my $col = {
    'package' => \@upackages,
  };
  $update->{'pkglist'} = {'collection' => [ $col ] };
  $update->{'patchinforef'} = "$projid/$packid";        # deleted in publisher...
  writexml("$jobdatadir/updateinfo.xml", undef, {'update' => [$update]}, $BSXML::updateinfo);
  writestr("$jobdatadir/logfile", undef, "update built succeeded ".localtime($now)."\n");
  $updateinfodata = {
    'packages' => \@tocopy,
    'metas' => \%metas,
    'binaryorigins' => \%donebins,
    'firstissued' => $firstissued,
  };
  $updateinfodata->{'supportstatus'} = \%supportstatus if %supportstatus;
  $updateinfodata->{'filtered'} = \%filtered if %filtered;
  $updateinfodata->{'target'} = $target if $target;
  BSUtil::store("$jobdatadir/.updateinfodata", undef, $updateinfodata);
  if ($broken) {
    BSUtil::cleandir($jobdatadir);
    writestr("$jobdatadir/logfile", undef, "update built failed ".localtime($now)."\n\n$broken\n");
  }
  my @new_meta = ($pdata->{'verifymd5'} || $pdata->{'srcmd5'})."  $packid";
  for my $apackid (sort(keys %metas)) {
    push @new_meta, "$metas{$apackid}  $apackid";
  }
  writestr("$jobdatadir/meta", undef, join("\n", @new_meta)."\n");
  # XXX write reason
  BSSched::BuildJob::fakejobfinished_nouseforbuild($ctx, $packid, $job, $broken ? 'failed' : 'succeeded', $bininfo, $pdata);
  return ('done');
}

1;

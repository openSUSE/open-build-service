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

package BSSched::BuildJob::Channel;

use strict;
use warnings;

use Digest::MD5 ();

use BSOBS;
use BSUtil;
use BSSched::BuildJob;
use BSSched::BuildResult;

my @binsufs = @BSOBS::binsufs;
my $binsufsre = join('|', map {"\Q$_\E"} @binsufs);

=head1 NAME

BSSched::BuildJob::Channel - A Class to handle Channel builds

=head1 SYNOPSIS

my $h = BSSched::BuildJob::Channel->new()

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

=head2 check - check if a patchinfo needs to be rebuilt

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info) = @_;
  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $repo = $ctx->{'repo'};
  my %repoarchs = map {$_ => 1} @{$repo->{'arch'} || []};
  my $channel = $pdata->{'channel'};
  my $projpacks = $gctx->{'projpacks'};
  my $proj = $projpacks->{$projid} || {};
  my $reporoot = $gctx->{'reporoot'};
  # do the channel filtering, same project but different repositories

  # first build a releasetarget -> repo map
  my %proj2repo;
  for my $arepo (@{$projpacks->{$projid}->{'repository'} || []}) {
    next unless grep {$_ eq $myarch} @{$arepo->{'arch'} || []};
    $proj2repo{"$projid/$arepo->{'name'}"}->{$arepo->{'name'}} = 1;
    for my $rt (@{$arepo->{'releasetarget'} || []}) {
      my $rtprojid = $rt->{'project'};
      my $rtrepoid = $rt->{'repository'};
      $proj2repo{"$rtprojid/$rtrepoid"}->{$arepo->{'name'}} = 1;
      $proj2repo{$rtprojid}->{$arepo->{'name'}} = 1;
    }
  }
  my $forme = {};
  if ($channel->{'target'}) {
    $forme = undef;
    for (@{$channel->{'target'}}) {
      if (!$_->{'project'}) {
        $forme = $_ if $_->{'repository'} && $repoid eq $_->{'repository'};
      } else {
        if ($_->{'repository'}) {
          $forme = $_ if $proj2repo{"$_->{'project'}/$_->{'repository'}"};
        } else {
          $forme = $_ if $proj2repo{$_->{'project'}};
        }
      }
    }
  }
  return ('excluded', 'not target of channel') if !$forme;

  # now create filter
  my %arepos;
  my %filter;
  my %packagefilter;
  for my $binaries (@{$channel->{'binaries'} || []}) {
    my $defprojid = $binaries->{'project'};
    my $defrepoid = $binaries->{'repository'};
    my $defarch = $binaries->{'arch'};
    for my $binary (@{$binaries->{'binary'} || []}) {
      next unless $binary->{'name'};
      my $bi = $binary;
      my $arch = $bi->{'arch'} || $defarch || '';
      if ($arch && !$repoarchs{$arch}) {
        # not in repo, go for the import!
        $bi = { %$binary, 'importedfrom' => $arch };
        $arch = $myarch;
      }
      next unless !$arch || $arch eq $myarch;
      my $aprojid = $bi->{'project'} || $defprojid || $projid;
      next unless $aprojid;
      my $arepoid = $bi->{'repository'} || $defrepoid || '';
      my $rtkey = $arepoid ? "$aprojid/$arepoid" : $aprojid;
      next unless $proj2repo{$rtkey};
      for my $arepoid (keys %{$proj2repo{$rtkey}}) {
        $arepos{$arepoid} = 1;
        push @{$filter{"$arepoid/$bi->{'name'}"}}, $bi;
      }
      if ($bi->{'package'}) {
        push @{$packagefilter{"$arepoid/$bi->{'package'}"}}, $bi;
      }
    }
  }
  #print Dumper(\%filter);

  # find packages (same code as in checkpatchinfo)
  my $pdatas = $proj->{'package'} || {};
  my @apackids = grep {!$pdatas->{$_}->{'aggregatelist'} && !$pdatas->{$_}->{'patchinfo'}} sort keys %$pdatas;

  # go through the repos and check the binaries
  my @new_meta = ($pdata->{'verifymd5'} || $pdata->{'srcmd5'})."  $packid";
  my @blocked;
  my @broken;
  my %collected;
  my @channelbins;
  for my $arepoid (sort keys %arepos) {
    my $aprp = "$projid/$arepoid";
    my $ps = $ctx->read_packstatus($aprp, $myarch);
    # find which projects go into this repo
    my %aprojids;
    for my $aprojid (keys %proj2repo) {
      $aprojids{$aprojid} = 1 if $proj2repo{$aprojid}->{$arepoid};
    }
    my $gbininfo = $ctx->read_gbininfo($aprp);
    for my $apackid (@apackids) {
      next if $arepoid eq $repoid && $apackid eq $packid;
      my $code = $ps->{$apackid} || 'unknown';
      if ($code eq 'scheduled' || $code eq 'blocked' || $code eq 'finished' || $code eq 'unknown') {
        push @blocked, "$arepoid/$apackid";
        next;
      }
      my $bininfo = $gbininfo->{$apackid} || {};
      my @sbins;
      my %usedsrc;

      my $apdata = $pdatas->{$apackid} || {};
      my $lapackid = $apackid;		# release target package
      my $flavor;
      if ($lapackid =~ /(?<!^_product)(?<!^_patchinfo):./) {
	$lapackid =~ s/^(.*):(.*?)$/$1/;	# split off multibuild flavor
	$flavor = $2;
      }
      if ($apdata->{'releasename'}) {
        $lapackid = $apdata->{'releasename'};
      } elsif (($proj->{'kind'} || '') eq 'maintenance_incident') {
        $lapackid =~ s/\.[^\.]+$//;
      }
      my $lapackid2 = $lapackid;		# compat...
      $lapackid .= ":$flavor" if defined $flavor;

      my @pf = @{$packagefilter{"$arepoid/$apackid"} || $packagefilter{"$arepoid/$lapackid"} || $packagefilter{"$arepoid/$lapackid2"} || []};

      my @bins = sort keys %$bininfo;
      # put imports last
      my @ibins = grep {/^::import::/} @bins;
      if (@ibins) {
        @bins = grep {!/^::import::/} @bins;
        push @bins, @ibins;
      }
      for my $filename (@bins) {
        my $bi = $bininfo->{$filename};
        my $n = $bi->{'name'};
        next unless $n;
        if ($bi->{'arch'} eq 'src' || $bi->{'arch'} eq 'nosrc') {
          push @sbins, $bi unless $bininfo->{'.nosourceaccess'};
          next;
        }
        if (@pf) {
          for my $f (splice @pf) {
            push @pf, $f if $f->{'name'} ne $n || ($f->{'binaryarch'} && $bi->{'arch'} ne $f->{'binaryarch'});
          }
        }
        my $tfilename = $filename;
        $tfilename =~ s/^::import::.*?:://;
        next if $collected{$tfilename};
        next unless $filter{"$arepoid/$n"};
        my $found;
        my $supportstatus;
        my $superseded_by;
        my $importedfrom;
        for my $f (@{$filter{"$arepoid/$n"}}) {
          next if $f->{'importedfrom'} && $filename !~ /^::import::\Q$f->{'importedfrom'}\E::/;
          next if $f->{'package'} && $apackid ne $f->{'package'} && $lapackid ne $f->{'package'} && $lapackid2 ne $f->{'package'};
          next if $f->{'binaryarch'} && $bi->{'arch'} ne $f->{'binaryarch'};
          $supportstatus = $f->{'supportstatus'};
          $superseded_by = $f->{'superseded_by'};
          $found = 1;
          last;
        }
        next unless $found;
        # oooh, this binary goes into the channel!
        $collected{$tfilename} = 1;
        $usedsrc{$bi->{'source'}} = 1;
        my $m = Digest::MD5::md5_hex($bi->{'id'})."  $arepoid/$apackid/$n.$bi->{'arch'}";
        push @new_meta, $m;
        $bi->{'filename'} = $filename;  # work around bug in bininfo generation
        push @channelbins, [ $arepoid, $apackid, $bi, $supportstatus, $superseded_by ];
      }
      if (%usedsrc) {
        for my $bi (@sbins) {
          next unless $usedsrc{$bi->{'name'}};
          next if $collected{$bi->{'filename'}};
          $collected{$bi->{'filename'}} = 1;
          my $m = Digest::MD5::md5_hex($bi->{'id'})."  $arepoid/$apackid/$bi->{'name'}.$bi->{'arch'}";
          push @new_meta, $m;
          push @channelbins, [ $arepoid, $apackid, $bi ];
        }
      }
      for my $f (@pf) {
        if ($f->{'binaryarch'}) {
          push @broken, "$arepoid/$apackid/$f->{'name'}.$f->{'binaryarch'}";
        } else {
          push @broken, "$arepoid/$apackid/$f->{'name'}";
        }
      }
    }
  }
  if (@broken) {
    print "      - $packid (channel)\n";
    print "        broken (@broken)\n";
    return ('broken', 'missing: '.join(', ', @broken));
  }
  if (@blocked) {
    splice(@blocked, 10, scalar(@blocked), '...') if @blocked > 10;
    print "      - $packid (channel)\n";
    print "        blocked (@blocked)\n";
    return ('blocked', join(', ', @blocked));
  }
  my @meta;
  if (open(F, '<', "$reporoot/$projid/$repoid/$myarch/:meta/$packid")) {
    @meta = <F>;
    close F;
    chomp @meta;
  }
  if (join('\n', @meta) eq join('\n', @new_meta)) {
    print "      - $packid (channel)\n";
    print "        nothing changed\n";
    return ('done');
  }
  my @diff = BSSched::BuildJob::diffsortedmd5(\@meta, \@new_meta);
  print "      - $packid (channel)\n";
  print "        $_\n" for @diff;
  my $new_meta = join('', map {"$_\n"} @new_meta);
  return ('scheduled', [ $new_meta, \@channelbins, $forme ]);
}

=head2 build - rebuild a channel

 TODO: add description

=cut

sub genbininfo {
  my ($dir, $filename) = @_;
  my $fd;
  open($fd, '<', "$dir/$filename") || die("$dir/$filename: $!\n");
  my @s = stat($fd);
  die unless @s;
  my $ctx = Digest::MD5->new;
  $ctx->addfile($fd);
  close $fd;
  return { 'md5sum' => $ctx->hexdigest(), 'filename' => $filename, 'id' => "$s[9]/$s[7]/$s[1]" };
}

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my ($new_meta, $channelbins, $forme) = @$data;
  my $gctx = $ctx->{'gctx'};
  my $myarch = $gctx->{'arch'};
  my $projid = $ctx->{'project'};
  my $repoid = $ctx->{'repository'};
  my $prp = "$projid/$repoid";
  my $job = BSSched::BuildJob::jobname($prp, $packid);
  my $myjobsdir = $gctx->{'myjobsdir'};
  return ('scheduled', $job) if -s "$myjobsdir/$job";
  my $reporoot = $gctx->{'reporoot'};
  my $jobdatadir = "$myjobsdir/$job:dir";
  unlink "$jobdatadir/$_" for ls($jobdatadir);
  mkdir_p($jobdatadir);
  my %channelinfo = ('/target' => $forme);
  my $bininfo = {};
  my $checksums = '';
  my %checksums_seen;
  for my $cb (@$channelbins) {
    my ($arepoid, $apackid, $bi, $supportstatus, $superseded_by) = @$cb;
    my $dir = "$reporoot/$projid/$arepoid/$myarch/$apackid";
    my $file = "$dir/$bi->{'filename'}";
    my @s = stat($file);
    if (!@s || "$s[9]/$s[7]/$s[1]" ne $bi->{'id'}) {
      BSUtil::cleandir($jobdatadir);
      rmdir($jobdatadir);
      $ctx->rebuild_gbininfo("$projid/$arepoid");	# the bininfo is wrong. trigger a rebuild
      return ('broken', "id mismatch in $arepoid/$apackid $s[9]/$s[7]/$s[1] $bi->{'id'}");
    }
    my $tfilename = $bi->{'filename'};
    $tfilename =~ s/^::import::.*?:://;
    link($file, "$jobdatadir/$tfilename") || die("link $file $jobdatadir/$tfilename: $!\n");
    if ($bi->{'arch'} ne 'src' && $bi->{'arch'} ne 'nosrc' && -e "$dir/$bi->{'name'}-appdata.xml") {
      unlink("$jobdatadir/$bi->{'name'}-appdata.xml");
      link("$dir/$bi->{'name'}-appdata.xml", "$jobdatadir/$bi->{'name'}-appdata.xml") || die("link $bi->{'name'}-appdata.xml $jobdatadir/$bi->{'name'}-appdata.xml: $!\n");
      $bininfo->{"$bi->{'name'}-appdata.xml"} = genbininfo($jobdatadir, "$bi->{'name'}-appdata.xml");
    }
    if ($bi->{'arch'} ne 'src' && $bi->{'arch'} ne 'nosrc' && -e "$dir/$bi->{'name'}.appdata.xml") {
      unlink("$jobdatadir/$bi->{'name'}.appdata.xml");
      link("$dir/$bi->{'name'}.appdata.xml", "$jobdatadir/$bi->{'name'}.appdata.xml") || die("link $bi->{'name'}.appdata.xml $jobdatadir/$bi->{'name'}.appdata.xml: $!\n");
      $bininfo->{"$bi->{'name'}.appdata.xml"} = genbininfo($jobdatadir, "$bi->{'name'}.appdata.xml");
    }
    if ($bi->{'filename'} =~ /(.*)\.(:?$binsufsre)$/) {
      my $tprovenance = "$1.slsa_provenance.json";
      my $provenance;
      $provenance = "$dir/$1.slsa_provenance.json" if -e "$dir/$1.slsa_provenance.json";
      $provenance = "$dir/_slsa_provenance.json" if !$provenance && $bi->{'filename'} !~ /^::import::/ && -e "$dir/_slsa_provenance.json";
      if ($provenance) {
	$tprovenance =~ s/^::import::.*?:://;
	unlink("$jobdatadir/$tprovenance");
	link($provenance, "$jobdatadir/$tprovenance") || die("link $provenance $jobdatadir/$tprovenance: $!\n");
	$bininfo->{$tprovenance} =  genbininfo($jobdatadir, $tprovenance);
      }
    }
    if (!$checksums_seen{"$arepoid/$apackid"}) {
      $checksums_seen{"$arepoid/$apackid"} = 1;
      # just append the checksums, it does not matter if we pick up too many
      if (-s "$reporoot/$projid/$arepoid/$myarch/$apackid/.checksums") {
        $checksums .= readstr("$reporoot/$projid/$arepoid/$myarch/$apackid/.checksums", 1) || '';
      }
    }
    $bininfo->{$tfilename} = $bi;
    my $ci = { 'repository' => $arepoid, 'package' => $apackid };
    if (defined $superseded_by) {
      $ci->{'superseded_by'} = $superseded_by;
      $ci->{'supportstatus'} = 'superseded';
    }
    $ci->{'supportstatus'} = $supportstatus if defined $supportstatus;
    $channelinfo{$tfilename} = $ci;
  }
  BSUtil::store("$jobdatadir/.channelinfo", undef, \%channelinfo);
  writestr("$jobdatadir/.checksums", undef, $checksums) if $checksums;
  writestr("$jobdatadir/meta", undef, $new_meta);
  BSSched::BuildJob::fakejobfinished_nouseforbuild($ctx, $packid, $job, 'succeeded', $bininfo, $pdata);
  return ('done');
}

1;

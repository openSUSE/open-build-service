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

package BSSched::BuildJob::BuildEnv;

use Data::Dumper;

use strict;
use warnings;

use BSSched::BuildJob;

=head1 NAME

BSSched::BuildJob::BuildEnv - A Class to handle package builds with a fixed buildenv

=head1 SYNOPSIS

my $h = BSSched::BuildJob::BuildEnv->new()

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
  return 1;
}

=head2 check - check if a package needs to be rebuilt

 TODO: add description

=cut

sub check {
  my ($self, $ctx, $packid, $pdata, $info, $buildtype) = @_;
  return ('broken', 'only works for buildinfo queries') unless $ctx->{'isreposerver'};
  return ('broken', 'only works with a provided buildenv') unless $pdata->{'buildenv'};
  return ('scheduled', [ {'explain' => 'buildinfo generation'} ]);
}

=head2 build - create a package build job

 TODO: add description

=cut

sub build {
  my ($self, $ctx, $packid, $pdata, $info, $data) = @_;
  my $gctx = $ctx->{'gctx'};
  my $arch      = $gctx->{'arch'};
  my $remotemap = $gctx->{'remoteprojs'};
  my $pool      = $ctx->{'pool'};
  my $bconf     = $ctx->{'conf'};

  my $buildenv = $pdata->{'buildenv'};
  my @bdeps = @{$buildenv->{'bdep'}};

  # find hdrmd5 of all available packages
  my @allpackages;
  if (defined &BSSolv::pool::allpackages) {
    @allpackages = $pool->allpackages();
  } else {
    # crude way to get ids of all packages
    my $npkgs = 0;
    for my $r ($pool->repos()) {
      my @pids = $r->getpathid();
      $npkgs += @pids / 2;
    }
    @allpackages = 2 ... ($npkgs + 1) if $npkgs;
  }
  my %allpackages;
  for my $p (@allpackages) {
    my $n = $pool->pkg2name($p);
    my $hdrmd5 = $pool->pkg2pkgid($p);
    next unless $n && $hdrmd5;
    push @{$allpackages{"$n.$hdrmd5"}}, $p;
  }

  # check if we got em all
  if (grep {$_->{'hdrmd5'} && !$allpackages{"$_->{'name'}.$_->{'hdrmd5'}"}} @bdeps) {
    # nope, need to search package data as well
    for my $aprp (@{$ctx->{'prpsearchpath'}}) {
      my ($aprojid, $arepoid) = split('/', $aprp, 2);
      my $gbininfo = $ctx->read_gbininfo($aprp, $arch, 1) || {};
      for my $packid (sort keys %$gbininfo) {
	for (map {$gbininfo->{$packid}->{$_}} sort keys %{$gbininfo->{$packid}}) {
	  next unless $_->{'name'} && $_->{'hdrmd5'};
	  $_->{'package'} = $packid;
	  $_->{'prp'} = $aprp;
	  push @{$allpackages{"$_->{'name'}.$_->{'hdrmd5'}"}}, $_;
	}
      }
    }
  }

  # fill in missing data
  my %pdeps = map {$_ => 1}  Build::get_preinstalls($bconf);
  my %vmdeps = map {$_ => 1} Build::get_vminstalls($bconf);
  my %runscripts = map {$_ => 1} Build::get_runscripts($bconf);
  for (@bdeps) {
    $_->{'name'} =~ s/\.rpm$//;	# workaround bug in buildenv generation
    my $n      = $_->{'name'};
    my $hdrmd5 = $_->{'hdrmd5'};
    die("buildenv package $n has no hdrmd5 set\n") unless $hdrmd5;
    die("package $n\@$hdrmd5 is unavailable\n") unless $allpackages{"$n.$hdrmd5"};

    my $p = $allpackages{"$n.$hdrmd5"}->[0];
    my ($d, $prp);
    if (ref($p)) {
      $d   = $p;
      $prp = $d->{'prp'};
    } else {
      $d   = $pool->pkg2data($p);
      $prp = $pool->pkg2reponame($p);
    }
    ($_->{'project'}, $_->{'repository'}) = split('/', $prp) if $prp;
    $_->{'version'} = $d->{'version'};
    $_->{'epoch'}   = $d->{'epoch'}   if $d->{'epoch'};
    $_->{'release'} = $d->{'release'} if defined $d->{'release'};
    $_->{'arch'}    = $d->{'arch'}    if $d->{'arch'};
    $_->{'package'} = $d->{'package'} if defined $d->{'package'};
    $_->{'notmeta'}    = 1;
    $_->{'preinstall'} = 1 if $pdeps{$_->{'name'}};
    $_->{'vminstall'}  = 1 if $vmdeps{$_->{'name'}};
    $_->{'runscripts'} = 1 if $runscripts{$_->{'name'}};
  }
  $ctx->{'extrabdeps'} = \@bdeps;
  $info->{'buildtype'} = 'buildenv';
  my $reason = $data->[0];
  return BSSched::BuildJob::create($ctx, $packid, $pdata, $info, $ctx->{'subpacks'}->{$info->{'name'}} || [], [], $reason, 0);
}

1;

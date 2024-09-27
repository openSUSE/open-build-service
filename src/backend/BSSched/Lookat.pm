# Copyright (c) 2015 SUSE LLC
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
package BSSched::Lookat;

use strict;
use warnings;

use BSUtil;


=head2 setchanged - add a prp to the lookat queue and the dependent prps to the changed hashes

 TODO

=cut

sub setchanged {
  my ($gctx, $changeprp, $changetype, $changelevel) = @_;

  return unless $changeprp;
  $changetype ||= 'high';
  $changelevel ||= 1;

  my $changed = $gctx->{"changed_$changetype"};
  my $changed_dirty = $gctx->{'changed_dirty'};
  my $lookat = $gctx->{"lookat_$changetype"};
  my $prps = $gctx->{'prps'};
  my ($projid, $repoid) = split('/', $changeprp, 2);
  if (defined($repoid)) {
    my $prp = $changeprp;
    @$lookat = grep {$_ ne $prp} @$lookat;
    unshift @$lookat, $prp;
    if ($changetype eq 'low') {
      # we don't use changed2lookat to prevent infinite looping
      my $prpdeps = $gctx->{'prpdeps'};
      for my $dprp (@$prps) {
	next if $dprp eq $prp;
	$changed->{$dprp} = 1 if grep {$_ eq $prp} @{$prpdeps->{$dprp}};
      }
    } else {
      if ($changelevel == 2) {
        $changed->{$prp} = 2;
      } else {
        $changed->{$prp} ||= 1;
      }
    }
    $changed_dirty->{$prp} = 1;
    return;
  }
  my $rprpdeps = $gctx->{'rprpdeps'};
  my @cprps;
  for my $prp (@$prps, sort(keys %{$rprpdeps || {}})) {
    push @cprps, $prp if (split('/', $prp, 2))[0] eq $projid;
  }
  @cprps = BSUtil::unify(@cprps);
  my %cprps = map {$_ => 1} @cprps;
  @$lookat = grep {!$cprps{$_}} @$lookat;
  if ($changelevel == 2) {
    for my $prp (@cprps) {
      unshift @$lookat, $prp;
      $changed->{$prp} = 2;
      $changed_dirty->{$prp} = 1;
    }
    $changed->{$projid} = 2;
  } else {
    for my $prp (@cprps) {
      unshift @$lookat, $prp;
      $changed->{$prp} ||= 1;
      $changed_dirty->{$prp} = 1;
    }
    $changed->{$projid} ||= 1;
  }
}


=head2 changed2lookat - add all changed prps to the lookat queues

 TODO

=cut

sub changed2lookat {
  my ($gctx) = @_;

  my $lookat_low  = $gctx->{'lookat_low'};
  my $lookat_med  = $gctx->{'lookat_med'};
  my $lookat_high = $gctx->{'lookat_high'};
  my $lookat_next = $gctx->{'lookat_next'};
  my $changed_low  = $gctx->{'changed_low'};
  my $changed_med  = $gctx->{'changed_med'};
  my $changed_high = $gctx->{'changed_high'};

  if (%$changed_high) {
    # add all changed_high entries to changed_med to make things simpler
    for (keys %$changed_high) {
      $changed_med->{$_} = $changed_high->{$_} unless ($changed_med->{$_} || 0) == 2;
    }
    push @$lookat_high, grep {$changed_high->{$_}} sort keys %$changed_med;
    push @$lookat_med, grep {!$changed_high->{$_}} sort keys %$changed_med;
  } else {
    push @$lookat_med, sort keys %$changed_med;
  }
  @$lookat_high = BSUtil::unify(@$lookat_high);
  @$lookat_med = BSUtil::unify(@$lookat_med);
  my %lookat_high = map {$_ => 1} @$lookat_high;
  @$lookat_med = grep {!$lookat_high{$_}} @$lookat_med;

  for my $prp (keys %$changed_low) {
    $lookat_next->{$prp} = 1;
  }
  my $rprpdeps = $gctx->{'rprpdeps'};
  for my $prp (keys %$changed_med) {
    $lookat_next->{$prp} = 1;
    my $alllocked = $gctx->{'alllocked'};
    $lookat_next->{$_} = 1 for grep {!$alllocked->{$_}} @{$rprpdeps->{$prp} || []};
  }

  #my $prpdeps = $gctx->{'prpdeps'};
  #for my $prp (@{$gctx->{'prps'}}) {
  #  if (!$changed_low->{$prp} && !$changed_med->{$prp}) {
  #    next unless grep {$changed_med->{$_}} @{$prpdeps->{$prp}};
  #  }
  #  $lookat_next->{$prp} = 1;
  #}

  %$changed_low = ();
  %$changed_med = ();
  %$changed_high = ();
}

sub extend_lookat_next {
  my ($gctx) = @_;
  my $lookat_next = $gctx->{'lookat_next'};
  my $alllocked = $gctx->{'alllocked'};
  my $rprpdeps = $gctx->{'rprpdeps'};
  my @todo = keys %$lookat_next;
  my $newcnt = 0;
  while (@todo) {
    # use chunks to keep memory usage low
    my @new = grep {!$lookat_next->{$_} && !$alllocked->{$_}} map {@{$rprpdeps->{$_} || []}} splice(@todo, 0, 100);
    if (@new) {
      @new = BSUtil::unify(@new);
      $newcnt += scalar(@new);
      $lookat_next->{$_} = 1 for @new;
      push @todo, @new;
    }
  }
  print "extended lookat_next by $newcnt indirect entries\n" if $newcnt;
}

=head2 nextlookat - calculate the next prp to check

 TODO

=cut

sub nextlookat {
  my ($gctx) = @_;

  my $lookat_low  = $gctx->{'lookat_low'};
  my $lookat_med  = $gctx->{'lookat_med'};
  my $lookat_high = $gctx->{'lookat_high'};
  my $lookat_next = $gctx->{'lookat_next'};
  my $nextmed = $gctx->{'nextmed'};
  my $nexthigh = $gctx->{'nexthigh'};
  my $notlow = $gctx->{'notlow'};
  my $notmed = $gctx->{'notmed'};

  sub check_queue {
    my ($lookat, $next) = @_;
    my $prp = shift @$lookat;

    if ($next && $next->{$prp}) {
      my $now = time();
      my @notyet;
      while ($next->{$prp} && $now < $next->{$prp}) {
	print "  not yet $prp\n";
	push @notyet, $prp;
	$prp = shift @$lookat;
	last unless defined $prp;
      }
      unshift @$lookat, @notyet;
    }
    return $prp;
  }

  # if lookat_low array is empty, start new series with lookat_next
  if (!@$lookat_low && %$lookat_next) {
    extend_lookat_next($gctx);
    @$lookat_low = grep {$lookat_next->{$_}} @{$gctx->{'prps'}};
    %$lookat_next = ();
  }

  my $prp;
  my $lookattype;
  while (1) {
    $lookattype = 'low',  last if @$lookat_low && $notlow > 10 && defined($prp = check_queue($lookat_low));
    $notlow = 0 if $notlow > 10;	# don't try so often
    $lookattype = 'med',  last if @$lookat_med && $notmed > 2  && defined($prp = check_queue($lookat_med,  $nextmed));
    $notmed = 0 if $notmed > 2;	# don't try so often
    $lookattype = 'high', last if @$lookat_high                && defined($prp = check_queue($lookat_high, $nexthigh));
    $lookattype = 'med',  last if @$lookat_med                 && defined($prp = check_queue($lookat_med,  $nextmed));
    $lookattype = 'low',  last if @$lookat_low                 && defined($prp = check_queue($lookat_low));
    $lookattype = 'high', last if @$lookat_high                && defined($prp = check_queue($lookat_high));
    $lookattype = 'med',  last if @$lookat_med                 && defined($prp = check_queue($lookat_med));
    last;
  }
  $gctx->{'notlow'} = $notlow;
  $gctx->{'notmed'} = $notmed;
  return ($lookattype, $prp);
}

sub lookatprp {
  my ($gctx, $lookattype, $prp) = @_;

  my $lookat_low  = $gctx->{'lookat_low'};
  my $lookat_med  = $gctx->{'lookat_med'};
  my $lookat_high = $gctx->{'lookat_high'};
  my $lookat_next = $gctx->{'lookat_next'};
  $gctx->{'notmed'}++;
  $gctx->{'notlow'}++;
  if ($lookattype eq 'low') {
    @$lookat_high = grep {$_ ne $prp} @$lookat_high;
    @$lookat_med = grep {$_ ne $prp} @$lookat_med;
    $gctx->{'notlow'} = 0;
  } elsif ($lookattype eq 'med') {
    @$lookat_high = grep {$_ ne $prp} @$lookat_high;
    $gctx->{'notmed'} = 0;
  } else {
    @$lookat_med = grep {$_ ne $prp} @$lookat_med;
  }
  delete $gctx->{'nextmed'}->{$prp};
  delete $gctx->{'nexthigh'}->{$prp};
  BSUtil::printlog("looking at $lookattype prio $prp".
    " (".@$lookat_high."/".@$lookat_med."/".@$lookat_low."/".(keys %$lookat_next)."/".@{$gctx->{'prps'}}.")");
}

sub setdelayed {
  my ($gctx, $prp, $checktime) = @_;
  if (!$checktime) {
    delete $gctx->{'nextmed'}->{$prp};
    delete $gctx->{'nexthigh'}->{$prp};
    return;
  }
  my $medfactor = 1 + @{$gctx->{'lookat_med'}} / 100;
  my $highfactor = 1 + @{$gctx->{'lookat_high'}} / 10;
  $medfactor = 4 if $medfactor > 4;
  $highfactor = 4 if $highfactor > 4;
  $medfactor *= ($BSConfig::delayscale_med ? $BSConfig::delayscaler_med : 10);
  $highfactor *= ($BSConfig::delayscale_high ? $BSConfig::delayscale_high : 1);
  $medfactor = $highfactor if $medfactor < $highfactor;
  my $now = time();
  $gctx->{'nextmed'}->{$prp} = $now + $medfactor * $checktime;
  $gctx->{'nexthigh'}->{$prp} = $now + $highfactor * $checktime;
}

1;

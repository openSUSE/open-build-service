# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
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
################################################################

package BSDispatcher::Constraints;

=head1 NAME

BSDispatcher::Constraints - function to check and calculate constraints 

=cut

use Data::Dumper;
use Build::Rpm;
use BSConfiguration;

use strict;

my %secure_sandboxes;
if ($BSConfig::secure_sandboxes) {
  %secure_sandboxes = map {$_ => 1} @$BSConfig::secure_sandboxes;
} else {
  # we just define xen, kvm and zvm as entirely secure sandboxes atm
  # chroot, emulator, lxc are currently considered as not safe
  $secure_sandboxes{$_} = 1 for qw{xen kvm zvm};
}

=head1 FUNCTIONS / METHODS

=cut

=head2 getmbsize - normalize xml size element

  return normalized mega bytes

=cut

sub getmbsize {
  my ($se) = @_;
  my $size = $se->{'size'}->{'_content'};
  my $unit = $se->{'size'}->{'unit'} || 'B';
  $size /= (1024*1024) if $unit eq 'B';
  $size /= 1024 if $unit eq 'K';
  # already MegaBytes
  $size *= 1024 if $unit eq 'G';
  $size *= 1024 * 1024 if $unit eq 'T';
  $size *= 1024 * 1024 * 1024 if $unit eq 'P';
  return $size;
}


=head2 worker_hostlabel_filter - check worker and constraints for matching hostlabels

  return 0 if hostlabels match, 1 otherwise

=cut

sub worker_hostlabel_filter {
  my ($worker, $constraints) = @_;

  return 1 unless $worker->{'hostlabelfiltermode'};
  return 1 unless $worker->{'hostlabel'};

  return 0 unless $constraints;
  return 0 unless $constraints->{'hostlabel'};

  if ($worker->{'hostlabelfiltermode'} eq "or") {
    for my $l (@{$worker->{'hostlabel'}}) {
      for my $ll (@{$constraints->{'hostlabel'}}) {
        return 1 if $ll->{'_content'} eq $l and (not $ll->{'exclude'} or $ll->{'exclude'} ne 'true');
      }
    }
    return 0;
  }

  if ($worker->{'hostlabelfiltermode'} eq "and") {
    OUTER: for my $l (@{$worker->{'hostlabel'}}) {
      for my $ll (@{$constraints->{'hostlabel'}}) {
        next OUTER if $ll->{'_content'} eq $l and (not $ll->{'exclude'} or $ll->{'exclude'} ne 'true');
      }
      return 0;
    }
    return 1;
  }

  warn("Ignoring unsupported hostlabelfiltermode '$worker->{'hostlabelfiltermode'}'.");
  return 1;
}


=head2 oracle - check constraints against worker

  my $ok = oracle($worker_strucht, $constraint_struct);
  checks if the given worker meets the constraints and can build the job. 

  Return Values:
    1   constraints ok
    0   constraint violation

=cut

sub oracle { 
  my ($worker, $constraints) = @_;
  return 0 unless worker_hostlabel_filter($worker, $constraints);
  return 1 unless $constraints;
  for my $l (@{$constraints->{'hostlabel'} || []}) { 
    if ($l->{'exclude'} && $l->{'exclude'} eq 'true') {
      return 0 if grep {$_ eq $l->{'_content'}} @{$worker->{'hostlabel'} || []};
    } else {
      return 0 unless grep {$_ eq $l->{'_content'}} @{$worker->{'hostlabel'} || []};
    }
  }
  if ($constraints->{'sandbox'} && $constraints->{'sandbox'}->{'_content'}) {
    if ($constraints->{'sandbox'}->{'exclude'} && $constraints->{'sandbox'}->{'exclude'} eq 'true') {
      return 0 if $constraints->{'sandbox'}->{'_content'} eq ($worker->{'sandbox'} || ''); 
    } else {
      if ($constraints->{'sandbox'}->{'_content'} eq 'secure') {
        return 0 unless $secure_sandboxes{$worker->{'sandbox'} || ''};
      } else { 
        return 0 unless $constraints->{'sandbox'}->{'_content'} eq ($worker->{'sandbox'} || '');
      }
    }
  } 
  if ($constraints->{'linux'}) {
    return 0 unless $worker->{'linux'};
    return 0 if $constraints->{'linux'}->{'flavor'} && $constraints->{'linux'}->{'flavor'} ne ($worker->{'linux'}->{'flavor'} || '');
    if ($constraints->{'linux'}->{'version'}) {
      return 0 unless defined $worker->{'linux'}->{'version'};
      return 0 if $constraints->{'linux'}->{'version'}->{'min'} && Build::Rpm::verscmp($constraints->{'linux'}->{'version'}->{'min'}, $worker->{'linux'}->{'version'}) > 0;
      return 0 if $constraints->{'linux'}->{'version'}->{'max'} && Build::Rpm::verscmp($constraints->{'linux'}->{'version'}->{'max'}, $worker->{'linux'}->{'version'}) < 0;
    }
  } 
  if ($constraints->{'hardware'}) {
    return 0 unless $worker->{'hardware'};
    return 0 if $constraints->{'hardware'}->{'processors'} && $constraints->{'hardware'}->{'processors'} > ($worker->{'hardware'}->{'processors'} || 0);
    return 0 if $constraints->{'hardware'}->{'jobs'} && $constraints->{'hardware'}->{'jobs'} > ($worker->{'hardware'}->{'jobs'} || 0);
    return 0 if $constraints->{'hardware'}->{'disk'} && getmbsize($constraints->{'hardware'}->{'disk'}) > ($worker->{'hardware'}->{'disk'} || 0);
    my $memory = ($worker->{'hardware'}->{'memory'} || 0);
    my $swap = ($worker->{'hardware'}->{'swap'} || 0);
    return 0 if $constraints->{'hardware'}->{'memory'} && getmbsize($constraints->{'hardware'}->{'memory'}) > ( $memory + $swap );
    return 0 if $constraints->{'hardware'}->{'physicalmemory'} && getmbsize($constraints->{'hardware'}->{'physicalmemory'}) > $memory;
    if ($constraints->{'hardware'}->{'cpu'}) {
      return 0 unless $worker->{'hardware'}->{'cpu'};
      my %workerflags = map {$_ => 1} @{$worker->{'hardware'}->{'cpu'}->{'flag'} || []};
      return 0 unless grep {$workerflags{$_}} @{$constraints->{'hardware'}->{'cpu'}->{'flag'} || []};
    }
  }
  return 1;
}

=head2 mergeconstraints - merge two constraint files

  and return the merged constraints

=cut

sub mergeconstraints {
  my ($con, @xmlcons) = @_;
  $con = Storable::dclone($con);
  # merge constraints
  for my $con2 (@xmlcons) {
    if ($con2->{'hostlabel'}) {
      $con->{'hostlabel'} = [ @{$con->{'hostlabel'} || []},  @{$con2->{'hostlabel'}} ];
    }
    if ($con2->{'sandbox'}) {
      $con->{'sandbox'} = $con2->{'sandbox'};
    }
    if ($con2->{'linux'}) {
      $con->{'linux'}->{'flavor'} = $con2->{'linux'}->{'flavor'} if $con2->{'linux'}->{'flavor'};
      for ('min', 'max') {
        $con->{'linux'}->{'version'}->{$_} = $con2->{'linux'}->{'version'}->{$_} if $con2->{'linux'}->{'version'} && $con2->{'linux'}->{'version'}->{$_};
      }
    }
    if ($con2->{'hardware'}) {
      for my $el (qw{processors jobs disk memory physicalmemory}) {
        next unless defined $con2->{'hardware'}->{$el};
        $con->{'hardware'}->{$el} = ref($con2->{'hardware'}->{$el}) ? Storable::dclone($con2->{'hardware'}->{$el}) : $con2->{'hardware'}->{$el};
      }
      if ($con2->{'hardware'}->{'cpu'} && $con2->{'hardware'}->{'cpu'}->{'flag'}) {
        my %oldflags = map {$_ => 1} @{$con->{'hardware'}->{'cpu'}->{'flag'} || []};
        for (@{$con2->{'hardware'}->{'cpu'}->{'flag'}}) {
          push @{$con->{'hardware'}->{'cpu'}->{'flag'}}, $_ unless $oldflags{$_};
        }
      }
    }
  }
  return $con;
}

# constructs a data object from a list and a XML::Structured dtd
sub list2struct {
  my ($dtd, $list, $job) = @_;
  my $top = {};
  for my $l (@{$list || []}) {
    my @l = @$l;
    next unless @l;
    eval {
      my @loc = split(':', shift @l);
      my @how = @$dtd;
      my $out = $top;
      while (@loc) {
        my $am = shift @how;
        my $e = shift @loc;
        my $addit;
        my $delit;
        $addit = 1 if $e =~ s/\+$//;
        $delit = 1 if !$addit && $e =~ s/=$//;
        my %known = map {ref($_) ? (!@$_ ? () : (ref($_->[0]) ? $_->[0]->[0] : $_->[0] => $_)) : ($_=> $_)} @how;
        my $ke = $known{$e};
        die("unknown element: $e\n") unless $ke;
        delete $out->{$e} if $delit;
        if ($delit && !@loc && !@l) {
          @how = ();
          last;
        }
        if (!ref($ke) || (@$ke == 1 && !ref($ke->[0]))) {
          die("element '$e' has subelements\n") if @loc;
          die("element '$e' contains attributes\n") if @l && $l[0] =~ /=/;
          delete $out->{$e} unless $addit;
          if (!ref($ke)) {
            die("element '$e' must be singleton\n") if exists $out->{$e};
            $out->{$e} = join(' ', @l);
          } else {
            push @{$out->{$e}}, @l;
          }
          @how = ();
        } else {
          my $nout = {};
          if (@$ke == 1) {
            $nout = pop @{$out->{$e}} if exists $out->{$e} && !$addit;
            push @{$out->{$e}}, $nout;
            @how = @{$ke->[0]};
          } else {
            $nout = delete $out->{$e} if exists $out->{$e} && !$addit;
            die("element '$e' must be singleton\n") if exists $out->{$e};
            $out->{$e} = $nout;
            @how = @$ke;
          }
          $out = $nout;
        }
      }
      if (@how) {
        my $am = shift @how;
        my %known = map {ref($_) ? (!@$_ ? () : (ref($_->[0]) ? $_->[0]->[0] : $_->[0] => $_)) : ($_=> $_)} @how;
        # clean old attribs
        for (@how) {
          last if ref($_) || $_ eq '_content';
          delete $out->{$_};
        }
        while (@l && $l[0] =~ /^(.*?)=(.*)$/) {
          my ($a, $av) = ($1, $2);
          die("element '$am' contains unknown attribute '$a'\n") unless $known{$a};
          if (ref($known{$a})) {
            die("attribute '$a' in '$am' must be element\n") if @{$known{$a}} > 1 || ref($known{$a}->[0]);
            push @{$out->{$a}}, $av;
          } else {
            die("attribute '$a' in '$am' must be singleton\n") if exists $out->{$a};
            $out->{$a} = $av;
          }
          shift @l;
        }
        if (@l) {
          die("element '$am' contains content\n") unless $known{'_content'};
          $out->{'_content'} = join(' ', @l);
        }
      }
    };
    warn("list2struct: $job: @$l: $@") if $@;
  }
  return $top;
}

1;

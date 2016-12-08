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

package BSDispatch::Constraints;

=head1 NAME

BSDispatch::Constraints - function to check and calculate constraints 

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


=head2 oracle - check constraints against worker

  my $ok = oracle($worker_strucht, $constraint_struct);
  checks if the given worker meets the constraints and can build the job. 

  Return Values:
    1   constraints ok
    0   constraint violation

=cut

sub oracle { 
  my ($worker, $constraints) = @_;
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

1;

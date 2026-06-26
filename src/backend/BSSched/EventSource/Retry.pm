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

package BSSched::EventSource::Retry;

use strict;
use warnings;

use Data::Dumper;

=head1

  Retry events

=cut


=head2 new - create a retry event source

 TODO

=cut

sub new {
  my ($class) = @_;
  my $self = {'queue' => []};
  return bless $self, $class;

}

=head2 addretryevent - add an event to the retry queue

 TODO

=cut

sub addretryevent {
  my ($self, $ev) = @_;
  my $type = $ev->{'type'};
  for my $oev (@{$self->{'queue'}}) {
    next if $type ne $oev->{'type'} || $ev->{'project'} ne $oev->{'project'};
    if ($type eq 'repository' || $type eq 'recheck' || $type eq 'unblocked') {
      next if $ev->{'repository'} ne $oev->{'repository'};
    } elsif ($type eq 'scanprjbinaries') {
      next if $ev->{'repository'} ne $oev->{'repository'} || ($ev->{'arch'} || '') ne ($oev->{'arch'} || '');
    } elsif ($type eq 'package') {
      next if ($ev->{'package'} || '') ne ($oev->{'package'} || '');
    }
    return;
  }
  $ev->{'retry'} = time() + 60;
  push @{$self->{'queue'}}, $ev;
}

=head2 due - remove all due retry events from the retry queue

=cut

sub due {
  my ($self) = @_;
  my $events = $self->{'queue'};
  my $now = time();
  my @due = grep {$_->{'retry'} <= $now} @$events;
  return () unless @due;
  @$events = grep {$_->{'retry'} > $now} @$events;
  delete $_->{'retry'} for @due;
  return @due;
}

=head2 events - return all retry events without removing them from the queue

=cut

sub events {
  my ($self) = @_;
  return @{$self->{'queue'}};
}

=head2 count - return the number of queued retry events

=cut

sub count {
  my ($self) = @_;
  return scalar(@{$self->{'queue'}});
}

1;

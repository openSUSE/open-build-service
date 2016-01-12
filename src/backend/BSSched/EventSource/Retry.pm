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


=head2 addretryevent - add an event to the retry queue

 TODO

=cut

sub addretryevent {
  my ($gctx, $ev) = @_;
  for my $oev (@{$gctx->{'retryevents'}}) {
    next if $ev->{'type'} ne $oev->{'type'} || $ev->{'project'} ne $oev->{'project'};
    if ($ev->{'type'} eq 'repository' || $ev->{'type'} eq 'recheck') {
      next if $ev->{'repository'} ne $oev->{'repository'};
    } elsif ($ev->{'type'} eq 'package') {
      next if ($ev->{'package'} || '') ne ($oev->{'package'} || '');
    }
    return;
  }
  $ev->{'retry'} = time() + 60;
  push @{$gctx->{'retryevents'}}, $ev;
}

=head2 getretryevents - get all due retry events from the retry queue

=cut

sub getretryevents {
  my ($gctx) = @_;
  my $retryevents = $gctx->{'retryevents'};
  my $now = time();
  my @due = grep {$_->{'retry'} <= $now} @$retryevents;
  return () unless @due;
  @$retryevents = grep {$_->{'retry'} > $now} @$retryevents;
  delete $_->{'retry'} for @due;
  return @due;
}

1;

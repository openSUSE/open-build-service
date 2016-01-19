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

package BSSched::EventQueue;

use strict;
use warnings;

use Data::Dumper;

use BSUtil;
use BSXML;
use BSConfiguration;
use BSSolv;
use BSSched::Checker;
use BSSched::BuildResult;
use BSSched::BuildRepo;
use BSSched::ProjPacks;
use BSSched::BuildJob;
use BSSched::BuildJob::Upload;
use BSSched::BuildJob::Import;
use BSSched::EventHandler;

=head1 NAME

 BSSched::EventQueue;

=head1 DESCRIPTION

 scheduler event queue handling

=head1 FUNCTIONS

=cut

our %event_handlers = (
  'built'           => \&BSSched::EventHandler::event_built,
  'uploadbuild'     => \&BSSched::EventHandler::event_built,
  'import'          => \&BSSched::EventHandler::event_built,

  'srcevent'        => \&BSSched::EventHandler::event_package,
  'package'         => \&BSSched::EventHandler::event_package,

  'project'         => \&BSSched::EventHandler::event_project,
  'projevent'       => \&BSSched::EventHandler::event_project,
  'lowprioproject'  => \&BSSched::EventHandler::event_project,
  'repository'      => \&BSSched::EventHandler::event_repository,
  'repoinfo'        => \&BSSched::EventHandler::event_repository,
  'rebuild'         => \&BSSched::EventHandler::event_check,
  'recheck'         => \&BSSched::EventHandler::event_check,
  'admincheck'      => \&BSSched::EventHandler::event_check,
  'unblocked'       => \&BSSched::EventHandler::event_check_med,
  'relsync'         => \&BSSched::EventHandler::event_check_med,
  'scanrepo'        => \&BSSched::EventHandler::event_scanrepo,
  'scanprjbinaries' => \&BSSched::EventHandler::event_scanprjbinaries,
  'dumprepo'        => \&BSSched::EventHandler::event_dumprepo,
  'wipenotyet'      => \&BSSched::EventHandler::event_wipenotyet,
  'wipe'            => \&BSSched::EventHandler::event_wipe,
  'exit'            => \&BSSched::EventHandler::event_exit,
  'exitcomplete'    => \&BSSched::EventHandler::event_exit,
  'restart'         => \&BSSched::EventHandler::event_exit,
  'dumpstate'       => \&BSSched::EventHandler::event_exit,
  'useforbuild'     => \&BSSched::EventHandler::event_useforbuild,
  'configuration'   => \&BSSched::EventHandler::event_configuration,
);


#
# EVENT QUEUE HANDLING
#

=head2 new - generate an event processor

 TODO: add description

=cut

sub new {
  my ($class, $gctx, @conf) = @_;
  my $ectx = {
    'gctx' => $gctx,
    'fetchprojpacks'          => {},
    'fetchprojpacks_nodelay'  => {},
    'deepcheck'               => {},
    'lowprioproject'          => {},
    'fullcache'               => undef,
    '_events'               => [],
    @conf
  };
  return bless $ectx, $class;
}

=head2 process_events - process a list of events

 TODO: add description

=cut

sub process_events {
  my ($ectx) = @_;

  my $gotevent = 0;
  my $gctx = $ectx->{'gctx'};

  $ectx->order() if @{$ectx->{_events}};

  while (@{$ectx->{_events}}) {
    my $ev = shift @{$ectx->{_events}};
    $ev->{'type'} ||= 'unknown';

    # have to be extra careful with uploadbuild/import events. if the package is in
    # (delayed)fetchprojpacks, delay event processing until we updated the projpack data.
    if ($ev->{'type'} eq 'uploadbuild' || $ev->{'type'} eq 'import') {
      if (BSSched::EventHandler::event_uploadbuildimport_delay($ectx, $ev)) {
	$gotevent = 1;    # still have an event to process
	next;
      }
    }

    # log event info
    if ($ev->{'type'} ne 'built') {
      my $estr = $ev->{'evfilename'} ? 'event' : 'remote event';
      for (qw{type project repository arch package}) {
	$estr .= " $ev->{$_}" if $ev->{$_};
      }
      print "$estr\n";
    }

    unlink($ev->{'evfilename'}) if $ev->{'evfilename'};
    delete $ev->{'evfilename'};

    if ($ev->{'type'} ne 'built' && $ectx->{'fullcache'}) {
      BSSched::BuildRepo::sync_fullcache($gctx, $ectx->{'fullcache'});
      $ectx->{'fullcache'} = undef;
    }
    if ($ev->{'type'} eq 'built' && !$ectx->{'fullcache'}) {
      # turn on fullcache if the next event is also of type built
      $ectx->{'fullcache'} = {} if $ectx->{_events}->[0] && $ectx->{_events}->[0]->{'type'} eq 'built';
    }
    $ectx->process_one($ev);
  }

  BSSched::BuildRepo::sync_fullcache($gctx, $ectx->{'fullcache'}) if $ectx->{'fullcache'} && $ectx->{'fullcache'}->{'prp'};
  $ectx->{'fullcache'} = undef;

  # postprocess
  if (%{$ectx->{'fetchprojpacks'}}) {
    BSSched::ProjPacks::do_fetchprojpacks($gctx,
					  $ectx->{'fetchprojpacks'}, $ectx->{'fetchprojpacks_nodelay'},
					  $ectx->{'deepcheck'}, $ectx->{'lowprioproject'});
  }
  $ectx->{'fetchprojpacks'} = {};
  $ectx->{'fetchprojpacks_nodelay'} = {};
  $ectx->{'deepcheck'} = {};
  $ectx->{'lowprioproject'} = {};
  return $gotevent;
}

=head2 process_one - process a single event

 TODO: add description

=cut

sub process_one {
  my ($ectx, $ev) = @_;
  my $type = $ev->{'type'} || 'unknown';
  if ($ectx->{'initialstartup'} && ($type eq 'exit' || $type eq 'exitcomplete')) {
    print "WARNING: there was an exit event, but we ignore it directly after starting the scheduler.\n";
    return;
  }
  my $evhandler = $event_handlers{$type};
  if ($evhandler) {
    $evhandler->($ectx, $ev);
  } else {
    print "unknown event type '$type'\n";
  }
}

=head2 order - order events so that the important ones come first

 TODO: add description

=cut

sub order {
  my ($ectx) = @_;
  
  if (@{$ectx->{_events}} > 1) {
    # sort events a bit, exit events go first ;-)
    # uploadbuild/import events must go last
    my %evprio = ('exit' => -1, 'exitcomplete' => -1, 'restart' => -1, 'uploadbuild' => 1, 'import' => 1);
    @{$ectx->{_events}}  = sort {
                    # the following lines might look a bit nasty, but this is needed to avoid 
                    # "Uninitialized values" warings
                    ($evprio{$a->{'type'} || ''} || 0) <=> ($evprio{$b->{'type'} || ''} || 0) || 
                    ($a->{'type'} || '' )  cmp ($b->{'type'} || '') ||
                    ($a->{'project'} || '') cmp ($b->{'project'} || '') ||
                    ($a->{'job'} || '') cmp ($b->{'job'} || '')
                    } @{$ectx->{_events}} ;
  }
  return 0;
}

sub add_events {
  my $self = shift;
  push(@{$self->{_events}},@_);
}

=head2 get_events - get list of actual events

  returns a ArrayRef

=cut

sub get_events {
  return $_[0]->{_events};
}

=head2 events_in_queue - get counter of events in queue

=cut

sub events_in_queue { return scalar(@{$_[0]->{_events}}) }

1;

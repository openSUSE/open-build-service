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

package BSSched::EventSource::Directory;

use strict;
use warnings;

use POSIX;
use Digest::MD5 ();
use Data::Dumper;

use BSUtil;
use BSXML;

=head1 NAME

 BSSched::EventSource::Directory

=head1 DESCRIPTION

 This class/module is reponsible for the scheduler`s event management, 
 e.g. creating, sending and reading events.

=head1 FUNCTIONS

=cut

###
###  Event reader code
###

=head2 readevents - read events from a directory

 we special case the "built" event type as it is so common

=cut

sub readevents {
  my ($gctx, $eventdir) = @_;
  my @events;

  for my $evfilename (sort(ls($eventdir))) {
    next if $evfilename =~ /^\./;
    my $ev;
    if ($evfilename =~ /^finished:(.*)/) {
      $ev = {'type' => 'built', 'job' => $1, 'evfilename' => "$eventdir/$evfilename"};
    } else {
      $ev = readxml("$eventdir/$evfilename", $BSXML::event, 1);
      if (!$ev) {
	print "$evfilename: bad event xml\n";
	unlink("$eventdir/$evfilename");
        next;
      }
      $ev->{'type'} ||= 'unknown';
      $ev->{'evfilename'} = "$eventdir/$evfilename";
    }
    push @events, $ev;
  }
  return @events;
}

###
###  Event writer code
###

=head2 sendevent - send an event to a different scheduler / publisher / signer

 TODO: add description

=cut

sub sendevent {
  my ($gctx, $ev, $arch, $evname) = @_;

  my $eventdir = $gctx->{'eventdir'};
  mkdir_p("$eventdir/$arch");
  $evname = "$ev->{'type'}:::".Digest::MD5::md5_hex($evname) if length($evname) > 200;
  writexml("$eventdir/$arch/.$evname$$", "$eventdir/$arch/$evname", $ev, $BSXML::event);
  BSUtil::ping("$eventdir/$arch/.ping");
}

=head2 sendrepochangeevent - send a repository/repoinfo event

 we don't directly send it to the src server, as this would
 slow down the scheduler too much. Instead, we write it on
 disk and the dispatcher will pick it up and send it for us.

=cut

sub sendrepochangeevent {
  my ($gctx, $prp, $type) = @_;

  my $myarch = $gctx->{'arch'};
  my ($projid, $repoid) = split('/', $prp, 2);
  my $ev = {
    'type' => ($type || 'repository'),
    'project' => $projid,
    'repository' => $repoid,
    'arch' => $myarch,
  };
  sendevent($gctx, $ev, 'repository', "$ev->{'type'}::${projid}::${repoid}::${myarch}");
}

=head2 sendunblockedevent - send an unblocked event to another scheduler

 input: $prp  - prp that is unblocked
        $arch - target scheduler architecture

=cut

sub sendunblockedevent {
  my ($gctx, $prp, $arch, $type) = @_;

  my $eventdir = $gctx->{'eventdir'};
  return unless -e "$eventdir/$arch/.ping";
  $type ||= 'unblocked';
  my ($projid, $repoid) = split('/', $prp, 2);
  my $ev = {
    'type' => $type,
    'project' => $projid,
    'repository' => $repoid,
  };
  sendevent($gctx, $ev, $arch, "${type}::${projid}::${repoid}");
}

=head2 sendpublishevent - send a publish event to the publisher

 input: $prp - prp to be published

=cut

sub sendpublishevent {
  my ($gctx, $prp) = @_;

  my ($projid, $repoid) = split('/', $prp, 2);
  my $ev = {
    'type' => 'publish',
    'project' => $projid,
    'repository' => $repoid,
  };
  sendevent($gctx, $ev, 'publish', "${projid}::$repoid");
}

=head2 sendimportevent - send an import event to another scheduler

 input: $job - import job name
        $arch - target scheduler architecture

=cut

sub sendimportevent {
  my ($gctx, $job, $arch) = @_;
  my $ev = {
    'type' => 'import',
    'job' => $job,
  };
  # prefix with "import." so that there's no name conflict
  sendevent($gctx, $ev, $arch, "import.$job");
}

1;

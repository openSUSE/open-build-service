#
# Copyright (c) 2010 Anas Nashif, Intel Inc.
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
#
# Module to talk to RabbitMQ
#

package notify_rabbitmq;

use Net::RabbitMQ;
use BSConfig;
use JSON::XS;
#use Data::UUID;

use strict;

sub new {
  my $self = {};
  bless $self, shift;
  return $self;
}

sub notify() {
  my ($self, $type, $paramRef ) = @_;

  $type = "UNKNOWN" unless $type;
  my $prefix = $BSConfig::notification_namespace || "OBS";
  $type =  "${prefix}_$type";


  #my $uu = Data::UUID->new;
  if ($paramRef) {
    $paramRef->{'eventtype'} = $type;
    my $mq = Net::RabbitMQ->new();
    $mq->connect("192.168.50.99", { user => "mailer", password => "mailerpwd", vhost => "mailer_vhost" });
    warn("RabbitMQ Plugin: $@") if $@;
    $mq->channel_open(1);
    #$mq->queue_declare(1, "mailer_queue");
    $mq->queue_bind(1, "mailer_queue", "mailer_exchange", "mailer");
    $mq->publish(1, "mailer", encode_json($paramRef), { exchange => 'mailer_exchange' });
    $mq->disconnect();
  }


}

1;

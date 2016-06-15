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

use Net::AMQP::RabbitMQ;
use BSConfig;
use JSON::XS;
#use Data::UUID;

use strict;

sub new {
  my $self = {};
  bless $self, shift;
  return $self;
}

# compat...
my $defaultconfig = {
  'server' => "192.168.50.99",
  'user' => "mailer",
  'password' => "mailerpwd",
  'vhost' => "mailer_vhost",
};

sub notify() {
  my ($self, $type, $paramRef ) = @_;

  my $prefix = $BSConfig::notification_namespace || "OBS";
  $type ||= "UNKNOWN";
  $type =  "${prefix}_$type";

  #my $uu = Data::UUID->new;
  $paramRef ||= {};
  $paramRef->{'eventtype'} = $type;
  my $mq = Net::AMQP::RabbitMQ->new();
  my %rabbitparam = %{$BSConfig::rabbitmqconfig || $BSConfig::rabbitmqconfig || $defaultconfig};
  my $rabbitserver = delete $rabbitparam{'server'};
  $mq->connect($rabbitserver, \%rabbitparam);
  $mq->channel_open(1);
  #$mq->queue_declare(1, "mailer_queue");
  $mq->queue_bind(1, "mailer_queue", "mailer_exchange", "mailer");
  $mq->publish(1, "mailer", encode_json($paramRef), { exchange => 'mailer_exchange' });
  $mq->disconnect();
}

1;

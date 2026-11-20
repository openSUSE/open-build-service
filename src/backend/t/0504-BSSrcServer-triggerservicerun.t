#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 3;

use Test::Mock::BSConfig;

require_ok('BSSrcServer::Service');

# A package without a _service file really has no service defined.
is(BSSrcServer::Service::no_service_to_trigger_error({ 'foo' => 'd41d8cd98f00b204e9800998ecf8427e' }),
   'no source service defined!',
   'reports no service defined when the package has no _service file');

# A package with a _service file only reaches triggerservicerun when none of its
# services is active, i.e. all of them are manual, disabled, localonly or buildtime.
is(BSSrcServer::Service::no_service_to_trigger_error({ '_service' => 'd41d8cd98f00b204e9800998ecf8427e' }),
   'no active source service to trigger, the services are in manual, disabled, localonly or buildtime mode!',
   'reports inactive services when the package has a _service file');

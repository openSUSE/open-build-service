#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 9;

use Test::Mock::BSConfig;

require_ok('BSSrcServer::Remote');

my $projid = 'RemoteInstance:openSUSE:Factory';
my $proj = {
  'remoteurl' => 'https://api.example.org/public',
  'remoteproject' => 'openSUSE:Factory',
};
my $uri = 'https://api.example.org/public/source/openSUSE:Factory';

my %status = (
  401 => '401 remote error: Unauthorized',
  403 => '403 remote error: Forbidden',
  404 => '404 remote error: Not Found',
);

# Returns the package list, the error and the warnings of findpackages_remote
# when the remote instance answers with the given HTTP status.
sub findpackages_with_status {
  my ($code, $nonfatal) = @_;
  no warnings 'redefine';
  local *BSRPC::rpc = sub {
    my ($param) = @_;
    die("$status{$code} ($param->{'uri'})\n");
  };
  my @warnings;
  local $SIG{'__WARN__'} = sub { push @warnings, @_ };
  my @packids = eval { BSSrcServer::Remote::findpackages_remote($projid, $proj, $nonfatal) };
  return [ \@packids, $@, \@warnings ];
}

{
  no warnings 'redefine';
  local *BSRPC::rpc = sub {
    return { 'entry' => [ { 'name' => 'pack1' }, { 'name' => 'pack2' } ] };
  };
  my @got = BSSrcServer::Remote::findpackages_remote($projid, $proj, 2);
  is_deeply(\@got, [ 'pack1', 'pack2' ], 'lists the packages of the remote project');
}

# nonfatal 2 is what getprojpack (bs_srcserver) passes for the scheduler
is_deeply(findpackages_with_status(404, 2), [ [], '', [] ],
  '404 with nonfatal 2: empty package list, no error');
is_deeply(findpackages_with_status(401, 2), [ [ ':missing_packages' ], '', [ "$status{401} ($uri)\n" ] ],
  '401 with nonfatal 2: the list is marked as incomplete');
is_deeply(findpackages_with_status(403, 2), [ [ ':access_denied' ], '', [ "$status{403} ($uri)\n" ] ],
  '403 with nonfatal 2: the list is marked as denied');

# nonfatal -1 is what findpackages_projlink (BSSrcServer/Projlink.pm) passes
is_deeply(findpackages_with_status(404, -1), [ [], '', [] ],
  '404 with nonfatal -1: empty package list, no error');
is_deeply(findpackages_with_status(401, -1), [ [], "$status{401} ($uri)\n", [] ],
  '401 with nonfatal -1: dies');
is_deeply(findpackages_with_status(403, -1), [ [], "$status{403} ($uri)\n", [] ],
  '403 with nonfatal -1: dies');

is_deeply(findpackages_with_status(404, undef), [ [], "$status{404} ($uri)\n", [] ],
  '404 without nonfatal: dies');

exit 0;

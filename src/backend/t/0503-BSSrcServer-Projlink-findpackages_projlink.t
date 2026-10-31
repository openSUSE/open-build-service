#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 3;

use Test::Mock::BSConfig;

require_ok('BSSrcServer::Projlink');

# Returns what findpackages_projlink lists for a project linking to a project
# whose package list is @linked.
sub findpackages_linking_to {
  my (@linked) = @_;
  no warnings qw(once redefine);
  local *BSSrcServer::Projlink::get_frozenlinks = sub { return undef };
  local *BSRevision::readproj_local = sub { return undef };
  local $BSSrcServer::Projlink::findpackages = sub { return @linked };
  my $proj = { 'name' => 'home:user', 'link' => [ { 'project' => 'RemoteInstance:openSUSE:Factory' } ] };
  return [ BSSrcServer::Projlink::findpackages_projlink('home:user', $proj, 2) ];
}

is_deeply(findpackages_linking_to('pack1', 'pack1:flavor', ':missing_packages'), [ ':missing_packages', 'pack1' ],
  'keeps the :missing_packages marker and drops multibuild flavors');
is_deeply(findpackages_linking_to('pack1', ':access_denied'), [ ':access_denied', 'pack1' ],
  'keeps the :access_denied marker');

exit 0;

#
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
#
# Build Service Configuration
#

package BSConfig;

use Net::Domain;
use BSServer;

my $hostname = Net::Domain::hostfqdn();
$hostname = "localhost" unless defined($hostname);

# configured to run on your localhost only
our $srcserver = "http://$hostname:6362";
our $reposerver = "http://$hostname:6262";
our $repodownload = "http://$hostname/repositories";
our $hermesserver = "http://$hostname/hermes";
our $hermesnamespace = "OBS";

# For the workers only, it is possible to define multiple repository servers here.
# But only one source server is possible yet.
our @reposervers = ("http://$hostname:6262");

# Package defaults
our $bsdir = '/srv/obs';
our $bsuser = 'obsrun';
our $bsgroup = 'obsrun';

#No extra stage server sync
#our $stageserver = 'rsync://127.0.0.1/put-repos-main';
#our $stageserver_sync = 'rsync://127.0.0.1/trigger-repos-sync';

#No public download server
#our $repodownload = 'http://software.opensuse.org/download/repositories';

#No package signing server
#our $sign = '/root/bin/sign';

# host specific configs
my $hostconfig = "bsconfig." . Net::Domain::hostname();
# print STDERR "TRYING TO READ CONFIG <$hostconfig>\n";

if( -r $hostconfig ) {
  my $return = do $hostconfig;
  if( $return ) {
    BSServer::msg( "Read local config <$hostconfig>" );
  } else {
    if( $@ ) {
      warn( "Cannot compile $hostconfig: $@" );
    } elsif( $! ) {
      warn( "Cannot read $hostconfig: $!" );
    } else {
      warn( "Cannot find $hostconfig" );
    }
  }
}

1;

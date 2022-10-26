#
# Copyright (c) 2018 Novell Inc.
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
# BSRegistryServer: registry server helpers
#

package BSRegistryServer;

use JSON::XS ();

use BSServer;
use BSStdServer;

our $registry_api_hdr = 'Docker-Distribution-Api-Version: registry/2.0';

my %registry_errors = (
  '400' => 'Bad Request',
  '404' => 'Not Found',
  '416' => 'Range Not Satisfiable',
  '500' => 'Internal Server Error',
);

sub errreply {
  return BSStdServer::errreply(@_) unless (($BSServer::request || {})->{'path'} || '') =~ /^\/registry/;
  my ($err, $code, $tag, @hdrs) = @_;
  my $regcode = 'SERVER_ERROR';
  if ($tag =~ /^([A-Z_]+)(?:\s+(.+?))?$/) {
    $regcode = $1;
    $tag = defined($2) ? $2 : '';
    if ($regcode eq 'RANGE_NOT_SATISFIABLE' && $tag =~ /^\d+$/) {
      push @hdrs, "Content-Range: bytes */$tag";
      undef $tag;
    }    
  }
  my $error = { 'code' => $regcode };
  $error->{'message'} = $tag if $tag;
  my $ret = { 'errors' => [ $error ] }; 
  $ret = JSON::XS->new->utf8->canonical->encode($ret);
  $tag = $registry_errors{$code} || $regcode;
  BSServer::reply($ret, "Status: $code $tag", 'Content-Type: application/json', $registry_api_hdr, @hdrs);
}

sub reply {
  my ($ret, @hdrs) = @_;
  return unless defined $ret;
  if (ref($ret)) {
    $ret = JSON::XS->new->utf8->canonical->encode($ret);
    unshift @hdrs, 'Content-Type: application/json' unless grep {/^content-type:/i} @hdrs;
  }
  push @hdrs, $registry_api_hdr;
  BSServer::reply($ret, @hdrs);
}

sub paginate {
  my ($cgi, $elements, $link, $hdrs) = @_;
  if (defined($cgi->{'last'})) {
    shift @$elements while @$elements && $elements->[0] le $cgi->{'last'};
  }
  @$elements = () if defined($cgi->{'n'}) && $cgi->{'n'} <= 0;
  if ($cgi->{'n'} && @$elements > $cgi->{'n'}) {
    @$elements = splice(@$elements, 0, $cgi->{'n'});
    my @link = map {BSHTTP::urlencode($_)} ($link, "$cgi->{'n'}", "$elements->[-1]");
    push @$hdrs, "Link: <$link[0]?n=$link[1]&last=$link[2]>; rel=\"next\"";
  }
}

1;

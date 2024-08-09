#
# Copyright (c) 2020 SUSE LLC
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
# Container handling of the publisher
#

package BSPublisher::Helm;

use BSTar;
use BSUtil;
use JSON::XS ();

eval { require YAML::XS; $YAML::XS::LoadBlessed = 0; };
*YAML::XS::Dump = sub {die("YAML::XS is not available\n")} unless defined &YAML::XS::Dump;

use strict;

# this also works as a containerinfo substitute
sub readhelminfo {
  my ($dir, $helminfofile) = @_;
  return undef unless -e "$dir/$helminfofile";
  return undef unless (-s _) < 1000000;
  my $m = readstr("$dir/$helminfofile");
  my $d;
  eval { $d = JSON::XS::decode_json($m); };
  return undef unless $d && ref($d) eq 'HASH';
  if (exists $d->{'tags'}) {
    $d->{'tags'} = [] unless ref($d->{'tags'}) eq 'ARRAY';
    for (splice @{$d->{'tags'}}) {
      push @{$d->{'tags'}}, $_ if defined($_) && ref($_) eq '';
    }
  }
  for my $k (qw{disturl buildtime name version release config_json}) {
    my $v = $d->{$k};
    $d->{$k} = $v if defined($v) && ref($v) eq '';
  }
  return undef unless $d->{'name'} && $d->{'config_json'};
  $d->{'chart'} = $helminfofile;
  $d->{'chart'} =~ s/.*\///;
  $d->{'chart'} =~ s/\.helminfo$/.tgz/;
  $d->{'type'} = 'helm';
  return $d;
}

# generate iso utc time 
sub isodatetimez {
  my ($t) = @_;
  my @gt = gmtime($t || time());
  return sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ", $gt[5] + 1900, $gt[4] + 1, @gt[3,2,1,0];
}

# generate an index entry from the helminfo
sub mkindexentry {
  my ($helminfo, $url) = @_;
  return undef unless $helminfo->{'config_json'} && $helminfo->{'chart_sha256'};
  my $chart;
  eval { $chart = JSON::XS::decode_json($helminfo->{'config_json'}) };
  return undef unless $chart && ref($chart) eq 'HASH';
  return undef unless $chart->{'name'} eq $helminfo->{'name'};	# sanity
  $chart->{'digest'} = $helminfo->{'chart_sha256'};
  $chart->{'urls'} = [ $url ] if $url;
  $chart->{'created'} = isodatetimez($helminfo->{'buildtime'});
  return $chart;
}

# generate the index of all charts
sub mkindex {
  my ($entries) = @_;
  for my $ents (values %$entries) {
    $ents = [ sort {$a->{'version'} cmp $b->{'version'}} @$ents ];
  }
  my $index = {
    'apiVersion' => 'v1',
    'entries' => $entries,
    'generated' => isodatetimez(),
  };
  return $index;
}

sub toyaml {
  my $yaml = YAML::XS::Dump($_[0]);
  $yaml =~ s/^---\n//s;
  return $yaml;
}

sub mkindex_yaml {
  return toyaml(mkindex(@_));
}

sub helminfo2nevra {
  my ($d) = @_;
  my $lnk = {};
  $lnk->{'name'} = "helm:$d->{'name'}";
  $lnk->{'version'} = defined($d->{'version'}) ? $d->{'version'} : '0';
  $lnk->{'release'} = defined($d->{'release'}) ? $d->{'release'} : '0';
  $lnk->{'arch'} = 'noarch';
  return $lnk;
}

1;

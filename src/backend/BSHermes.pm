#
# Copyright (c) 2008 Klaas Freitag, Novell Inc.
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
# Module to talk to Hermes
#

package BSHermes;

use BSRPC;
use BSConfig;

use strict;

sub notify($$) {
  my ($type, $paramRef ) = @_;

  return unless $BSConfig::hermesserver;

  my @args = ( "rm=notify" );

  $type = "UNKNOWN" unless $type;
  # prepend something BS specific
  my $prefix = $BSConfig::hermesnamespace || "OBS";
  $type =  "${prefix}_$type";

  push @args, "_type=$type";

  if ($paramRef) {
    for my $key (sort keys %$paramRef) {
      next if ref $paramRef->{$key};
      push @args, "$key=$paramRef->{$key}" if defined $paramRef->{$key};
    }
  }

  my $hermesuri = "$BSConfig::hermesserver/index.cgi";

  # print STDERR "Notifying hermes at $hermesuri: <" . join( ', ', @args ) . ">\n";

  my $param = {
    'uri' => $hermesuri,
    'timeout' => 60,
  };
  eval {
    BSRPC::rpc( $param, undef, @args );
  };
  warn("Hermes: $@") if $@;
}

# assemble hermes conform parameters for BS Requests
sub requestParams( $$ )
{
  my ($req, $user) = @_;

  my %reqinfo;

  $reqinfo{'id'} = $req->{'id'} || '';
  $reqinfo{'type'} = $req->{'type'} || '';
  $reqinfo{'description'} = $req->{'description'};
  $reqinfo{'state'} = '';
  $reqinfo{'when'}  = '';
  if( $req->{'state'} ) {
    $reqinfo{'state'} = $req->{'state'}->{'name'} || '';
    $reqinfo{'when'}  = $req->{'state'}->{'when'} || '';
    $reqinfo{'comment'} = $req->{'state'}->{'comment'};
  }
  $reqinfo{'who'} = $user || 'unknown';
  $reqinfo{'sender'} = $reqinfo{'who'};

  my $actions;
  if ($req->{'type'} && $req->{'type'} eq 'submit' && $req->{'submit'}) {
    # old style submit requests
    push @$actions, $req->{'submit'};
  }else{
    $actions = $req->{'action'};
  }

  for my $a (@{$actions || []}) {
    # FIXME: how to handle multiple actions in one request here ?
    # right now the last one just wins ....
    $reqinfo{'type'} = $a->{'type'};
    if( $a->{'type'} eq 'submit' && $a->{'source'} &&
        $a->{'target'}) {
        $reqinfo{'sourceproject'}  = $a->{'source'}->{'project'};
        $reqinfo{'sourcepackage'}  = $a->{'source'}->{'package'};
        $reqinfo{'sourcerevision'} = $a->{'source'}->{'rev'};
        $reqinfo{'targetproject'}  = $a->{'target'}->{'project'};
        $reqinfo{'targetpackage'}  = $a->{'target'}->{'package'};
    }elsif( $a->{'type'} eq 'change_devel' && $a->{'source'} &&
            $a->{'target'}) {
        $reqinfo{'sourceproject'}  = $a->{'source'}->{'project'};
        $reqinfo{'sourcepackage'}  = $a->{'source'}->{'package'};
        $reqinfo{'targetproject'}  = $a->{'target'}->{'project'};
        $reqinfo{'targetpackage'}  = ($a->{'target'}->{'package'} || $a->{'source'}->{'package'});
    }elsif( $a->{'type'} eq 'delete' && $a->{'target'}->{'project'} ) {
        $reqinfo{'deleteproject'}  = $a->{'target'}->{'project'};
        $reqinfo{'deletepackage'}  = $a->{'target'}->{'package'};
    }
  }
  if( $req->{'oldstate'} ) {
    $reqinfo{'oldstate'} = $req->{'oldstate'}->{'name'};
  }
  $reqinfo{'author'} = $req->{'history'} ? $req->{'history'}->[0]->{'who'} : $req->{'state'}->{'who'};
  return \%reqinfo;
}

##
# generate_commit_flist($files_old, $files_new)
#
#   $files_old/$files_new are hash references as returned by lsrep
#
#   returns a list of changed files categorized similar to svn commit mails
#
sub generate_commit_flist {
  my $ret = "";
  my %categorized_files;
  my ($files_old, $files_new) = @_;
  my %files_all = (%$files_new, %$files_old);
  for my $fname (sort keys %files_all) {
    if(!$files_old->{$fname}) {
      my $flist = $categorized_files{"Added:"} ||= [];
      push(@$flist, $fname);
    } elsif(!$files_new->{$fname}) {
      my $flist = $categorized_files{"Deleted:"} ||= [];
      push(@$flist, $fname);
    } elsif($files_old->{$fname} ne $files_new->{$fname}) {
      my $flist = $categorized_files{"Modified:"} ||= [];
      push(@$flist, $fname);
    }
  }

  for my $cat (sort keys %categorized_files) {
    $ret .= "$cat\n";
    for my $fname (@{$categorized_files{$cat}}) {
      $ret .= "  $fname\n";
    }
    $ret .= "\n";
  }
  return $ret;
}

1;

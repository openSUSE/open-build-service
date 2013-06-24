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
# Module to talk to notification systems
#

package BSNotify;

use BSRPC;
use BSConfig;

use strict;

sub notify($$) {
  my ($type, $paramRef ) = @_;

  return unless $BSConfig::notification_plugin;

  my @hostnames = split(/\s+/, $BSConfig::notification_plugin);

  for my $hostname (@hostnames) {
      my $notifier = &loadPackage($hostname);
      $notifier->notify($type, $paramRef );
  }

}

sub loadPackage {
  my ($componentname) = @_;
  my $file = "plugins/$componentname.pm";

  my $componentfile = $file;
  eval{
     require "$componentfile";
  };
  print "error: $@" if $@;
  my $obj = $componentname->new();
  return $obj;    
}

# FIXME2.4 remove whole function
# Create parameters for BS Requests
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
    if ($BSConfig::multiaction_notify_support) {
      # Use a nested data structure to support multiple actions in one request
      my %action ;
      $action{'type'} = $a->{'type'};
      if( $a->{'type'} eq 'submit' && $a->{'source'} &&
	  $a->{'target'}) {
        $action{'sourceproject'}  = $a->{'source'}->{'project'};
        $action{'sourcepackage'}  = $a->{'source'}->{'package'};
        $action{'sourcerevision'} = $a->{'source'}->{'rev'};
        $action{'targetproject'}  = $a->{'target'}->{'project'};
        $action{'targetpackage'}  = $a->{'target'}->{'package'};
        $action{'deleteproject'}  = undef;
        $action{'deletepackage'}  = undef;
        $action{'person'} = undef;
        $action{'role'} = undef;
      }elsif( $a->{'type'} eq 'change_devel' && $a->{'source'} &&
	      $a->{'target'}) {
        $action{'sourceproject'}  = $a->{'source'}->{'project'};
        $action{'sourcepackage'}  = $a->{'source'}->{'package'};
        $action{'targetproject'}  = $a->{'target'}->{'project'};
        $action{'targetpackage'}  = ($a->{'target'}->{'package'} || $a->{'source'}->{'package'});
        $action{'deleteproject'}  = undef;
        $action{'deletepackage'}  = undef;
        $action{'sourcerevision'} = undef;
        $action{'person'} = undef;
        $action{'role'} = undef;
      }elsif( $a->{'type'} eq 'add_role' &&  $a->{'target'}->{'project'}) {
        $action{'targetproject'}  = $a->{'target'}->{'project'};
        $action{'targetpackage'}  = $a->{'target'}->{'package'};
        $action{'sourceproject'}  = undef;
        $action{'sourcepackage'}  = undef;
        $action{'deleteproject'}  = undef;
        $action{'deletepackage'}  = undef;
        $action{'sourcerevision'} = undef;
        $action{'person'} = $a->{'person'}->{'name'};
        $action{'role'} = $a->{'person'}->{'role'};
      }elsif( $a->{'type'} eq 'delete' && $a->{'target'}->{'project'} ) {
        # FIXME3 this parameter is duplicating infos
        $action{'deleteproject'}  = $a->{'target'}->{'project'};
        $action{'deletepackage'}  = $a->{'target'}->{'package'};
        $action{'sourceproject'}  = undef;
        $action{'sourcepackage'}  = undef;
        $action{'targetproject'}  = $a->{'target'}->{'project'};
        $action{'targetpackage'}  = $a->{'target'}->{'package'};
        $action{'sourcerevision'} = undef;
        $action{'person'} = undef;
        $action{'role'} = undef;
      }
      push @{$reqinfo{'actions'}}, \%action;
    } else {
      # This is the old code that doesn't handle multiple actions in one request.
      # The last one just wins ....
      # Needed until Hermes supports $reqinfo{'actions'}
      $reqinfo{'type'} = $a->{'type'};
      if( $a->{'type'} eq 'submit' && $a->{'source'} &&
	  $a->{'target'}) {
        $reqinfo{'sourceproject'}  = $a->{'source'}->{'project'};
        $reqinfo{'sourcepackage'}  = $a->{'source'}->{'package'};
        $reqinfo{'sourcerevision'} = $a->{'source'}->{'rev'};
        $reqinfo{'targetproject'}  = $a->{'target'}->{'project'};
        $reqinfo{'targetpackage'}  = $a->{'target'}->{'package'};
        $reqinfo{'deleteproject'}  = undef;
        $reqinfo{'deletepackage'}  = undef;
        $reqinfo{'person'} = undef;
        $reqinfo{'role'} = undef;
      }elsif( $a->{'type'} eq 'change_devel' && $a->{'source'} &&
	      $a->{'target'}) {
        $reqinfo{'sourceproject'}  = $a->{'source'}->{'project'};
        $reqinfo{'sourcepackage'}  = $a->{'source'}->{'package'};
        $reqinfo{'targetproject'}  = $a->{'target'}->{'project'};
        $reqinfo{'targetpackage'}  = ($a->{'target'}->{'package'} || $a->{'source'}->{'package'});
        $reqinfo{'deleteproject'}  = undef;
        $reqinfo{'deletepackage'}  = undef;
        $reqinfo{'sourcerevision'} = undef;
        $reqinfo{'person'} = undef;
        $reqinfo{'role'} = undef;
      }elsif( $a->{'type'} eq 'add_role' &&  $a->{'target'}->{'project'}) {
        $reqinfo{'targetproject'}  = $a->{'target'}->{'project'};
        $reqinfo{'targetpackage'}  = $a->{'target'}->{'package'};
        $reqinfo{'sourceproject'}  = undef;
        $reqinfo{'sourcepackage'}  = undef;
        $reqinfo{'deleteproject'}  = undef;
        $reqinfo{'deletepackage'}  = undef;
        $reqinfo{'sourcerevision'} = undef;
        $reqinfo{'person'} = $a->{'person'}->{'name'};
        $reqinfo{'role'} = $a->{'person'}->{'role'};
      }elsif( $a->{'type'} eq 'delete' && $a->{'target'}->{'project'} ) {
        # FIXME3 this parameter is duplicating infos
        $reqinfo{'deleteproject'}  = $a->{'target'}->{'project'};
        $reqinfo{'deletepackage'}  = $a->{'target'}->{'package'};
        $reqinfo{'sourceproject'}  = undef;
        $reqinfo{'sourcepackage'}  = undef;
        $reqinfo{'targetproject'}  = $a->{'target'}->{'project'};
        $reqinfo{'targetpackage'}  = $a->{'target'}->{'package'};
        $reqinfo{'sourcerevision'} = undef;
        $reqinfo{'person'} = undef;
        $reqinfo{'role'} = undef;
      }
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

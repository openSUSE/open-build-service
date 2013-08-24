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

# Copyright (c) 2015 SUSE LLC
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
package BSSched::RPC;

use strict;
use warnings;

use Data::Dumper;

use BSRPC;
use BSUtil;
use BSConfiguration;

=head1 NAME

 BSSched::RPC

=head1 DESCRIPTION

 TODO: add description

=head1 SYNOPSIS


=head1 METHODS

=head2 new - create a new rpc manager

 TODO: add description

=cut

sub new {
  my ($class, @conf) = @_;
  my $rctx = {
    'iswaiting' => {},
    'iswaiting_server' => {},
    'iswaiting_serverload' => {},
    'iswaiting_serverload_low' => {},
    'resumed_highload' => 0,
    'wakeupfunction' => sub { die("BSSched::RPC: no wakeupfunction defined\n") },
    @conf
  };
  return bless $rctx, $class;
}

=head2 is_transient_error - TODO: add summary

 TODO: add description

=cut

sub is_transient_error {
  my ($error) = @_;
  return 1 if $error =~ /^5\d\d/;
  if ($error =~ /^400/) {
    return 1 if $error =~ /Too many open files/;
    return 1 if $error =~ /No space left on device/;
    return 1 if $error =~ /Not enough space/;
    return 1 if $error =~ /Resource temporarily unavailable/;
  }
  return 0 if $error =~ /remote error:/;
  return 1;
}

=head2 xrpc - TODO: add summary

 TODO: add description

=cut

sub xrpc {
  my ($rctx, $ctx, $resource, $param, @args) = @_;

  my $async = $param->{'async'};
  return BSRPC::rpc($param, @args) unless $async;

  my $iswaiting = $rctx->{'iswaiting'};
  my $rhandle = $iswaiting->{$resource};
  if ($rhandle) {
    # resource is busy. Enqueue.
    if (!$ctx->{'_orderedrpcs'} && $ctx->{'changeprp'}) {
      # xrpc resulted from looking at a prp. Just do that again. Order does not matter.
      my $handle = { '_ctx' => $ctx};
      $handle->{$_} = $async->{$_} for keys %$async;
      push @{$rhandle->{'_wakeup'}}, $handle;
      return $handle;
    }
    # project rpcs, we need to run them in order
    my $handle = { '_xrpc_data' => [$ctx, $resource, $param, @args] };
    push @{$rhandle->{'_nextxrpc'}}, $handle;
    return $handle;
  }

  # free to get resource from server
  my $server = $param->{'uri'};
  $server =~ s/.*?\/\///;
  $server =~ s/\/.*//;
  my $maxserverload = $rctx->{'maxserverload'};
  my $iswaiting_server = $rctx->{'iswaiting_server'};
  my $serverload = scalar(keys %{$iswaiting_server->{$server} || {}});
  if (defined($maxserverload) && $serverload >= $maxserverload) {
    # load too high. postpone.
    my $handle = { '_xrpc_data' => [$ctx, $resource, $param, @args] };
    if (($async->{'_changetype'} || $ctx->{'changetype'} || '') ne 'low') {
      push @{$rctx->{'iswaiting_serverload'}->{$server}}, $handle;
    } else {
      push @{$rctx->{'iswaiting_serverload_low'}->{$server}}, $handle;
    }
    $handle->{'_iswaiting'} = $resource;
    $handle->{'_server'} = $server;
    $iswaiting->{$resource} = $handle;
    return $handle;
  }
  my $handle = BSRPC::rpc($param, @args);
  $handle->{'_ctx'} = $ctx;
  $handle->{'_iswaiting'} = $resource;
  $handle->{'_server'} = $server;

  $handle->{$_} = $async->{$_} for keys %$async;
  $iswaiting->{$resource} = $handle;
  $iswaiting_server->{$server}->{$resource} = 1;
  return $handle;
}

=head2 xrpc_addwakeup - TODO: add summary

 TODO: add description

=cut

sub xrpc_addwakeup {
  my ($rctx, $ctx, $resource) = @_;
  my $iswaiting = $rctx->{'iswaiting'};
  my $rhandle = $iswaiting->{$resource};
  die("addwakeup to not busy resource '$resource'\n") unless $rhandle;
  my $handle = { '_ctx' => $ctx };
  push @{$rhandle->{'_wakeup'}}, $handle;
  return $handle;
}

=head2 xrpc_handles - return all active handles

 TODO: add description

=cut

sub xrpc_handles {
  my ($rctx) = @_;
  my $iswaiting = $rctx->{'iswaiting'};
  return values(%$iswaiting);
}

=head2 xrpc_busy - check if a request to a resource is in progress

 TODO: add description

=cut

sub xrpc_busy {
  my ($rctx, $resource) = @_;
  return %{$rctx->{'iswaiting'}} ? 1 : 0 unless defined $resource;
  return $rctx->{'iswaiting'}->{$resource} ? 1 : 0;
}

=head2 xrpc_printstats - print some statistics about running requests

 TODO: add description

=cut

sub xrpc_printstats {
  my ($rctx) = @_;
  my $iswaiting = $rctx->{'iswaiting'};
  return unless %$iswaiting;
  my $iswaiting_server = $rctx->{'iswaiting_server'};
  my $iswaiting_serverload = $rctx->{'iswaiting_serverload'};
  my $iswaiting_serverload_low = $rctx->{'iswaiting_serverload_low'};
  print "running async RPC requests:\n";
  for my $server (sort keys %$iswaiting_server) {
    next unless %{$iswaiting_server->{$server} || {}};
    print "  - $server: ".scalar(keys %{$iswaiting_server->{$server}})." running, ".@{$iswaiting_serverload->{$server} || []}."/".@{$iswaiting_serverload_low->{$server} || []}." waiting\n";
  }
}

sub xrpc_resume_nextrpc {
  my ($rctx, $nextrpc) = @_;

  my $handle;
  eval {
    $handle = xrpc($rctx, @{$nextrpc->{'_xrpc_data'}});
  };
  if (!$@ && $handle) {
    # copy over handle additions
    for (keys %$nextrpc) {
      $handle->{$_} = $nextrpc->{$_} if $_ ne '_xrpc_data';
    }
    return;
  }
  my $error = $@ || "internal xrpc_resume_nextrpc error\n";
  # create fake handle, call resume function with the error
  my ($ctx, $resource, $param, @args) = @{$nextrpc->{'_xrpc_data'}};
  my $async = $param->{'async'};
  $handle = {};
  $handle->{'_ctx'} = $ctx;
  $handle->{'_iswaiting'} = $resource;
  $handle->{$_} = $async->{$_} for keys %$async;
  for (keys %$nextrpc) {
    $handle->{$_} = $nextrpc->{$_} if $_ ne '_xrpc_data';
  }
  die("no _resume set in handler $handle\n") unless $handle->{'_resume'};
  $handle->{'_resume'}->($handle->{'_ctx'}, $handle, $error);
}

=head2 xrpc_resume - to be called when a rpc handle can be processed

 TODO: add description

=cut

sub xrpc_resume {
  my ($rctx, $handle) = @_;

  # iswaiting rpc, finish...
  my $iswaiting = $rctx->{'iswaiting'};
  my $iswaiting_server = $rctx->{'iswaiting_server'};
  my $iswaiting_serverload = $rctx->{'iswaiting_serverload'};
  my $iswaiting_serverload_low = $rctx->{'iswaiting_serverload_low'};
  my $iw = $handle->{'_iswaiting'};
  my $server = $handle->{'_server'};
  print "response from RPC $iw ($handle->{'uri'})\n";
  delete $iswaiting->{$iw};
  delete $iswaiting_server->{$server}->{$iw};

  # fire up rpcs delayed because of server load
  if ($iswaiting_serverload->{$server} || $iswaiting_serverload_low->{$server}) {
    my @loadrpcs;
    my @loadrpcs_low;
    @loadrpcs = @{delete $iswaiting_serverload->{$server}} if $iswaiting_serverload->{$server};
    @loadrpcs_low = @{delete $iswaiting_serverload_low->{$server}} if $iswaiting_serverload_low->{$server};
    while (@loadrpcs || @loadrpcs_low) {
      my $nextrpc;
      if ((@loadrpcs && $rctx->{'resumed_highload'}++ < 2) || !@loadrpcs_low) {
        $nextrpc = shift @loadrpcs;
      } else {
        $rctx->{'resumed_highload'} = 0;
        $nextrpc = shift @loadrpcs_low;
      }
      my $resource = $nextrpc->{'_iswaiting'};
      delete $iswaiting->{$resource};
      xrpc_resume_nextrpc($rctx, $nextrpc);
      last if $iswaiting_serverload->{$server} || $iswaiting_serverload_low->{$server};
    }
    push @{$iswaiting_serverload->{$server}}, @loadrpcs;
    push @{$iswaiting_serverload_low->{$server}}, @loadrpcs_low;
  }

  # get result of rpc
  my $ret;
  eval { $ret = BSRPC::rpc($handle) };
  my $error;
  if ($@) {
    warn $@;
    $error = $@;
    chomp $error;
  }
  # run result handler
  die("no _resume set in handler $handle\n") unless $handle->{'_resume'};
  $handle->{'_resume'}->($handle->{'_ctx'}, $handle, $error, $ret);

  # fire up waiting rpcs
  for my $nextrpc (@{$handle->{'_nextxrpc'} || []}) {
    xrpc_resume_nextrpc($rctx, $nextrpc);
  }

  # call wakeup function
  if (@{$handle->{'_wakeup'} || []}) {
    my %did;
    for my $whandle (BSUtil::unify(@{$handle->{'_wakeup'} || []})) {
      my $wctx = $whandle->{'_ctx'};
      my $changeprp = $whandle->{'_changeprp'} || $wctx->{'changeprp'};
      my $changetype = $whandle->{'_changetype'} || $wctx->{'changetype'} || 'high';
      my $changelevel = $whandle->{'_changelevel'} || $wctx->{'changelevel'} || 1;
      next if !$changeprp || $did{"$changeprp/$changetype/$changelevel"};
      $did{"$changeprp/$changetype/$changelevel"} = 1;
      $rctx->{'wakeupfunction'}->($wctx, $whandle);
    }
  }
}

sub xrpc_nextparams {
  my ($rctx, $handle) = @_;
  my @next = @{$handle->{'_nextxrpc'} || []};
  unshift @next, $handle if $handle->{'_xrpc_data'};	# waiting because of server load
  return map {$_->{'_xrpc_data'}->[2]} @next;		# map to param argument
}

1;

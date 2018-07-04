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
# implementation of state change watchers. Can watch for file
# changes, RPC results, and file download data. Handle with care.
#

package BSWatcher;

use BSServer;
use BSServerEvents;
use BSRPC;
use BSEvents;
use BSHTTP;
use POSIX;
use Socket;
use XML::Structured;
use Data::Dumper;
use Digest::MD5 ();

use strict;

my %hostlookupcache;
my %cookiestore;        # our session store to keep iChain fast
my $tossl;

sub import {
  if (grep {$_ eq ':https'} @_) {
    require BSSSL;
    $tossl = \&BSSSL::tossl;
    BSRPC::import(':https');
  }
}

sub reply {
  my $jev = $BSServerEvents::gev;
  return BSServer::reply(@_) unless $jev;
  deljob($jev);
  return BSServerEvents::reply(@_);
}

sub reply_file {
  my $jev = $BSServerEvents::gev;
  return BSServer::reply_file(@_) unless $jev;
  deljob($jev);
  return BSServerEvents::reply_file(@_);
}

sub reply_cpio {
  my $jev = $BSServerEvents::gev;
  return BSServer::reply_cpio(@_) unless $jev;
  deljob($jev);
  return BSServerEvents::reply_cpio(@_);
}


###########################################################################
#
# job handling
#

#
# we add the following elements to the connection event:
# - redohandler
# - args
#

sub redo_request {
  my ($jev) = @_;
  return if $jev->{'deljob_done'};	# job is already deleted
  local $BSServerEvents::gev = $jev;
  local $BSServer::request = $jev->{'request'};
  my $conf = $jev->{'conf'};
  eval {
    my @r = $jev->{'redohandler'}->(@{$jev->{'args'} || []});
    if ($conf->{'stdreply'}) {
      $conf->{'stdreply'}->(@r);
    } elsif (@r && (@r != 1 || defined($r[0]))) {
      BSServerEvents::reply(@r);
    }
  };
  if ($@) {
    print $@;
    BSServerEvents::reply_error($conf, $@);
  }
}

sub deljob {
  my ($jev) = @_;
  #print "deljob #$jev->{'id'}\n";
  $jev->{'deljob_done'} = 1;
  filewatcher_deljob($jev);
  serialize_deljob($jev);
  rpc_deljob($jev);
}


###########################################################################
#
# file watching
#

# state
my %filewatchers;
my %filewatchers_s;
my %filewatchers_periodic;
my $filewatchers_ev;
my $filewatchers_ev_active;

our $filewatchers_interval = 1;

sub filewatcher_handler {
  # print "filewatcher_handler\n";
  BSEvents::add($filewatchers_ev, $filewatchers_interval);
  for my $file (sort keys %filewatchers) {
    next unless $filewatchers{$file};
    my $periodic = $filewatchers_periodic{$file};
    my @s = stat($file);
    my $s = @s ? "$s[9]/$s[7]/$s[1]" : "-/-/-";
    if ($s eq $filewatchers_s{$file}) {
      if ($periodic && $periodic->[1] + $periodic->[0] < time()) {
        print "periodic call for file $file!\n";
      } else {
        next;
      }
    } else {
      print "file $file changed!\n";
    }
    $filewatchers_s{$file} = $s;
    $periodic->[1] = time() if $periodic;
    my @jobs = @{$filewatchers{$file}};
    for my $jev (@jobs) {
      redo_request($jev);
    }
  }
}

sub addfilewatcher {
  my ($file, $periodic) = @_;

  my $jev = $BSServerEvents::gev;
  return unless $jev;
  $jev->{'closehandler'} = \&deljob;
  if ($filewatchers{$file}) {
    #print "addfilewatcher to already watched $file\n";
    if ($periodic) {
      $filewatchers_periodic{$file} ||= [ $periodic, time() ];
      $filewatchers_periodic{$file}->[0] = $periodic if $filewatchers_periodic{$file}->[0] > $periodic;
    }
    push @{$filewatchers{$file}}, $jev unless grep {$_ eq $jev} @{$filewatchers{$file}};
    return;
  }
  #print "addfilewatcher $file\n";
  if (!$filewatchers_ev) {
    $filewatchers_ev = BSEvents::new('timeout', \&filewatcher_handler);
  }
  if (!$filewatchers_ev_active) {
    BSEvents::add($filewatchers_ev, $filewatchers_interval);
    $filewatchers_ev_active = 1;
  }
  my @s = stat($file);
  my $s = @s ? "$s[9]/$s[7]/$s[1]" : "-/-/-";
  push @{$filewatchers{$file}}, $jev;
  $filewatchers_s{$file} = $s;
  $filewatchers_periodic{$file} = [ $periodic, time() ] if $periodic;
}

sub filewatcher_deljob {
  my ($jev) = @_;
  for my $file (keys %filewatchers) {
    next unless grep {$_ == $jev} @{$filewatchers{$file}};
    @{$filewatchers{$file}} = grep {$_ != $jev} @{$filewatchers{$file}};
    if (!@{$filewatchers{$file}}) {
      delete $filewatchers{$file};
      delete $filewatchers_s{$file};
      delete $filewatchers_periodic{$file};
    }    
  }
  if (!%filewatchers && $filewatchers_ev_active) {
    BSEvents::rem($filewatchers_ev);
    $filewatchers_ev_active = 0; 
  }
}

###########################################################################
#
# serialization
#

# state
my %serializations;
my %serializations_waiting;

sub serialize {
  my ($file) = @_;
  my $jev = $BSServerEvents::gev;
  die("only supported in AJAX servers\n") unless $jev;
  $jev->{'closehandler'} = \&deljob;
  if ($serializations{$file}) {
    if ($serializations{$file} != $jev) {
      #print "adding to serialization queue of $file\n";
      push @{$serializations_waiting{$file}}, $jev unless grep {$_ eq $jev} @{$serializations_waiting{$file}};
      return undef;
    }
  } else {
    $serializations{$file} = $jev;
  }
  return {'file' => $file};
}

sub serialize_end {
  my ($ser) = @_;
  return unless $ser;
  my $file = $ser->{'file'};
  #print "serialize_end for $file\n";
  delete $serializations{$file};
  my @waiting = @{$serializations_waiting{$file} || []};
  delete $serializations_waiting{$file};
  while (@waiting) {
    my $jev = shift @waiting;
    #print "waking up $jev\n";
    redo_request($jev);
    if ($serializations{$file}) {
      push @{$serializations_waiting{$file}}, @waiting;
      last;
    }
  }
}

sub serialize_deljob {
  my ($jev) = @_;
  for my $file (keys %serializations) {
    @{$serializations_waiting{$file}} = grep {$_ != $jev} @{$serializations_waiting{$file}};
    delete $serializations_waiting{$file} unless @{$serializations_waiting{$file} || []};
    serialize_end({'file' => $file}) if $jev == $serializations{$file};
  }
}



###########################################################################
#
# rpc implementation
#

# state
my %rpcs;

sub rpc_error {
  my ($ev, $err) = @_;
  $ev->{'rpcstate'} = 'error';
  #print "rpc_error: $err\n";
  my $uri = $ev->{'rpcuri'};
  delete $rpcs{$uri};
  close $ev->{'fd'} if $ev->{'fd'};
  delete $ev->{'fd'};
  my @jobs = @{$ev->{'joblist'} || []};
  for my $jev (@jobs) {
    $jev->{'rpcdone'} = $jev->{'rpcoriguri'} || $uri;
    $jev->{'rpcerror'} = $err;
    redo_request($jev);
    delete $jev->{'rpcdone'};
    delete $jev->{'rpcerror'};
    delete $jev->{'rpcoriguri'};
  }
}

sub rpc_result {
  my ($ev, $res) = @_;
  $ev->{'rpcstate'} = 'done';
  my $uri = $ev->{'rpcuri'};
  #print "got result for $uri\n";
  delete $rpcs{$uri};
  close $ev->{'fd'} if $ev->{'fd'};
  delete $ev->{'fd'};
  my @jobs = @{$ev->{'joblist'} || []};
  for my $jev (@jobs) {
    $jev->{'rpcdone'} = $jev->{'rpcoriguri'} || $uri;
    $jev->{'rpcresult'} = $res;
    redo_request($jev);
    delete $jev->{'rpcdone'};
    delete $jev->{'rpcresult'};
    delete $jev->{'rpcoriguri'};
  }
}

sub rpc_redirect {
  my ($ev, $location) = @_;
  unless ($location) {
    rpc_error($ev, "remote error: got status 302 but no location header");
    return;
  }
  my $param = $ev->{'param'};
  if (!$param->{'maxredirects'}) {
    unless (exists $param->{'maxredirects'}) {
      rpc_error($ev, "no redirects allowed");
    } else {
      rpc_error($ev, "max number of redirects exhausted");
    }
    return;
  }
  delete $rpcs{$ev->{'rpcuri'}};
  close $ev->{'fd'} if $ev->{'fd'};
  delete $ev->{'fd'};
  #print "redirecting to: $location\n";
  my @jobs = @{$ev->{'joblist'} || []};
  for my $jev (@jobs) {
    $jev->{'rpcoriguri'} ||= $ev->{'rpcuri'};
    local $BSServerEvents::gev = $jev;
    rpc({%$param, 'uri' => $location, 'maxredirects' => $param->{'maxredirects'} - 1});
  }
}


###########################################################################
#
# rpc_recv_chunked_stream_handler
#
# do chunk decoding and forward to next handler
# (should probably do this in BSServerEvents::stream_read_handler)
#
sub rpc_recv_chunked_stream_handler {
  my ($ev) = @_;
  my $rev = $ev->{'readev'};

  #print "rpc_recv_chunked_stream_handler\n";
  $ev->{'paused'} = 1;	# always need more bytes!
nextchunk:
  $ev->{'replbuf'} =~ s/^\r?\n//s;
  if ($ev->{'replbuf'} !~ /\r?\n/s) {
    return unless $rev->{'eof'};
    BSServerEvents::stream_close($rev, $ev, undef, "rpc_recv_chunked_stream_handler: premature EOF");
    return;
  }
  if ($ev->{'replbuf'} !~ /^([0-9a-fA-F]+)/) {
    BSServerEvents::stream_close($rev, $ev, undef, "rpc_recv_chunked_stream_handler: bad chunked data");
    return;
  }
  my $cl = hex($1);
  # print "rpc_recv_chunked_stream_handler: chunk len $cl\n";
  if ($cl < 0 || $cl >= 1000000) {
    BSServerEvents::stream_close($rev, $ev, undef, "rpc_recv_chunked_stream_handler: illegal chunk size: $cl");
    return;
  }
  if ($cl == 0) {
    # wait till trailer is complete
    if ($ev->{'replbuf'} !~ /\n\r?\n/s) {
      return unless $rev->{'eof'};
      BSServerEvents::stream_close($rev, $ev, undef, "rpc_recv_chunked_stream_handler: premature EOF");
      return;
    }
    #print "rpc_recv_chunked_stream_handler: chunk EOF\n";
    my $trailer = $ev->{'replbuf'};
    $trailer =~ s/^(.*?\r?\n)/\r\n/s;	# delete chunk header
    $trailer =~ s/\n\r?\n.*//s;		# delete stuff after trailer
    $trailer =~ s/\r$//s;
    $trailer = substr($trailer, 2) if $trailer ne '';
    $trailer .= "\r\n" if $trailer ne '';
    $ev->{'chunktrailer'} = $trailer;
    BSServerEvents::stream_close($rev, $ev);
    return;
  }
  # split the chunk into 8192 sized subchunks if too big
  my $lcl = $cl > 8192 ? 8192 : $cl;
  $ev->{'replbuf'} =~ /^(.*?\r?\n)/s;
  if (length($1) + $lcl > length($ev->{'replbuf'})) {
    return unless $rev->{'eof'};
    BSServerEvents::stream_close($rev, $ev, undef, "rpc_recv_chunked_stream_handler: premature EOF");
    return;
  }

  my $data = substr($ev->{'replbuf'}, length($1), $lcl);
  my $nextoff = length($1) + $lcl;

  # handler returns false: cannot consume now, try later
  return unless $ev->{'datahandler'}->($ev, $rev, $data);

  $ev->{'replbuf'} = substr($ev->{'replbuf'}, $nextoff);
  if ($lcl < $cl) {
    # had to split the chunk
    $ev->{'replbuf'} = sprintf("%X\r\n", $cl - $lcl) . $ev->{'replbuf'};
  }

  goto nextchunk if length($ev->{'replbuf'});

  if ($rev->{'eof'}) {
    #print "rpc_recv_chunked_stream_handler: EOF\n";
    BSServerEvents::stream_close($rev, $ev);
  }
}

sub rpc_recv_unchunked_stream_handler {
  my ($ev) = @_;
  my $rev = $ev->{'readev'};

  #print "rpc_recv_unchunked_stream_handler\n";
  my $cl = $rev->{'contentlength'};
  $ev->{'paused'} = 1;	# always need more bytes!
  my $data = $ev->{'replbuf'};
  if (length($data) && (!defined($cl) || $cl)) {
    my $oldeof = $rev->{'eof'};
    if (defined($cl)) {
      $data = substr($data, 0, $cl) if $cl < length($data);
      $cl -= length($data);
      $rev->{'eof'} = 1 if !$cl;
    }
    return unless $ev->{'datahandler'}->($ev, $rev, $data);
    delete $rev->{'eof'} unless $oldeof;
    $rev->{'contentlength'} = $cl;
    $ev->{'replbuf'} = '';
  }
  if ($rev->{'eof'} && $cl) {
    BSServerEvents::stream_close($rev, $ev, undef, "rpc_recv_unchunked_stream_handler: premature EOF");
    return;
  }
  if ($rev->{'eof'} || (defined($cl) && !$cl)) {
    #print "rpc_recv_unchunked_stream_handler: EOF\n";
    BSServerEvents::stream_close($rev, $ev);
  }
}

###########################################################################
#
#  forward receiver methods
#

sub rpc_adddata {
  my ($jev, $data) = @_;

  $data = sprintf("%X\r\n", length($data)).$data."\r\n";
  $jev->{'replbuf'} .= $data;
  if ($jev->{'paused'}) {
    delete $jev->{'paused'};
    BSEvents::add($jev);
  }
}

sub rpc_recv_forward_close_handler {
  my ($ev, $err) = @_;
  #print "rpc_recv_forward_close_handler\n";
  my $rev = $ev->{'readev'};
  my $trailer = $ev->{'chunktrailer'} || '';
  my @jobs = @{$rev->{'joblist'} || []};
  for my $jev (@jobs) {
    $jev->{'replbuf'} .= "0\r\n$trailer\r\n";
    if ($jev->{'paused'}) {
      delete $jev->{'paused'};
      BSEvents::add($jev);
    }
    $jev->{'readev'} = {'eof' => 1, 'rpcuri' => $rev->{'rpcuri'}};
  }
  # the stream rpc is finished!
  #print "stream rpc $rev->{'rpcuri'} is finished!\n";
  delete $rpcs{$rev->{'rpcuri'}};
}

sub rpc_recv_forward_data_handler {
  my ($ev, $rev, $data) = @_;

  my @stay;
  my @leave;

  my @jobs = @{$rev->{'joblist'} || []};
  for my $jev (@jobs) {
    if (length($jev->{'replbuf'}) >= 16384) {
      push @stay, $jev;
    } else {
      push @leave, $jev;
    }
  }
  if ($rev->{'eof'}) {
    # must not hold back data at eof
    @leave = @jobs;
    @stay = ();
  }
  if (@stay && !@leave) {
    # too full! wait till there is more room
    #print "stay=".@stay.", leave=".@leave.", blocking\n";
    $rev->{'paused'} = 1;
    return 0;
  }

  # advance our uri
  my $newuri = $rev->{'rpcuri'};
  my $newpos = length($data);
  if ($newuri =~ /start=(\d+)/) {
    $newpos += $1;
    $newuri =~ s/start=\d+/start=$newpos/;
  } elsif ($newuri =~ /\?/) {
    $newuri .= '&' unless $newuri =~ /\?$/;
    $newuri .= "start=$newpos";
  } else {
    $newuri .= "?start=$newpos";
  }
  # mark it as in progress so that only other calls in progress can join
  $newuri .= "&inprogress" unless $newuri =~ /\&inprogress$/;

  #print "stay=".@stay.", leave=".@leave.", newpos=$newpos\n";

  if (@leave && $rpcs{$newuri}) {
    my $nev = $rpcs{$newuri};
    print "joining ".@leave." jobs with $newuri!\n";
    for my $jev (@leave) {
      push @{$nev->{'joblist'}}, $jev unless grep {$_ == $jev} @{$nev->{'joblist'}};
      $jev->{'readev'} = $nev;
    }
    $rev->{'joblist'} = [ @stay ];
    for my $jev (@leave) {
      rpc_adddata($jev, $data);
    }
    @leave = ();
  }

  if (!@leave) {
    if (!@stay) {
      BSServerEvents::stream_close($rev, $ev);
      return 0;
    }
    # too full! wait till there is more room
    $rev->{'paused'} = 1;
    return 0;
  }

  my $olduri = $rev->{'rpcuri'};
  $rpcs{$newuri} = $rev;
  delete $rpcs{$olduri};
  $rev->{'rpcuri'} = $newuri;

  if (@stay) {
    # worst case: split of
    $rev->{'joblist'} = [ @leave ];
    print "splitting ".@stay." jobs from $newuri!\n";
    # put old output event on hold
    for my $jev (@stay) {
      delete $jev->{'readev'};
      if (!$jev->{'paused'}) {
        BSEvents::rem($jev);
      }
      delete $jev->{'paused'};
    }
    # this is scary
    $olduri =~ s/\&inprogress$//;
    eval {
      local $BSServerEvents::gev = $stay[0];
      my $param = {
	'uri' => $olduri,
	'verbatim_uri' => 1,
	'joinable' => 1,
      };
      $param->{'receiver'} = $rev->{'param'}->{'receiver'} if $rev->{'param'}->{'receiver'};
      rpc($param);
      die("could not restart rpc\n") unless $rpcs{$olduri};
    };
    if ($@ || !$rpcs{$olduri}) {
      # terminate all old rpcs
      my $err = $@ || "internal error\n";
      $err =~ s/\n$//s;
      warn("$err\n");
      for my $jev (@stay) {
	if ($jev->{'streaming'}) {
	  # can't do much here, sorry
	  local $BSServerEvents::gev = $jev;
	  BSServerEvents::reply_error($jev->{'conf'}, $err);
	  next;
	}
	$jev->{'rpcdone'} = $olduri;
	$jev->{'rpcerror'} = $err;
	redo_request($jev);
	delete $jev->{'rpcdone'};
	delete $jev->{'rpcerror'};
      }
    } else {
      my $nev = $rpcs{$olduri};
      for my $jev (@stay) {
        push @{$nev->{'joblist'}}, $jev unless grep {$_ == $jev} @{$nev->{'joblist'}};
      }
    }
  }

  for my $jev (@leave) {
    rpc_adddata($jev, $data);
  }

  return 1;
}

sub rpc_recv_forward_setup {
  my ($jev, $ev, @args) = @_;
  if (!$jev->{'streaming'}) {
     local $BSServerEvents::gev = $jev;
     BSServerEvents::reply(undef, @args);
     BSEvents::rem($jev);
     $jev->{'streaming'} = 1;
     delete $jev->{'timeouthandler'};
  }
  $jev->{'handler'} = \&BSServerEvents::stream_write_handler;
  $jev->{'readev'} = $ev;
  if (length($jev->{'replbuf'})) {
    delete $jev->{'paused'};
    BSEvents::add($jev, 0);
  } else {
    $jev->{'paused'} = 1;
  }
}

sub rpc_recv_forward {
  my ($ev, $chunked, $data, @args) = @_;

  push @args, 'Transfer-Encoding: chunked';
  unshift @args, 'Content-Type: application/octet-stream' unless grep {/^content-type:/i} @args;
  $ev->{'rpcstate'} = 'streaming';
  $ev->{'replyargs'} = \@args;
  #
  # setup output streams for all jobs
  #
  my @jobs = @{$ev->{'joblist'} || []};
  for my $jev (@jobs) {
    rpc_recv_forward_setup($jev, $ev, @args);
  }

  #
  # setup input stream from rpc client
  #
  $ev->{'streaming'} = 1;
  my $wev = BSEvents::new('always');
  # print "new rpc input stream $ev $wev\n";
  $wev->{'replbuf'} = $data;
  $wev->{'readev'} = $ev;
  $ev->{'writeev'} = $wev;
  if ($chunked) {
    $wev->{'handler'} = \&rpc_recv_chunked_stream_handler;
  } else {
    $wev->{'handler'} = \&rpc_recv_unchunked_stream_handler;
  }
  $wev->{'datahandler'} = \&rpc_recv_forward_data_handler;
  $wev->{'closehandler'} = \&rpc_recv_forward_close_handler;
  $ev->{'handler'} = \&BSServerEvents::stream_read_handler;
  BSEvents::add($ev);
  BSEvents::add($wev);	# do this last
}

###########################################################################
#
#  file receiver methods
#

sub rpc_recv_file_data_handler {
  my ($ev, $rev, $data) = @_;
  if ((syswrite($ev->{'fd'}, $data) || 0) != length($data)) {
    BSServerEvents::stream_close($rev, $ev, undef, "rpc_recv_file_data_handler: write error");
    return 0;
  }
  $ev->{'ctx'}->add($data) if $ev->{'ctx'};
  return 1;
}

sub rpc_recv_file_close_handler {
  my ($ev, $err) = @_;
  #print "rpc_recv_file_close_handler\n";
  my $rev = $ev->{'readev'};
  my $res = {};
  if ($ev->{'fd'}) {
    my @s = stat($ev->{'fd'});
    $res->{'size'} = $s[7] if @s;
    close $ev->{'fd'};
    if ($ev->{'ctx'}) {
      $res->{'md5'} = $ev->{'ctx'}->hexdigest;
      delete $ev->{'ctx'};
    }
  }
  delete $ev->{'fd'};
  my $trailer = $ev->{'chunktrailer'} || '';
  if ($err) {
    rpc_error($rev, $err);
  } else {
    rpc_result($rev, $res);
  }
  #print "file rpc $rev->{'rpcuri'} is finished!\n";
  delete $rpcs{$rev->{'rpcuri'}};
}

sub rpc_recv_file {
  my ($ev, $chunked, $data, $filename, $withmd5) = @_;
  #print "rpc_recv_file $filename\n";
  my $fd;
  if (!open($fd, '>', $filename)) {
    rpc_error($ev, "$filename: $!");
    return;
  }
  my $wev = BSEvents::new('always');
  $wev->{'replbuf'} = $data;
  $wev->{'readev'} = $ev;
  $ev->{'writeev'} = $wev;
  $wev->{'fd'} = $fd;
  $wev->{'ctx'} = Digest::MD5->new if $withmd5;
  if ($chunked) {
    $wev->{'handler'} = \&rpc_recv_chunked_stream_handler;
  } else {
    $wev->{'handler'} = \&rpc_recv_unchunked_stream_handler;
  }
  $wev->{'datahandler'} = \&rpc_recv_file_data_handler;
  $wev->{'closehandler'} = \&rpc_recv_file_close_handler;
  $ev->{'handler'} = \&BSServerEvents::stream_read_handler;
  BSEvents::add($ev);
  BSEvents::add($wev);	# do this last
}

###########################################################################
#
#  string receiver methods
#

sub rpc_recv_string_data_handler {
  my ($ev, $rev, $data) = @_;
  $ev->{'string'} .= $data;
  return 1;
}

sub rpc_recv_string_close_handler {
  my ($ev, $err) = @_;
  #print "rpc_recv_string_close_handler\n";
  my $rev = $ev->{'readev'};
  my $trailer = $ev->{'chunktrailer'} || '';
  if ($err) {
    rpc_error($rev, $err);
  } else {
    rpc_result($rev, $ev->{'string'});
  }
  #print "string rpc $rev->{'rpcuri'} is finished!\n";
  delete $rpcs{$rev->{'rpcuri'}};
}

sub rpc_recv_string {
  my ($ev, $chunked, $data) = @_;
  my $wev = BSEvents::new('always');
  $wev->{'replbuf'} = $data;
  $wev->{'readev'} = $ev;
  $ev->{'writeev'} = $wev;
  if ($chunked) {
    $wev->{'handler'} = \&rpc_recv_chunked_stream_handler;
  } else {
    $wev->{'handler'} = \&rpc_recv_unchunked_stream_handler;
  }
  $wev->{'string'} = '';
  $wev->{'datahandler'} = \&rpc_recv_string_data_handler;
  $wev->{'closehandler'} = \&rpc_recv_string_close_handler;
  $ev->{'handler'} = \&BSServerEvents::stream_read_handler;
  BSEvents::add($ev);
  BSEvents::add($wev);	# do this last
}

###########################################################################
#
#  null receiver methods
#

sub rpc_recv_null {
  my ($ev, $chunked, $data) = @_;
  my $wev = BSEvents::new('always');
  $wev->{'replbuf'} = $data;
  $wev->{'readev'} = $ev;
  $ev->{'writeev'} = $wev;
  if ($chunked) {
    $wev->{'handler'} = \&rpc_recv_chunked_stream_handler;
  } else {
    $wev->{'handler'} = \&rpc_recv_unchunked_stream_handler;
  }
  $wev->{'string'} = '';
  $wev->{'datahandler'} = sub {1};
  $wev->{'closehandler'} = \&rpc_recv_string_close_handler;
  $ev->{'handler'} = \&BSServerEvents::stream_read_handler;
  BSEvents::add($ev);
  BSEvents::add($wev);	# do this last
}

###########################################################################
#
#  rpc methods
#

sub rpc_tossl {
  my ($ev) = @_;
#  print "switching to https\n";
  fcntl($ev->{'fd'}, F_SETFL, 0);     # in danger honor...
  eval {
    ($ev->{'param'}->{'https'} || $tossl)->($ev->{'fd'}, $ev->{'param'}->{'ssl_keyfile'}, $ev->{'param'}->{'ssl_certfile'}, 1);
    if ($ev->{'param'}->{'sslpeerfingerprint'}) {
      die("bad sslpeerfingerprint '$ev->{'param'}->{'sslpeerfingerprint'}'\n") unless $ev->{'param'}->{'sslpeerfingerprint'} =~ /^(.*?):(.*)$/s;
      my $pfp =  tied($ev->{'fd'})->peerfingerprint($1);
      die("peer fingerprint does not match: $2 != $pfp\n") if $2 ne $pfp;
    }
  };
  fcntl($ev->{'fd'}, F_SETFL, O_NONBLOCK);
  if ($@) {
    my $err = $@;
    $err =~ s/\n$//s;
    rpc_error($ev, $err);
    return undef;
  }
  return 1;
}

sub rpc_recv_handler {
  my ($ev) = @_;
  my $cs = 1024;
  # needs to be bigger than the ssl package size...
  $cs = 16384 if $ev->{'param'} && $ev->{'param'}->{'proto'} && $ev->{'param'}->{'proto'} eq 'https';
  my $r = sysread($ev->{'fd'}, $ev->{'recvbuf'}, $cs, length($ev->{'recvbuf'}));
  if (!defined($r)) {
    if ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK) {
      BSEvents::add($ev);
      return;
    }
    rpc_error($ev, "read error from $ev->{'rpcdest'}: $!");
    return;
  }
  my $ans;
  $ev->{'rpceof'} = 1 if !$r;
  $ans = $ev->{'recvbuf'};

  if ($ev->{'_need'}) {
    #shortcut for need more bytes...
    if (!$ev->{'rpceof'} && length($ans) < $ev->{'_need'}) {
      #printf "... %d/%d\n", length($ans), $ev->{'_need'};
      BSEvents::add($ev);
      return;
    }
    delete $ev->{'_need'};
  }

  if ($ans !~ /\n\r?\n/s) {
    if ($ev->{'rpceof'}) {
      rpc_error($ev, "EOF from $ev->{'rpcdest'}");
      return;
    }
    BSEvents::add($ev);
    return;
  }
  if ($ans !~ s/^HTTP\/\d+?\.\d+?\s+?(\d+[^\r\n]*)/Status: $1/s) {
    rpc_error($ev, "bad answer from $ev->{'rpcdest'}");
    return;
  }
  my $status = $1;
  $ans =~ /^(.*?)\n\r?\n(.*)$/s;
  my $headers = $1;
  $ans = $2;
  my %headers;
  BSHTTP::gethead(\%headers, $headers);
  if ($status =~ /^302[^\d]/) {
    rpc_redirect($ev, $headers{'location'});
    return;
  } elsif ($status !~ /^200[^\d]/) {
    if ($status =~ /^(\d+) +(.*?)$/) {
      rpc_error($ev, "$1 remote error: $2");
    } else {
      rpc_error($ev, "remote error: $status");
    }
    return;
  }
  if ($ev->{'proxytunnel'}) {
    # CONNECT method worked. we now have a https connection
    return unless rpc_tossl($ev);
    $ev->{'param'}->{'proto'} = 'https';
    $ev->{'sendbuf'} = $ev->{'proxytunnel'};
    delete $ev->{'proxytunnel'};
    delete $ev->{'recvbuf'};
    $ev->{'rpcstate'} = 'sending';
    $ev->{'type'} = 'write';
    $ev->{'handler'} = \&rpc_send_handler;
    BSEvents::add($ev, 0);
    return;
  }
  my $param = $ev->{'param'};
  BSRPC::updatecookies(\%cookiestore, $param->{'uri'}, $headers{'set-cookie'}) if $headers{'set-cookie'};

  my $cl = $headers{'content-length'};
  my $chunked = $headers{'transfer-encoding'} && lc($headers{'transfer-encoding'}) eq 'chunked' ? 1 : 0;

  if ($param->{'receiver'}) {
    #rpc_error($ev, "answer is neither chunked nor does it contain a content length\n") unless $chunked || defined($cl);
    $ev->{'contentlength'} = $cl if !$chunked;
    if ($param->{'receiver'} == \&BSHTTP::file_receiver) {
      rpc_recv_file($ev, $chunked, $ans, $param->{'filename'}, $param->{'withmd5'});
    } elsif ($param->{'receiver'} == \&BSHTTP::cpio_receiver) {
      if (defined $param->{'tmpcpiofile'}) {
        rpc_recv_file($ev, $chunked, $ans, $param->{'tmpcpiofile'});
      } else {
        rpc_error($ev, "need tmpcpiofile for cpio_receiver\n");
      }
    } elsif ($param->{'receiver'} == \&BSServer::reply_receiver) {
      my $ct = $headers{'content-type'} || 'application/octet-stream';
      my @args;
      push @args, "Status: $headers{'status'}" if $headers{'status'};
      push @args, "Content-Type: $ct";
      rpc_recv_forward($ev, $chunked, $ans, @args);
    } elsif ($param->{'receiver'} == \&BSHTTP::null_receiver) {
      rpc_recv_null($ev, $chunked, $ans);
    } else {
      rpc_error($ev, "unsupported receiver\n");
    }
    return;
  }

  if ($chunked) {
    rpc_recv_string($ev, $chunked, $ans);
    return;
  }
  if ($ev->{'rpceof'} && $cl && length($ans) < $cl) {
    rpc_error($ev, "EOF from $ev->{'rpcdest'}");
    return;
  }
  if (!$ev->{'rpceof'} && (!defined($cl) || length($ans) < $cl)) {
    $ev->{'_need'} = length($headers) + $cl if defined $cl;
    BSEvents::add($ev);
    return;
  }
  $ans = substr($ans, 0, $cl) if defined $cl;
  rpc_result($ev, $ans);
}

sub rpc_send_handler {
  my ($ev) = @_;
  my $l = length($ev->{'sendbuf'});
  return unless $l;
  $l = 4096 if $l > 4096;
  my $r = syswrite($ev->{'fd'}, $ev->{'sendbuf'}, $l);
  if (!defined($r)) {
    if ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK) {
      BSEvents::add($ev);
      return;
    }
    rpc_error($ev, "write error to $ev->{'rpcdest'}: $!");
    return;
  }
  if ($r != length($ev->{'sendbuf'})) {
    $ev->{'sendbuf'} = substr($ev->{'sendbuf'}, $r) if $r;
    BSEvents::add($ev);
    return;
  }
  # print "done sending to $ev->{'rpcdest'}, now receiving\n";
  delete $ev->{'sendbuf'};
  $ev->{'recvbuf'} = '';
  $ev->{'type'} = 'read';
  $ev->{'rpcstate'} = 'receiving';
  $ev->{'handler'} = \&rpc_recv_handler;
  BSEvents::add($ev);
}

sub rpc_connect_timeout {
  my ($ev) = @_;
  rpc_error($ev, "connect to $ev->{'rpcdest'}: timeout");
}

sub rpc_connect_handler {
  my ($ev) = @_;
  my $err;
  #print "rpc_connect_handler\n";
  $err = getsockopt($ev->{'fd'}, SOL_SOCKET, SO_ERROR);
  if (!defined($err)) {
    $err = "getsockopt: $!";
  } else {
    $err = unpack("I", $err);
    if ($err == 0 || $err == POSIX::EISCONN) {
      $err = undef;
    } else {
      $! = $err;
      $err = "connect to $ev->{'rpcdest'}: $!";
    }
  }
  if ($err) {
    rpc_error($ev, $err);
    return;
  }
  #print "rpc_connect_handler: connected!\n";
  if ($ev->{'param'} && $ev->{'param'}->{'proto'} && $ev->{'param'}->{'proto'} eq 'https') {
    return unless rpc_tossl($ev);
  }
  $ev->{'rpcstate'} = 'sending';
  delete $ev->{'timeouthandler'};
  $ev->{'handler'} = \&rpc_send_handler;
  BSEvents::add($ev, 0);
}

my $tcpproto = getprotobyname('tcp');

#
# This implements a subset of the BSRPC::rpc functionality with
# the async ServerEvents mechansim.
#
# not supported are:
#  * data
#  * sender
#  * timeout (its timeouts are fixed)
#  * generic receivers, supported are only:
#    - BSHTTP::file_receiver
#    - BSHTTP::cpio_receiver (with tmpcpiofile set)
#    - BSHTTP::null_receiver
#    - BSServer::reply_receiver
#
# the following extra functionality is available:
#  * joinable   - try to join with already running requests
#  * background - run the request detached, no result will be reported
#
sub rpc {
  my ($uri, $xmlargs, @args) = @_;

  my $jev = $BSServerEvents::gev;
  return BSRPC::rpc($uri, $xmlargs, @args) unless $jev;
  my @xhdrs;
  my $param = {'uri' => $uri};
  if (ref($uri) eq 'HASH') {
    $param = $uri;
    $uri = $param->{'uri'};
    @xhdrs = @{$param->{'headers'} || []};
  }
  if ($param->{'background'}) {
    my $ev = BSEvents::new('never');
    for (keys %$jev) {
      $ev->{$_} = $jev->{$_} unless $_ eq 'id' || $_ eq 'handler' || $_ eq 'fd' || $_ eq 'rpcerror';
    }
    $ev->{'redohandler'} = sub {
      die("$ev->{'rpcerror'}\n") if $ev->{'rpcerror'};
      return undef
    };
    local $BSServerEvents::gev = $ev;
    rpc({%$param, 'background' => 0}, $xmlargs, @args);
    return;
  }
  $uri = BSRPC::createuri($param, @args);
  my $rpcuri = $uri;
  $rpcuri .= ";$jev->{'id'}" unless $param->{'joinable'};

  if ($jev->{'rpcdone'} && $rpcuri eq $jev->{'rpcdone'}) {
    die("$jev->{'rpcerror'}\n") if exists $jev->{'rpcerror'};
    my $ans = $jev->{'rpcresult'};
    if ($xmlargs) {
      die("answer is not xml\n") if $ans !~ /<.*?>/s;
      return XMLin($xmlargs, $ans);
    }
    if ($param->{'receiver'} == \&BSHTTP::cpio_receiver && defined($param->{'tmpcpiofile'})) {
      local *CPIOFILE;
      open(CPIOFILE, '<', $param->{'tmpcpiofile'}) || die("open tmpcpiofile: $!\n");
      unlink($param->{'tmpcpiofile'});
      $ans = BSHTTP::cpio_receiver(BSHTTP::fd2req(\*CPIOFILE), $param);
      close CPIOFILE;
    }
    return $ans;
  }

  $jev->{'closehandler'} = \&deljob;
  if ($rpcs{$rpcuri}) {
    my $ev = $rpcs{$rpcuri};
    print "rpc $rpcuri already in progress, ".@{$ev->{'joblist'} || []}." entries\n";
    return undef if grep {$_ == $jev} @{$ev->{'joblist'}};
    if ($ev->{'rpcstate'} eq 'streaming') {
      # this seams wrong, cannot join a living stream!
      # (we're lucky to change the url when streaming...)
      print "joining stream\n";
      rpc_recv_forward_setup($jev, $ev, @{$ev->{'replyargs'} || []});
    }
    push @{$ev->{'joblist'}}, $jev;
    return undef;
  }

  my $proxy = $param->{'proxy'};
  my ($proto, $host, $port, $req, $proxytunnel) = BSRPC::createreq($param, $uri, $proxy, \%cookiestore, @xhdrs);
  if ($proto eq 'https' || $proxytunnel) {
    die("https not supported\n") unless $tossl || $param->{'https'};
  }
  $param->{'proto'} = $proto;
  if (!$hostlookupcache{$host}) {
    # should do this async, but that's hard to do in perl
    my $hostaddr = inet_aton($host);
    die("unknown host '$host'\n") unless $hostaddr;
    $hostlookupcache{$host} = $hostaddr;
  }
  my $fd;
  socket($fd, PF_INET, SOCK_STREAM, $tcpproto) || die("socket: $!\n");
  fcntl($fd, F_SETFL,O_NONBLOCK);
  setsockopt($fd, SOL_SOCKET, SO_KEEPALIVE, pack("l",1));
  my $ev = BSEvents::new('write', \&rpc_send_handler);
  if ($proxytunnel) {
    $ev->{'proxytunnel'} = $req;
    $req = $proxytunnel;
  }
  $ev->{'fd'} = $fd;
  $ev->{'sendbuf'} = $req;
  $ev->{'rpcdest'} = "$host:$port";
  $ev->{'rpcuri'} = $rpcuri;
  $ev->{'rpcstate'} = 'connecting';
  $ev->{'param'} = $param;
  $ev->{'starttime'} = time();
  push @{$ev->{'joblist'}}, $jev;
  $rpcs{$rpcuri} = $ev;
  #print "new rpc $uri\n";
  if (!connect($fd, sockaddr_in($port, $hostlookupcache{$host}))) {
    if ($! == POSIX::EINPROGRESS) {
      $ev->{'handler'} = \&rpc_connect_handler;
      $ev->{'timeouthandler'} = \&rpc_connect_timeout;
      BSEvents::add($ev, 60);	# 60s connect timeout
      return undef;
    }
    close $ev->{'fd'};
    delete $ev->{'fd'};
    delete $rpcs{$rpcuri};
    die("connect to $host:$port: $!\n");
  }
  $ev->{'rpcstate'} = 'sending';
  BSEvents::add($ev);
  return undef;
}

sub rpc_deljob {
  my ($jev) = @_;
  for my $uri (keys %rpcs) {
    my $ev = $rpcs{$uri};
    next unless $ev; 
    next unless grep {$_ == $jev} @{$ev->{'joblist'}};
    @{$ev->{'joblist'}} = grep {$_ != $jev} @{$ev->{'joblist'}};
    if (!@{$ev->{'joblist'}}) {
      print "deljob: rpc $uri no longer needed\n";
      BSServerEvents::stream_close($ev, $ev->{'writeev'});
      delete $rpcs{$uri};
    }    
  }
}


###########################################################################
#
# status query and setup functions
#

sub jobstatus {
  my ($ev) = @_;
  my $j = {'ev' => $ev->{'id'}};
  $j->{'fd'} = fileno(*{$ev->{'fd'}}) if $ev->{'fd'};
  my $req = $ev->{'request'};
  if ($req) {
    $j->{'state'} = $req->{'state'} if $req->{'state'};
    $j->{'starttime'} = $req->{'starttime'} if $req->{'starttime'};
    $j->{'peer'} = $req->{'headers'}->{'x-peer'} if $req->{'headers'} && $req->{'headers'}->{'x-peer'};
    $j->{'request'} = substr("$req->{'action'} $req->{'path'}?$req->{'query'}", 0, 1024) if $req->{'action'};
  }
  return $j;
}

sub getstatus {
  my $ret = {};
  my $jev = $BSServerEvents::gev;
  $ret->{'ev'} = $jev->{'id'};
  my $req = $jev->{'request'};
  $ret->{'starttime'} = $req->{'server'}->{'starttime'};
  for my $filename (sort keys %filewatchers) {
    my $fw = {'filename' => $filename, 'state' => $filewatchers_s{$filename}};
    for my $jev (@{$filewatchers{$filename}}) {
      push @{$fw->{'job'}}, jobstatus($jev);
    }
    push @{$ret->{'watcher'}}, $fw;
  }
  for my $uri (sort keys %rpcs) {
    my $ev = $rpcs{$uri};
    my $r = {'uri' => substr($uri, 0, 1024), 'ev' => $ev->{'id'}};
    $r->{'fd'} = fileno(*{$ev->{'fd'}}) if $ev->{'fd'};
    $r->{'state'} = $ev->{'rpcstate'} if $ev->{'rpcstate'};
    $r->{'starttime'} = $ev->{'starttime'} if $ev->{'starttime'};
    for my $jev (@{$ev->{'joblist'} || []}) {
      push @{$r->{'job'}}, jobstatus($jev);
    }
    push @{$ret->{'rpc'}}, $r;
  }
  for my $filename (sort keys %serializations_waiting) {
    my $sz = {'filename' => $filename};
    for my $jev (@{$serializations_waiting{$filename}}) {
      push @{$sz->{'job'}}, jobstatus($jev);
    }
    push @{$ret->{'serialize'}}, $sz;
  }
  for my $jev (BSServerEvents::getrequestevents($req->{'server'})) {
    push @{$ret->{'joblist'}->{'job'}}, jobstatus($jev);
  }
  return $ret;
}

# put our call data into the job event so that we can redo the request
sub dispatches_call {
  my ($f, @args) = @_;
  my $jev = $BSServerEvents::gev;
  $jev->{'redohandler'} = $f;
  $jev->{'args'} = [ @args ];
  return $f->(@args);
}

sub background {
  return BSServerEvents::background(@_);
}

1;

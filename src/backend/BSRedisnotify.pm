#
# Copyright (c) 2019 SUSE LLC
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
package BSRedisnotify;

use BSConfiguration;
use BSUtil;

my $eventdir = "$BSConfig::bsdir/events";

my $notifyforwarddir = "$eventdir/notifyforward";

sub addforwardjob {
  my (@job) = @_;
  s/([\000-\037%|=\177-\237])/sprintf("%%%02X", ord($1))/ge for @job;
  my $job = join('|', @job)."\n";
  my $file;
  mkdir_p($notifyforwarddir) unless -d $notifyforwarddir;
  BSUtil::lockopen($file, '>>', "$notifyforwarddir/queue");
  my $oldlen = -s $file;
  (syswrite($file, $job) || 0) == length($job) || die("notifyforward/queue: $!\n");
  close($file);
  BSUtil::ping("$notifyforwarddir/.ping") unless $oldlen;
}

sub updateresult {
  my ($prpa, $packstatus, $packerror, $jobs) = @_;
  my @job = ('redis', 'updateresult', $prpa);
  for my $packid (sort keys %$packstatus) {
    my $code = $packstatus->{$packid};
    my $details = $code eq 'scheduled' ? $jobs->{$packid} : $packerror->{$packid};
    push @job, $packid, ($details ? "$code:$details" : $code);
  }
  addforwardjob(@job);
}

sub deleteresult {
  my ($prpa) = @_;
  my @job = ('redis', 'deleteresult', $prpa);
  addforwardjob(@job);
}

sub updateoneresult {
  my ($prpa, $packid, $codedetails, $job) = @_;
  my @job = ('redis', 'updateoneresult', $prpa, $packid, $codedetails);
  push @job, "scheduled:$job" if $job;
  addforwardjob(@job);
}

sub updatejobstatus {
  my ($prpa, $job, $codedetails) = @_;
  my @job = ('redis', 'updatejobstatus', $prpa, "scheduled:$job");
  push @job, $codedetails if $codedetails;
  addforwardjob(@job);
}

1;

#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my $tests    = 14;
my $max_wait = 300;

my @active_daemons = qw/obsdispatcher.service  obspublisher.service    obsrepserver.service
                 obsscheduler.service   obssrcserver.service/;

my $out=`systemctl list-units`;
my $mariadb;
foreach my $unit (split(/\n/, $out)) {
  if ($unit =~ /^\s*((mysql|mariadb)\.service)\s+/) {
    $mariadb = $1;
    last;
  }
}

die "could not find mariadb or mysql" if ! $mariadb;

push @active_daemons, $mariadb;

my $os = get_distribution();
if ($os eq "suse") {
  push @active_daemons, "apache2.service";
} elsif ($os eq 'rh') {
  push @active_daemons, "httpd.service";
} else {
  die "Could not determine distribution!\n";
}

my $version = `rpm -q --queryformat %{Version} obs-server`;

my @enabled_daemons = @active_daemons;

if ($version !~ /^2\.[89]\./) {
  push @active_daemons, 'obs-clockwork.service', 'obs-delayedjob-queue-consistency_check.service', 'obs-delayedjob-queue-default.service', 'obs-delayedjob-queue-issuetracking.service', 'obs-delayedjob-queue-mailers.service', 'obs-delayedjob-queue-project_log_rotate.service', 'obs-delayedjob-queue-quick@0.service', 'obs-delayedjob-queue-quick@1.service', 'obs-delayedjob-queue-quick@2.service', 'obs-delayedjob-queue-releasetracking.service', 'obs-delayedjob-queue-staging.service', 'obs-sphinx.service';
  $tests += 12;
  my @out=`systemctl show --property=LoadError obs-delayedjob-queue-scm.service`;
  if ($out[0] !~  /^LoadError=(org.freedesktop.systemd1.NoSuchUnit|org.freedesktop.DBus.Error.FileNotFound) /) {
    push @active_daemons, 'obs-delayedjob-queue-scm.service';
    $tests += 1;
  }
}

plan tests => $tests;

foreach my $srv (@enabled_daemons) {
	my @state=`systemctl is-enabled $srv 2>/dev/null`;
	my $result='';
	if (@state) {
	  $result=$state[-1];
	  chomp($result);
	}
	is($result, "enabled", "Checking if recommended systemd unit $srv is enabled") || print "result: $result\n";
}

my %srv_state=();

while ($max_wait > 0) {
	my $failed=0;
	foreach my $srv (@active_daemons) {
		my @state=`systemctl is-active $srv 2>/dev/null`;
		chomp($state[0]);
		if ( $state[0] eq 'active') {
			$srv_state{$srv} = $state[0];
		} elsif ( $state[0] eq 'failed') {
			$failed=1;
			$srv_state{$srv} = $state[0];
		}
	}
	last if (keys(%srv_state) == scalar(@active_daemons));
	last if ($failed);
	$max_wait--;
	sleep 1;
}

foreach my $srv ( @active_daemons ) {
	is($srv_state{$srv} || 'timeout','active',"Checking recommended systemd unit '$srv' status");
}


exit 0;

sub get_distribution {
  my $fh;
  my $os = "";
  open $fh, '<', '/etc/os-release' || die "Could not open /etc/os-release: $!";
  my $line;
  while ($line = <$fh>) {
    $os = 'suse' if ($line =~ /^ID_LIKE=.*suse.*/);
    $os = 'rh' if ($line =~ /^ID(_LIKE)?=.*fedora.*/);
  }
  close $fh;
  return $os
}

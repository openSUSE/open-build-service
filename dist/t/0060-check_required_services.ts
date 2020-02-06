#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my $tests    = 14;
my $max_wait = 300;

my @daemons = qw/obsdispatcher.service  obspublisher.service    obsrepserver.service
                 obsscheduler.service   obssrcserver.service    /;

my $os = get_distribution();
if ($os eq "suse") {
  push @daemons, "apache2.service", "mysql.service";
} elsif ($os eq 'rh') {
  push @daemons, "httpd.service", "mariadb.service";
} else {
  die "Could not determine distribution!\n";
}

my $version = `rpm -q --queryformat %{Version} obs-server`;

if ($version !~ /^2\.[89]\./) {
  unshift @daemons, "obs-api-support.target";
  $tests = 16;
}

plan tests => $tests;

foreach my $srv (@daemons) {
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
	foreach my $srv (@daemons) {
		my @state=`systemctl is-active $srv 2>/dev/null`;
		chomp($state[0]);
		if ( $state[0] eq 'active') {
			$srv_state{$srv} = 'active';
		}
	}
	if ( keys(%srv_state) == scalar(@daemons) ) {
		last;
	}
	$max_wait--;
	sleep 1;
}

foreach my $srv ( @daemons ) {
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
    $os = 'rh' if ($line =~ /^ID_LIKE=.*fedora.*/);
  }
  close $fh;
  return $os
}

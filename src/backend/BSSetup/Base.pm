package BSSetup::Base;

use strict;
use warnings;

our ($FATAL, $ERROR, $WARN, $INFO, $DEBUG, $TRACE) = (qw/1 2 3 4 5 6/);

sub new {
  my ($class, @opts) = @_;
  bless {@opts}, $class;
}

sub hostname { $_[0]->{hostname} || '' }

sub print_log {
  my ($self, $loglevel, @msgs) = @_;
  return if (($loglevel||1) < $main::LOGLEVEL);
  print "$_\n" for @msgs;
}

sub execute_cmd {
  my ($self, $cmd, $fatal) = @_;
  my @out = `$cmd`;
  if ($?) {
    my $rc = $? >> 8;
    if ($fatal) {
      die "Command '$cmd' failed($rc): @out\n";
    } else {
      warn "Command '$cmd' failed($rc): @out\n";
    }
  }

  return @out;
}

sub prepare_mounts_conf {
  my ($self, @opts) = @_;
  my @remove_from_mounts;
  my $mounts_conf = '/etc/containers/mounts.conf';
  $self->print_log($DEBUG, "Starting prepare_mounts_conf\n");
  if (-f $mounts_conf) {
    $self->print_log($DEBUG, "Found file $mounts_conf\n");
    for my $path (qw{/etc/SUSEConnect /etc/zypp/credentials.d/SCCcredentials}) {
      push @remove_from_mounts, $path unless -f $path;
    }

    my $tmp         = join '|', @remove_from_mounts;
    my $re          = qr{^($tmp)$};
    my $content;

    # Comment out non existant files in /etc/containers/mounts.conf
    if (open my $fh, '+<', $mounts_conf) {
      while (my $line = <$fh>) {
	$line =~ s/$re/# $1 ## --- disabled by `obs_admin --service-container setup`/;
	$content .= $line;
      }
      seek $fh, 0, 0;
      truncate $fh, 0;
      print $fh $content || die "Could not write to $mounts_conf: $!\n";
      close $fh || die "Could not close to $mounts_conf: $!\n";
    } else {
      warn "Could not open $mounts_conf: $!\n";
    }
  } else {
    $self->print_log($DEBUG, "No such file $mounts_conf\n");
  }

  return 1;
}

sub prepare_storage_conf {
  my ($self, @opts) = @_;
  $self->print_log($DEBUG, "Starting prepare_storage_conf\n");
  my $storage_conf = '/etc/containers/storage.conf';
  if (open my $fh, '+<', $storage_conf) {
    $self->print_log($DEBUG, "Reconfigure $storage_conf\n");
    local $/ = undef;
    my $content = <$fh>;
    my $re = qr#additionalimagestores\s*=\s*\[([^\]]*)\]#;
    if ($content =~ $re) {
      my $cdir = "$BSConfig::bsdir/service/containers";
      my $val = $1;
      if ($val !~ /$cdir/) {
        my $repl = "additionalimagestores = [\n  '$cdir'".( $val ? ",\n  $val" : q{})."]";
        $content =~ s/$re/$repl/smx;
        seek $fh, 0, 0;
        truncate $fh, 0;
        print $fh $content || die "Could not write to $storage_conf: $!\n";
      }
    }
    close $fh || die "Could not close to $storage_conf: $!\n";
  } else {
    warn "Could not open $storage_conf: $!\n";
  }

  return 1;
}

sub configure_bsserviceuser {
  my ($self, $user, @opts) = @_;
  my $cmd;
  my @out;

  $cmd = "id -u $user";
  @out = `$cmd`;
  if ($?) {
    my $rc = $? >> 8;
    die "Command '$cmd' failed($rc): @out\n";
  }
  $cmd = "loginctl enable-linger $out[0]";
  @out = `$cmd`;

  # Configure system settings for obsservicerun _before_ installing container
  # containment rpm to make sure that import to image store works properly
  $cmd = "usermod -v 200000-265535 -w 200000-265535 $user";
  @out = `$cmd`;
  warn "Command '$cmd' failed:\n@out" if $?;
  return 1;
}

sub libdir {
  my ($self, $libdir) = @_;
  $self->{_libdir} = $libdir if defined  $libdir;
  return $self->{_libdir} if exists $self->{_libdir};
  $self->{_libdir} = __FILE__;
  $self->{_libdir} =~ s#/[^/]+/[^/]+$##;
  return $self->{_libdir};
}

sub generate_bsconfig {
  my ($self) = @_;
  # Settings for package BSConfig
  my $hostname  = $self->hostname;
  my $image     = 'localhost/obs-source-service-podman:latest';
  my $bs_config = "/usr/lib/obs/server/bsconfig.$hostname";
  my $libdir    = $self->libdir;
  if (open my $fh, '>>', $bs_config) {
    print $fh <<EOF;
our \$api_url='http://api-opensuse.suse.de:80';
our \$containers_root="\$bsdir/service/containers";
our \$container_image='$image';
our \$service_wrapper = {
  '*' => '$libdir/call-service-in-container',
};

1;
EOF
    close $fh || die "Could not close $bs_config: $!\n";
  } else {
    die "Could not open $bs_config: $!\n";
  }
  return 1;
}

sub restart_bs_service {
  my ($self) = @_;
  $self->print_log($DEBUG, "Restarting bs_service\n");
  my $libdir    = $self->libdir;
  my @cmd = ("$libdir/bs_service", '--restart');
  system(@cmd);
  if ($?) {
    $self->print_log($WARN, "Failed system call '@cmd'\n");
    return 0;
  }
  $self->print_log($DEBUG, "System call '@cmd' succeed\n");
  return 1;
}

1;

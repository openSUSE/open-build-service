#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
# Copyright (c) 2016  Frank Schreiner, SUSE LLC
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

package BSUtil;

=head1 NAME

BSUtil - collection of useful functions

=cut

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw{writexml writestr readxml readstr ls mkdir_p xfork str2utf8 data2utf8 str2utf8xml data2utf8xml};

use XML::Structured;
use POSIX;
use Fcntl qw(:DEFAULT :flock);
use Encode;
use Storable ();
use IO::Handle;
use strict;

# should we do a slow fdatasync?
our $fdatasync_before_rename;

# the current debug level
my $debuglevel;

# the critical log callback
my $critlogger;

=head1 FUNCTIONS / METHODS

=cut

sub set_fdatasync_before_rename {
  $fdatasync_before_rename = 1;
  if (!defined(&File::Sync::fdatasync_fd)) {
    eval {
      require File::Sync;
    };
    warn($@) if $@;
    *File::Sync::fdatasync_fd = sub {} unless defined &File::Sync::fdatasync_fd;
  }
}

sub do_fdatasync {
  my ($fd) = @_;
  set_fdatasync_before_rename() unless defined &File::Sync::fdatasync_fd;
  File::Sync::fdatasync_fd($fd);
}

sub writexml {
  my ($fn, $fnf, $dd, $dtd) = @_;
  my $d = XMLout($dtd, $dd);
  my $f;
  open($f, '>', $fn) || die("$fn: $!\n");
  (syswrite($f, $d) || 0) == length($d) || die("$fn write: $!\n");
  do_fdatasync(fileno($f)) if defined($fnf) && $fdatasync_before_rename;
  close($f) || die("$fn close: $!\n");
  return unless defined $fnf;
  $! = 0;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n");
}

sub writestr {
  my ($fn, $fnf) = @_;
  my $f;
  open($f, '>', $fn) || die("$fn: $!\n");
  my $l = length($_[2]);
  if ($l) {
    (syswrite($f, $_[2] || 0) == $l) || die("$fn write: $!\n");
  }
  do_fdatasync(fileno($f)) if defined($fnf) && $fdatasync_before_rename;
  close($f) || die("$fn close: $!\n");
  return unless defined $fnf;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n");
}

sub appendstr {
  my ($fn, $d) = @_;
  my $f;
  open($f, '>>', $fn) || die("$fn: $!\n");
  if (length($d)) {
    (syswrite($f, $d) || 0) == length($d) || die("$fn write: $!\n");
  }
  close($f) || die("$fn close: $!\n");
}

sub readstr {
  my ($fn, $nonfatal) = @_;
  my $f;
  if (!open($f, '<', $fn)) {
    die("$fn: $!\n") unless $nonfatal;
    return undef;
  }
  my $d = '';
  1 while sysread($f, $d, 8192, length($d));
  close $f;
  return $d;
}

sub readxml {
  my ($fn, $dtd, $nonfatal) = @_;
  my $d = readstr($fn, $nonfatal);
  return $d unless defined $d;
  if ($d !~ /<.*?>/s) {
    die("$fn: not xml\n") unless $nonfatal;
    return undef;
  }
  return XMLin($dtd, $d) unless $nonfatal;
  $d = eval { XMLin($dtd, $d) };
  return $@ ? undef : $d;
}

sub fromxml {
  my (undef, $dtd, $nonfatal) = @_;
  return XMLin($dtd, $_[0]) unless $nonfatal;
  my $d = eval { XMLin($dtd, $_[0]) };
  return $@ ? undef : $d;
}

sub toxml {
  XMLout($_[1], $_[0]);
}

sub touch($) {
  my ($file) = @_;
  if (-e $file) {
    my $t = time();
    utime($t, $t, $file); 
  } else {
    # create new file, mtime is anyway current
    my $f;
    open($f, '>>', $file) || die("$file: $!\n");
    close($f) || die("$file close: $!\n");
  }
}

sub ls {
  my $d;
  opendir($d, $_[0]) || return ();
  my @r = grep {$_ ne '.' && $_ ne '..'} readdir($d);
  closedir $d;
  return @r;
}

sub mkdir_p {
  my ($dir) = @_;

  return 1 if -d $dir;
  my $pdir;
  if ($dir =~ /^(.+)\//) {
    $pdir = $1;
    mkdir_p($pdir) || return undef;
  }
  while (!mkdir($dir, 0777)) {
    my $e = $!;
    return 1 if -d $dir;
    if (defined($pdir) && ! -d $pdir) {
      mkdir_p($pdir) || return undef;
      next;
    }
    $! = $e;
    warn("mkdir: $dir: $!\n");
    return undef;
  }
  return 1;
}

=head2 chown_multiple - change the ownership of multiple files/dirs

 BSUtil::chown_multiple($user, $group, $file1...);

=cut

sub chown_multiple {
  my ($user, $group, @files) = @_;
  return 1 unless @files && (defined($user) || defined($group));
  my $ret = 1;
  my $ouser = $user;
  my $ogroup = $group;
  $user = -1 unless defined $user;
  $group = -1 unless defined $group;
  
  if ($user  !~ /^-?\d+$/ && !defined($user = getpwnam($user))) {
    warn "user $ouser unknown\n";
    return undef
  }
  if ($group !~ /^-?\d+$/ && !defined($group = getgrnam($group))) {
    warn "group $ogroup unknown\n";
    return undef
  }

  for my $file (@files) {
    my @s = stat($file);
    next unless @s;
    if ((defined($ouser) && $s[4] != $user) || (defined($ogroup) && $s[5] != $group)) {
      if (!chown $user, $group, $file) {
        warn "failed to chown $file to $user:$group\n";
        $ret = undef;
      }
    }
  }
  return $ret;
}

=head2 mkdir_p_chown - create directory recursivly and change ownership

 calls mkdir_p and changes ownership of the created directory to the
 supplied user and group if provided.

=cut

sub mkdir_p_chown {
  my ($dir, $user, $group) = @_;

  if (! -d $dir) {
    mkdir_p($dir) || return undef;
  }
  return chown_multiple($user, $group, $dir);
}

sub drop_privs_to {
  my ($user, $group) = @_;

  if (defined($group)) {
    printlog("Drop privileges to group '$group'", 1);
    $group = getgrnam($group) unless $group =~ /^\d+$/;
    die("unknown group\n") unless defined $group;
    if ($) != $group || $( != $group) {
      ($), $() = ($group, $group);
      die("setgid: $!\n") if $) != $group;
    }
  }
  if (defined($user)) {
    printlog("Drop privileges to user '$user'", 1);
    $user = getpwnam($user) unless $user =~ /^\d+$/;
    die("unknown user\n") unless defined $user;
    if ($> != $user || $< != $user) {
      ($>, $<) = ($user, $user);
      die("setuid: $!\n") if $> != $user;
    }
  }
}

sub cleandir {
  my ($dir) = @_;

  my $ret = 1;
  return 1 unless -d $dir;
  for my $c (ls($dir)) {
    my @s = lstat("$dir/$c");
    if (! -l _ && -d _) {
      chmod(0700, "$dir/$c") if ($s[2] & 0700) != 0700;	# set dirs to rxw
      cleandir("$dir/$c");
      $ret = undef unless rmdir("$dir/$c");
    } else {
      $ret = undef unless unlink("$dir/$c");
    }
  }
  return $ret;
}

sub linktree {
  my ($from, $to) = @_;
  return unless -d $from;
  mkdir_p($to);
  my @todo = sort(ls($from));
  while (@todo) {
    my $f = shift @todo;
    if (! -l "$from/$f" && -d _) {
      mkdir_p("$to/$f");
      unshift @todo, map {"$f/$_"} ls("$from/$f");
    } else {
      link("$from/$f", "$to/$f") || die("link $from/$f $to/$f: $!\n");
    }
  }
}

sub treeinfo {
  my ($dir) = @_;
  my @info;
  my @todo = sort(ls($dir));
  while (@todo) {
    my $f = shift @todo;
    my @s = lstat("$dir/$f");
    next unless @s;
    if (-d _) { 
      push @info, "$f";
      unshift @todo, map {"$f/$_"} ls("$dir/$f");
    } else {
      push @info, "$f $s[9]/$s[7]/$s[1]";
    }    
  }
  return \@info;
}

sub xfork {
  my $pid;
  while (1) {
    $pid = fork();
    last if defined $pid;
    die("fork: $!\n") if $! != POSIX::EAGAIN;
    sleep(5);
  }
  return $pid;
}

sub cp {
  my ($from, $to, $tof) = @_;
  my ($f, $t);
  open($f, '<', $from) || die("$from: $!\n");
  open($t, '>', $to) || die("$to: $!\n");
  my $buf;
  while (sysread($f, $buf, 8192)) {
    (syswrite($t, $buf) || 0) == length($buf) || die("$to write: $!\n");
  }
  close($f);
  close($t) || die("$to: $!\n");
  if (defined($tof)) {
    rename($to, $tof) || die("rename $to $tof: $!\n");
  }
}

sub checkutf8 {
  my ($oct) = @_;
  Encode::_utf8_off($oct);
  return 1 unless defined $oct;
  return 1 unless $oct =~ /[\200-\377]/;
  eval {
    Encode::_utf8_on($oct);
    encode('UTF-8', $oct, Encode::FB_CROAK);
  };
  return $@ ? 0 : 1;
}

sub str2utf8 {
  my ($oct) = @_;
  return $oct unless defined $oct;
  return $oct unless $oct =~ /[^\011\012\015\040-\176]/s;
  eval {
    Encode::_utf8_on($oct);
    $oct = encode('UTF-8', $oct, Encode::FB_CROAK);
  };
  if ($@) {
    # assume iso-8859-1
    eval {
      Encode::_utf8_off($oct);
      $oct = encode('UTF-8', $oct, Encode::FB_CROAK);
    };
    if ($@) {
      Encode::_utf8_on($oct);
      $oct = encode('UTF-8', $oct, Encode::FB_XMLCREF);
    }
  }
  Encode::_utf8_off($oct);	# just in case...
  return $oct;
}

sub data2utf8 {
  my ($d) = @_;
  if (ref($d) eq 'ARRAY') {
    for my $dd (@$d) {
      if (ref($dd) eq '') {
        $dd = str2utf8($dd);
      } else {
        data2utf8($dd);
      }
    }
  } elsif (ref($d) eq 'HASH') {
    for my $dd (keys %$d) {
      if (ref($d->{$dd}) eq '') {
        $d->{$dd} = str2utf8($d->{$dd});
      } else {
        data2utf8($d->{$dd});
      }
    }
  }
}

sub str2utf8xml {
  my ($oct) = @_;
  return $oct unless defined $oct;
  return $oct unless $oct =~ /[^\011\012\015\040-\176]/s;
  $oct = str2utf8($oct);
  Encode::_utf8_on($oct);
  # xml does not accept all utf8 chars, escape the illegal
  $oct =~ s/([\000-\010\013\014\016-\037\177])/sprintf("&#x%x;",ord($1))/sge;
  $oct =~ s/([\x{d800}-\x{dfff}\x{fffe}\x{ffff}])/sprintf("&#x%x;",ord($1))/sge;
  Encode::_utf8_off($oct);
  return $oct;
}

sub data2utf8xml {
  my ($d) = @_;
  if (ref($d) eq 'ARRAY') {
    for my $dd (@$d) {
      if (ref($dd) eq '') {
        $dd = str2utf8xml($dd);
      } else {
        data2utf8xml($dd);
      }
    }
  } elsif (ref($d) eq 'HASH') {
    for my $dd (keys %$d) {
      if (ref($d->{$dd}) eq '') {
        $d->{$dd} = str2utf8xml($d->{$dd});
      } else {
        data2utf8xml($d->{$dd});
      }
    }
  }
}

sub waituntilgone {
  my ($fn, $timeout) = @_;
  while (1) {
    return 1 unless -e $fn;
    return 0 if defined($timeout) && $timeout <= 0;
    select(undef, undef, undef, .1);
    $timeout -= .1 if defined $timeout;
  }
}

sub lockopen {
  my ($fg, $op, $fn, $nonfatal) = @_;

  while (1) {
    if (!open($fg, $op, $fn)) {
      return undef if $nonfatal;
      die("$fn: $!\n");
    }
    flock($fg, LOCK_EX) || die("flock $fn: $!\n");
    my @s = stat($fg);
    last if @s && $s[3];
    close $fg;
    $fg = $_[0];	# support auto-vivify
  }
  $_[0] = $fg;	# support auto-vivify
  return 1;
}

sub lockcheck {
  my ($op, $fn) = @_;
  my $fg;
  while (1) {
    if (!open($fg, $op, $fn)) {
      return -1;
    }
    if (!flock($fg, LOCK_EX | LOCK_NB)) {
      close($fg);
      return 0;
    }
    my @s = stat($fg);
    close $fg;
    return 1 if @s && $s[3];
  }
}

sub lockopenxml {
  my ($fg, $op, $fn, $dtd, $nonfatal) = @_;
  if (!lockopen($fg, $op, $fn, $nonfatal)) {
    die("$fn: $!\n") unless $nonfatal;
    return undef;
  }
  my $d = readxml($fn, $dtd, $nonfatal);
  if (!$d) {
    close $fg;
    return undef;
  }
  $_[0] = $fg;	# support auto-vivify
  return $d;
}

sub lockcreatexml {
  my ($fg, $fn, $fnf, $dd, $dtd) = @_;

  writexml($fn, undef, $dd, $dtd);
  open($fg, '<', $fn) || die("$fn: $!\n");
  flock($fg, LOCK_EX | LOCK_NB) || die("lock: $!\n");
  if (!link($fn, $fnf)) {
    unlink($fn);
    close $fg;
    return undef;
  }
  unlink($fn);
  $_[0] = $fg;	# support auto-vivify
  return 1;
}

# XXX: does that really belong here?
#

=head2 enabled

 Algorithm:
 each enable/disable has a score:
 +1 if it's a disable
 +2 if the arch matches
 +4 if the repo matches

=cut

sub enabled {
  my ($repoid, $disen, $default, $arch) = @_;

  # filter matching elements, check for shortcuts
  return $default unless $disen;
  my @dis = grep { (!defined($_->{'arch'}) || $_->{'arch'} eq $arch) && 
                   (!defined($_->{'repository'}) || $_->{'repository'} eq $repoid)
                 } @{$disen->{'disable'} || []};
  return 1 if !@dis && $default;
  my @ena = grep { (!defined($_->{'arch'}) || $_->{'arch'} eq $arch) && 
                   (!defined($_->{'repository'}) || $_->{'repository'} eq $repoid)
                 } @{$disen->{'enable'} || []};
  return @dis ? 0 : $default unless @ena;
  return @ena ? 1 : $default unless @dis;

  # have @dis and @ena, need to do score thing...
  my $disscore = 0;
  for (@dis) {
    my $score = 1;
    $score += 2 if defined($_->{'arch'});
    $score += 4 if defined($_->{'repository'});
    if ($score > $disscore) {
      return 0 if $score == 7;		# can't max this!
      $disscore = $score;
    }
  }
  my $enascore = 0;
  for (@ena) {
    my $score = 0;
    $score += 2 if defined($_->{'arch'});
    $score += 4 if defined($_->{'repository'});
    if ($score > $enascore) {
      return 1 if $score > $disscore;
      $enascore = $score;
    }
  }
  return $enascore > $disscore ? 1 : 0;
}

sub store {
  my ($fn, $fnf, $dd) = @_;
  if ($fdatasync_before_rename && defined($fnf)) {
    my $f;
    open($f, '>', $fn) || die("$fn: $!\n");
    if (!Storable::nstore_fd($dd, $f)) {
      die("nstore_fd $fn: $!\n");
    }
    $f->flush();
    do_fdatasync(fileno($f));
    close($f) || die("$fn close: $!\n");
  } else {
    if (!Storable::nstore($dd, $fn)) {
      die("nstore $fn: $!\n");
    }
  }
  return unless defined $fnf;
  $! = 0;
  rename($fn, $fnf) || die("rename $fn $fnf: $!\n");
}

sub retrieve {
  my ($fn, $nonfatal) = @_;
  my $dd;
  if (!$nonfatal) {
    $dd = ref($fn) ? Storable::fd_retrieve($fn) : Storable::retrieve($fn);
    die("retrieve $fn: $!\n") unless $dd;
  } else {
    eval {
      $dd = ref($fn) ? Storable::fd_retrieve($fn) : Storable::retrieve($fn);
    };
    warn($@ || "retrieve $fn: $!\n") if !$dd && $nonfatal == 2;
  }
  return $dd;
}

sub tostorable {
  return 'pst0'.Storable::nfreeze($_[0]);
}

sub fromstorable {
  my $nonfatal = $_[1];
  my $dd;
  if (!$nonfatal) {
    $dd = Storable::thaw(substr($_[0], 4));
    die("fromstorable error\n") unless $dd;
  } else {
    $dd = eval { Storable::thaw(substr($_[0], 4)) };
    warn($@ || "fromstorable error\n") if !$dd && $nonfatal == 2;
  }
  return $dd;
}

sub ping {
  my ($pingfile) = @_;
  my $f;
  if (sysopen($f, $pingfile, POSIX::O_WRONLY|POSIX::O_NONBLOCK)) {
    syswrite($f, 'x');
    close($f);
  }
}

sub openping {
  my ($ping, $pingfile) = @_;
  if (! -p $pingfile) {
    POSIX::mkfifo($pingfile, 0666) || die("$pingfile: $!\n");
  }
  sysopen($ping, $pingfile, POSIX::O_RDWR) || die("$pingfile: $!\n");
  $_[0] = $ping;	# support auto-vivify
}

sub drainping {
  my ($ping) = @_; 
  my $dummy;
  fcntl($ping, F_SETFL, POSIX::O_NONBLOCK);
  1 while (sysread($ping, $dummy, 1024, 0) || 0) > 0;
  fcntl($ping, F_SETFL, 0); 
}

sub waitping {
  my ($ping, $timeout) = @_; 

  my $dummy;
  if (!defined($timeout)) {
    sysread($ping, $dummy, 1, 0); 
    return 1;
  }
  fcntl($ping, F_SETFL, POSIX::O_NONBLOCK);
  while ($timeout > 0) {
    last if (sysread($ping, $dummy, 1024, 0) || 0) > 0;
    sleep(1);
    $timeout -= 1;
  }
  fcntl($ping, F_SETFL, 0); 
  return $timeout > 0 ? 1 : 0;
}

sub openrunlock {
  my ($lock, $runfile, $name) = @_;
  open($lock, '>>', "$runfile.lock") || die("$runfile.lock: $!\n");
  flock($lock, LOCK_EX | LOCK_NB) || die("$name is already running!\n");
  utime undef, undef, "$runfile.lock";
  $_[0] = $lock;	# support auto-vivify
}

sub restartexit {
  my ($arg, $name, $runfile, $pingfile) = @_;
  return unless $arg;

  # support option hash as arg
  $arg = '--stop' if ref($arg) && $arg->{stop};
  $arg = '--restart' if ref($arg) && $arg->{restart};
  return if ref($arg);

  if ($arg eq '--stop' || $arg eq '--exit') {
    if (!(-e "$runfile.lock") || lockcheck('>>', "$runfile.lock")) {
      print "$name not running.\n";
      exit 0;
    }    
    print "exiting $name...\n";
    touch("$runfile.exit");
    ping($pingfile) if $pingfile;
    waituntilgone("$runfile.exit");
    exit(0);
  }
  if ($arg eq '--restart') {
    die("$name not running.\n") if !(-e "$runfile.lock") || lockcheck('>>', "$runfile.lock");
    print "restarting $name...\n";
    touch("$runfile.restart");
    ping($pingfile) if $pingfile;
    waituntilgone("$runfile.restart");
    exit(0);
  }
}

sub xsystem {
  my ($in, @args) = @_;

  my ($rin, $win, $rerr, $werr);
  if (defined($in)) {
    pipe($rin, $win) || die("stdin pipe: $!\n");
  }
  pipe($rerr, $werr) || die("stderr pipe: $!\n");
  my $rout;
  my $pid = open($rout, '-|');
  die("fork: $!\n") unless defined $pid;
  if (!$pid) {
    close $win if $win;
    close $rerr;
    if ($rin) {
      open(STDIN, '<&', $rin);
    } else {
      open(STDIN, '<', '/dev/null');
    }
    open(STDERR, '>&', $werr);
    eval {
      exec(@args);
      die("$args[0]: $!\n");
    };
    warn($@) if $@;
    exit 1;
  }
  close $rin if $rin;
  undef $rin;
  close $werr;
  undef $werr;

  my ($out, $err) = ('', '');
  my $stat;
  while ($rout || $rerr) {
    my ($rvec, $wvec) = ('', '');
    vec($wvec, fileno($win), 1) = 1 if $win;
    vec($rvec, fileno($rout),  1) = 1 if $rout;
    vec($rvec, fileno($rerr),  1) = 1 if $rerr;
    my $nfound = select($rvec, $wvec, undef, undef);
    if (!defined($nfound) || $nfound == -1) {
      next if $! == POSIX::EINTR;
      die("select: $!\n");
    }
    next unless $nfound;
    if ($win && vec($wvec, fileno($win), 1)) {
      my $l = syswrite($win, $in);
      if (!defined($l) || $l < 0) {
        next if $! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK;
        close($win);
	undef $win;
      } else {
        $in = substr($in, $l);
        if (length($in) <= 0) {
          close($win);
	  undef $win;
        }
      }
    }
    if ($rout && vec($rvec, fileno($rout), 1)) {
      my $l = sysread($rout, $out, 4096, length($out));
      if (!defined($l) || $l <= 0) {
        next if !defined($l) && ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK);
        $stat = close($rout);
	undef $rout;
      }
    }
    if ($rerr && vec($rvec, fileno($rerr), 1)) {
      my $l = sysread($rerr, $err, 4096, length($err));
      if (!defined($l) || $l <= 0) {
        next if !defined($l) && ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK);
        close($rerr);
	undef $rerr;
      }
    }
  }
  close $win if $win;
  if (!$stat) {
    chomp $err;
    die(($err || "$args[0]: $?") . "\n");
  }
  if (!wantarray) {
    chomp $err;
    warn("$err\n") if $err;
    return $out;
  } else {
    return ($out, $err);
  }
}

sub unify {
  my %h = map {$_ => 1} @_; 
  return grep(delete($h{$_}), @_); 
}

sub clone {
  return Storable::dclone($_[0]);
}

sub identical {
  my ($d1, $d2, $except, $subexcept) = @_;

  if (!defined($d1)) {
    return defined($d2) ? 0 : 1;
  }
  return 0 unless defined($d2);
  my $r = ref($d1);
  return 0 if $r ne ref($d2);
  if ($r eq '') {
    return 0 if $d1 ne $d2; 
  } elsif ($r eq 'HASH') {
    my %k = (%$d1, %$d2);
    for my $k (keys %k) {
      next if $except && $except->{$k};
      return 0 unless identical($d1->{$k}, $d2->{$k}, $subexcept, $subexcept);
    }    
  } elsif ($r eq 'ARRAY') {
    return 0 unless @$d1 == @$d2;
    for (my $i = 0; $i < @$d1; $i++) {
      return 0 unless identical($d1->[$i], $d2->[$i], $subexcept, $subexcept);
    }    
  } else {
    return 0;
  }
  return 1;
}

sub identicalfile {
  my ($f1, $f2) = @_;
  my ($fd1, $fd2);
  open($fd1, '<', $f1) || die("$f1: $!\n");
  open($fd2, '<', $f2) || die("$f2: $!\n");
  my $r = 1;
  while (1) {
    my $c1 = '';
    while (length($c1) < 65536) {
      my $r1 = sysread($fd1, $c1, 65536 - length($c1), length($c1));
      die("sysread $f1: $!\n") unless defined $r1;
      last unless $r1;
    }
    my $c2 = '';
    while (length($c2) < 65536) {
      my $r2 = sysread($fd2, $c2, 65536 - length($c2), length($c2));
      die("sysread $f2: $!\n") unless defined $r2;
      last unless $r2;
    }
    if ($c1 ne $c2) {
      $r = 0;
      last;
    }
    last if length($c1) < 65536;	# eof reached
  }
  close($fd1);
  close($fd2);
  return $r;
}

=head2 isotime - convert time to iso format

 BSUtil::isotime($time);

=cut

sub isotime {
  my ($t) = @_;
  my @lt = localtime($t || time());
  return sprintf "%04d-%02d-%02d %02d:%02d:%02d", $lt[5] + 1900, $lt[4] + 1, @lt[3,2,1,0];
}

=head2 getdebuglevel - get the current debug level

 BSUtil::getdebuglevel();

=cut

sub getdebuglevel {
  return $debuglevel;
}

=head2 setdebuglevel - set the current debug level

 BSUtil::setdebuglevel($newlevel);

=cut

sub setdebuglevel {
  my ($level) = @_;
  my $oldlevel = $debuglevel;
  $debuglevel = $level;
  return $oldlevel;
}

=head2 openlog - open STDOUT/STDERR to log file

 checks if $logfile is set and reopens STDOUT/STDERR to logfile

 BSUtil::openlog($logfile, $user, $group);

=cut

sub openlog {
  my ($logfile, $logdir, $user, $group) = @_;
  return unless defined $logfile;
  $logfile = "$logdir/$logfile" unless $logfile =~ /\//;
  my ($ld) = $logfile =~ m-(.*)/- ;
  mkdir_p_chown($ld, $user, $group) if $ld;
  open(STDOUT, '>>', $logfile) || die("Could not open $logfile: $!\n");
  chown_multiple($user, $group, $logfile);
  open(STDERR, ">&STDOUT");
}

=head2 printlog - print unified log messages

  BSUtil::printlog($message [, $level]);

FORMAT: "YYYY-MM-DD hh:mm:ss [$pid] $message"

=cut

sub printlog {
  my ($msg, $level, $id) = @_;
  return if $level && !($debuglevel && $debuglevel >= $level);
  $id ||= $$;
  $msg = "[debug $level] $msg" if $level;
  printf "%s: %-7s %s\n", isotime(time), "[$id]", $msg;
}

sub setcritlogger {
  my ($logger) = @_;
  my ($oldlogger) = $critlogger;
  $critlogger = $logger;
  return $oldlogger;
}

sub logcritical {
  my ($msg, $id) = @_;
  chomp $msg;
  $id ||= $$;
  printf "%s: %-7s CRITICAL %s\n", isotime(time), "[$id]", $msg;
  eval {
    $critlogger->($msg, $id) if $critlogger;
  };
  warn($@) if $@;
}

sub diecritical {
  my ($msg, $id) = @_;
  chomp $msg;
  logcritical($msg, $id);
  die("$msg\n");
}

1;

#!/usr/bin/perl

use strict;
use warnings;

use Digest::SHA ();
use File::Find ();
use FindBin;

use lib "$FindBin::Bin/lib";

use Test::More tests => 60;
use Test::Mock::BSConfig;

use BSUtil;
use BSStdRunner;

my $tmpdir = "$FindBin::Bin/tmp/0910";
BSUtil::cleandir($tmpdir) if -d $tmpdir;
BSUtil::mkdir_p($tmpdir);
die("could not create tmpdir $tmpdir\n") unless -d $tmpdir;

{
  no warnings 'once';
  $BSConfig::bsdir = "$tmpdir/bs";
  $BSConfig::stageserver = 'rsync://stage.test/repos';
  $BSConfig::rsync_extra_options = undef;
  $BSConfig::stageserver_sync = undef;
  $BSConfig::sign = undef;
}

# Locate optional system rsync before prepending our shim directory to PATH
my $real_rsync;
for my $dir (split(':', $ENV{'PATH'} || '')) {
  next unless $dir && -x "$dir/rsync";
  $real_rsync = "$dir/rsync";
  last;
}

{
  no warnings 'redefine';
  local *BSStdRunner::run = sub { return 1; };
  require_ok('./bs_publish');
}

my $bindir   = "$tmpdir/bin";
my $stagedir = "$tmpdir/stage";
my $logdir   = "$tmpdir/logs";
BSUtil::mkdir_p($_) for ($bindir, $stagedir, $logdir);

# Write an rsync wrapper that records argv/stdin, delegates to system rsync when
# available (or runs a faithful pure-Perl rsync subset when rsync is absent in
# minimal buildroots), and snapshots destination state after Pass 1.
my $shim_code = <<'EOS';
#!__PERL__
use strict;
use warnings;
use File::Find ();

my $real_rsync = $ENV{'OBS_TEST_REAL_RSYNC'} || '';
my $stage_dir  = $ENV{'OBS_TEST_STAGE_DIR'}  || die "missing OBS_TEST_STAGE_DIR\n";
my $log_dir    = $ENV{'OBS_TEST_LOG_DIR'}    || die "missing OBS_TEST_LOG_DIR\n";
my $no_log     = $ENV{'OBS_TEST_NO_LOG'}     || 0;

my @orig_argv = @ARGV;
my $is_pass2 = grep { $_ eq '--delete-after' } @orig_argv;

local $/;
my $stdin_data = <STDIN>;
$stdin_data = '' unless defined $stdin_data;

my $idx = 0;
if (!$no_log) {
  opendir(my $dh, $log_dir) || die "opendir $log_dir: $!\n";
  my @existing = grep { /^call-\d+\.txt$/ } readdir($dh);
  closedir($dh);
  $idx = scalar(@existing) + 1;

  open(my $lf, '>', "$log_dir/call-$idx.txt") || die "write call-$idx.txt: $!\n";
  print $lf "PASS:" . ($is_pass2 ? '2' : '1') . "\n";
  print $lf "STDIN:" . unpack('H*', $stdin_data) . "\n";
  for my $a (@orig_argv) {
    print $lf "ARG:$a\n";
  }
  close($lf);
}

if (!$is_pass2 && $ENV{'OBS_TEST_FAIL_PASS1'}) {
  exit 12;
}

my @exec_argv = @orig_argv;
$exec_argv[-1] =~ s{^rsync://[^/]+/[^/]+/?}{$stage_dir/} if @exec_argv;

sub compile_rule {
  my ($inc, $pat) = @_;
  my $dir_only = ($pat =~ s{/$}{}) ? 1 : 0;
  my $anchored = ($pat =~ m{/}) ? 1 : 0;
  my $rx = '';
  for my $ch (split(//, $pat)) {
    if ($ch eq '*') {
      $rx .= '[^/]*';
    } elsif ($ch eq '?') {
      $rx .= '[^/]';
    } else {
      $rx .= quotemeta($ch);
    }
  }
  return { include => $inc, dir_only => $dir_only, anchored => $anchored, re => qr/\A$rx\z/ };
}

sub is_included {
  my ($rel, $name, $is_dir, $rules) = @_;
  for my $r (@$rules) {
    next if $r->{dir_only} && !$is_dir;
    my $target = $r->{anchored} ? $rel : $name;
    return $r->{include} if $target =~ $r->{re};
  }
  return 1;
}

sub rm_tree {
  my ($p) = @_;
  my @st = lstat($p);
  return unless @st;
  if (-l $p || !-d $p) {
    unlink($p) || die "unlink $p: $!\n";
    return;
  }
  opendir(my $dh, $p) || die "opendir $p: $!\n";
  my @children = grep { $_ ne '.' && $_ ne '..' } readdir($dh);
  closedir($dh);
  rm_tree("$p/$_") for @children;
  rmdir($p) || die "rmdir $p: $!\n";
}

sub ensure_dir {
  my ($dir) = @_;
  return if -d $dir;
  my @parts = split(m{/}, $dir, -1);
  my $cur = ($parts[0] eq '') ? '' : '.';
  for my $part (@parts) {
    next if $part eq '';
    $cur .= ($cur eq '' ? "/$part" : ($cur eq '.' ? $part : "/$part"));
    next if -d $cur;
    mkdir($cur) || (-d $cur) || die "mkdir $cur: $!\n";
  }
}

sub run_perl_rsync {
  my ($stdin, $argv) = @_;
  my ($links, $nul, $dry_run, $delete_after, $delete_excluded, $files_from_stdin) = (0, 0, 0, 0, 0, 0);
  my $out_format = '';
  my (@rules, @pos);

  my $i = 0;
  while ($i < @$argv) {
    my $a = $argv->[$i++];
    if ($a eq '--files-from=-') {
      $files_from_stdin = 1;
    } elsif ($a eq '--timeout') {
      $i++;
    } elsif ($a =~ /^--out-format=(.*)$/) {
      $out_format = $1;
    } elsif ($a eq '--no-links') {
      $links = 0;
    } elsif ($a eq '--fuzzy') {
      # no-op in simulator
    } elsif ($a eq '--delete-after') {
      $delete_after = 1;
    } elsif ($a eq '--delete-excluded') {
      $delete_excluded = 1;
    } elsif ($a =~ /^--include=(.*)$/) {
      push @rules, compile_rule(1, $1);
    } elsif ($a =~ /^--exclude=(.*)$/) {
      push @rules, compile_rule(0, $1);
    } elsif ($a =~ /^--/) {
      die "unsupported option in perl rsync simulator: $a\n";
    } elsif ($a =~ /^-([a-zA-Z0-9]+)$/) {
      for my $f (split(//, $1)) {
        if ($f eq 'a') { $links = 1; }
        elsif ($f eq 'l') { $links = 1; }
        elsif ($f eq '0') { $nul = 1; }
        elsif ($f eq 'n') { $dry_run = 1; }
      }
    } else {
      push @pos, $a;
    }
  }

  die "expected src and dst\n" unless @pos == 2;
  my ($src, $dst) = @pos;
  $src =~ s{/+$}{};
  $dst =~ s{/+$}{};

  my @roots = $files_from_stdin ? ($nul ? split(/\0/, $stdin) : split(/\n/, $stdin)) : ('.');
  @roots = grep { defined($_) && $_ ne '' } @roots;
  s{/+$}{} for @roots;

  my $sync_entry;
  $sync_entry = sub {
    my ($rel) = @_;
    my $name = ($rel =~ m{([^/]+)$}) ? $1 : $rel;
    my $sp = "$src/$rel";
    my $dp = "$dst/$rel";
    my @lst = lstat($sp);
    return unless @lst;

    if (-l _) {
      return unless $links;
      return unless is_included($rel, $name, 0, \@rules);
      my $target = readlink($sp);
      my $same = (-l $dp && readlink($dp) eq $target) ? 1 : 0;
      if (!$same) {
        print "$rel\n" if $out_format =~ /%n/;
        if (!$dry_run) {
          my ($pdir) = $dp =~ m{^(.*)/[^/]+$};
          ensure_dir($pdir) if $pdir;
          rm_tree($dp) if lstat($dp);
          symlink($target, $dp) || die "symlink $dp: $!\n";
        }
      }
    } elsif (-d _) {
      return unless is_included($rel, $name, 1, \@rules);
      if (!$dry_run) {
        rm_tree($dp) if lstat($dp) && (-l _ || !-d _);
        ensure_dir($dp);
      }
      opendir(my $dh, $sp) || die "opendir $sp: $!\n";
      my @kids = sort grep { $_ ne '.' && $_ ne '..' } readdir($dh);
      closedir($dh);
      $sync_entry->("$rel/$_") for @kids;
    } elsif (-f _) {
      return unless is_included($rel, $name, 0, \@rules);
      my ($ssize, $smtime) = ($lst[7], $lst[9]);
      my @dlst = lstat($dp);
      my $same = (@dlst && !-l $dp && -f $dp && $dlst[7] == $ssize && $dlst[9] == $smtime) ? 1 : 0;
      if (!$same) {
        print "$rel\n" if $out_format =~ /%n/;
        if (!$dry_run) {
          my ($pdir) = $dp =~ m{^(.*)/[^/]+$};
          ensure_dir($pdir) if $pdir;
          rm_tree($dp) if @dlst && (-l $dp || -d $dp);
          open(my $in, '<', $sp) || die "open $sp: $!\n";
          binmode($in);
          local $/;
          my $data = <$in>;
          close($in);
          $data = '' unless defined $data;
          open(my $out, '>', "$dp.tmp.$$") || die "write $dp.tmp.$$: $!\n";
          binmode($out);
          print $out $data;
          close($out) || die "close $dp.tmp.$$: $!\n";
          rename("$dp.tmp.$$", $dp) || die "rename $dp: $!\n";
          utime($lst[8], $smtime, $dp);
        }
      }
    }
  };

  my $clean_extra;
  $clean_extra = sub {
    my ($rel) = @_;
    my $dp = "$dst/$rel";
    my $sp = "$src/$rel";
    return unless !-l $dp && -d $dp;
    opendir(my $dh, $dp) || die "opendir $dp: $!\n";
    my @kids = sort grep { $_ ne '.' && $_ ne '..' } readdir($dh);
    closedir($dh);
    for my $k (@kids) {
      my $crel = "$rel/$k";
      my $cd = "$dp/$k";
      my $cs = "$sp/$k";
      my $is_dir = (!-l $cd && -d $cd) ? 1 : 0;
      my $inc = is_included($crel, $k, $is_dir, \@rules);
      if (!$inc) {
        rm_tree($cd) if $delete_excluded;
        next;
      }
      my @sl = lstat($cs);
      if (!@sl || (!$links && -l $cs)) {
        rm_tree($cd);
      } elsif ($is_dir && !-l $cs && -d $cs) {
        $clean_extra->($crel);
      }
    }
  };

  for my $root (@roots) {
    $sync_entry->($root);
    $clean_extra->($root) if $delete_after && !$dry_run;
  }
  return 0;
}

my $rc;
if ($real_rsync && -x $real_rsync) {
  open(my $pipe, '|-', $real_rsync, @exec_argv) || die "exec $real_rsync: $!\n";
  binmode($pipe);
  print $pipe $stdin_data;
  close($pipe);
  $rc = $? >> 8;
} else {
  $rc = run_perl_rsync($stdin_data, \@exec_argv);
}

# Record destination tree state immediately after Pass 1 finishes
if (!$no_log && !$is_pass2 && $rc == 0) {
  open(my $sf, '>', "$log_dir/after-pass1-$idx.txt") || die "write snap: $!\n";
  my $base = $stage_dir;
  $base =~ s{/+$}{};
  my @entries;
  File::Find::find(
    {
      no_chdir => 1,
      wanted   => sub {
        my $p = $File::Find::name;
        return if $p eq $base;
        (my $rel = $p) =~ s{^\Q$base\E/}{};
        my $rel_hex = unpack('H*', $rel);
        if (-l $p) {
          push @entries, "L:$rel_hex:" . unpack('H*', readlink($p));
        } elsif (-d $p) {
          push @entries, "D:$rel_hex";
        } else {
          open(my $fh, '<', $p) || die "open $p: $!\n";
          local $/;
          my $c = <$fh>;
          close($fh);
          push @entries, "F:$rel_hex:" . unpack('H*', defined($c) ? $c : '');
        }
      },
    },
    $base
  );
  print $sf "$_\n" for sort @entries;
  close($sf);
}

exit $rc;
EOS
$shim_code =~ s{__PERL__}{$^X}g;
BSUtil::writestr("$bindir/rsync", undef, $shim_code);
chmod(0755, "$bindir/rsync") || die("chmod $bindir/rsync: $!\n");

local $ENV{'PATH'}                = "$bindir:" . ($ENV{'PATH'} || '');
local $ENV{'OBS_TEST_REAL_RSYNC'} = defined($real_rsync) ? $real_rsync : '';
local $ENV{'OBS_TEST_STAGE_DIR'}  = $stagedir;
local $ENV{'OBS_TEST_LOG_DIR'}    = $logdir;

sub reset_logs {
  BSUtil::cleandir($logdir);
  BSUtil::mkdir_p($logdir);
}

sub read_calls {
  my @files = sort grep { /^call-\d+\.txt$/ } ls($logdir);
  my @calls;
  for my $f (@files) {
    my $txt = readstr("$logdir/$f");
    my ($pass, $stdin_hex, @args);
    for my $line (split(/\n/, $txt)) {
      if ($line =~ /^PASS:(.*)$/) {
        $pass = $1;
      } elsif ($line =~ /^STDIN:(.*)$/) {
        $stdin_hex = $1;
      } elsif ($line =~ /^ARG:(.*)$/) {
        push @args, $1;
      }
    }
    push @calls, {
      pass  => $pass,
      stdin => pack('H*', $stdin_hex || ''),
      args  => \@args,
    };
  }
  return @calls;
}

sub read_snapshot {
  my ($file) = @_;
  my %map;
  for my $line (split(/\n/, readstr($file))) {
    if ($line =~ /^([LDF]):([0-9a-f]+)(?::([0-9a-f]*))?$/) {
      my ($type, $rel, $val) = ($1, pack('H*', $2), defined($3) ? pack('H*', $3) : undef);
      $map{$rel} = [ $type, $val ];
    }
  }
  return \%map;
}

sub sha256_data {
  my ($data) = @_;
  return Digest::SHA::sha256_hex($data);
}

sub write_file_old_mtime {
  my ($path, $content, $mtime) = @_;
  my ($dir) = $path =~ m{^(.*)/[^/]+$};
  BSUtil::mkdir_p($dir) if $dir && !-d $dir;
  BSUtil::writestr($path, undef, $content);
  utime($mtime, $mtime, $path) if defined $mtime;
}

sub setup_image_repo_38_45 {
  my ($root, $mtime) = @_;
  BSUtil::mkdir_p("$root/repodata");
  BSUtil::mkdir_p("$root/repocache");
  my $raw1 = "NEST-OCTOPUS-38.45-OLD-IMAGE-PAYLOAD";
  my $raw2 = "APPLIANCE-38.45-OLD-IMAGE-PAYLOAD";
  my $h1 = sha256_data($raw1);
  my $h2 = sha256_data($raw2);

  write_file_old_mtime("$root/nest-octopus_38.45_arm64.raw.zst", $raw1, $mtime);
  write_file_old_mtime("$root/nest-octopus_38.45_arm64.raw.zst.sha256", "$h1  nest-octopus_38.45_arm64.raw.zst\n", $mtime);
  symlink('nest-octopus_38.45_arm64.raw.zst', "$root/nest-octopus_arm64.raw.zst") || die "symlink: $!\n";
  write_file_old_mtime("$root/nest-octopus_arm64.raw.zst.sha256", "$h1  nest-octopus_arm64.raw.zst\n", $mtime);

  write_file_old_mtime("$root/appliance_38.45.raw.zst", $raw2, $mtime);
  write_file_old_mtime("$root/appliance_38.45.raw.zst.sha256", "$h2  appliance_38.45.raw.zst\n", $mtime);
  symlink('appliance_38.45.raw.zst', "$root/appliance.raw.zst") || die "symlink: $!\n";
  write_file_old_mtime("$root/appliance.raw.zst.sha256", "$h2  appliance.raw.zst\n", $mtime);

  my $sums = "$h2  appliance.raw.zst\n$h2  appliance_38.45.raw.zst\n"
           . "$h1  nest-octopus_38.45_arm64.raw.zst\n$h1  nest-octopus_arm64.raw.zst\n";
  write_file_old_mtime("$root/SHA256SUMS", $sums, $mtime);
  write_file_old_mtime("$root/SHA256SUMS.asc", "OLD-ASC-38.45\n", $mtime);
  write_file_old_mtime("$root/SHA256SUMS.gpg", "OLD-GPG-38.45", $mtime);
  write_file_old_mtime("$root/repodata/repomd.xml", "<repomd>old</repomd>\n", $mtime);
  return ($h1, $h2);
}

sub setup_image_repo_38_46 {
  my ($root, $mtime) = @_;
  BSUtil::mkdir_p("$root/repodata");
  BSUtil::mkdir_p("$root/repocache");
  my $raw1 = "NEST-OCTOPUS-38.46-NEW-IMAGE-PAYLOAD-WITH-DIFFERENT-SIZE";
  my $raw2 = "APPLIANCE-38.46-NEW-IMAGE-PAYLOAD-WITH-DIFFERENT-SIZE";
  my $raw3 = "SPACED-AND-[BRACKETED]-38.46-IMAGE-PAYLOAD";
  my $h1 = sha256_data($raw1);
  my $h2 = sha256_data($raw2);
  my $h3 = sha256_data($raw3);

  write_file_old_mtime("$root/nest-octopus_38.46_arm64.raw.zst", $raw1, $mtime);
  write_file_old_mtime("$root/nest-octopus_38.46_arm64.raw.zst.sha256", "$h1  nest-octopus_38.46_arm64.raw.zst\n", $mtime);
  write_file_old_mtime("$root/appliance_38.46.raw.zst", $raw2, $mtime);
  write_file_old_mtime("$root/appliance_38.46.raw.zst.sha256", "$h2  appliance_38.46.raw.zst\n", $mtime);
  write_file_old_mtime("$root/my image [v2]_38.46_arm64.raw.zst", $raw3, $mtime);
  write_file_old_mtime("$root/my image [v2]_38.46_arm64.raw.zst.sha256", "$h3  my image [v2]_38.46_arm64.raw.zst\n", $mtime);
  write_file_old_mtime("$root/zzz-image_38.46_arm64.raw.zst", $raw1, $mtime);
  write_file_old_mtime("$root/zzz-image_38.46_arm64.raw.zst.sha256", "$h1  zzz-image_38.46_arm64.raw.zst\n", $mtime);

  createrepo_staticlinks($root, 'home:bluca:octpus', 'debian_13_images', {});
  createrepo_checksumsfile($root, 'home:bluca:octpus', 'debian_13_images', {}, ['rawsig']);

  write_file_old_mtime("$root/SHA256SUMS.asc", "NEW-ASC-38.46-SIGNATURE\n", $mtime);
  write_file_old_mtime("$root/SHA256SUMS.gpg", "NEW-GPG-38.46-RAWSIG", $mtime);
  write_file_old_mtime("$root/repodata/repomd.xml", "<repomd>38.46-new-metadata</repomd>\n", $mtime);
  write_file_old_mtime("$root/repocache/primary.sqlite", "cache-only-not-synced\n", $mtime);
  return ($h1, $h2, $h3);
}

# ---------------------------------------------------------------------------
# Test 1: Demonstrate that previous binsufs-only Pass 1 skips .raw.zst payloads,
# leaving updated images absent before Pass 2 and causing Pass 2 to sync
# SHA256SUMS before updated image payloads finish transferring.
# ---------------------------------------------------------------------------
{
  my $p = 'home:/bluca:/octpus/debian_13_images';
  my $s_old = "$tmpdir/control_stage/$p";
  my $s_new = "$tmpdir/control_src/$p";
  my $old_t = time() - 120;
  setup_image_repo_38_45($s_old, $old_t);
  setup_image_repo_38_46($s_new, time());

  # Run legacy Pass 1 filter (@binsufsrsync equivalent) into control_stage
  local $ENV{'OBS_TEST_NO_LOG'} = '1';
  my $ctrl_rsync = defined($real_rsync) ? $real_rsync : "$bindir/rsync";
  {
    open(my $in, '|-', $ctrl_rsync, '-ar0', '--fuzzy',
         '--include=*.rpm', '--include=*.deb', '--include=*.udeb', '--include=*.ddeb',
         '--include=*.pkg.tar.gz', '--include=*.pkg.tar.xz', '--include=*.pkg.tar.zst',
         '--include=*.apk', '--include=*/', '--exclude=*',
         '--files-from=-', "$tmpdir/control_src", "$tmpdir/control_stage")
      || die "exec rsync: $!";
    print $in "$p\0";
    close($in);
    is($? >> 8, 0, 'Legacy Pass 1 filter exits cleanly');
  }
  ok(!-e "$s_old/nest-octopus_38.46_arm64.raw.zst",
     'Legacy Pass 1 filter omitted updated .raw.zst payload');

  # Verify Pass 2 transfers SHA256SUMS before nest-octopus_38.46_arm64.raw.zst
  my @dry_lines;
  {
    my $pid = open(my $out, '-|');
    die "fork: $!" unless defined $pid;
    if ($pid == 0) {
      open(my $in, '|-', $ctrl_rsync, '-nar0', '--out-format=%n', '--delete-after', '--exclude=repocache', '--delete-excluded', '--files-from=-', "$tmpdir/control_src", "$tmpdir/control_stage")
        || die "exec rsync: $!";
      print $in "$p\0";
      close($in);
      exit($? >> 8);
    }
    @dry_lines = <$out>;
    close($out);
  }
  chomp @dry_lines;
  my %pos;
  $pos{$dry_lines[$_]} = $_ for 0 .. $#dry_lines;
  ok(defined($pos{"$p/SHA256SUMS"}) && defined($pos{"$p/nest-octopus_38.46_arm64.raw.zst"})
     && $pos{"$p/SHA256SUMS"} < $pos{"$p/nest-octopus_38.46_arm64.raw.zst"},
     'Single Pass 2 without Pass 1 image sync updates SHA256SUMS before nest-octopus_38.46_arm64.raw.zst');
}

# ---------------------------------------------------------------------------
# Test 2: Full two-pass sync_to_stage() for staticlinks + checksumsfile:rawsig
# ---------------------------------------------------------------------------
{
  my $prp     = 'home:bluca:octpus/debian_13_images';
  my $prp_ext = 'home:/bluca:/octpus/debian_13_images';
  my $extrep  = "$BSConfig::bsdir/repos/$prp_ext";
  my $stgrep  = "$stagedir/$prp_ext";

  my $old_t = time() - 120;
  my ($old_h1, $old_h2) = setup_image_repo_38_45($stgrep, $old_t);
  my ($new_h1, $new_h2, $new_h3) = setup_image_repo_38_46($extrep, time());

  reset_logs();
  sync_to_stage($prp, $extrep, undef, undef, undef, 0);

  my @calls = read_calls();
  is(scalar(@calls), 2, 'sync_to_stage invokes rsync in two passes');
  is($calls[0]->{pass}, '1', 'First rsync invocation is Pass 1');
  is($calls[1]->{pass}, '2', 'Second rsync invocation is Pass 2');
  is($calls[0]->{stdin}, "$prp_ext\0", 'Pass 1 passes NUL-delimited extdirx to --files-from=-');
  is($calls[1]->{stdin}, "$prp_ext\0", 'Pass 2 passes NUL-delimited extdirx to --files-from=-');

  ok(scalar(grep { $_ eq '--no-links' } @{$calls[0]->{args}}), 'Pass 1 includes --no-links');
  ok(scalar(grep { $_ eq '--fuzzy' } @{$calls[0]->{args}}), 'Pass 1 preserves --fuzzy');
  ok(!scalar(grep { $_ eq '--delete-after' || $_ eq '--delete' } @{$calls[0]->{args}}), 'Pass 1 does not delete files');
  ok(scalar(grep { $_ eq '--delete-after' } @{$calls[1]->{args}}), 'Pass 2 preserves --delete-after');
  ok(scalar(grep { $_ eq '--delete-excluded' } @{$calls[1]->{args}}), 'Pass 2 preserves --delete-excluded');

  # Inspect staged state IMMEDIATELY after Pass 1 (before Pass 2 runs)
  my $p1_snap = read_snapshot("$logdir/after-pass1-1.txt");
  my $p1_prefix = $prp_ext;
  ok($p1_snap->{"$p1_prefix/nest-octopus_38.46_arm64.raw.zst"}
     && $p1_snap->{"$p1_prefix/nest-octopus_38.46_arm64.raw.zst"}->[0] eq 'F',
     'Pass 1 transferred new nest-octopus_38.46_arm64.raw.zst payload');
  is(sha256_data($p1_snap->{"$p1_prefix/nest-octopus_38.46_arm64.raw.zst"}->[1]), $new_h1,
     'Pass 1 nest-octopus_38.46_arm64.raw.zst content matches new sha256');
  ok($p1_snap->{"$p1_prefix/appliance_38.46.raw.zst"}
     && sha256_data($p1_snap->{"$p1_prefix/appliance_38.46.raw.zst"}->[1]) eq $new_h2,
     'Pass 1 transferred new appliance_38.46.raw.zst payload');
  ok($p1_snap->{"$p1_prefix/my image [v2]_38.46_arm64.raw.zst"}
     && sha256_data($p1_snap->{"$p1_prefix/my image [v2]_38.46_arm64.raw.zst"}->[1]) eq $new_h3,
     'Pass 1 transferred image payload containing spaces and brackets');
  ok($p1_snap->{"$p1_prefix/zzz-image_38.46_arm64.raw.zst"}
     && sha256_data($p1_snap->{"$p1_prefix/zzz-image_38.46_arm64.raw.zst"}->[1]) eq $new_h1,
     'Pass 1 transferred payload sorting after SHA256SUMS before Pass 2');

  # Old payload, old symlinks, old checksums, and old metadata remain consistent after Pass 1
  ok(defined($p1_snap->{"$p1_prefix/nest-octopus_38.45_arm64.raw.zst"}),
     'Pass 1 did not delete old 38.45 payload');
  is_deeply($p1_snap->{"$p1_prefix/nest-octopus_arm64.raw.zst"}, [ 'L', 'nest-octopus_38.45_arm64.raw.zst' ],
     'Pass 1 left nest-octopus_arm64.raw.zst symlink pointing to 38.45');
  is_deeply($p1_snap->{"$p1_prefix/appliance.raw.zst"}, [ 'L', 'appliance_38.45.raw.zst' ],
     'Pass 1 left appliance.raw.zst symlink pointing to 38.45');
  ok(!exists($p1_snap->{"$p1_prefix/my image [v2]_arm64.raw.zst"})
     && !exists($p1_snap->{"$p1_prefix/zzz-image_arm64.raw.zst"}),
     'Pass 1 did not create new staticlink symlinks before Pass 2');
  like($p1_snap->{"$p1_prefix/SHA256SUMS"}->[1], qr/^\Q$old_h1\E  nest-octopus_arm64\.raw\.zst$/m,
     'Pass 1 left SHA256SUMS at old 38.45 digest');
  is($p1_snap->{"$p1_prefix/SHA256SUMS.asc"}->[1], "OLD-ASC-38.45\n",
     'Pass 1 did not overwrite SHA256SUMS.asc');
  is($p1_snap->{"$p1_prefix/SHA256SUMS.gpg"}->[1], "OLD-GPG-38.45",
     'Pass 1 did not overwrite SHA256SUMS.gpg');
  is($p1_snap->{"$p1_prefix/repodata/repomd.xml"}->[1], "<repomd>old</repomd>\n",
     'Pass 1 did not overwrite repodata/repomd.xml');
  ok(!exists($p1_snap->{"$p1_prefix/nest-octopus_38.46_arm64.raw.zst.sha256"}),
     'Pass 1 did not transfer 38.46 detached .sha256 file');

  # Inspect final stage directory state AFTER Pass 2
  ok(!-e "$stgrep/nest-octopus_38.45_arm64.raw.zst", 'Pass 2 deleted stale 38.45 payload');
  ok(!-e "$stgrep/appliance_38.45.raw.zst", 'Pass 2 deleted stale appliance_38.45 payload');
  is(readlink("$stgrep/nest-octopus_arm64.raw.zst"), 'nest-octopus_38.46_arm64.raw.zst',
     'Pass 2 updated nest-octopus_arm64.raw.zst symlink to 38.46');
  is(readlink("$stgrep/my image [v2]_arm64.raw.zst"), 'my image [v2]_38.46_arm64.raw.zst',
     'Pass 2 created spaced/bracketed staticlink symlink to 38.46');
  is(sha256_data(readstr("$stgrep/nest-octopus_arm64.raw.zst")), $new_h1,
     'Resolved staticlink content matches new 38.46 sha256');
  my $final_sums = readstr("$stgrep/SHA256SUMS");
  like($final_sums, qr/^\Q$new_h1\E  nest-octopus_arm64\.raw\.zst$/m,
     'Pass 2 SHA256SUMS matches resolved staticlink digest');
  like($final_sums, qr/^\Q$new_h1\E  nest-octopus_38\.46_arm64\.raw\.zst$/m,
     'Pass 2 SHA256SUMS contains versioned 38.46 digest');
  is(readstr("$stgrep/SHA256SUMS.gpg"), "NEW-GPG-38.46-RAWSIG",
     'Pass 2 updated SHA256SUMS.gpg');
  ok(!-e "$stgrep/repocache", 'repocache remains excluded from stage');
}

# ---------------------------------------------------------------------------
# Test 3: Failed Pass 1 prevents Pass 2 from running and preserves old state
# ---------------------------------------------------------------------------
{
  my $prp     = 'home:bluca:octpus/debian_13_fail';
  my $prp_ext = 'home:/bluca:/octpus/debian_13_fail';
  my $extrep  = "$BSConfig::bsdir/repos/$prp_ext";
  my $stgrep  = "$stagedir/$prp_ext";

  my ($old_h1) = setup_image_repo_38_45($stgrep, time() - 120);
  setup_image_repo_38_46($extrep, time());

  reset_logs();
  local $ENV{'OBS_TEST_FAIL_PASS1'} = 1;
  eval { sync_to_stage($prp, $extrep, undef, undef, undef, 0) };
  my $err = $@;
  like($err, qr/rsync failed/, 'sync_to_stage dies when Pass 1 fails');

  my @calls = read_calls();
  is(scalar(@calls), 1, 'Pass 2 is NOT invoked when Pass 1 fails');
  is(readlink("$stgrep/nest-octopus_arm64.raw.zst"), 'nest-octopus_38.45_arm64.raw.zst',
     'Failed Pass 1 leaves stage staticlink untouched at 38.45');
  like(readstr("$stgrep/SHA256SUMS"), qr/^\Q$old_h1\E  nest-octopus_arm64\.raw\.zst$/m,
     'Failed Pass 1 leaves stage SHA256SUMS untouched at 38.45');
}

# ---------------------------------------------------------------------------
# Test 4: Standard package repos (RPM, Deb, Arch, APK) sync packages in Pass 1
# while withholding metadata, signatures, and symlinks until Pass 2
# ---------------------------------------------------------------------------
{
  my $prp     = 'home:test:pkgs/standard';
  my $prp_ext = 'home:/test:/pkgs/standard';
  my $extrep  = "$BSConfig::bsdir/repos/$prp_ext";
  my $stgrep  = "$stagedir/$prp_ext";

  BSUtil::mkdir_p("$extrep/$_") for qw{x86_64 all repodata repocache};
  write_file_old_mtime("$extrep/x86_64/app-2.0-1.x86_64.rpm", "RPM-PAYLOAD-NEW", time());
  symlink('app-2.0-1.x86_64.rpm', "$extrep/x86_64/app-latest.rpm") || die "symlink: $!\n";
  write_file_old_mtime("$extrep/all/app_2.0-1_all.deb", "DEB-PAYLOAD-NEW", time());
  write_file_old_mtime("$extrep/all/app_2.0-1_all.udeb", "UDEB-PAYLOAD-NEW", time());
  write_file_old_mtime("$extrep/x86_64/archapp-2.0-1-x86_64.pkg.tar.zst", "ARCH-PKG-NEW", time());
  write_file_old_mtime("$extrep/x86_64/archapp-2.0-1-x86_64.pkg.tar.zst.sig", "ARCH-SIG", time());
  write_file_old_mtime("$extrep/x86_64/apkapp-2.0-r0.apk", "APK-PKG-NEW", time());
  write_file_old_mtime("$extrep/x86_64/standard.db.tar.gz", "ARCH-DB", time());
  write_file_old_mtime("$extrep/x86_64/APKINDEX.tar.gz", "APK-INDEX", time());
  write_file_old_mtime("$extrep/Packages", "Package: app\n", time());
  write_file_old_mtime("$extrep/Packages.gz", "PKG-GZ", time());
  write_file_old_mtime("$extrep/Release", "Suite: test\n", time());
  write_file_old_mtime("$extrep/Release.gpg", "REL-GPG", time());
  write_file_old_mtime("$extrep/InRelease", "INREL", time());
  write_file_old_mtime("$extrep/repodata/repomd.xml", "<repomd>pkgs</repomd>\n", time());
  write_file_old_mtime("$extrep/repocache/cache", "CACHE", time());

  reset_logs();
  sync_to_stage($prp, $extrep, undef, undef, undef, 0);

  my $p1_snap = read_snapshot("$logdir/after-pass1-1.txt");
  for my $pkg (
    "$prp_ext/x86_64/app-2.0-1.x86_64.rpm",
    "$prp_ext/all/app_2.0-1_all.deb",
    "$prp_ext/all/app_2.0-1_all.udeb",
    "$prp_ext/x86_64/archapp-2.0-1-x86_64.pkg.tar.zst",
    "$prp_ext/x86_64/apkapp-2.0-r0.apk",
  ) {
    ok($p1_snap->{$pkg} && $p1_snap->{$pkg}->[0] eq 'F', "Pass 1 synced package $pkg");
  }
  for my $meta (
    "$prp_ext/x86_64/app-latest.rpm",
    "$prp_ext/x86_64/archapp-2.0-1-x86_64.pkg.tar.zst.sig",
    "$prp_ext/x86_64/standard.db.tar.gz",
    "$prp_ext/x86_64/APKINDEX.tar.gz",
    "$prp_ext/Packages",
    "$prp_ext/Packages.gz",
    "$prp_ext/Release",
    "$prp_ext/Release.gpg",
    "$prp_ext/InRelease",
    "$prp_ext/repodata/repomd.xml",
    "$prp_ext/repocache/cache",
  ) {
    ok(!exists($p1_snap->{$meta}), "Pass 1 withheld symlink/metadata $meta");
  }

  is(readlink("$stgrep/x86_64/app-latest.rpm"), 'app-2.0-1.x86_64.rpm',
     'Pass 2 synced package symlink');
  ok(-e "$stgrep/Packages" && -e "$stgrep/repodata/repomd.xml" && -e "$stgrep/x86_64/APKINDEX.tar.gz",
     'Pass 2 synced package repository metadata');
  ok(!-e "$stgrep/repocache", 'Pass 2 excluded repocache');
}

BSUtil::cleandir($tmpdir);
rmdir($tmpdir);

#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

# This is far from being complete. We only
# support the OPs that are needed for our (quite limited)
# use case.
sub parse_subcalls {
  my ($filename) = @_;
  open(F, "-|", 'perl', '-MO=Concise,-terse', $filename) || die("tree: $@\n");
  my $level = 0;
  my $ctx;
  my @subs;
  my @contexts;
  while (<F>) {
    s/\s*$//;
    my $lcnt = 0;
    $lcnt++ while s/^(?:    )//;
    next unless $lcnt;
    if ($level > $lcnt) {
      while ($level > $lcnt) {
        $level--;
        next unless @contexts;
        pop @contexts;
        $ctx = $contexts[-1];
        $ctx = $ctx->{''} if ref($ctx) eq 'HASH';
      }
    } elsif ($level == $lcnt - 1) {
      $level++;
    } elsif ($level != $lcnt) {
      die("level mismatch (current: $level, got: $lcnt)\n");
    }
    die("illegal format: $_\n") unless s/^([^ ]+) \([^ ]+\) ([^ ]+)\s*//;
    my ($op, $kind) = ($1, $2);
    if ($op eq 'SVOP' && $kind eq 'const') {
      next unless @contexts;
      #print "svop\n";
      /^\[[^ ]+\] ([^ ]+) \([^ ]+\) (.*)$/;
      my ($type, $data) = ($1, $2);
      if ($type eq 'IV') {
        $data = 0 + $data;
      } elsif ($type eq 'PV') {
        $data =~ s/^"(.*)"$/$1/;
      }
      die("no data found: $_\n") unless defined($data);
      push @$ctx, $data;
    } elsif ($op eq 'BINOP') {
      next unless @contexts;
      # we don't handle a binary op
      print "unhandled binary operator: $kind\n";
      # just push a dummy context
      # note: the binop won't appear in the original context!
      push @contexts, [];
      $ctx = $contexts[-1];
    } elsif ($op eq 'LISTOP' && $kind =~ '^anon(?:list|hash)$' || $op eq 'UNOP' && $kind eq 'entersub') {
      next if $kind ne 'entersub' && !@contexts;
      #print "$kind\n";
      my $tmp = [];
      if ($kind eq 'anonhash' || $kind eq 'entersub') {
        push @$ctx, {'' => $tmp};
      } else {
        push @$ctx, $tmp;
      }
      $ctx = $ctx->[-1];
      push @contexts, $ctx;
      $ctx = $tmp;
    } elsif ($op eq 'OP' && $kind eq 'undef') {
      next unless @contexts;
      #print "undef\n";
      push @$ctx, undef;
    } elsif ($op eq 'UNOP' && $kind eq 'scalar') {
      next unless @contexts;
      # (probably) a heredoc 
      # just push a dummy context
      #print "unop\n";
      push @contexts, '';
    } elsif ($op eq 'PADOP') {
      next unless @contexts;
      #print "padop\n";
      /GV \([^ ]+\) \*(.*)$/;
      die("unexpected PADOP: $_\n") unless $1;
      $level -= 3;
      my $func = pop @contexts;
      die("illegal state (contexts is empty): $_\n") unless $func;
      $func->{$1} = delete $func->{''};
      push @subs, $func unless @contexts;
      $ctx = $contexts[-1];
      $ctx = $ctx->{''} if ref($ctx) eq 'HASH';
    }
  }
  close(F) || die("close: $@\n");
  die("pending contexts: " . @contexts . "\n") if @contexts;
  return @subs;
}

# It just replaces an anon hash like {'' => ['a', 1, 'b', 2]}
# with the anon hash {'a' => 1, 'b' => 2}
sub harmonize_args {
  my ($todo) = @_;
  for my $data (@$todo) {
    if (ref($data) eq 'HASH' && !exists($data->{''})) {
      harmonize_args($data->{$_}) for keys %$data;
      next;
    }
    if (ref($data) eq 'HASH') {
        harmonize_args($data->{''});
        $data = {@{$data->{''}}};
    } elsif (ref($data) eq 'ARRAY') {
        harmonize_args($data);
    }
  }
}

sub handle_create {
  my ($ctx, $projid, $packid) = @_;
  my $s = '';
  $s .= ' ' x $ctx->{'hwm'} . "$projid/$packid";
  $ctx->{'hwm'} = length($s);
  $ctx->{'pdata'}->{"$projid/$packid"} = \$s;
  push @{$ctx->{'rows'}}, \$s;
  my $s2 = '';
  push @{$ctx->{'rows'}}, \$s2;
}

sub handle_commit {
  my ($ctx, $projid, $packid, $opts, %files) = @_;
  my $r = $ctx->{'pdata'}->{"$projid/$packid"};
  die("package $projid/$packid was never created\n") unless $r;
  # if the right op of the repetition op ('x') is <= 0,
  # it evaluates to the empty str ('')
  $$r .= ' ' . '-' x ($ctx->{'hwm'} - length($$r) - 2) . "--> C";
  if ($ctx->{'opts'}->{'with-files'}) {
    $$r .= '(';
    $$r .= join(', ', map { defined($files{$_}) ? $_ : $_ . ' (D)' } sort keys %files);
    $$r .= ')';
  }
  $ctx->{'hwm'} = length($$r);
  if ($ctx->{'opts'}->{'verbose'}) {
    for (sort keys %files) {
      next unless defined($files{$_});
      # hrm better do this when parsing there heredoc?
      # (this might produce wrong results for a non-heredoc str)
      my %tr = ('n' => "\n", 't' => "\t");
      $files{$_} =~ s/\\([nt])/$tr{$1}/g;
      my $s = "$projid/$packid/$_ <<EOF\n" . $files{$_} . 'EOF';
      push @{$ctx->{'vrows'}}, $s;
    }
  }
}

sub handle_branch {
  my ($ctx, $projid, $packid, $oprojid, $opackid, %query) = @_;
  die("cannot handle orev parameter\n") if $query{'orev'} && !$ctx->{'opts'}->{'ignore-orev'};
  my $or = $ctx->{'pdata'}->{"$oprojid/$opackid"};
  my $r = $ctx->{'pdata'}->{"$projid/$packid"};
  die("package $oprojid/$opackid was never created\n") unless $or;
  die("package $projid/$packid was never created\n") unless $r;
  my $rows = @{$ctx->{'rows'}} - 1;
  my %r2idx = map { $ctx->{'rows'}->[$_] => $_ } 0 .. $rows;
  my %r2p = map { $ctx->{'pdata'}->{$_} => 1 } keys %{$ctx->{'pdata'}};
  my $oidx = $r2idx{$or};
  my $idx = $r2idx{$r};
  my $incr = $idx < $oidx ? 1 : -1;
  my $hwm = $ctx->{'hwm'};
  # format branch line for the origin
  $$or .= ' ' . '-' x ($hwm - length($$or)) . '\\';
  # format branch line for the branch
  $$r .= ' ' . '-' x ($hwm - length($$r)) . '/';
  # format all lines in between
  $idx += $incr;
  while ($idx > $oidx || $idx < $oidx) {
    my $tr = $ctx->{'rows'}->[$idx];
    $$tr .= ' ' . ($r2p{$tr} ? '-' : ' ') x ($hwm - length($$tr)) . '|';
    $idx += $incr;
  }
  $ctx->{'hwm'} = length($$r);
}

sub handle_test {
  my ($ctx) = @_;
  $ctx->{'testno'}++;
}

my $legend = <<EOF;
Legend:
C                    -- commit
C(file1, ..., filen) -- commit file1, ..., filen
C(file1, file2 (D))  -- commit file1 and delete file2

oprj/opkg ....\\
              |
branch/pkg .../      -- a branch originating at oprj/opkg


EOF

sub print_timeline {
  my ($handler, $opts, @subs) = @_;
  my $ctx = {'hwm' => 0, 'testno' => 0, 'opts' => $opts};
  my $until = exists $opts->{'until-test'} ? $opts->{'until-test'} + 0 : -1;
  for (@subs) {
    last if $until == $ctx->{'testno'};
    my $name = (keys %$_)[0];
    $handler->{$name}->($ctx, @{$_->{$name}}) if exists $handler->{$name};
  }
  for (@{$ctx->{'rows'} || []}) {
    print "$$_\n";
  }
  print $legend if $opts->{'legend'};
  for (@{$ctx->{'vrows'} || []}) {
    print "$_\n\n";
  }
}

sub usage {
  print <<EOF;
$0 <options> /path/to/testcase.t

Note: this script just statically analyzes the given /path/to/testcase.t file
      (the testcase is NOT executed). Moreover, it does not "visualize"
      branches that are created with the "olinkrev" param.

Options:
--help/-h            display help/usage
--until-test number  stop printing the timeline after test "number"
--with-files         print information whether a file is added/kept or deleted
                     during a commit
--ignore-orev        this script cannot visualize a branch that is create with
                     an orev param and aborts by default (with this option,
                     it does not abort and will print a "wrong" timeline)
--legend             print a legend
--verbose            print file content during a commit

EOF
  exit(0);
}

my $handler = {
  'create' => \&handle_create,
  'commit' => \&handle_commit,
  'branch' => \&handle_branch,
  'blame_is' => \&handle_test,
  'list_like' => \&handle_test
};

my $filename = pop @ARGV;
usage() if !defined($filename) || $filename eq '-h' || $filename eq '--help';

my $opts = {};
# quick and dirty: perl will (hopefully) complain if an illegal
# opt was specified (e.g. a str where an int was expected etc.)
# so, do it right:)
while (@ARGV) {
  my $opt = shift @ARGV;
  die("$opt is not an option\n") unless $opt =~ s/^--//;
  $opts->{$opt} = @ARGV && $ARGV[0] !~ /^--/ ? shift @ARGV : 1;
}
my @subs = parse_subcalls($filename);
harmonize_args(\@subs);
print_timeline($handler, $opts, @subs);

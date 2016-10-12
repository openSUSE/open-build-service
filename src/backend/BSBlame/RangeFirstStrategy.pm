package BSBlame::RangeFirstStrategy;

use strict;
use warnings;

use Data::Dumper;

use BSBlame::Blamer;
use BSBlame::Constraint;
use BSBlame::Revision;
use BSBlame::RevisionManager;

# basically, this could be plain module with functions instead
# of a class (it's a class for reusability reasons...)

sub new {
  my ($class, $storage) = @_;
  return bless {'storage' => $storage}, $class;
}

sub blame {
  my ($self, $rev, $filename) = @_;
  $self->resolve($rev);
  my @blamers;
  my @deps = BSBlame::Blamer->new($rev, $self->{'storage'});
  my %seen;
  while (@deps) {
    my $blamer = shift(@deps);
    push @blamers, $blamer;
    $self->lastworkingautomerge($blamer) if $blamer->hasconflict();
    for my $rev (@{$blamer->deps()}) {
      next if $seen{$rev->cookie()};
      $seen{$rev->cookie()} = 1;
      push @deps, BSBlame::Blamer->new($rev, $self->{'storage'});
    }
    # potential inifinite loop?
  }
  while (@blamers) {
    my @ready = grep {$_->ready($filename)} @blamers;
    die("ready queue empty\n") unless @ready;
    for my $blamer (@ready) {
      $blamer->blame($filename);
    }
    my $ready = {map {$_ => 1} @ready};
    @blamers = grep {!$ready->{$_}} @blamers;
  }
}

# The goal of this step is to associate $rev and all its deps to a
# corresponding localrev (cf. BSBlame::Revision for a localrev
# "definition").
# Note: this is just a heuristic that can "easily" fooled:
# - play with different commit times (affects only branches)
# - play with the "olinkrev" parameter when creating branches
# - manually specified _links
# - etc.
# TODO: create testcases for these scenarios
sub resolve {
  my ($self, $rev) = @_;
  my @todo = $rev;
  while (@todo) {
    $rev = shift(@todo);
    my @deps;
    @deps = $self->resolve_expanded($rev) if $rev->isexpanded();
    @deps = $self->resolve_branch($rev) if $rev->isbranch();
    @deps = $self->resolve_plain($rev) if $rev->isplain();
    die("todo: plain links\n") if $rev->islink() && !$rev->isbranch();
    push @todo, @deps;
  }
}

sub resolve_expanded {
  my ($self, $rev) = @_;
  my $revmgr = $rev->revmgr();
  my ($projid, $packid) = ($rev->project(), $rev->package());
  dbgprint("resolve expanded: $projid/$packid" . " (" . ($rev + 0) . ")\n");
  my @deps;
  if ($rev->localrev()) {
    dbgprint(" localrev set\n");
    push @deps, $rev->targetrev();
    push @deps, $rev->localrev() unless $rev->localrev()->resolved();
    $rev->resolved(1);
    return @deps;
  }
  dbgprint(" srcmd5: " . $rev->srcmd5() . "\n");
  dbgprint(" lsrcmd5: " . $rev->lsrcmd5() . "\n");
  my $lrev = $revmgr->find($rev->project(), $rev->package(), $rev->lsrcmd5(),
                           $rev->constraints());
  die("unable to find lrev\n") unless $lrev;
  # merge constraints and install lrev
  $lrev->constraints($rev->constraints());
  $rev->localrev($lrev);
  $rev->resolved(1);
  push @deps, $rev->targetrev();
  push @deps, $lrev unless $lrev->resolved();
  dbgprint(" push " . ($rev->targetrev() + 0) . "\n");
  dbgprint(" push " . ($lrev + 0) . "\n") unless $lrev->resolved();
  return @deps;
}

sub resolve_branch {
  my ($self, $primarylrev) = @_;
  my $revmgr = $primarylrev->revmgr();
  my $lprojid = $primarylrev->project();
  my $lpackid = $primarylrev->package();
  my $tprojid = $primarylrev->targetrev()->project();
  my $tpackid = $primarylrev->targetrev()->package();
  my @deps;
  dbgprint("resolve branch: $lprojid/$lpackid\n");
  while (!$primarylrev->resolved()) {
    # by construction of the range all local revs are branches to same target
    my $it = $revmgr->range($primarylrev)->iter();
    my $tit = $revmgr->iter($tprojid, $tpackid);
    # successor lrev
    my $slrev;
    while (my $lrev = $it->next()) {
      dbgprint(" resolve rev: $lprojid/$lpackid/r" . $lrev->intrev()->{'rev'});
      dbgprint("\n");
      my @constraints = $lrev->constraints();
      push @constraints, $slrev->constraints() if $slrev;
      my ($time, $idx) = ($lrev->time(), $lrev->idx());
      push @constraints, BSBlame::Constraint->new("time <= $time", 1);
      push @constraints, BSBlame::Constraint->new("idx > $idx", 1,
                                                  "project = $lprojid",
                                                  "package = $lpackid");
      my $blsrcmd5 = $lrev->targetrev()->lsrcmd5();
      dbgprint("              blsrcmd5: $blsrcmd5\n");
      my $blrev = $tit->find(BSBlame::Constraint->new("lsrcmd5 = $blsrcmd5", 0,
                                                      "project = $tprojid",
                                                      "package = $tpackid"),
                             @constraints);
      if (!$blrev) {
        die("unable to resolve first elm in range\n") unless $slrev;
        # ok, let's hope that $lrev is really the start of a new range
        $revmgr->rangesplit($lrev);
        last;
      }
      dbgprint("              -> $tprojid/$tpackid/r");
      dbgprint($blrev->intrev()->{'rev'} . "\n");
      # install blrev and merge constraints
      # (constraints are installed to blrev _and_ the targetrev)
      $lrev->targetrev()->localrev($blrev);
      $lrev->targetrev()->constraints(@constraints);
      $lrev->resolved(1);
      push @deps, $lrev->targetrev();
      dbgprint("                push " . ($lrev->targetrev() + 0) . "\n");
      $slrev = $lrev;
    }
  }
  return @deps;
}

sub resolve_plain {
  my ($self, $rev) = @_;
  my $revmgr = $rev->revmgr();
  my ($projid, $packid) = ($rev->project(), $rev->package());
  dbgprint("resolve plain: $projid/$packid\n");
  return () if $rev->resolved();
  my $lrev = $revmgr->find($rev->project(), $rev->package(), $rev->lsrcmd5(),
                           $rev->constraints());
  die("unable to resolve plain rev\n") unless $lrev;
  $rev->localrev($lrev);
  $rev->resolved(1);
  my $it = $revmgr->range($lrev)->iter();
  while ($lrev = $it->next()) {
    dbgprint(" rev: " . $lrev->intrev()->{'rev'} . "\n");
    last if $lrev->resolved();
    $lrev->resolved(1);
  }
  return ();
}

sub lastworkingautomerge {
  my ($self, $blamer) = @_;
  my $lrev = $blamer->{'rev'};
  die("branch expected\n") unless $lrev->isbranch();
  my $plrev = $blamer->deps()->[2];
  my $rev = findlastworkingautomerge($plrev, $lrev->time(), []);
  die("no last working automerge found\n") unless $rev;
  die("not expanded\n") unless $rev->isexpanded();
  dbgprint(Dumper($rev->intrev()));
  $self->resolve($rev);
  $blamer->lastworking($rev->targetrev());
}

# assumption: all revisions that we encounter during calls to
# findlastworkingautomerge satisfy the following properties:
# - either "isbranch" or "isplain" holds
# - in case of a branch, no linkrev attribute is set (in the _link file)
#   and no "olinkrev" parameter was used when creating the branch (and of
#   course no manually specified _link file etc.)
sub findlastworkingautomerge {
  my ($lrev, $stime, $revs, @idxconstraints) = @_;
  my $lprojid = $lrev->project();
  my $lpackid = $lrev->package();
  dbgprint("findcandidate: $lprojid/$lpackid/r");
  dbgprint($lrev->intrev()->{'rev'} . "\n");
  my $revmgr = $lrev->revmgr();
  if ($lrev->isplain()) {
    my $rev = $lrev;
    for my $lrev (@$revs) {
      $rev = $revmgr->expand($lrev, $rev);
      return undef unless $rev;
    }
    return $rev;
  }
  die("expanded rev makes no sense\n") if $lrev->isexpanded();
  # idx is always defined
  my $idx = $lrev->idx();
  die("logic error (idx undefined)\n") unless defined($idx);
  push @idxconstraints, BSBlame::Constraint->new("idx > $idx", 1,
                                                 "project = $lprojid",
                                                 "package = $lpackid");
  my $ltime = $lrev->time();
  my @tconstraints = (
    BSBlame::Constraint->new("time <= $stime", 0),
    BSBlame::Constraint->new("time >= $ltime", 0)
  );

  unshift @$revs, $lrev;
  my $tprojid = $lrev->targetrev()->project();
  my $tpackid = $lrev->targetrev()->package();
  my $tit = $revmgr->iter($tprojid, $tpackid, @idxconstraints, @tconstraints);
  # successor target lrev
  my $stlrev;
  my $rev;
  while ((my $tlrev = $tit->next()) && !$rev) {
    $rev = findlastworkingautomerge($tlrev, $stlrev ? $stlrev->time() : $stime,
                                    $revs, @idxconstraints);
    $stlrev = $tlrev;
  }

  if (!$rev) {
    # we tried all target revs in the time range from ltime to stime;
    # next we try the first target rev whose commit time is strictly less
    # than ltime (with our assumptions, this rev is supposed to be a
    # part of lrev's baserev (note: if all commits happened at the same time,
    # we already found a part of lrev's baserev in the previous while loop and
    # this codepath shouldn't be reached)).
    @tconstraints = BSBlame::Constraint->new("time < $ltime", 0);
    $tit = $revmgr->iter($tprojid, $tpackid, @idxconstraints, @tconstraints);
    my $tlrev = $tit->next();
    if ($tlrev) {
      # TODO: come up with a reasonable testcase for the case where $stlrev
      #       is undefined
      $stime = $stlrev->time() if $stlrev;
      $rev = findlastworkingautomerge($tlrev, $stime, $revs, @idxconstraints);
    }
  }
  shift @$revs;
  return $rev;
}

our $DEBUG = 0;

sub dbgprint {
  my ($msg) = @_;
  print $msg if $DEBUG;
}

1;

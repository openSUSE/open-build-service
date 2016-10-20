package BSBlame::Blamer;

use strict;
use warnings;

use Data::Dumper;

use BSBlame::Diff3;

# Performs the actual blame of a revision.

sub new {
  my ($class, $rev, $storage) = @_;
  my $self = {'rev' => $rev, 'storage' => $storage};
  bless $self, $class;
  $self->setupdeps_expanded() if $rev->isexpanded();
  $self->setupdeps_branch() if $rev->isbranch();
  $self->setupdeps_plain() if $rev->isplain();
  die("plain link not supported\n") if $rev->islink() && !$rev->isbranch();
  return $self;
}

sub setupdeps_expanded {
  my ($self) = @_;
  die("plain links are not yet supported\n")
    unless $self->{'rev'}->localrev()->isbranch();
  push @{$self->{'deps'}}, $self->{'rev'}->targetrev();
  push @{$self->{'deps'}}, $self->{'rev'}->localrev()->targetrev();
  push @{$self->{'deps'}}, $self->{'rev'}->localrev();
}

sub setupdeps_branch {
  my ($self) = @_;
  push @{$self->{'deps'}}, $self->{'rev'}->targetrev();
  my $range = $self->{'rev'}->revmgr()->range($self->{'rev'});
  my $plrev = $range->pred($self->{'rev'});
  return unless $plrev;
  push @{$self->{'deps'}}, $plrev->targetrev();
  push @{$self->{'deps'}}, $plrev;
}

sub setupdeps_plain {
  my ($self) = @_;
  my $range = $self->{'rev'}->revmgr()->range($self->{'rev'});
  my $prev = $range->pred($self->{'rev'});
  push @{$self->{'deps'}}, $prev if $prev;
}

sub hasconflict {
  my ($self) = @_;
  return 0 if $self->{'rev'}->isplain() || $self->{'rev'}->isexpanded();
  return $self->{'conflict'} if exists $self->{'conflict'};
  # need to check this only for a branch (or a link...)
  my $revmgr = $self->{'rev'}->revmgr();
  my ($brev, $pbrev, $plrev) = @{$self->{'deps'}};
  # no predecessor => start of a branch, hence, no conflict
  return $self->{'conflict'} = 0 unless $plrev;
  my $rev = $revmgr->expand($plrev, $brev);
  return $self->{'conflict'} = !defined($rev);
}

sub deps {
  my ($self) = @_;
  my @deps = @{$self->{'deps'} || []};
  push @deps, $self->{'lastworking'} if $self->{'lastworking'};
  return \@deps;
}

sub lastworking {
  my ($self, $rev) = @_;
  $self->{'lastworking'} = $rev;
}

sub ready {
  my ($self, $filename) = @_;
  my $storage = $self->{'storage'};
  return 1 if $storage->retrieve($self->{'rev'}, $filename);
  return !grep {!$storage->retrieve($_, $filename)} @{$self->{'deps'}};
}

sub blame {
  my ($self, $filename) = @_;
  die("deps not blamed\n") unless $self->ready($filename);
  my $rev = $self->{'rev'};
  my $storage = $self->{'storage'};
  return $storage->retrieve($rev, $filename)
    if $storage->retrieve($rev, $filename);
  my $blamedata;
  ($blamedata) = $self->blame_expanded($filename) if $rev->isexpanded();
  ($blamedata) = $self->blame_branch($filename) if $rev->isbranch();
  ($blamedata) = $self->blame_plain($filename) if $rev->isplain();
  die("plain link not supported\n") if $rev->islink() && !$rev->isbranch();
  die("XXX\n") unless $blamedata;
  $storage->store($rev, $filename, $blamedata);
  return $blamedata;
}

sub blame_expanded {
  my ($self, $filename) = @_;
  my $rev = $self->{'rev'};
  my $lrev = $rev->localrev();
  my $trev = $rev->targetrev();
  my $brev = $rev->localrev()->targetrev();
  return $self->calcblame($filename, $lrev, $trev, $brev);
}

sub blame_branch {
  my ($self, $filename) = @_;
  return $self->blame_branch_conflict($filename) if $self->hasconflict();
  my $storage = $self->{'storage'};
  my ($brev, $pbrev, $plrev) = @{$self->{'deps'}};
  # no predecessor => start of a branch, hence, just take the baserev's
  # blamedata (assumption: no keepcontent case branch)
  return $storage->retrieve($brev, $filename) unless $plrev;
  # calculate blame for last working expanded predecessor
  my ($pblame) = $self->calcblame($filename, $plrev, $brev, $pbrev);
  # next diff my rev against its last working expanded predecessor
  # 2-way diff: diff prev lrev
  my $lrev = $self->{'rev'};
  my $prev = $lrev->revmgr()->expand($plrev, $brev, 1);
  $storage->store($prev, $filename, $pblame);
  return $self->calcblame($filename, $prev, $lrev, $prev);
}

sub blame_branch_conflict {
  my ($self, $filename) = @_;
  die("there is no conflict\n") unless $self->hasconflict();
  die("no last working automerge\n") unless $self->{'lastworking'};
  my $storage = $self->{'storage'};
  my $lrev = $self->{'rev'};
  my ($brev, $pbrev, $plrev) = @{$self->{'deps'}};
  my $prev = $lrev->revmgr()->expand($plrev, $self->{'lastworking'}, 1);
  my ($pblame) = $self->calcblame($filename, $plrev, $self->{'lastworking'},
                                  $pbrev);
  $storage->store($prev, $filename, $pblame);
  my ($brevblamedata, $brevblame) = $self->calcblame($filename, $brev, $lrev,
                                                     $brev);
  my ($prevblamedata, $prevblame) = $self->calcblame($filename, $prev, $lrev,
                                                     $prev);
  my @blame;
  my @blamedata;
  for (my $i = 0; $i < @$brevblame; $i++) {
    if ($brevblame->[$i]->[0] == $BSBlame::Diff3::FY) {
      $blame[$i] = $prevblame->[$i];
      $blamedata[$i] = $prevblamedata->[$i];
    } else {
      $blame[$i] = $brevblame->[$i];
      $blamedata[$i] = $brevblamedata->[$i];
    }
  }
  return (\@blamedata, \@blame);
}

sub blame_plain {
  my ($self, $filename) = @_;
  my $lrev = $self->{'rev'};
  # if lrev is the first rev in the range, plrev is undefined
  my $plrev = $self->{'deps'}->[0];
  # 2-way diff of myrev against its predecessor
  return $self->calcblame($filename, $plrev, $lrev, $plrev);
}

# could be static, but this way subclasses can override it
sub calcblame {
  my ($self, $filename, $myrev, $yourrev, $commonrev) = @_;
  my $storage = $self->{'storage'};
  my @blames = (
    $myrev ? $storage->retrieve($myrev, $filename) : undef,
    $yourrev ? $storage->retrieve($yourrev, $filename) : undef,
    $commonrev ? $storage->retrieve($commonrev, $filename) : undef
  );
  my @blame;
  if ($myrev && $yourrev && $commonrev) {
    @blame = BSBlame::Diff3::merge($myrev->file($filename) || '/dev/null',
                                   $yourrev->file($filename) || '/dev/null',
                                   $commonrev->file($filename) || '/dev/null',
                                   scalar(@{$blames[2]}) - 1);
  } elsif (!$myrev && $yourrev && !$commonrev) {
    @blame = BSBlame::Diff3::merge('/dev/null',
                                   $yourrev->file($filename) || '/dev/null',
                                   '/dev/null');
  } else {
    die("calcblame: illegal argument combination\n");
  }
  return (
    [map {$blames[$_->[0]] ? $blames[$_->[0]]->[$_->[1]] : $yourrev} @blame],
    \@blame
  );
}

1;

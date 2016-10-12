package BSBlame::RevisionManager;

use strict;
use warnings;

use Data::Dumper;

use BSFileDB;
use BSBlame::Revision;
use BSBlame::Range;
use BSBlame::Constraint;
use BSBlame::Iterator;

# Manages local revision objects and ranges. Moreover, it encapsulates the
# access to source files etc.

sub new {
  my ($class, $projectsdir, $srcrevlay, $getrev, $lsrev, $revfilename,
      $expand) = @_;
  return bless {
    'projectsdir' => $projectsdir,
    'srcrevlay' => $srcrevlay,
    'getrev' => $getrev,
    'lsrev' => $lsrev,
    'revfilename' => $revfilename,
    'expand' => $expand
  }, $class;
}

# private
sub read {
  my ($self, $projid, $packid) = @_;
  my $key = "$projid/$packid";
  return $self->{'revs'}->{$key} if $self->{'revs'}->{$key};
  my $dbfn = "$self->{'projectsdir'}/$projid.pkg/$packid.rev";
  my @orevs = BSFileDB::fdb_getall($dbfn, $self->{'srcrevlay'});
  my (@revs, @ranges);
  my $i = 0;
  my $range = BSBlame::Range->new(0, \@revs);
  while (@orevs) {
    my $orev = pop @orevs;
    $orev->{'project'} = $projid;
    $orev->{'package'} = $packid;
    my $lrev = BSBlame::Revision->new($orev, $self, $i);
    push @revs, $lrev;
    if (!$range->contains($lrev)) {
      $range->end($i - 1);
      push @ranges, $range;
      $range = BSBlame::Range->new($i, \@revs);
    }
    $i++;
  }
  if (@revs) {
    $range->end($i - 1);
    push @ranges, $range;
  }
  $self->{'revs'}->{$key} = \@revs;
  $self->{'ranges'}->{$key} = \@ranges;
  return \@revs;
}

# returns an "internal" revision (part of the _public_ api)
sub intgetrev {
  my ($self, @args) = @_;
  return $self->{'getrev'}->(@args);
}

sub lsrev {
  my ($self, $rev) = @_;
  return $self->{'lsrev'}->($rev->intrev());
}

sub expand {
  my ($self, $lrev, $trev, $fatal) = @_;
  die("rev must be a branch\n") unless $lrev->isbranch();
  my $lfiles = $lrev->files();
  my %lrev = %{$lrev->intrev()};
  $lrev{'linkrev'} = $trev->srcmd5();
  my $files = $self->{'expand'}->(\%lrev, $lfiles);
  if (!ref($files)) {
    die("cannot be expanded\n") if $fatal;
    return undef;
  }
  my $rev = BSBlame::Revision->new(\%lrev, $self);
  $rev->init($lrev, $trev);
  return $rev;
}

sub revfilename {
  my ($self, $rev, $filename) = @_;
  my $md5 = $self->lsrev($rev)->{$filename};
  return '' unless $md5;
  return $self->{'revfilename'}->($rev->intrev(), $filename, $md5);
}

sub iter {
  my ($self, $projid, $packid, @constraints) = @_;
  my $revs = $self->read($projid, $packid);
  return BSBlame::Iterator->new($revs, @constraints);
}

sub find {
  my ($self, $projid, $packid, $lsrcmd5, @constraints) = @_;
  push @constraints, BSBlame::Constraint->new("lsrcmd5 = $lsrcmd5", 0,
                                              "project = $projid",
                                              "package = $packid");
  my $it = $self->iter($projid, $packid, @constraints);
  return $it->next();
}

sub range {
  my ($self, $lrev) = @_;
  my $key = $lrev->project() . '/' . $lrev->package();
  $self->read($lrev->project(), $lrev->package());
  die("$key not known\n") unless $self->{'ranges'}->{$key};
  for my $range (@{$self->{'ranges'}->{$key}}) {
    return $range if $range->contains($lrev);
  }
  # we could print more details, but this code path shouldn't be
  # reached in the first place...
  die("unknown rev\n");
}

sub rangesplit {
  my ($self, $lrev) = @_;
  my $range = $self->range($lrev);
  my $revs = $self->read($lrev->project(), $lrev->package());
  my $oldend = $range->end($lrev->idx() - 1);
  my $newrange = BSBlame::Range->new($lrev->idx(), $revs);
  $newrange->end($oldend);
  my $key = $lrev->project() . '/' . $lrev->package();
  # we do not care about the ordering
  push @{$self->{'ranges'}->{$key}}, $newrange;
}

1;

package BSBlame::Revision;

use strict;
use warnings;

use Data::Dumper;
use Digest::MD5 ();

use BSRevision;
use BSXML;

# This code needs a bit more love (get rid of this stupid $self->{'data'}
# indirection etc.)

# This class represents a revision. A revision object will be associated to
# a corresponding local revision (localrev), which is also a revision object.
# The association is done in BSBlame::RangeFirstStrategy::resolve.
# A local revision is a revision object that corresponds to a certain commit,
# which is tracked in a $projid.pkg/$packid.rev file.
#
# Currently, we support three types of revisions:
#
# 1. Plain Revision
# A plain revision is a BSBlame::Revision object that corresponds to a package
# that has no _link file. From a conceptual point of view, a plain
# BSBlame::Revision $rev can either be a _local revision_ itself or "normal"
# plain revision object that has to be associated to a correponding plain
# _local revision_ BSBlame::Revision object. For instance, all
# BSBlame::Revision objects that are created in BSBlame::Revision::init can
# be interpreted as a "normal" plain revision.
# Note: from a code POV, there is no difference between a plain local revision
#       and "normal" plain revision.
#
# 2. Expanded Revision
# An expanded obs revision refers to two other obs revisions: the local
# revision (lsrcmd5) (/LOCAL) and the link revision (srcmd5) (/LINK).
# The lsrcmd5, which contains the _link file, corresponds to one or more
# commits in the $projid.pkg/$packid.rev. The srcmd5 corresponds to a
# plain rev or an expanded rev of the link target.
# Both concepts are mapped to a BSBlame::Revision object $rev as follows:
#
# - lsrcmd5 -> $rev->localrev()
# - srcmd5  -> $rev->targetrev()
#
# (Note: $rev->localrev() can only be accessed once $rev is resolved
#        (otherwise undef is returned))
#
# Keep in mind that a lsrcmd5 might correspond to more commits and, hence,
# it might be possible that an expanded revision is associated to a
# "wrong" local revision.
#
# 3. Branch Revision
# A branch revision _is_ a _local revision_ whose file set contains a _link
# file that represents an obs branch. The _link's baserev is either a plain
# rev or an expanded rev of the link target. This is mapped to a
# BSBlame::Revision object $lrev as follows:
#
# - $lrev -> $lrev->localrev() (remember that a branch revision _is_ a local
#                               revision => $lrev->localrev() returns itself)
# - baserev -> $lrev->targetrev()


# Variable naming conventions:
#
# $lrev:  local revision
# $plrev: preceeding local revision (e.g., $plrev->idx() == $lrev->idx() + 1)
# $slrev: succeeding local revision (e.g., $slrev->idx() == $lrev->idx() - 1)
# $tlrev: target local revision
# $rev:   expanded revision or a normal plain revision

sub new {
  my ($class, $rev, $revmgr, $idx) = @_;
  return bless {
    'data' => {
      'rev' => $rev,
      'revmgr' => $revmgr,
      'idx' => $idx
    }
  }, $class;
}

sub init {
  my ($self, $lrev, $trev) = @_;
  return if $self->{'data'}->{'lsrcmd5'};
  die("trev without lrev makes no sense\n") if $trev && !$lrev;
  my $data = $self->{'data'};
  $data->{'lsrcmd5'} = $data->{'rev'}->{'srcmd5'};
  my %li;
  my $files = BSRevision::lsrev($data->{'rev'}, \%li);
  my ($l, $tsrcmd5);
  if (%li) {
    $data->{'lsrcmd5'} = $li{'lsrcmd5'};
    $data->{'expanded'} = 1;
    my $lrev = $data->{'revmgr'}->intgetrev($data->{'rev'}->{'project'},
                                            $data->{'rev'}->{'package'},
                                            $data->{'lsrcmd5'});
    $files = BSRevision::lsrev($lrev);
    $l = BSRevision::revreadxml($lrev, '_link', $files->{'_link'},
                                $BSXML::link);
    $tsrcmd5 = $li{'srcmd5'};
  } elsif ($files->{'_link'}) {
    $data->{'link'} = 1;
    $l = BSRevision::revreadxml($data->{'rev'}, '_link', $files->{'_link'},
                                $BSXML::link);
    my @patches = @{$l->{'patches'}->{''} || []};
    $data->{'branch'} = grep {(keys %$_)[0] eq 'branch'} @patches;
    $tsrcmd5 = $l->{'baserev'};
  }
  if ($l && !$trev) {
    my $tprojid = $l->{'project'} || $data->{'rev'}->{'project'};
    my $tpackid = $l->{'package'} || $data->{'rev'}->{'package'};
    $trev = $data->{'revmgr'}->intgetrev($tprojid, $tpackid, $tsrcmd5);
    $data->{'targetrev'} = BSBlame::Revision->new($trev, $data->{'revmgr'});
  } elsif ($trev) {
    $self->localrev($lrev);
    $data->{'targetrev'} = $trev;
    $self->resolved(1);
  }
}

sub project {
  my ($self) = @_;
  return $self->{'data'}->{'rev'}->{'project'};
}

sub package {
  my ($self) = @_;
  return $self->{'data'}->{'rev'}->{'package'};
}

sub isexpanded {
  my ($self) = @_;
  $self->init();
  return exists $self->{'data'}->{'expanded'};
}

sub isbranch {
  my ($self) = @_;
  $self->init();
  return $self->islink() && $self->{'data'}->{'branch'};
}

sub islink {
  my ($self) = @_;
  $self->init();
  return exists $self->{'data'}->{'link'};
}

sub isplain {
  my ($self) = @_;
  return !$self->islink() && !$self->isexpanded();
}

sub lsrcmd5 {
  my ($self) = @_;
  $self->init();
  return $self->{'data'}->{'lsrcmd5'};
}

sub srcmd5 {
  my ($self) = @_;
  return $self->{'data'}->{'rev'}->{'srcmd5'};
}

sub time {
  my ($self) = @_;
  if ($self->isexpanded()) {
    my $lrev = $self->localrev();
    # lrev itself is not necessarily resolved
    return $lrev->time() if $self->resolved();
    die("time cannot be requested for an expanded rev\n");
  }
  return $self->{'data'}->{'rev'}->{'time'};
}

sub localrev {
  my ($self, $lrev) = @_;
  $self->init();
  my $data = $self->{'data'};
  if ($lrev) {
    die("localrev cannot be changed\n") if $data->{'localrev'}
      && $data->{'localrev'} != $lrev; # XXX: use ref comparison
    $data->{'localrev'} = $lrev;
  }
  return $self if $self->resolved() && !$data->{'localrev'};
  return $data->{'localrev'};
}

sub targetrev {
  my ($self) = @_;
  $self->init();
  die("targetrev makes no sense for a non link\n") if $self->isplain();
  return $self->{'data'}->{'targetrev'};
}

sub intrev {
  my ($self) = @_;
  my $lrev = $self->localrev();
  return $lrev->intrev() if $lrev && !$self->isexpanded() && $lrev != $self;
  return $self->{'data'}->{'rev'};
}

sub resolved {
  my ($self, $status) = @_;
  $self->{'data'}->{'resolved'} = 1 if $status;
  return $self->{'data'}->{'resolved'};
}

sub idx {
  my ($self) = @_;
  my $lrev = $self->localrev();
  return $self->{'data'}->{'idx'} if !$lrev || $lrev == $self;
  return $lrev->idx();
}

sub satisfies {
  my ($self, @constraints) = @_;
  for my $c (@constraints) {
    next unless $c->isfor($self);
    return 0 unless $c->eval($self);
  }
  $self->init();
  if ($self->resolved() && ($self->islink() || $self->isexpanded())) {
    @constraints = grep {$_->isglobal()} @constraints;
    my $trev = $self->targetrev();
    return $trev->satisfies(@constraints) if $trev->resolved();
  }
  return 1;
}

sub constraints {
  my ($self, @constraints) = @_;
  # TODO: instead of just pushing the @constraints, it would be more
  #       reasonable to "merge" the constraints
  my $data = $self->{'data'};
  push @{$data->{'constraints'}}, @constraints;
  $data->{'targetrev'}->constraints(@constraints) if $data->{'targetrev'};
  return @{$data->{'constraints'}};
}

sub revmgr {
  my ($self) = @_;
  return $self->{'data'}->{'revmgr'};
}

sub files {
  my ($self) = @_;
  return $self->revmgr()->lsrev($self);
}

sub file {
  my ($self, $filename) = @_;
  return $self->revmgr()->revfilename($self, $filename);
}

sub cookie {
  my ($self) = @_;
  die("rev has to be resolved\n") unless $self->resolved();
  return $self->{'data'}->{'cookie'} if $self->{'data'}->{'cookie'};
  my $cookie = $self->project() . '/' . $self->package;
  $cookie .= '/' . $self->localrev()->intrev()->{'rev'};
  # idx is needed in the future if we support deleted revisions...
  $cookie .= '/' . $self->localrev()->idx();
  if ($self->isexpanded()) {
    $cookie .= "\n" . $self->targetrev()->cookie();
  }
  $self->{'data'}->{'cookie'} = Digest::MD5::md5_hex($cookie);
  return $self->{'data'}->{'cookie'};
}

1;

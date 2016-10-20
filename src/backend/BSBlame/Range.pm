package BSBlame::Range;

use strict;
use warnings;

use Data::Dumper;

use BSBlame::Constraint;
use BSBlame::Iterator;

# A range is a contiguous ordered set of _local revision_ objects that refer
# to the same $projid/$packid and have the same type (possible types: plain
# revision or branch revision (see docs of BSBlame::Revision)).
# For a range that contains branch revisions the following property holds:
# - all branch revisions in this range have the same target (target project
#   and target package)
#
# Note: it is possible that during the resolve step (see
#       BSBlame::RangeFirstStrategy::resolve) an existing range is split into
#       two different ranges.

sub new {
  my ($class, $start, $data) = @_;
  return bless {
    'start' => $start,
    # don't even dare to modify data (we could also use a list but well...
    # this class behaves;) )
    'data' => $data
  }, $class;
}

sub end {
  my ($self, $end) = @_;
  die("illegal end\n") unless defined($end);
  my $oldend = $self->{'end'};
  $self->{'end'} = $end;
  return $oldend;
}

sub contains {
  my ($self, $lrev) = @_;
  die("illegal rev\n") if !defined($lrev) || $lrev->isexpanded();
  return 0 unless $lrev->idx() >= $self->{'start'};
  return 0 unless !defined($self->{'end'}) || $lrev->idx() <= $self->{'end'};
  # representant of the whole range
  my $lrrev = $self->{'data'}->[$self->{'start'}];
  return 0 unless $lrrev->project() eq $lrev->project();
  return 0 unless $lrrev->package() eq $lrev->package();
  for (qw(islink isbranch)) {
    return 0 if $lrrev->$_() && !$lrev->$_();
    return 0 if !$lrrev->$_() && $lrev->$_();
  }
  if ($lrrev->islink()) {
    # TODO: plain link handling
    die("branches only\n") unless $lrrev->isbranch();
    my $tlrrev = $lrrev->targetrev();
    my $tlrev = $lrev->targetrev();
    return 0 unless $tlrrev->project() eq $tlrev->project();
    return 0 unless $tlrrev->package() eq $tlrev->package();
  }
  return 1;
}

sub pred {
  my ($self, $lrev) = @_;
  die("rev not in range\n") unless $self->contains($lrev);
  return undef unless $lrev->idx() < $self->{'end'};
  return $self->{'data'}->[$lrev->idx() + 1];
}

sub iter {
  my ($self) = @_;
  my $start = $self->{'start'};
  my $end = $self->{'end'};
  die("inconsistent range state\n") unless defined($start) && defined($end);
  # hmm introduce special constraints such that we can pass
  # start and end as a reference (so that the iterator is consistent
  # after a range split)?
  # TODO: testcase that demonstrates why we need non-global constraints here
  return BSBlame::Iterator->new($self->{'data'},
                                BSBlame::Constraint->new("idx >= $start", 0),
                                BSBlame::Constraint->new("idx <= $end", 0));
}

1;

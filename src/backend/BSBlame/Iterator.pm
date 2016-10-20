package BSBlame::Iterator;

use strict;
use warnings;

use Data::Dumper;

sub new {
  my ($class, $data, @constraints) = @_;
  return bless {
    'data' => $data,
    'constraints' => \@constraints,
    'cur' => -1
  }, $class;
}

sub item {
  my ($self) = @_;
  my $cur = $self->{'cur'};
  return undef if $cur < 0 || $cur > @{$self->{'data'}};
  return $self->{'data'}->[$cur];
}

sub next {
  my ($self, @constraints) = @_;
  push @constraints, @{$self->{'constraints'}};
  my $i = \$self->{'cur'};
  my $data = $self->{'data'};
  for ($$i++; $$i < @$data; $$i++) {
    my $item = $self->item();
    # item should always be defined
    return $item if defined($item) && $item->satisfies(@constraints);
  }
  # not needed (just to be explicit)
  return undef;
}

sub find {
  my ($self, @constraints) = @_;
  my $item = $self->item();
  return $item if defined($item) && $item->satisfies(@constraints);
  return $self->next(@constraints);
}

1;

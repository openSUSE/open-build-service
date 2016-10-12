package BSBlame::Constraint;

use strict;
use warnings;

use Data::Dumper;

my $opmap = {
  '<' => sub { !defined($_[0]) ? 1 : ($_[0] + 0 < $_[1] + 0) },
  '<=' => sub { !defined($_[0]) ? 1 : ($_[0] + 0 <= $_[1] + 0) },
  '=' => sub { !defined($_[0]) ? 1 : ($_[0] eq $_[1]) },
  '>=' => sub { !defined($_[0]) ? 1 : ($_[0] + 0 >= $_[1] + 0) },
  '>' => sub { !defined($_[0]) ? 1 : ($_[0] + 0 > $_[1] + 0) }
};

my $opre = join('|',
                map {"\Q$_\E"} sort {length($b) <=> length($a)} keys(%$opmap));

sub new {
  my ($class, $expr, $global, @preexprs) = @_;
  my $self = {};
  bless $self, $class;
  $self->parse($expr);
  $self->{'global'} = $global;
  for my $preexpr (@preexprs) {
    push @{$self->{'preconditions'}}, BSBlame::Constraint->new($preexpr);
  }
  return $self;
}

sub parse {
  my ($self, $expr) = @_;
  die("illegal expression: \"$expr\"\n")
    unless $expr =~ /^([^\s]+)\s*($opre)\s*(.*)/;
  $self->{'attr'} = $1;
  $self->{'op'} = $2;
  $self->{'val'} = $3;
}

sub eval {
  my ($self, $rev) = @_;
  my $meth = $rev->can($self->{'attr'});
  die("unknown attribute $self->{'attr'}\n") unless $meth;
  return $opmap->{$self->{'op'}}->($rev->$meth(), $self->{'val'});
}

sub isfor {
  my ($self, $rev) = @_;
  for my $precondition (@{$self->{'preconditions'} || []}) {
    return 0 if !$precondition->eval($rev);
  }
  return 1;
}

sub isglobal {
  my ($self) = @_;
  return $self->{'global'};
}

# needed? (only for constraint merging, contradiction checking etc.)

sub attr {
  my ($self) = @_;
  return $self->{'attr'};
}

sub op {
  my ($self) = @_;
  return $self->{'op'};
}

sub val {
  my ($self) = @_;
  return $self->{'val'};
}

1;

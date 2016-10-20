package BSBlame::BlameStorage;

use strict;
use warnings;

sub new {
  my ($class) = @_;
  return bless {}, $class;
}

sub retrieve {
  my ($self, $rev, $filename) = @_;
  return $self->{$rev->cookie()}->{$filename};
}

sub store {
  my ($self, $rev, $filename, $blamedata) = @_;
  die("already present\n") if $self->retrieve($rev, $filename);
  $self->{$rev->cookie()}->{$filename} = $blamedata;
}

1;

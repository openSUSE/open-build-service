package BSBlame::Diff3;

use strict;
use warnings;

use Data::Dumper;

sub diff3 {
  my ($my, $your, $common) = @_;
  open(D, "-|", 'diff3', '-T', $my, $your, $common) || die("diff3: $!\n");
  my $diff3; # current diff3 block
  my @diff3; # all diff3 blocks
  my $lines; # all this line handling is just a sanity check...
  while (<D>) {
    chomp;
    if (/^\t/ && defined($lines)) {
      $lines--;
    } elsif (/====(\d)?$/) {
      die("illegal format: $_ (data expected)\n") if defined($lines) && $lines != 0;
      push @diff3, $diff3 if $diff3;
      $diff3 = {};
      $diff3->{'odd'} = $1 ? $1 - 1 : undef;
      $lines = undef;
    } elsif (/(\d):(\d+)(?:,(\d+))?(a|c)/) {
      die("illegal format: $_\n") if defined($lines) && $lines != 0;
      my ($fno, $lo, $hi) = ($1 - 1, $2 - 1, (defined($3) ? $3 : $2) - 1);
      $diff3->{'data'}->[$fno] = [$lo, $hi, $4];
      $lines = $hi - $lo;
      $lines++ if $lines || $4 eq 'c';
      undef $lines if defined($diff3->{'odd'}) && $fno == ($diff3->{'odd'} == 0);
    } else {
      die("illegal format: $_\n") unless $_ eq '\ No newline at end of file';
    }
  }
  die("unexpected eof\n") if $lines;
  push @diff3, $diff3 if $diff3;
  close(D) || die("close: $!\n");
  return @diff3;
}

our $FM = 0; # my file
our $FY = 1; # your file
our $FC = 2; # common file

sub merge {
  my ($my, $your, $common, $cnumlines, $ctie) = @_;
  my @diff3 = diff3($my, $your, $common);
  return undef if grep {!defined($_->{'odd'})} @diff3;
  $ctie = $FY unless defined($ctie);
  die("illegal ctie value: $ctie\n") unless $ctie == $FY || $ctie == $FM;
  my @merge;
  my $off = 0;
  for my $diff3 (@diff3) {
    my ($low, $high, $type) = @{$diff3->{'data'}->[$FC]};
    my $lo = $low;
    $lo-- if $type eq 'c'; # stop one line before the change starts
    while ($off <= $lo) {
      push @merge, [$FC, $off];
      $off++;
    }
    # the change affects high - low + 1 lines (inclusive)
    $off += $high - $low + 1 if $type eq 'c';
    my $odd = $diff3->{'odd'};
    # nothing todo, if common is the odd file and if the diff
    # block of my and common has the type "add" ("a") 
    # (note: since we have no conflicts, the diff block of
    # your and common also has the type "add" (that's why we
    # just check the type of the my ($FM) block))
    next if $odd == $FC && $diff3->{'data'}->[$FM]->[2] eq 'a';
    # nothing todo, if my/your is the odd file and the diff
    # block of my/your and common has type "add" ("a")
    # (that is, lines were removed from the my/your file and, hence,
    # there is nothing to merge)
    next if $odd != $FC && $diff3->{'data'}->[$odd]->[2] eq 'a';
    # if common is the odd file, the my file and the your
    # file have the "same" diff - so we can either take the
    # information from the my file or from the your file.
    # so, $ctie acts as tie breaker (it represents the
    # choice)
    $odd = $ctie if $odd == $FC;
    ($low, $high, $type) = @{$diff3->{'data'}->[$odd]};
    while ($low <= $high) {
      push @merge, [$odd, $low];
      $low++;
    }
  }
  unless (defined($cnumlines)) {
    # fancy way to compute the number of lines for the common file
    @diff3 = diff3($common, '/dev/null', '/dev/null');
    $cnumlines = @diff3 ? $diff3[0]->{'data'}->[$FM]->[1] : -1;
  }
  # take the rest from the common file
  while ($off <= $cnumlines) {
    push @merge, [$FC, $off];
    $off++;
  }
  return @merge;
}

1;

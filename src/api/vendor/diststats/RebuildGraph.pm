#!/usr/bin/perl -w

package RebuildGraph;

use strict;

use GD;

sub hhmm {
  my $t = shift;
  $t /= 60;
  return sprintf("%02d:%02d", int($t / 60), $t % 60);
}

sub render {
  my %params = @_;
  my $header = $params{'header'} || '';
  my $width = $params{'width'} || 800;
  my $height = $params{'height'} || 600;
  my $data = $params{'data'} || {};
  my $scalecol = $params{'scalecol'} || 0; # column in data used for scaling the graph
  my $inttimes = $params{'inttimes'} || {};
  my $starttime = $params{'starttime'} || 0;
  my $endtime = $params{'endtime'} || 0;
  my $colors = $params{'colors'} || [ qw/0000ff 3f71ff 6ec8ff 00ff00 ff0000/];

  my $maxval = 0;
  my $maxtime = 0;
  for (sort {$a <=> $b} keys %$data) {
    next if ($_ < $starttime);
    last if ($endtime && $_ > $endtime);
    my $nb = $data->{$_}->[$scalecol];
    $maxval = $nb if ($maxval < $nb);
    $maxtime = $_ if ($maxtime < $_);
  }

  $maxval *= 1.2;

  my $yaxisround;
  $yaxisround = $maxval > 200 ? 100 : 10;

  my $xaxisend = int(($maxtime-$starttime + 3600 - 1) / 3600) * 3600;
  my $yaxisend = int(($maxval + $yaxisround - 1) / $yaxisround) * $yaxisround;
  my $xaxisstep = int($xaxisend / 12);
  $xaxisstep = int(($xaxisstep + 3600 - 1) / 3600) * 3600;
  my $yaxisstep = int($yaxisend / 10);
  $yaxisstep = int(($yaxisstep + $yaxisround / 2 - 1) / $yaxisround) * $yaxisround;
  $yaxisstep = $yaxisround == $yaxisend ? $yaxisround / 5 : $yaxisround unless $yaxisstep;
  $xaxisstep = int($xaxisstep / 4);
  $yaxisstep = int($yaxisstep / 5);
  $yaxisstep = 1 unless $yaxisstep;

  my $image = new GD::Image($width, $height);
  my $black = $image->colorAllocate (0, 0, 0);
  my $white = $image->colorAllocate (0xff, 0xff, 0xff);
#  my $blue = $image->colorAllocate (0, 0, 255);
#  my $lblue = $image->colorAllocate (110, 200, 255);
#  my $lblue2 = $image->colorAllocate (63, 113, 255);
  my @colors;
  for my $c (@{$colors}) {
    if ($c =~ /([[:xdigit:]]{2})([[:xdigit:]]{2})([[:xdigit:]]{2})/) {
      push @colors, $image->colorAllocate(hex $1, hex $2, hex $3);
    }
  }
  my $ncolors = @colors;
  my $gray    = $image->colorAllocate (128, 128, 128);
#my $grayd   = $image->colorAllocate (64, 64, 64);
  my $grayd = $black;
  my $back    = $image->colorAllocate (0xee, 0xee, 0xee);
  my $red     = $image->colorAllocate (255,   0,   0);
  my $green   = $image->colorAllocate (0,   255,   0);
  $image->filledRectangle (0, 0, $width - 1, $height - 1, $back);
  my $ixoff = 60;
  my $iyoff = 30;
  my $SmallFontWidth = gdSmallFont->width;
  my $SmallFontHeight = gdSmallFont->height;
  my $iw = $width - $ixoff - 20;
  my $ih = $height - $iyoff - $SmallFontHeight * 6;


  $image->filledRectangle ($ixoff, $iyoff, $ixoff + $iw - 1, $iyoff +$ih - 1, $white);

  my $ox = 0;
  my @oy;
  for my $t (sort {$a <=> $b} keys %$data) {
    next if ($t < $starttime);
    last if ($endtime && $t > $endtime);
    my $x = $ixoff + int($iw / $xaxisend * ($t - $starttime));
    my @y;
    for my $y (@{$data->{$t}}) {
      my $yv = $iyoff + $ih - 1 - int($ih / $yaxisend * $y);
      $yv = $iyoff if $yv < $iyoff;
      push @y, $yv;
    }
    if ($ox) {
      for my $i (0 .. $#oy) {
	$image->filledRectangle($ox, $oy[$i], $x, $iyoff + $ih - 1, $colors[$i%$ncolors]);
      }
    }
    $ox = $x;
    @oy = @y;
  }

  $image->rectangle($ixoff, $iyoff, $ixoff + $iw - 1, $iyoff +$ih - 1, $gray);
  my $xax = $xaxisstep;
  my $sub = 1;
  while ($xax < $xaxisend) {
    my $x = $ixoff + int($iw / $xaxisend * $xax);
    if ($sub) {
      $image->setStyle ($gray, gdTransparent, gdTransparent);
    } else {
      $image->setStyle ($grayd, gdTransparent, gdTransparent);
    }

    $image->line($x, $iyoff, $x, $iyoff + $ih - 1, gdStyled);
    $image->line($x, $iyoff + $ih - 3, $x, $iyoff +$ih, $sub ? $gray : $grayd);
    $image->line($x, $iyoff - 1, $x, $iyoff + 2, $sub ? $gray : $grayd);
    if ($sub == 0) {
      my $str = hhmm($xax+$starttime);
      my $strw = $SmallFontWidth * length($str);
      $image->string(gdSmallFont, $x - $strw/2, $iyoff +$ih + 5, $str, $black);
    }
    $xax += $xaxisstep;
    $sub = ($sub + 1) % 4;
  }

  my $yax = $yaxisstep;
  $sub = 1;
  while ($yax < $yaxisend) {
    my $y = $iyoff + $ih - 1 - int($ih / $yaxisend * $yax);
    if ($sub) {
      $image->setStyle ($gray, gdTransparent, gdTransparent);
    } else {
      $image->setStyle ($grayd, gdTransparent, gdTransparent);
    }
    $image->line($ixoff, $y, $ixoff + $iw - 1, $y, gdStyled);
    $image->line($ixoff - 1, $y, $ixoff + 2, $y, $sub ? $gray : $grayd);
    $image->line($ixoff + $iw - 3, $y, $ixoff + $iw, $y, $sub ? $gray : $grayd);

    if ($sub == 0) {
      my $str = "$yax";
      my $strw = $SmallFontWidth * length($str);
      $image->string(gdSmallFont, $ixoff - $strw - 5, $y - $SmallFontHeight/2, $str, $black);
    }
    $yax += $yaxisstep;
    $sub = ($sub + 1) % 5;
  }

  my $TinyFontWidth = gdTinyFont->width;
  my $TinyFontHeight = gdTinyFont->height;
  my $yy = 0;
  for my $t (sort {$a <=> $b} keys %$inttimes) {
    next if ($t < $starttime);
    last if ($endtime && $t > $endtime);
    my $x = $ixoff + int($iw / $xaxisend * ($t - $starttime));
    my $y = $iyoff + $ih + 20 + $SmallFontHeight + $yy * $TinyFontHeight;
    $image->line($x, $iyoff + $ih - 1, $x, $y, $gray);
    my $str = $inttimes->{$t};
    $str = substr($str, 0, 10);
    my $strw = $TinyFontWidth * length($str);
    $image->filledRectangle($x - $strw - 1, $y - $TinyFontHeight, $x - 1, $y, $back);
    $image->string(gdTinyFont, $x - $strw - 1, $y - $TinyFontHeight, $str, $black);
    $yy++;
    $yy = 0 if $yy == 5;
  }

  my $str = "# of packages";
  my $strw = $SmallFontWidth * length($str);
  $image->stringUp(gdSmallFont, 7, $iyoff + $ih/2 + $strw/2, $str, $black);

  if ($header) {
    $strw = gdMediumBoldFont->width() * length($header);
    $image->string(gdMediumBoldFont, $width/2 - $strw/2, 5, $header, $black);
  }

  return $image->png;
}

1;

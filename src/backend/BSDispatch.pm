#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
################################################################
#
# request dispatcher
#
# parses the cgi data and calls the matching function from the
# dispatch table
#

package BSDispatch;

use Data::Dumper;

# FIXME: we should not set the request
$BSServer::request if 0;

sub parse_cgi {
  # $req:
  #      the part of URI after ?
  # $multis:
  #      hash of separators
  #      key does not exist - multiple cgi values are not allowed
  #      key is undef - multiple cgi values are put into array
  #      key is - then value is used as separator between cgi values
  my ($req, $multis, $singles) = @_;

  my $query_string = $req->{'query'};
  my %cgi;
  my @query_string = split('&', $query_string);
  while (@query_string) {
    my ($name, $value) = split('=', shift(@query_string), 2);
    next unless defined $name && $name ne '';
    # convert from URI format
    $name  =~ tr/+/ /;
    $name  =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    if (defined($value)) {
      # convert from URI format
      $value =~ tr/+/ /;
      $value =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    } else {
      $value = 1;	# assume boolean
    }
    if ($multis && exists($multis->{$name})) {
      if (defined($multis->{$name})) {
        if (exists($cgi{$name})) {
	  $cgi{$name} .= "$multis->{$name}$value";
        } else {
          $cgi{$name} = $value;
        }
      } else {
        push @{$cgi{$name}}, $value;
      }
    } elsif ($singles && $multis && !exists($singles->{$name}) && exists($multis->{'*'})) {
      if (defined($multis->{'*'})) {
        if (exists($cgi{$name})) {
	  $cgi{$name} .= "$multis->{'*'}$value";
        } else {
          $cgi{$name} = $value;
        }
      } else {
        push @{$cgi{$name}}, $value;
      }
    } else {
      die("parameter '$name' set multiple times\n") if exists $cgi{$name};
      $cgi{$name} = $value;
    }
  }
  return \%cgi;
}

# return only the singles from a query
sub parse_cgi_singles {
  my ($req) = @_;
  my $query_string = $req->{'query'};
  my %cgi;
  for my $qu (split('&', $query_string)) {
    my ($name, $value) = split('=', $qu, 2);
    $name  =~ tr/+/ /;
    $name  =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    if (exists $cgi{$name}) {
      $cgi{$name} = undef;
      next;
    }
    $value = 1 unless defined $value;
    $value =~ tr/+/ /;
    $value =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    $cgi{$name} = $value;
  }
  for (keys %cgi) {
    delete $cgi{$_} unless defined $cgi{$_};
  }
  return \%cgi;
}

sub dispatch_checkcgi {
  my ($cgi, @known) = @_;
  my %known = map {$_ => 1} @known;
  my @bad = grep {!$known{$_}} keys %$cgi;
  die("unknown parameter '".join("', '", @bad)."'\n") if @bad;
}

sub compile_dispatches {
  my ($disps, $verifyers, $callfunction) = @_;
  my @disps = @$disps;
  $verifyers ||= {};
  my @out;
  while (@disps) {
    my $p = shift @disps;
    my $f = shift @disps;
    my $needsauth;
    my $cgisingles;
    if ($p =~ /^!([^\/\s]*)\s*(.*?)$/) {
      $needsauth = $1 || 'auth';
      $p = $2;
    }
    if ($p eq '/') {
      my $cpld = [ qr/^(?:GET|HEAD|POST):\/$/ ];
      $cpld->[2] = $needsauth eq '-' ? undef : $needsauth if $needsauth;
      push @out, $cpld, $f;
      next;
    }
    my @cgis = split(' ', $p);
    s/%([a-fA-F0-9]{2})/chr(hex($1))/ge for @cgis;
    $p = shift @cgis;
    my @p = split('/', $p, -1);
    my $code = "my (\@args);\n";
    my $code2 = '';
    my $num = 1;
    my @args;
    my $known = '';
    for my $pp (@p) {
      if ($pp =~ /^\$(.*)$/) {
        my $var = $1;
        my $vartype = $var;
	($var, $vartype) = ($1, $2) if $var =~ /^(.*):(.*)/;
        die("no verifyer for $vartype\n") unless $vartype eq '' || $verifyers->{$vartype};
        $pp = "([^\\/]*)";
        $code .= "\$cgi->{'$var'} = \$$num;\n";
        $code2 .= "\$verifyers->{'$vartype'}->(\$cgi->{'$var'});\n" if $vartype ne '';
	push @args, $var;
	$known .= ", '$var'";
        $num++;
      } else {
        $pp = "\Q$pp\E";
      }
    }
    $p[0] .= ".*" if @p == 1 && $p[0] =~ /^[A-Z]*\\:$/;
    $p[0] = '[^:]*:.*' if $p[0] eq '\\:.*';
    $p[0] = "(?:GET|HEAD|POST):$p[0]" if $p[0] !~ /:/;
    $p[-1] = '.*' if $p[-1] eq '\.\.\.';
    $p[-1] = '(.*)' if $p[-1] eq "([^\\/]*)" && $args[-1] eq '...';
    my $multis = '';
    my $singles = '';
    my $hasstar;
    for my $pp (@cgis) {
      my ($arg, $qual) = (0, '{1}');
      $arg = 1 if $pp =~ s/^\$//;
      $qual = $1 if $pp =~ s/([+*?])$//;
      my $var = $pp;
      if ($var =~ /^(.*)=(.*)$/) {
	$cgisingles ||= {};
	$cgisingles->{$1} = $2;
	$singles .= ', ' if $singles ne '';
	$singles .= "'$1' => undef";
	$known .= ", '$1'";
	next;
      }
      my $vartype = $var;
      ($var, $vartype) = ($1, $2) if $var =~ /^(.*):(.*)/;
      die("no verifyer for $vartype\n") unless $vartype eq '' || $verifyers->{$vartype};
      $code2 .= "die(\"parameter '$var' is missing\\n\") unless exists \$cgi->{'$var'};\n" if $qual ne '*' && $qual ne '?';
      $hasstar = 1 if $var eq '*';
      if ($qual eq '+' || $qual eq '*') {
	$multis .= ', ' if $multis ne '';
	$multis .= "'$var' => undef";
        $code2 .= "\$verifyers->{'$vartype'}->(\$_) for \@{\$cgi->{'$var'} || []};\n" if $vartype ne '';
      } else {
	$singles .= ', ' if $singles ne '';
	$singles .= "'$var' => undef";
        $code2 .= "\$verifyers->{'$vartype'}->(\$cgi->{'$var'}) if exists \$cgi->{'$var'};\n" if $vartype ne '';
      }
      push @args, $var if $arg;
      $known .= ", '$var'";
    }
    if ($hasstar) {
      $code = "my \$cgi = parse_cgi(\$req, {$multis}, {$singles});\n$code";
    } else {
      $code = "my \$cgi = parse_cgi(\$req, {$multis});\n$code";
    }
    $code2 .= "push \@args, \$cgi->{'$_'};\n" for @args;
    $code2 .= "&dispatch_checkcgi(\$cgi$known);\n" unless $hasstar;
    if ($callfunction) {
      $code .= "$code2\$callfunction->(\$f, \$cgi, \@args);\n";
    } else {
      $code .= "$code2\$f->(\$cgi, \@args);\n";
    }
    my $np = join('/', @p);
    my $cpld = [ qr/^$np$/ ];
    $cpld->[1] = $cgisingles if $cgisingles;
    $cpld->[2] = $needsauth eq '-' ? undef : $needsauth if $needsauth;
    my $fnew;
    if ($f) {
      eval "\$fnew = sub {my (\$conf, \$req) = \@_;\n$code};";
      die("compile_dispatches: $@\n") if $@;
    }
    push @out, $cpld, $fnew;
  }
  return \@out;
}

sub dispatch {
  my ($conf, $req) = @_;
  my $disps = $conf->{'dispatches'};
  my $stdreply = $conf->{'stdreply'};
  die("500 no dispatches configured\n") unless $disps;
  my @disps = @$disps;
  my $path = "$req->{'action'}:$req->{'path'}";
  if (1) {
    # path is already urldecoded
    die("400 path is not utf-8\n") unless BSUtil::checkutf8($path);
    my $q = $req->{'query'};
    $q =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/ge if defined($q) && $q =~ /\%/s;
    die("400 query string is not utf-8\n") unless BSUtil::checkutf8($q);
  }
  my $ppath = $path;
  # strip trailing slash
  $ppath =~ s/\/+$// if substr($ppath, -1, 1) eq '/' && $ppath !~ /^[A-Z]*:\/$/s;
  my $auth;
  my $cgisingles;
  while (@disps) {
    my ($p, $f) = splice(@disps, 0, 2);
    next unless $ppath =~ /$p->[0]/;
    if ($p->[1]) {
      $cgisingles ||= parse_cgi_singles($req);
      next if grep {($cgisingles->{$_} || '') ne $p->[1]->{$_}} keys %{$p->[1]};
    }
    $auth = $p->[2] if @$p > 2;	# optional auth overwrite
    next unless $f;
    if ($auth) {
      die("500 no authenticate method defined\n") unless $conf->{'authenticate'};
      my @r = $conf->{'authenticate'}->($conf, $req, $auth);
      if (@r) {
        return $stdreply->(@r) if $stdreply;
	return @r;
      }
    }
    return $stdreply->($f->($conf, $req)) if $stdreply;
    return $f->($conf, $req);
  }
  die("400 unknown request: $path\n");
}

1;

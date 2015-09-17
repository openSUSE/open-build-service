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

sub parse_cgi {
  # $req:
  #      the request data
  # $multis:
  #      hash of cgi names
  #      * key does not exist - multiple cgi values are not allowed
  #      * value is undef - multiple cgi values are put into array
  #      * value is a string - used as separator to join multiple cgi values
  # $singles:
  #      hash of cgi names
  #      * key exists and multis->key does not exist - multiple cgi values are not allowed
 
  my ($req, $multis, $singles) = @_;

  $multis ||= {};
  $singles ||= {'*' => undef};
  my %cgi;
  my %unknown;
  my @query_string = split('&', $req->{'query'});
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
    if (exists($multis->{$name})) {
      if (defined($multis->{$name})) {
        $cgi{$name} = exists($cgi{$name}) ? "$cgi{$name}$multis->{$name}$value" : $value;
      } else {
        push @{$cgi{$name}}, $value;
      }
    } elsif (exists($singles->{$name})) {
      die("parameter '$name' set multiple times\n") if exists $cgi{$name};
      $cgi{$name} = $value;
    } elsif (exists($multis->{'*'})) {
      if (defined($multis->{'*'})) {
        $cgi{$name} = exists($cgi{$name}) ? "$cgi{$name}$multis->{'*'}$value" : $value;
      } else {
        push @{$cgi{$name}}, $value;
      }
    } elsif (exists($singles->{'*'})) {
      die("parameter '$name' set multiple times\n") if exists $cgi{$name};
      $cgi{$name} = $value;
    } else {
      $unknown{$name} = 1;
    }
  }
  die("unknown parameter '".join("', '", sort keys %unknown)."'\n") if %unknown;
  return \%cgi;
}

# return only the singles from a query
sub parse_cgi_singles {
  my ($req) = @_;
  my %cgi;
  for my $qu (split('&', $req->{'query'})) {
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
  delete $cgi{$_} for grep {!defined($cgi{$_})} keys %cgi;
  return \%cgi;
}

sub compile {
  my ($conf) = @_;
  die("no dispatches configured\n") unless $conf->{'dispatches'};
  my @disps = @{$conf->{'dispatches'}};
  my $verifiers = $conf->{'verifiers'} || {};
  my $callfunction = $conf->{'dispatches_call'};
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
    my $code = '';
    my $code2 = '';
    my $num = 1;
    my @args;
    for my $pp (@p) {
      if ($pp =~ /^\$(.*)$/) {
        my $var = $1;
        my $vartype = $var;
	($var, $vartype) = ($1, $2) if $var =~ /^(.*):(.*)/;
        die("no verifier for $vartype\n") unless $vartype eq '' || $verifiers->{$vartype};
        $pp = "([^\\/]*)";
        $code .= "\$cgi->{'$var'} = \$$num;\n";
        $code2 .= "\$verifiers->{'$vartype'}->(\$cgi->{'$var'});\n" if $vartype ne '';
	push @args, $var;
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
    for my $pp (@cgis) {
      my ($arg, $qual) = (0, '{1}');
      $arg = 1 if $pp =~ s/^\$//;
      $qual = $1 if $pp =~ s/([+*?])$//;
      my $var = $pp;
      if ($var =~ /^(.*)=(.*)$/) {
	$cgisingles ||= {};
	$cgisingles->{$1} = $2;
	$singles .= ", '$1' => undef";
	next;
      }
      my $vartype = $var;
      ($var, $vartype) = ($1, $2) if $var =~ /^(.*):(.*)/;
      die("no verifier for $vartype\n") unless $vartype eq '' || $verifiers->{$vartype};
      $code2 .= "die(\"parameter '$var' is missing\\n\") unless exists \$cgi->{'$var'};\n" if $qual ne '*' && $qual ne '?';
      if ($qual eq '+' || $qual eq '*') {
	$multis .= ", '$var' => undef";
        $code2 .= "\$verifiers->{'$vartype'}->(\$_) for \@{\$cgi->{'$var'} || []};\n" if $vartype ne '';
      } else {
	$singles .= ", '$var' => undef";
        $code2 .= "\$verifiers->{'$vartype'}->(\$cgi->{'$var'}) if exists \$cgi->{'$var'};\n" if $vartype ne '';
      }
      push @args, $var if $arg;
    }
    $multis = substr($multis, 2) if $multis;
    $singles = substr($singles, 2) if $singles;
    $code = "my \$cgi = parse_cgi(\$req, {$multis}, {$singles});\n$code";
    $code2 .= "my \@args;\n";
    $code2 .= "push \@args, \$cgi->{'$_'};\n" for @args;
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
  $conf->{'compiled_dispatches'} = \@out;
}

sub dispatch {
  my ($conf, $req) = @_;
  my $disps = $conf->{'compiled_dispatches'};
  if (!$disps) {
    die("500 no dispatches configured\n") unless $conf->{'dispatches'};
    die("500 dispatches are not compiled\n");
  }
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
      die("500 authorize method is not defined\n") unless $conf->{'authorize'};
      my @r = $conf->{'authorize'}->($conf, $req, $auth);
      return @r if @r;
    }
    return $f->($conf, $req);
  }
  die("400 unknown request: $path\n");
}

1;

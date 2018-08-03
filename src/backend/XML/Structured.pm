
# the newline is intended to avoid the provides in the package
# of this embedded modul
package
  XML::Structured;

use vars qw($VERSION @ISA @EXPORT);

require Exporter;
@ISA               = qw(Exporter);
@EXPORT            = qw(XMLin XMLinfile XMLout);
$VERSION           = '1.1';

use Encode;

use strict;

our $bytes;

sub import {
  $bytes = 1 if grep {$_ eq ':bytes'} @_;
  __PACKAGE__->export_to_level(1, grep {$_ ne ':bytes'} @_);
}

sub _workin {
  my ($how, $out, $ain, @in) = @_;
  my @how = @$how;
  my $am = shift @how;

  my %known = map {ref($_) ? (!@$_ ? () : (ref($_->[0]) ? $_->[0]->[0] : $_->[0] => $_)) : ($_=> $_)} @how;
  for my $a (keys %$ain) {
    die("unknown attribute: $a\n") unless $known{$a};
    if (ref($known{$a})) {
      die("attribute '$a' must be element\n") if @{$known{$a}} > 1 || ref($known{$a}->[0]);
      push @{$out->{$a}}, $ain->{$a};
    } else {
      die("attribute '$a' must be singleton\n") if exists $out->{$a};
      $out->{$a} = $ain->{$a};
      Encode::_utf8_off($out->{$a}) if $bytes;
    }
  }
  while (@in) {
    my ($e, $v) = splice(@in, 0, 2);
    my $ke = $known{$e};
    if ($e eq '0') {
      next if $v =~ /^\s*$/s;
      die("element '$am' contains content\n") unless $known{'_content'};
      Encode::_utf8_off($v) if $bytes;
      $v =~ s/\s+$/ /s;
      $v =~ s/^\s+/ /s;
      if (exists $out->{'_content'}) {
        $out->{'_content'} =~ s/ $//s if $v =~ /^ /s;
        $out->{'_content'} .= $v;
      } else {
        $out->{'_content'} = $v;
      }
      next;
    }
    if (!$ke && $known{''}) {
      $ke = $known{''};
      $v = [{}, $e, $v];
      $e = '';
    }
    die("unknown element: $e\n") unless $ke;
    if (!ref($ke)) {
      push @$v, '0', '' if @$v == 1;
      die("element '$e' contains attributes @{[keys %{$v->[0]}]}\n") if %{$v->[0]};
      die("element '$e' has subelements\n") if $v->[1] ne '0';
      die("element '$e' must be singleton\n") if exists $out->{$e};
      Encode::_utf8_off($v->[2]) if $bytes;
      $out->{$e} = $v->[2];
    } elsif (@$ke == 1 && !ref($ke->[0])) {
      push @$v, '0', '' if @$v == 1;
      die("element '$e' contains attributes\n") if %{$v->[0]};
      die("element '$e' has subelements\n") if $v->[1] ne '0';
      Encode::_utf8_off($v->[2]) if $bytes;
      push @{$out->{$e}}, $v->[2];
    } else {
      if (@$ke == 1) {
	push @{$out->{$e}}, {};
	_workin($ke->[0], $out->{$e}->[-1], @$v);
      } else {
        die("element '$e' must be singleton\n") if exists $out->{$e};
        $out->{$e} = {};
        _workin($ke, $out->{$e}, @$v);
      }
    }
  }
  if (exists $out->{'_content'}) {
    $out->{'_content'} =~ s/^ //s;
    $out->{'_content'} =~ s/ $//s;
  }
}

sub _escape {
  my ($d) = @_;
  $d =~ s/&/&amp;/sg;
  $d =~ s/</&lt;/sg;
  $d =~ s/>/&gt;/sg;
  $d =~ s/"/&quot;/sg;
  return $d;
}

sub _workout {
  my ($how, $d, $indent) = @_;
  my @how = @$how;
  my $am = _escape(shift @how);
  my $ret = "$indent<$am";
  my $inelem;
  my %d2 = %$d;
  my $gotel = 0;
  if ($am eq '') {
    $ret = '';
    $gotel = $inelem = 1;
    $indent = substr($indent, 2);
  }
  for my $e (@how) {
    if (!$inelem && !ref($e) && $e ne '_content') {
      next unless exists $d2{$e};
      $ret .= _escape(" $e=").'"'._escape($d2{$e}).'"';
      delete $d2{$e};
      next;
    }
    $inelem = 1;
    next if ref($e) && !@$e;	# magic inelem marker
    my $en = $e;
    $en = $en->[0] if ref($en);
    $en = $en->[0] if ref($en);
    next unless exists $d2{$en};
    my $ee = _escape($en);
    if (!ref($e) && $e eq '_content' && !$gotel) {
      $gotel = 2;	# special marker to strip indent
      $ret .= ">"._escape($d2{$e})."\n";
      delete $d2{$e};
      next;
    }
    $ret .= ">\n" unless $gotel;
    $gotel = 1;
    if (!ref($e)) {
      die("'$e' must be scalar\n") if ref($d2{$e});
      if ($e eq '_content') {
	my $c = $d2{$e};
        $ret .= "$indent  "._escape("$c\n");
        delete $d2{$e};
        next;
      }
      if (defined($d2{$e})) {
        $ret .= "$indent  <$ee>"._escape($d2{$e})."</$ee>\n";
      } else {
        $ret .= "$indent  <$ee/>\n";
      }
      delete $d2{$e};
      next;
    } elsif (@$e == 1 && !ref($e->[0])) {
      die("'$en' must be array\n") unless UNIVERSAL::isa($d2{$en}, 'ARRAY');
      for my $se (@{$d2{$en}}) {
        $ret .= "$indent  <$ee>"._escape($se)."</$ee>\n";
      }
      delete $d2{$en};
    } elsif (@$e == 1) {
      die("'$en' must be array\n") unless UNIVERSAL::isa($d2{$en}, 'ARRAY');
      for my $se (@{$d2{$en}}) {
        die("'$en' must be array of hashes\n") unless UNIVERSAL::isa($se, 'HASH');
	$ret .= _workout($e->[0], $se, "$indent  ");
      }
      delete $d2{$en};
    } else {
      die("'$en' must be hash\n") unless UNIVERSAL::isa($d2{$en}, 'HASH');
      $ret .= _workout($e, $d2{$en}, "$indent  ");
      delete $d2{$en};
    }
  }
  die("excess hash entries: ".join(', ', sort keys %d2)."\n") if %d2;
  if ($gotel == 2 && $ret =~ s/\n$//s) {
    $ret .= "</$am>\n" unless $am eq '';
  } elsif ($gotel) {
    $ret .= "$indent</$am>\n" unless $am eq '';
  } else {
    $ret .= " />\n";
  }
  return $ret;
}

package XML::Structured::saxparser;

sub new {
  return bless [];
}

sub start_document {
  my ($self) = @_;
  $self->[0] = [];
}

sub start_element {
  my ($self, $e) = @_;
  my %as = map {$_->{'Name'} => $_->{'Value'}} values %{$e->{'Attributes'} || {}};
  push @{$self->[0]}, $e->{'Name'}, [ $self->[0], \%as ];
  $self->[0] = $self->[0]->[-1];
}

sub end_element {
  my ($self) = @_;
  $self->[0] = shift @{$self->[0]};
}

sub characters {
  my ($self, $c)  = @_;

  my $cl = $self->[0];
  if (@$cl > 2 && $cl->[-2] eq '0') {
    $cl->[-1] .= $c->{'Data'};
  } else {
    push @$cl, '0' => $c->{'Data'};
  }
}

sub end_document {
  my ($self) = @_;
  return $self->[0];
}

package XML::Structured;

my $xmlinparser;

sub _xmlparser {
  my ($str) = @_;
  my $p = new XML::Parser(Style => 'Tree');
  return $p->parse($str);
}

sub _saxparser {
  my ($str) = @_;
  my $handler = new XML::Structured::saxparser;
  my $sp = XML::SAX::ParserFactory->parser('Handler' => $handler);
  if (ref(\$str) eq 'GLOB' || UNIVERSAL::isa($str, 'IO::Handle')) {
    return $sp->parse_file($str);
  }
  return $sp->parse_string($str);
}

sub _chooseparser {
  eval { require XML::SAX; };
  my $saxok;
  if (!$@) {
    $saxok = 1;
    my $parsers = XML::SAX->parsers();
    return \&_saxparser if $parsers && @$parsers && (@$parsers > 1 || $parsers->[0]->{'Name'} ne 'XML::SAX::PurePerl');
  }
  eval { require XML::Parser; };
  return \&_xmlparser unless $@;
  return \&_saxparser if $saxok;
  die("XML::Structured needs either XML::SAX or XML::Parser\n");
}

sub XMLin {
  my ($dtd, $str) = @_;
  $xmlinparser = _chooseparser() unless defined $xmlinparser;
  my $d = $xmlinparser->($str);
  my $out = {};
  $d = ['', [{}, @$d]] if $dtd->[0] eq '';
  die("document element must be '$dtd->[0]', was '$d->[0]'\n") if $d->[0] ne $dtd->[0];
  _workin($dtd, $out, @{$d->[1]});
  return $out;
}

sub XMLinfile {
  my ($dtd, $fn) = @_;
  local *F;
  open(F, '<', $fn) || die("$fn: $!\n");
  my $out = XMLin($dtd, *F);
  close F;
  return $out;
}

sub XMLout {
  my ($dtd, $d) = @_;
  die("parameter is not a hash\n") unless UNIVERSAL::isa($d, 'HASH');
  if ($dtd->[0] eq '') {
    die("excess hash elements\n") if keys %$d > 1;
    for my $el (@$dtd) {
      return _workout($el, $d->{$el->[0]}, '') if ref($el) && $d->{$el->[0]};
    }
    die("no match for alternative\n");
  }
  return _workout($dtd, $d, '');
}

1;

__END__

=head1 NAME

XML::Structured - simple conversion API from XML to perl structures and back

=head1 SYNOPSIS

    use XML::Structured;

    $dtd = [
        'element' =>
            'attribute1',
            'attribute2',
            [],
            'element1',
            [ 'element2' ],
            [ 'element3' =>
                ...
            ],
            [[ 'element4' =>
                ...
            ]],
    ];

    $hashref = XMLin($dtd, $xmlstring);
    $hashref = XMLinfile($dtd, $filename_or_glob);
    $xmlstring = XMLout($dtd, $hashref);

=head1 DESCRIPTION

The XML::Structured module provides a way to convert xml data into
a predefined perl data structure and back to xml. Unlike with modules
like XML::Simple it is an error if the xml data does not match
the provided skeleton (the "dtd"). Another advantage is that the
order of the attributes and elements is taken from the dtd when
converting back to xml.

=head2 XMLin()

The XMLin() function takes the dtd and a string as arguments and
returns a hash reference containing the data.

=head2 XMLinfile()

This function works like C<XMLin()>, but takes a filename or a
file descriptor glob as second argument.

=head2 XMLout()

C<XMLout()> provides the reverse operation to C<XMLin()>, it takes
a dtd and a hash reference as arguments and returns an XML string.

=head1 The DTD

The dtd parameter specifies the structure of the allowed xml data.
It consists of nested perl arrays.

=head2 simple attributes and elements

The very simple example for a dtd is:

    $dtd = [ 'user' =>
                 'login',
                 'password',
           ];

This dtd will accept/create XML like:

    <user login="foo" password="bar" />

XMLin doesn't care if "login" or "password" are attributes or
elements, so

    <user>
      <login>foo</login>
      <password>bar</password>
    </user>

is also valid input (but doesn't get re-created by C<XMLout()>).

=head2 multiple elements of the same name

If an element may appear multiple times, it must be declared as
an array in the dtd:

    $dtd = [ 'user' =>
                 'login',
                 [ 'favorite_fruits' ],
           ];

XMLin will create an array reference as value in this case, even if
the xml data contains only one element. Valid XML looks like:

    <user login="foo">
      <favorite_fruits>apple</favorite_fruits>
      <favorite_fruits>peach</favorite_fruits>
    </user>

As attributes may not appear multiple times, XMLout will create
elements for this case. Note also that all attributes must come
before the first element, thus the first array in the dtd ends
the attribute list. As an example, the following dtd

    $dtd = [ 'user' =>
                 'login',
                 [ 'favorite_fruits' ],
                 'password',
           ];

will create xml like:

    <user login="foo">
      <favorite_fruits>apple</favorite_fruits>
      <favorite_fruits>peach</favorite_fruits>
      <password>bar</password>
    </user>

"login" is translated to an attribute and "password" to an element.

You can use an empty array reference to force the end of the attribute
list, e.g.:

    $dtd = [ 'user' =>
                 [],
                 'login',
                 'password',
           ];

will translate to

    <user>
      <login>foo</login>
      <password>bar</password>
    </user>

instead of

    <user login="foo" password="bar" />

=head2 sub-elements

sub-elements are elements that also contain attributes or other
elements. They are specified in the dtd as arrays with more than
one element. Here is an example:

    $dtd = [ 'user' =>
                 'login',
                 [ 'address' =>
                     'street',
                     'city',
                 ],
           ];

Valid xml for this dtd looks like:

    <user login="foo">
      <address street="broadway 7" city="new york" />
    </user>

It is sometimes useful to specify such dtds in multiple steps:

    $addressdtd = [ 'address' =>
                         'street',
                         'city',
                  ];

    $dtd = [ 'user' =>
                 'login',
                 $addressdtd,
           ];

=head2 multiple sub-elements with the same name

As with simple elements, one can allow sub-elements to occur multiple
times. C<XMLin()> creates an array of hash references in this case.
The dtd specification uses an array reference to an array for this
case, for example:

    $dtd = [ 'user' =>
                 'login',
                 [[ 'address' =>
                     'street',
                     'city',
                 ]],
           ];
Or, with the $addressdtd definition used in the previous example:

    $dtd = [ 'user' =>
                 'login',
                 [ $addressdtd ],
           ];

Accepted XML is:

    <user login="foo">
      <address street="broadway 7" city="new york" />
      <address street="rural road 12" city="tempe" />
    </user>

=head2 the _content pseudo-element

All of the non-whitespace parts between elements get collected
into a single "_content" element. As example,

    <user login="foo">
      <address street="broadway 7" city="new york"/>hello
      <address street="rural road 12" city="tempe"/>world
    </user>

would set the _content element to C<hello world> (the dtd must allow
a _content element, of course). If the dtd is

    $dtd = [ 'user' =>
                 'login',
                 [ $addressdtd ],
                 '_content',
           ];

the xml string created by XMLout() will be:

    <user login="foo">
      <address street="broadway 7" city="new york" />
      <address street="rural road 12" city="tempe" />
      hello world    
    </user>

The exact input cannot be re-created, as the positions and the
fragmentation of the content data is lost.

=head1 SEE ALSO

B<XML::Structured> requires either L<XML::Parser> or L<XML::SAX>.

=head1 COPYRIGHT 

Copyright 2006 Michael Schroeder E<lt>mls@suse.deE<gt>

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. 

=cut


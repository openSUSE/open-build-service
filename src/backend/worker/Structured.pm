
package XML::Structured;

use vars qw($VERSION @ISA @EXPORT);

require Exporter;
@ISA               = qw(Exporter);
@EXPORT            = qw(XMLin XMLinfile XMLout XMLoutfile);
$VERSION           = '1.3';

use Encode;

use strict;

our $bytes = 0;
our $pureperl;
our $preferred_parser;
our $force_preferred_parser;

if (!$pureperl) {
  require XSLoader;
  eval { XSLoader::load('XML::Structured', $VERSION) };
  $pureperl = 1 if $@;
}

if ($pureperl) {
  *_addescaped = sub ($$) { $_[0] .= _escape($_[1]) };
  *_addescaped3 = sub ($$$$) { $_[0] .= $_[1] . _escape($_[2]). $_[3] };
}

sub import {
  $bytes = 1 if grep {$_ eq ':bytes'} @_;
  if (grep {$_ eq ':pureperl'} @_) {
    if (!$pureperl) {
      *_addescaped = sub ($$) { $_[0] .= _escape($_[1]) };
      *_addescaped3 = sub ($$$$) { $_[0] .= $_[1] . _escape($_[2]). $_[3] };
    }
    $pureperl = 1;
  }
  __PACKAGE__->export_to_level(1, grep {$_ ne ':bytes' && $_ ne ':pureperl'} @_);
}

sub _escape {
  my $d = $_[0];
  Encode::_utf8_off($d);
  $d =~ s/&/&amp;/sg;
  $d =~ s/</&lt;/sg;
  $d =~ s/>/&gt;/sg;
  $d =~ s/"/&quot;/sg;
  $d =~ tr/[\000-\010\013\014\016-\037]//d;	# illegal xml
  return $d unless $d =~ /[\200-\377]/;		# common case
  eval {
    Encode::_utf8_on($d);
    $d = encode('UTF-8', $d, Encode::FB_CROAK);
  };
  if ($@) {
    eval {
      Encode::_utf8_off($d);
      $d = encode('UTF-8', $d, Encode::FB_CROAK);
    };
    if ($@) {
      Encode::_utf8_on($d);
      $d = encode('UTF-8', $d, Encode::FB_XMLCREF);
    }
  }
  Encode::_utf8_off($d);
  return $d; 
}

sub _workout {
  my ($how, $d, $indent, $fh) = @_;
  my @how = @$how;
  my $am = shift @how;
  my $ret = $indent;
  _addescaped3($ret, '<', $am, '');
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
      _addescaped($ret, " $e");
      _addescaped3($ret, '="', $d2{$e}, '"');
      delete $d2{$e};
      next;
    }
    $inelem = 1;
    next if ref($e) && !@$e;	# magic inelem marker
    my $en = $e;
    $en = $en->[0] if ref($en);
    $en = $en->[0] if ref($en);
    next unless exists $d2{$en};
    my $ee = '';
    _addescaped($ee, $en);
    if (!ref($e) && $e eq '_content' && !$gotel) {
      $gotel = 2;	# special marker to strip indent
      _addescaped3($ret, '>', $d2{$e}, "\n");
      delete $d2{$e};
      next;
    }
    $ret .= ">\n" unless $gotel;
    $gotel = 1;
    if (!ref($e)) {
      die("'$e' must be scalar\n") if ref($d2{$e});
      if ($e eq '_content') {
	my $c = $d2{$e};
        _addescaped3($ret, "$indent  ", $c, "\n");
        delete $d2{$e};
        next;
      }
      if (defined($d2{$e})) {
        _addescaped3($ret, "$indent  <$ee>", $d2{$e}, "</$ee>\n");
      } else {
        $ret .= "$indent  <$ee/>\n";
      }
      delete $d2{$e};
      next;
    } elsif (@$e == 1 && !ref($e->[0])) {
      die("'$en' must be array\n") unless UNIVERSAL::isa($d2{$en}, 'ARRAY');
      for my $se (@{$d2{$en}}) {
	_addescaped3($ret, "$indent  <$ee>", $se, "</$ee>\n");
      }
      delete $d2{$en};
    } elsif (@$e == 1) {
      die("'$en' must be array\n") unless UNIVERSAL::isa($d2{$en}, 'ARRAY');
      if ($fh) {
        print $fh $ret or die("XMLout: write error\n");
        $ret = '';
      }
      for my $se (@{$d2{$en}}) {
        die("'$en' must be array of hashes\n") unless UNIVERSAL::isa($se, 'HASH');
	$ret .= _workout($e->[0], $se, "$indent  ", $fh);
      }
      delete $d2{$en};
    } else {
      die("'$en' must be hash\n") unless UNIVERSAL::isa($d2{$en}, 'HASH');
      if ($fh) {
        print $fh $ret or die("XMLout: write error\n");
        $ret = '';
      }
      $ret .= _workout($e, $d2{$en}, "$indent  ", $fh);
      delete $d2{$en};
    }
  }
  die("excess hash entries: ".join(', ', sort keys %d2)."\n") if %d2;
  if ($gotel == 2 && $ret =~ s/\n$//s) {
    _addescaped3($ret, '</', $am, ">\n") unless $am eq '';
  } elsif ($gotel) {
    _addescaped3($ret, "$indent</", $am, ">\n") unless $am eq '';
  } else {
    $ret .= "/>\n";
  }
  if ($fh) {
    print $fh $ret or die("XMLout: write error\n");
    return '';
  }
  return $ret;
}

sub _handle_start_slow {
  my ($p, $e, @a) = @_;

  if (ref($e)) {
    # deal with SAX
    ($e, @a) = ($e->{'Name'}, map {$_->{'Name'} => $_->{'Value'}} values %{$e->{'Attributes'} || {}});
  }
  my ($known, $out) = @{$p->{'work'}}[-3, -2];
  my $chr;

  my $ke = $known->{$e};
  if (!defined($ke)) {
    $ke = $known->{''};
    die("unknown element '$e'\n") unless defined $ke;
    die("bad dtd\n") unless ref $ke;
    my $ed = {};
    if (!$ke->[0]) {
      die("element '' must be singleton\n") if exists $out->{''};
      $out->{''} = $ed;
    } else {
      push @{$out->{''}}, $ed;
    }
    $out = $ed;
    $known= $ke->[1];
    $ke = $known->{$e};
    die("unknown element '$e'\n") unless defined $ke;
  }
  if (!ref($ke)) {
    die("element '$e' contains attributes @{[keys %{{@a}}]}\n") if @a;
    if (!$ke) {
      die("element '$e' must be singleton\n") if exists $out->{$e};
      $out->{$e} = '';
      $chr = \$out->{$e};
    } else {
      push @{$out->{$e}}, '';
      $chr = \$out->{$e}->[-1];
    }
    Encode::_utf8_on($$chr) unless $bytes;
    push @{$p->{'work'}}, {}, undef, $chr;
  } else {
    my $ed = {};
    if (!$ke->[0]) {
      die("element '$e' must be singleton\n") if exists $out->{$e};
      $out->{$e} = $ed;
    } else {
      push @{$out->{$e}}, $ed;
    }
    $known= $ke->[1];
    $out = $ed;
    while (@a > 1) {
      my ($a, $av) = splice(@a, 0, 2);
      die("element '$e' contains unknown attribute '$a'\n") unless defined $known->{$a};
      die("attribute '$a' in '$e' must be element\n") if ref($known->{$a});
      Encode::_utf8_off($av) if $bytes;
      if ($known->{$a}) {
        push @{$out->{$a}}, $av
      } else {
        die("attribute '$a' in '$e' must be singleton\n") if exists $out->{$a};
        $out->{$a} = $av
      }
    }
    if (defined $known->{'_content'}) {
      $out->{'_content'} = '';
      Encode::_utf8_on($out->{'_content'}) unless $bytes;
      $chr = \$out->{'_content'};
    }
    push @{$p->{'work'}}, $known, $out, $chr;
  }
}

sub _handle_end_slow {
  my ($p) = @_;
  my (undef, $out, $chr) = splice(@{$p->{'work'}}, -3);
  if ($out && $chr) {
    $$chr =~ s/^[ \t\r\n]+//s;
    $$chr =~ s/[ \t\r\n]+$//s;
    delete $out->{'_content'} if $$chr eq '';
  }
}

sub _handle_char_slow {
  my ($p, $str) = @_;
  $str = $str->{'Data'} if ref($str);	# deal with SAX
  Encode::_utf8_off($str) if $bytes;
  my $cp = $p->{'work'}->[-1];
  if (!defined $cp) {
    return if $str !~ /[^ \t\r\n]/;
    my $known = $p->{'work'}->[-3];
    die("element '$known->{'.'}' contains content\n");
  }
  $$cp .= $str;
}

sub _toknown {
  my ($me, @dtd) = @_;
  my %known = map {ref($_) ? (!@$_ ? () : (ref($_->[0]) ? $_->[0]->[0] : $_->[0] => $_)) : ($_=> $_)} @dtd;
  for my $v (values %known) {
    if (!ref($v)) {
      $v = 0;
    } elsif (@$v == 1 && !ref($v->[0])) {
      $v = 1;
    } elsif (@$v == 1) {
      $v = [1, _toknown(@{$v->[0]}) ];
    } else {
      $v = [0, _toknown(@$v) ];
    }
  }
  $known{'.'} = $me;
  return \%known;
}


package XML::Structured::saxparser;

sub new { bless {} }
sub start_element;
sub end_element;
sub characters;

*start_element = *XML::Structured::_handle_start;
*end_element = *XML::Structured::_handle_end;
*characters = *XML::Structured::_handle_char;

package XML::Structured::saxparser_pureperl;

sub new { bless {} }
sub start_element;
sub end_element;
sub characters;

*start_element = *XML::Structured::_handle_start_slow;
*end_element = *XML::Structured::_handle_end_slow;
*characters = *XML::Structured::_handle_char_slow;

package XML::Structured;

my $xmlinparser;

sub _xmlparser {
  my ($dtd, $str) = @_;
  my $p;
  my $hashsalt = int(rand(2**32));
  if ($pureperl) {
    $p = new XML::Parser(Style => 'Subs', 'Handlers' => {
      'Start' => \&_handle_start_slow,
      'End'   => \&_handle_end_slow,
      'Char'  => \&_handle_char_slow,
    }, 'HashSalt' => $hashsalt);
  } else {
    $p = new XML::Parser(Style => 'Subs', 'Handlers' => {
      'Start' => \&_handle_start,
      'End'   => \&_handle_end,
      'Char'  => \&_handle_char,
    }, 'HashSalt' => $hashsalt);
  }
  $p->setHandlers('ExternEnt' => sub {undef});
  my $ret = {};
  $p->{'work'} = [ {$dtd->[0] => [ 0, _toknown(@$dtd) ]}, $ret, undef ];
  $p->parse($str);
  return $ret->{$dtd->[0]};
}

sub _saxparser {
  my ($dtd, $str) = @_;
  my $p;
  if ($pureperl) {
    $p = new XML::Structured::saxparser_pureperl;
  } else {
    $p = new XML::Structured::saxparser;
  }
  my $ret = {};
  $p->{'work'} = [ {$dtd->[0] => [ 0, _toknown(@$dtd) ]}, $ret, undef ];

  my $sp = XML::SAX::ParserFactory->parser('Handler' => $p, 'LibParser' => 'FOO');
  if (ref($sp) eq 'XML::LibXML::SAX') {
    $sp->{ParserOptions}->{LibParser} = XML::LibXML->new(no_network => 1, expand_xinclude => 0, expand_entities => 0, load_ext_dtd => 0);
  }
  if (ref(\$str) eq 'GLOB' || UNIVERSAL::isa($str, 'IO::Handle')) {
    $sp->parse_file($str);
  } else {
    $sp->parse_string($str);
  }
  return $ret->{$dtd->[0]};
}

sub _chooseparser {
  if ($preferred_parser) {
    my $module = $preferred_parser;
    $module =~ s/::/\//g;
    eval {
      require XML::SAX if $preferred_parser ne 'XML::Parser';
      require "$module.pm";
      $XML::SAX::ParserPackage = $preferred_parser if $preferred_parser ne 'XML::Parser' && $preferred_parser ne 'XML::SAX';
    };
    return $preferred_parser eq 'XML::Parser' ? \&_xmlparser : \&_saxparser unless $@;
    die($@) if $force_preferred_parser;
  }
  eval { require XML::Parser; };
  return \&_xmlparser unless $@;
  eval { require XML::SAX };
  if (!$@) {
    eval { require XML::LibXML::SAX; $XML::SAX::ParserPackage = 'XML::LibXML::SAX' } unless $XML::SAX::ParserPackage;
    return \&_saxparser;
  }
  die("XML::Structured needs either XML::SAX or XML::Parser\n");
}

sub XMLin {
  my ($dtd, $str) = @_;
  $xmlinparser = _chooseparser() unless defined $xmlinparser;
  _setbytes($bytes) unless $pureperl;
  return $xmlinparser->($dtd, $str);
}

sub XMLinfile {
  my ($dtd, $fn) = @_;
  if (ref($fn)) {
    return XMLin($dtd, $fn) if ref($fn) eq 'GLOB' || UNIVERSAL::isa($fn, 'IO::Handle');
  }
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

# XXX: should stream into the io handle
sub _XMLout_file {
  my ($dtd, $d, $fh) = @_;
  if ($dtd->[0] eq '') {
    die("excess hash elements\n") if keys %$d > 1;
    for my $el (@$dtd) {
      next unless ref($el) && $d->{$el->[0]};
      _workout($el, $d->{$el->[0]}, '', $fh);
      $fh->flush() or die("XMLout: write error: $!\n");
      return 1;
    }
    die("no match for alternative\n");
  }
  _workout($dtd, $d, '', $fh);
  $fh->flush() or die("XMLout: write error: $!\n");
  return 1;
}

sub XMLoutfile {
  my ($dtd, $d, $fn) = @_;
  die("parameter is not a hash\n") unless UNIVERSAL::isa($d, 'HASH');
  if (ref($fn)) {
    return _XMLout_file($dtd, $d, $fn) if ref($fn) eq 'GLOB' || UNIVERSAL::isa($fn, 'IO::Handle');
  }
  local *F;
  open(F, '>', $fn) || die("$fn: $!\n");
  _XMLout_file($dtd, $d, \*F);
  close(F) || die("$fn close: $!\n");
  return 1;
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
    $hashref = XMLinfile($dtd, $filename_or_handle);
    $xmlstring = XMLout($dtd, $hashref);
    XMLoutfile($dtd, $hashref, $filename_or_handle);

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
file handle as second argument.

=head2 XMLout()

C<XMLout()> provides the reverse operation to C<XMLin()>, it takes
a dtd and a hash reference as arguments and returns an XML string.

=head2 XMLoutfile()
This function works like C<XMLout()>, but takes a filename or a
file handle as third argument.

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

would set the _content element to C<hello\n  world> (the dtd must allow
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
      hello
      world    
    </user>

The exact input cannot be re-created, as the positions and the
fragmentation of the content data is lost.

=head1 SEE ALSO

B<XML::Structured> requires either L<XML::Parser> or L<XML::SAX>.

=head1 COPYRIGHT 

Copyright 2006-2019 Michael Schroeder E<lt>mls@suse.deE<gt>

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. 

=cut


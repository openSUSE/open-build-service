#
# Copyright (c) 2008 Adrian Schroeter, Novell Inc.
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
# XML templates for the BuildService. See XML/Structured.
#

package BSProductXML;

use strict;
use Data::Dumper;
use XML::Structured ':bytes';

# 
# an explained example entry of this file
#
#our $pack = [             creates <package name="" project=""> space
#    'package' =>          
#	'name',
#	'project',
#	[],                before the [] all strings become attributes to <package>
#       'title',           from here on all strings become children like <title> </title>
#       'description',
#       [[ 'person' =>     creates <person> children, the [[ ]] syntax allows any number of them including zero
#           'role',        again role and userid attributes, both are required
#           'userid',    
#       ]],                this block describes a <person role="defeatist" userid="statler" /> construct
# 	@flags,            copies in the block of possible flag definitions
#       [ $repo ],         refers to the repository construct and allows again any number of them (0-X)
#];                        closes the <package> child with </package>

our $group = [
    'group' =>
          'name',
          'version',
          'release',
          [],
          [[ 'include' => 'group' ]],
          [ 'pattern' =>
            'ordernumber',
            [],
            [ 'name' => '_content' ],
            [ 'icon' => '_content' ],
            [ 'visible' => '_content' ],
            [ 'category' => 'lang', [], '_content' ],
            [ 'summary' => 'lang', [], '_content' ],
            [ 'description' => 'lang', [], '_content' ],
            [ 'relationships' =>
               [],
               [[ 'pattern' => 'name', 'relationship' ]],
            ],
          ],
          [[ 'packagelist' =>
             'relationship',
             'id',
             [],
             [[ 'package' => 'name',
#'forcearch', 'addarch', 'removearch', 'onlyarch', 'source', 'script', 'medium', 'priority'
                [[ 'conditional' => 'name' ]],
                [[ 'plattform' => 'excludearch', 'onlyarch', 'arch', 'soruce_arch', 'replace_native' ]],
             ]],
          ]],
];

# Defines a single product, will be used in installed system to indentify it 
our $product = [
           'product' =>
           'id',
           [],
           'vendor',
           'name',
           'version',
           'release',
           [[ 'register' => 
              [],
              'target',
              'release',
              'flavor',
           ]],
           'updaterepokey',
           [[ 'summary' =>
              'lang',
              [],
              '_content'
           ]],
           [[ 'description' =>
              'lang',
              [],
              '_content'
           ]],
           [ 'linguas' =>
             [],
             [[ 'lang' => '_content' ]],
           ],
           [ 'urls' =>
             [],
             [[ 'url' => 
                'name',
                [],
                '_content',
             ]],
           ],
           [ 'buildconfig' =>
             'producttheme',
             'betaversion',
             [ 'linguas' =>
               [],
               [[ 'lang' => '_content' ]],
             ],
             'allowresolving',
             'packagemanager',
           ],
           [ 'installconfig' =>
              'defaultlang',
              'datadir',
              'descrdir',
              [ 'references' => 'name', 'version' ],
              'distribution',
           ],
           [ 'runtimeconfig' =>
              'allowresolving',
           ],
];

# Complete product definition. Defines how a media is setup
# and which products are available.
our $productdesc = [
    'productdefinition' =>
      'xmlns:xi',
      'schemeversion',
      [],
      [ 'products' =>
        [ $product ],
      ],
      [ 'conditionals' =>
        [[ 'conditional' =>
           'name',
           [ 'platform' => 
             'onlyarch',
             'arch',
             'baselibs_arch',
           ],
           [ 'media' => 
             'number',
           ],
        ]],
      ],
      [ 'repositories' =>
        [[ 'repository' =>
           'name',
           'priority',
           'path',
        ]],
      ],
      [ 'mediasets' =>
         [[ 'media' =>
            'type',
            'product',
            'name',
            'sourcemedia',
            'create_pattern',
            'use_recommended',
            'use_suggested',
            'use_required',
            [ 'mediaarchs' =>
              [[ 'archset' => 
                   'basearch',
                   [],
                   [[ 'arch' => '_content' ]],
              ]],
            ],
            [[ 'use' =>
               'group',
               'use_recommended',
               'use_suggested',
               'use_required',
               'create_pattern',
               [[ 'package' => 'name', 'relationship' ]],
               [[ 'include' => 'group', 'relationship' ]],
            ]],
            [ 'metadata' =>
               [[ 'package' => 'name', 'medium', 'removearch' ]],
               [[ 'file' => 'name' ]],
            ],
         ]],
      ],
      [ $group ],
];

sub mergexmlfiles {
  my ($absfile) = @_;

  my $data;
  my $dir;
  if ($absfile =~ /(.*\/)(.+)$/) {
    $dir = $1;
  } else {
    $dir = './';
  }

  local *F;
  if (!open(F, '<', $absfile)) {
    return undef;
  }
  my $str = '';
  1 while sysread(F, $str, 8192, length($str));
  close F;

  while ($str =~ /<xi:include href="(.+?)".*?>/s) {
     my $ref = $1;
     if ($ref =~ /^obs:.+/) {
       print "ERROR: obs: references are not handled yet ! \n";
       return undef;
     } else {
       my $file = "$dir$ref";
       my $replace = mergexmlfiles($file);
       if ( ! $replace ) {
         print "ERROR: Unable to read $file !\n";
         return undef unless $replace;
       }
       $str =~ s/<xi:include href=".+?".*?>/$replace/s;
     }
  }

  return $str;
}

sub readproductxml {
  my ($file, $nonfatal) = @_;

  my $str = mergexmlfiles( $file );
  return undef if ( ! $str );

  return XMLin($productdesc, $str) unless $nonfatal;
  eval { $str = XMLin($productdesc, $str); };
  return $@ ? undef : $str;
}

1;

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
          'relationship',
          'pattern:ordernumber',
          'pattern:category',
          'pattern:icon',
          'pattern:summary',
          'pattern:description',
          'pattern:visible',
          [],
          [[ 'pattern:provides' ]],
          [[ 'include' => 'group' ]],
          [[ 'pattern' =>
             'name',
             'path',
             'relationship',
             'condition',
             'version',
             'flag',
          ]],
          [[ 'conditional' => 'name' ]],
          [[ 'package' =>
             'name',
             [[ 'conditional' => 'name' ]],
             [[ 'plattform' => 'arch', 'source_arch', 'replace_native', 'excludearch', 'onlyarch' ]],
          ]],
];
#  hack:greate cyclic definition!
push @$group, [$group];

our $productdesc = [
    'product' =>
       [ 'general' =>
         [],
         'vendor',
         'name',
         'version',
         'release',
         'update_repo_key',
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
         ],
         [ 'installconfig' =>
            'defaultlang',
         ],
         [ 'runtimeconfig' =>
            'allowresolving',
            'packagemanager',
         ],
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
       [[ 'instrepo' =>
          'name',
          'priority',
          'username',
          'pwd',
          'local',
          [],
          [[ 'source' => 'href' ]],
       ]],
       [ 'mediasets' =>
          [[ 'media' =>
             'type',
             [],
             [[ 'use' =>
                'group',
                'create_pattern',
                'pattern',
                'use_recommended',
                'use_suggested',
                'use_required',
                [[ 'package' => 'name', 'relationship' ]],
                [[ 'include' => 'group', 'relationship' ]],
             ]],
             [[ 'metadata' =>
                [[ 'package' => 'name' ]],
                [[ 'file' => 'name' ]],
             ]],
             [[ 'sourcemedia' => 'disable' ]],
          ]],
       ],
       [ $group ],
       [[ 'xi:include' => 'href' ]],
];

sub mergexmlfiles {
  my ($absfile) = @_;

  my $data;
  $absfile =~ /(.*\/)(.+)$/;
  my $dir = $1;
  my $file = $2;

  local *F;
  if (!open(F, '<', $absfile)) {
    return undef;
  }
  my $str = '';
  1 while sysread(F, $str, 8192, length($str));
  close F;

  while ( $str =~ /.*(<xi:include href="(.+)".*>).*/ ) {
     my $ref = $2;
     if ( $ref =~ /^obs:.+/ ) {
       print "ERROR: obs: references are not handled yet ! \n";
       return undef;
     } else {
       $file = "$dir$ref";
       my $replace = mergexmlfiles( $file );
       return undef if ( ! $replace );
       $str =~ s/.*(<xi:include href="(.+)".*>).*/$replace/;
     };
  };

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

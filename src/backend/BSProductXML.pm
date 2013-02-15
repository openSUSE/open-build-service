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
use File::Basename;
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
          [[ 'conditional' => 'name' ]],
          [[ 'include' => 'group' ]],
          [ 'pattern' =>
            'ordernumber',
            [],
            [ 'name' => '_content' ],
            [ 'icon' => '_content' ],
            [ 'visible' => '_content' ],
            [ 'category' => 'language', [], '_content' ],
            [ 'summary' => 'language', [], '_content' ],
            [ 'description' => 'language', [], '_content' ],
            [ 'relationships' =>
               [],
               [[ 'pattern' => 'name', 'relationship' ]],
            ],
          ],
          [[ 'packagelist' =>
             'relationship',
             'supportstatus',
             'id',
             [],
             [[ 'package' =>
                'name',
                'supportstatus',
                [[ 'conditional' => 'name' ]],
             ]],
          ]],
];

# Defines a single product, will be used in installed system to indentify it 
our $product = [
           'product' =>
           'id',
           'schemeversion',
           [],
           'vendor',
           'name',
           'version',       # shall not be used, if baseversion is used. It is baseversion.patchlevel than.
           'baseversion',
           'patchlevel',
           'migrationtarget',
           'release',
           'arch',
           'productline',
           [ 'register' => 
              [],
              'target',
              'release',
              'flavor',
              [ 'repositories' =>
                [[ 'repository' =>
                   'path',
                ]],
              ], # this is for prod file export only
           ],
           [ 'upgrades' =>
              [[ 'upgrade' =>
                 [],
                 'name',
                 'summary',
                 'repository',
                 'product',
                 'notify',
                 'status',
              ]],
           ],
           'updaterepokey',
           [[ 'summary' =>
              'language',
              [],
              '_content'
           ]],
           [[ 'shortsummary' =>
              'language',
              [],
              '_content'
           ]],
           [[ 'description' =>
              'language',
              [],
              '_content'
           ]],
           [ 'linguas' =>
             [],
             [[ 'language' => '_content' ]],
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
              [],
             'producttheme',
             'betaversion',
             [ 'linguas' =>
               [],
               [[ 'language' => '_content' ]],
             ],
             'allowresolving',
             'packagemanager',
           ],
           [ 'installconfig' =>
              [],
              'defaultlang',
              'datadir',
              'descriptiondir',
              [ 'releasepackage' => 'name', 'flag', 'version', 'release' ],
              'distribution',
              [[ 'obsoletepackage' => '_content' ]],
           ],
           [ 'runtimeconfig' =>
              [],
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
           [[ 'platform' =>
              'excludearch',
              'onlyarch',
              'arch',
              'baselibs_arch',
              'addarch',
              'replace_native'
           ]],
           [ 'media' => 
             'number',
           ],
        ]],
      ],
      [ 'repositories' =>
        [[ 'repository' =>
           'path',
           'build',
           'product_file',
        ]],
      ],
      [ 'archsets' =>
        [[ 'archset' => 
             'name',
             'productarch',
             [],
             [[ 'arch' => '_content' ]],
        ]],
      ],
      [ 'mediasets' =>
         [[ 'media' =>
            'type',
            'product',                 # obsolete, should not be used anymore
            'name',
            'flavor',
            'repo_only',
            'mediastyle',
            'firmware',
            'registration',
            'create_repomd',
            'sourcemedia',
            'debugmedia',
            'create_pattern',
            'ignore_missing_packages',      # may be "true", default for mediastyle 11.3 and before
            'ignore_missing_meta_packages', # may be "true", default for mediastyle 11.3 and before
            'skip_release_package',         # skip adding the release packages to the media
            'run_media_check',
            'run_hybridiso',
            'run_make_listings',
            'use_recommended',
            'use_suggested',
            'use_required',
            'use_undecided', # take all packages, even the ungrouped ones
            'allow_overflow',
            'next_media_in_set',
            'size',
            [[ 'preselected_patterns' => 
               [[ 'pattern' =>
                  'name',
	       ]]
            ]],
            [[ 'archsets' =>
              [[ 'archset' => 
                   'ref',
              ]],
            ]],
            [[ 'use' =>
               'group',
               'use_recommended',
               'use_suggested',
               'use_required',
               'create_pattern',
               [[ 'package' => 'name', 'medium', 'relationship', 'arch', 'addarch' ]],
               [[ 'include' => 'group', 'relationship' ]],
            ]],
            [[ 'productdependency' =>
               'relationship',
               'name',
               'version',
               'patchlevel',
               'release',
               'flavor',
               'flag',
            ]],
            [ 'metadata' =>
               [[ 'package' => 'name', 'medium', 'arch', 'addarch', 'onlyarch', 'removearch' ]],
               [[ 'file' => 'name' ]],
            ],
         ]],
      ],
      [ $group ],
];

sub mergexmlfiles {
  my ($absfile, $seen, $debug) = @_;

  if ($seen->{$absfile}) {
    print "ERROR: cyclic file include ($absfile)!\n";
    return undef;
  }
  my $data;
  my ($dummy, $dir) = fileparse( $absfile );

  local *F;
  if (!open(F, '<', $absfile)) {
    return undef;
  }
  my $str = '';
  1 while sysread(F, $str, 8192, length($str));
  close F;

  # wipe out comments globally
#  $str =~ s/<!--.+?-->//gs;

  if( $debug && open F, ">/tmp/naked.xml" ) {
    print F $str;
    close F;
  }

  while ($str =~ /<xi:include href="(.+?)".*?>/s) {
     my $ref = $1;
     if ($ref =~ /^obs:.+/) {
       print "ERROR: obs: references are not handled yet ! \n";
       return undef;
     } else {
       if ($ref =~ /^\."/ || $ref =~ /\//) {
         print "ERROR: obs: reference to illegal file ! \n";
         return undef;
       }
       my $file = "$dir$ref";
       $seen->{$absfile} = 1;
       my $replace = mergexmlfiles( $file, $seen, $debug );
       delete $seen->{$absfile};
       if ( ! defined $replace ) {
         print "ERROR: Unable to read $file !\n";
         return undef unless $replace;
       }
       # This is a subfile, so wipe out the xml header.
       $replace =~ s/<\?xml .+\?>//;
       $str =~ s/<xi:include href=".+?".*?>/$replace/s;
     }
  }

  if( $debug && open F, ">/tmp/naked_all.xml" ) {
    print F $str;
    close F;
  }

  return $str;
}

sub readproductxml( $$$ ) {
  my ($file, $nonfatal, $debug) = @_;

  my $str = mergexmlfiles( $file, {}, $debug );
  return undef if ( ! $str );

  return XMLin($productdesc, $str) unless $nonfatal;
  eval { $str = XMLin($productdesc, $str); };
  return $@ ? undef : $str;
}

1;

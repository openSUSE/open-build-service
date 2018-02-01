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
# XML templates and parser for the BuildService. See XML/Structured.
#

package BSProductXML;

use strict;
use Data::Dumper;
use BSUtil;

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

# private zypp element definition
our $zypp = [ 'zypp' =>
             'name',
             'alias',
             [],
             'disable', # repo should be added, but not enabled by default
           ],

# Defines a single product, will be used in installed system to indentify it 
our $product = [
           'product' =>
           'id',            # obsolete, do not use anymore
           'schemeversion',
           [],
           'vendor',
           'name',
           'version',       # shall not be used, if baseversion is used. It is baseversion.patchlevel than.
           'baseversion',
           'patchlevel',
           'migrationtarget',
           [ 'predecessor' ],   # former name of product(s) replaced by this.
           'release',
           'endoflife',     # in ISO 8601 format (YYYY-MM-DD), valid for this patchlevel
           'arch',
           'cpeid',         # generated, not for input
           'productline',
           'releasepkgname', # defaults to $name-release
           [ 'codestream' =>
              [],
              'name',          # code stream name, often similar to summary, but may differ on falvours
              'endoflife',     # in ISO 8601 format (YYYY-MM-DD), may need an update to a future patchlevel
           ],
           [ 'register' => 
              [],
              'target',     # distro-target for NCC, only for .prod files since SLE 12
              'release',
              'flavor',

              # following is for support tools
              [ 'pool' =>
                [[ 'repository' =>
                   'project',   # input
                   'name',
                   'medium',
                   'url',       # this conflicts with project/name/medium
                   $zypp,
                   'arch',      # for arch specific definitions
                ]],
              ],
              [ 'updates' =>
                [[ 'distrotarget' =>     # for SMT update service
                   'arch',      # for arch specific definitions
                   [],
                   '_content'
                ]],
                [[ 'repository' =>
                   'project',   # input
                   'name',
                   'repoid',    # output for .prod file
                   'arch',      # for arch specific definitions
                   $zypp,
                ]],
              ],
              [ 'repositories' =>
                [[ 'repository' =>
                   'path',
                ]],
              ], # this is for prod file export only, not used for SLE 12/openSUSE 13.2 media style anymore
           ],
           [ 'repositories' =>
             [[ 'repository' =>
                'type',
                'repoid',
             ]],
           ], # this is for prod file export only since Leap 15
           [ 'upgrades' =>     # to announce service pack releases
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
           'updaterepokey',  # obsolete
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
                'arch',
                [],
                '_content',
             ]],
           ],
           [ 'buildconfig' =>
              [],
             'producttheme',
             'betaversion',
             'mainproduct',
             'create_flavors',
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
           [[ 'productdependency' =>
              'relationship',
              'name',
              'baseversion',
              'patchlevel',
              'release',
              'flavor',
              'flag',
           ]],
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
            'repo_only',                    # do not create iso files
            'drop_repo',                    # remove trees, just having iso files as result
            'mediastyle',
            'firmware',
            'registration',
            'create_repomd', # old format only
            'sourcemedia',
            'debugmedia',
            'separate',
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
            'separate',
            'size',
            'datadir',        # old format only
            'descriptiondir', # old format only
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
            # product dependency got moved to product definition
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

# list of product definitions
our $products = [
   'productlist' =>
      [ $productdesc ],
];

our $productrepositories = [
  'product' =>
    'name',
    [[
      'distrotarget' => 
        'arch', # optional
        [],
        '_content',
    ]],
    [[
      'repository' =>
        'path', # eith path or url is set
        'url',
        'arch', # optional
        [],
        $zypp,
        'debug',  # optional flags
        'update',
    ]],
];
our $productlistrepositories = [
   'productrepositories' =>
      [ $productrepositories ],
];

sub mergexmlfiles {
  my ($dir, $file, $seen, $debug) = @_;

  if ($seen->{$file}) {
    print "ERROR: cyclic file include ($file)!\n";
    return undef;
  }
  my $str = ref($dir) ? $dir->($file) : readstr("$dir/$file", 1);
  return undef unless defined $str;

  writestr("/tmp/naked.xml", undef, $str) if $debug;

  while ($str =~ /<xi:include href="(.+?)".*?>/s) {
    my $ref = $1;
    if ($ref =~ /^obs:.+/) {
      print "ERROR: obs: references are not handled yet!\n";
      return undef;
    }
    if ($ref =~ /^\./ || $ref =~ /\//) {
      print "ERROR: obs: reference to illegal file!\n";
      return undef;
    }
    $seen->{$file} = 1;
    my $replace = mergexmlfiles($dir, $ref, $seen, $debug);
    delete $seen->{$file};
    if (! defined $replace) {
      print "ERROR: Unable to read $ref!\n";
      return undef;
    }
    # This is a subfile, so wipe out the xml header.
    $replace =~ s/<\?xml .+\?>//;
    $str =~ s/<xi:include href=".+?".*?>/$replace/s;
  }
  writestr("/tmp/naked_all.xml", undef, $str) if $debug;
  return $str;
}

sub readproductxml {
  my ($file, $nonfatal, $debug) = @_;
  my $dir = '.';
  if (ref($file)) {
    $dir = $file->[0];
    $file = $file->[1];
  } elsif ($file =~ /^(.*)\/([^\/]*)$/s) {
    $dir = $1;
    $file = $2;
  }
  my $str = mergexmlfiles($dir, $file, {}, $debug);
  return undef unless $str;
  return BSUtil::fromxml($str, $productdesc, $nonfatal);
}

1;

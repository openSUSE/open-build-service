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

package BSKiwiXML;

use strict;

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

our $kiwidesc = [
    'image' =>
	'name',
	'schemeversion', # for kiwi version until 3.74
	'schemaversion', # for kiwi after 3.74
	'displayname',
	[],
      [ 'description' => 
	    'type',
	    [],
	    'author',
	    'contact',
	    'specification',
      ],
      [ 'preferences' =>
	[[ 'type' =>
		'baseroot',
		'bootprofile',
		'bootkernel',
		'bootloader',
		'boottimeout',
		'boot',
		'checkprebuilt',
		'compressed',
		'editbootconfig',
		'editbootinstall',
		'flags',
		'filesystem',
		'firmware',
		'fsmountoptions',
		'fsnocheck',
		'fsreadonly',
		'fsreadwrite',
		'format',
		'hybrid',
		'hybridpersistent',
		'image',
		'installboot',
		'installiso',
		'installstick',
		'luks',
		'kernelcmdline',
		'primary',
		'ec2accountnr',
		'ec2privatekeyfile',
		'ec2certfile',
		'vga',
		'volid',
		'oemconfig',
	      [ 'machine' =>
		    'memory',
		  [ 'vmdisk' =>
			'id',
			'controller'
		  ],
	      ],
	      [ 'size' =>
		    'unit',
		    '_content',
	      ],
		'_content',
	]],
	'version',
      [ 'size' =>
	    'unit',
	    '_content',
      ],
	'bootloader-theme',
	'bootsplash-theme',
	'compressed',
	'defaultbaseroot',
	'defaultdestination',
	'defaultroot',
	'hwclock',
	'packagemanager',
	'rpm-check-signatures',
	'rpm-excludedocs',
	'rpm-force',
	'locale',
	'keytable',
	'oem-home',
	'oem-reboot',
	'oem-recovery',
	'oem-swap',
	'oem-boot-title',
	'timezone',
      ],
      [ 'instsource' =>
	    [],
	  [ 'architectures' => 
	     [[ 'arch' =>
		'id',
		'name',
		'fallback',
	     ]],
	     [[ 'requiredarch' =>
		'ref',
	     ]],
	  ],
	  [ 'productoptions' => 
	     [[ 'productvar' =>
		'name',
		'_content'
	     ]],
	     [[ 'productinfo' =>
		'name',
		'_content'
	     ]],
	     [[ 'productoption' =>
		'name',
		'_content'
	     ]]
	  ],
	 [[ 'instrepo' =>
		'name',
		'priority',
		'username',
		'pwd',
		'local',
		[],
	      [ 'source' =>
		    'path'
	      ],
	 ]],
	  [ 'metadata' =>
	     [[ 'repopackage' =>
		    'name',
		    'medium',
		    'arch',
		    'addarch',
		    'removearch',
		    'onlyarch',
	     ]],
	  ],
	 [[ 'repopackages' =>
	     [[ 'repopackage' =>
		'name',
		'addarch', 'arch', 'baselibs_arch', 
		'forcearch','removearch', 'onlyarch', 'source', 'script', 'medium', 'priority'
	     ]],
	 ]],
	  [ 'driverupdate' => 
	     [[ 'target' =>
		'arch',
		'_content'
	     ]],
	     [[ 'install' =>
		 [[ 'repopackage' =>
			'name',
			'addarch', 'arch', 'baselibs_arch', 
			'forcearch','removearch', 'onlyarch', 'source', 'script', 'medium', 'priority'
		 ]],
	     ]],
	     [[ 'modules' =>
		 [[ 'repopackage' =>
			'name',
			'addarch', 'arch', 'baselibs_arch', 
			'forcearch','removearch', 'onlyarch', 'source', 'script', 'medium', 'priority'
		]],
	     ]],
	     [[ 'instsys' =>
		 [[ 'repopackage' =>
			'name',
			'addarch', 'arch', 'baselibs_arch', 
			'forcearch','removearch', 'onlyarch', 'source', 'script', 'medium', 'priority'
		 ]],
	     ]]
	  ]
      ],
     [[ 'users' =>
	    'group',
	    'id',
	    [],
	 [[ 'user' =>
		'name', 'id', 'pwd', 'home', 'pwdformat', 'realname', 'shell'
	 ]],
     ]],
      [ 'split' =>
	  [ 'temporary' => 
	     [[ 'except' => 'name' ]],
	     [[ 'file' => 'name' ]],
	  ],
	  [ 'persistent' => 
	     [[ 'except' => 'name' ]],
	     [[ 'file' => 'name' ]],
	  ],
      ],
      [ 'profiles' =>
	 [[ 'profile' => 'name', 'description', 'import' ]],
      ],
     [[ 'strip' =>
	    'type',
	    [],
	 [[ 'file' => 'name' ]],
     ]],
     [[ 'drivers' =>
	    'type',
	    [],
	 [[ 'file' => 'name' ]],
     ]],
     [[ 'repository' =>
	    'type',
	    'status',
	    'priority',
	    [],
	  [ 'source' => 'path' ],
     ]],
     [[ 'deploy' =>
	    'server',
	    'blocksize',
	    [],
	 [[ 'partitions' =>
		'device',
		[],
	     [[ 'partition' =>
		    'type',
		    'number',
		    'size',
		    'mountpoint',
		    'target',
	     ]],
	 ]],
	 [[ 'configuration' =>
		'source',
		'dest',
	 ]],
     ]],
     [[ 'packages' =>
	    'type',
	    'profiles',
	    'patternType',
	    'patternPackageType',
	    'memory',
	    'disk',
	    [],
	 [[ 'archive' =>
		'name',
		'bootinclude',
		'bootdelete',
	 ]],
	 [[ 'package' =>
		'name',
		'arch',
		'bootinclude',
		'bootdelete',
	 ]],
	 [[ 'opensusePattern' =>
		'name',
		'arch',
	 ]],
	 [[ 'ignore' =>
		'name',
		'arch',
	 ]],
     ]],
      [ 'vmwareconfig' =>
	    'memory',
	    'guestOS',
	    'HWversion',
	    [],
	 [[ 'vmwaredisk' => 'controller', 'id' ]],
	 [[ 'vmwarenic' => 'driver', 'interface', 'mode' ]],
      ],
      [ 'xenconfig' =>
	    'memory',
	    [],
	 [[ 'xendisk' => 'device' ]],
      ],
];

1;

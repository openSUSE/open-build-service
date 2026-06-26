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
	'id',
	'kiwirevision',
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
		'boot',
		'bootfilesystem',
		'bootkernel',
		'bootloader',
		'bootpartsize',
		'bootprofile',
		'boottimeout',
		'checkprebuilt',
		'compressed',
		'container',
		'devicepersistency',
		'editbootconfig',
		'editbootinstall',
		'flags',
		'filesystem',
		'firmware',
		'fsnocheck',
		'fsreadonly',
		'fsreadwrite',
		'fsmountoptions',
		'format',
		'hybrid',
		'hybridpersistent',
		'image',
		'installboot',
		'installiso',
		'installstick',
		'installpxe',
		'installprovidefailsafe',
		'luks',
		'luksOS',
		'kernelcmdline',
		'mdraid',
		'primary',
		'ramonly',
		'ec2accountnr',
		'ec2privatekeyfile',
		'ec2certfile',
		'vga',
		'vhdfixedtag',
		'volid',
		'zfsoptions',
	      [ 'machine' =>
		    'HWversion',
		    'arch',
		    'domain',
		    'guestOS',
		    'max_cpu',
		    'max_memory',
		    'memory',
		    'min_cpu',
		    'minx_memory',
		    'ncpus',
		    'ovftype',
		    [],
		    'vmconfig-entry',
		  [ 'vmdisk' =>
			'id',
			'controller',
			'device',
			'diskmode',
			'disktype',
		  ],
		  [ 'vmdvd' =>
			'id',
			'controller'
		  ],
		  [ 'vmnic' =>
			'driver',
			'interface',
			'mac',
			'mode',
		  ],
	      ],
	      [ 'oemconfig' =>
		    [],
		    'oem-ataraid-scan',
		    'oem-multipath-scan',
		    'oem-boot-title',
		    'oem-bootwait',
		    'oem-inplace-recovery',
		    'oem-kiwi-initrd',
		    'oem-partition-install',
		    'oem-reboot',
		    'oem-reboot-interactive',
		    'oem-recovery',
		    'oem-recoveryID',
		    'oem-recovery-part-size',
		    'oem-shutdown',
		    'oem-shutdown-interactive',
		    'oem-silent-boot',
		    'oem-silent-install',
		    'oem-silent-verify',
		    'oem-skip-verify',
		    'oem-swap',
		    'oem-swapsize',
		    'oem-systemsize',
		    'oem-unattended',
		    'oem-unattended-id',
	      ],
	      [	'pxedeploy' =>
		    'blocksize',
		    'server',
		    [],
		    'timeout',
		    'kernel',
		    'initrd',
		  [ 'partitions' =>
			'device',
		     [[ 'partition' =>
			    'mountpoint',
			    'number',
			    'size',
			    'target',
			    'type',
		     ]],
		  ],
		  [ 'union' =>
			'ro',
			'rw',
			'type',
		  ],
		  [ 'configuration' =>
			'arch',
			'dest',
			'source',
		  ],
	      ],
	      [ 'size' =>
		    'unit',
		    'additive',
		    '_content',
	      ],
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
	      [ 'systemdisk' =>
		    'name',
		 [[ 'volume' =>
			'freespace',
			'mountpoint',
			'name',
			'size',
		 ]],
	      ],
	      [ 'vagrantconfig' =>
		    'provider',
		    'virtualsize',
	      ],
		'_content',
	]],
	'version',
      [ 'size' =>
	    'unit',
	    '_content',
      ],
	'boot-theme',
	'compressed',
	'defaultbaseroot',
	'defaultdestination',
	'defaultroot',
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
	'bootsplash-theme',
	'bootloader-theme',
	'defaultprebuilt',
	'hwclock',
	'partitioner',
	'showlicense',
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
		    'version',
	     ]],
	  ],
	 [[ 'repopackages' =>
	     [[ 'repopackage' =>
		'name',
		'addarch', 'arch', 'baselibs_arch', 
		'forcearch','removearch', 'onlyarch', 'version', 'source', 'script', 'medium', 'module', 'priority'
	     ]],
	 ]],
	  [ 'driverupdate' =>
	     [],
             'moduleorder',
             [[ 'config' =>
                'key', 'value'
             ]],
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
	    'profiles',
	    [],
	 [[ 'user' =>
		'name', 'id', 'pwd', 'home', 'pwdformat', 'realname', 'shell', 'password',
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
	 [[ 'profile' =>
		'name',
		'description',
		'import',
	 ]],
      ],
     [[ 'drivers' =>
	    'type',
	    'profiles',
	    [],
	 [[ 'file' => 'name' ]],
     ]],
     [[ 'strip' =>
	    'type',
	    'profiles',
	    [],
	 [[ 'file' => 'name' ]],
     ]],
     [[ 'repository' =>
	    'type',
	    'status',
	    'priority',
	    'alias',
	    'components',
	    'distribution',
	    'imageinclude',
	    'username',
	    'password',
	    'prefer-license',
	    'profiles',
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
	 [[ 'product' =>
		'name',
		'arch',
	 ]],
	 [[ 'package' =>
		'name',
		'arch',
		'bootinclude',
		'bootdelete',
		'replaces',
	 ]],
	 [[ 'opensusePattern' =>
		'name',
		'arch',
	 ]],
	 [[ 'namedCollection' =>
		'name',
		'arch',
	 ]],
	 [[ 'ignore' =>
		'name',
	 ]],
	 [[ 'archive' =>
		'name',
		'bootinclude',
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

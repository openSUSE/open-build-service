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
# XML templates for the BuildService. See XML/Structured.
#

package BSXML;

use strict;

# 
# an explained example entry of this file
#
#our $pack = [             creates <package name="" project=""> space
#    'package' =>          
#	'name',
#	'project',
#	[],                before the [] all strings become attributes to <package>
#       'title',           from here on all strings become childs like <title> </title>
#       'description',
#       [[ 'person' =>     creates <person> childs, the [[ ]] syntax allows any number of them including zero
#           'role',        again role and userid attributes, both are required
#           'userid',    
#       ]],                this block describes a <person role="defaetist" userid="adrian" /> construct
# 	@flags,            copies in the block of possible flag definitions
#       [ $repo ],         refers to the repository construct and allows again any number of them (0-X)
#];                        closes the <package> child with </package>

our $repo = [
   'repository' => 
	'name',
     [[ 'path' =>
	    'project',
	    'repository',
     ]],
      [ 'arch' ],
	'status',
];

our @disableenable = (
     [[	'disable' =>
	'arch',
	'repository',
     ]],
     [[	'enable' =>
	'arch',
	'repository',
     ]],
);

our @flags = (
      [ 'build' => @disableenable ],
      [ 'publish' => @disableenable ],
      [ 'debuginfo' => @disableenable ],
      [ 'useforbuild' => @disableenable ],
);

our $proj = [
    'project' =>
        'name',
	 [],
        'title',
        'description',
	'remoteurl',
	'remoteproject',
     [[ 'person' =>
            'role',
            'userid',
     ]],
	@flags,
      [ $repo ],
];

our $pack = [
    'package' =>
	'name',
	'project',
	[],
        'title',
        'description',
      [ 'devel', =>
	    'project',
      ],
     [[ 'person' =>
            'role',
            'userid',
     ]],
	@disableenable,
	@flags,
	'url',
	'group',
];

our $packinfo = [
    'info' =>
	'repository',
	'name',
	'file',
	'error',
	[ 'dep' ],
	[ 'imagetype' ],
];

our $linked = [
    'linked' =>
	'project',
	'package',
];

our $aggregatelist = [
    'aggregatelist' =>
     [[ 'aggregate' =>
	    'project',
	  [ 'package' ],
	  [ 'binary' ],
	 [[ 'repository' =>
		'target',
		'source',
         ]],
     ]],
];

our $kiwidesc = [
    'image' =>
        'name',
        'schemeversion',
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
              'primary',
              'filesystem',
              'boot',
              'bootprofile',
              'flags',
              '_content',
          ]],
             'version',
          [ 'size' =>
              'unit',
              '_content',
          ],
          [  'compressed', ],
             'packagemanager',
             'rpm-check-signatures',
        ],
        [[ 'users' =>
             'group',
             [],
             [[ 'user' => 'name', 'pwd', 'home', 'realname' ]],
        ]],
	[[ 'repository' =>
	       'type',
               [],
	       [[ 'source' => 'path' ]],
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
               'patternType',
               'patternPackageType',
               'memory',
               'disk',
               [],
	       [['package' =>
                     'name',
                     'arch',
               ]],
	       [['opensusePattern' =>
                     'name',
                     'arch',
               ]],
	       [['ignore' =>
                     'name',
                     'arch',
               ]],
        ]],
];

our $projpack = [
    'projpack' =>
     [[ 'project' =>
	    'name',
	     [],
	    'title',
	    'description',
	    'config',
	    'patternmd5',
	    'remoteurl',
	    'remoteproject',
	    @flags,
	  [ $repo ],
	 [[ 'package' =>
		'name',
		'rev',
		'srcmd5',
		'versrel',
		'verifymd5',
		[ $linked ],
		'error',
		[ $packinfo ],
		$aggregatelist,
		@flags,
	 ]],
     ]],
     [[ 'remotemap' =>
	    'project',
	    'remoteurl', 
	    'remoteproject', 
     ]],
];

our $linkinfo = [
    'linkinfo' =>
	# information from link
	'project',
	'package',
	'rev',
	'srcmd5',
	# expanded / unexpanded srcmd5
	'xsrcmd5',
	'lsrcmd5',
	'error',
];


our $dir = [
    'directory' =>
	'name',
	'rev',
	'vrev',
	'srcmd5',
        'tproject',
        'tpackage',
        'trev',
        'tsrcmd5',
        'lsrcmd5',
        'error',
        'xsrcmd5',
        $linkinfo,
     [[ 'entry' =>
	    'name',
	    'md5',
	    'size',
	    'mtime',
	    'error',
	    'id',
     ]]
];

our $fileinfo = [
    'fileinfo' =>
	'filename',
	[],
	'name',
        'epoch',
	'version',
	'release',
	'arch',
	'summary',
	'description',
	'size',
      [ 'provides' ],
      [ 'requires' ],
      [ 'prerequires' ],
      [ 'conflicts' ],
      [ 'obsoletes' ],
      [ 'recommends' ],
      [ 'supplements' ],
      [ 'suggests' ],
      [ 'enhances' ],
];

our $buildinfo = [
    'buildinfo' =>
	'project',
	'repository',
	'package',
	[],
	'job',
	'arch',
	'error',
	'srcmd5',
	'verifymd5',
	'rev',
	'specfile',	# obsolete
	'file',
	'versrel',
	'bcnt',
	'release',
	'debuginfo',
      [ 'subpack' ],
      [ 'imagetype' ],
      [ 'dep' ],
     [[ 'bdep' =>
	'name',
	'preinstall',
	'vminstall',
	'runscripts',
	'notmeta',

	'epoch',
	'version',
	'release',
	'arch',
	'project',
	'repository',
     ]],
      [ 'pdep' ],	# obsolete
     [[ 'path' =>
	    'project',
	    'repository',
	    'server',
     ]]
];

our $jobstatus = [
    'jobstatus' =>
	'code',
	'details',
	[],
	'starttime',
	'endtime',
	'workerid',
	'hostarch',

	'uri',		# uri to reach worker

	'arch',		# our architecture
	'job',		# our jobname
	'jobid',	# md5 of job info file
];

our $buildstatus = [
    'status' =>
	'package',
	'code',
	'status',	# obsolete, now code
	'error',	# obsolete, now details
	[],
	'details',

	'workerid',	# last build data
	'hostarch',
	'readytime',
	'starttime',
	'endtime',

	'job',		# internal, job when building

	'uri',		# obsolete
	'arch',		# obsolete
];

our $event = [
    'event' =>
	'type',
	[],
	'project',
	'repository',
	'arch',
	'package',
	'job',
	'due',
];

our $events = [
    'events' =>
	'next',
	'sync',
       [ $event ],
];

our $revision = [
     'revision' =>
	'rev',
	'vrev',
	[],
	'srcmd5',
	'version',
	'time',
	'user',
	'comment',
];

our $revisionlist = [
    'revisionlist' =>
      [ $revision ]
];

our $buildhist = [
    'buildhistory' =>
     [[ 'entry' =>
	    'rev',
	    'srcmd5',
	    'versrel',
	    'bcnt',
	    'time',
     ]]
];

our $binaryversionlist = [
    'binaryversionlist' =>
      [ 'binary' ]
];

our $worker = [
    'worker' =>
	'hostarch',
	'ip',
	'port',
	'workerid',
	[],
	'job',		# set when worker is busy
	'arch',		# set when worker is busy
];

our $packstatuslist = [
    'packstatuslist' =>
	'project',
	'repository',
	'arch',
     [[ 'packstatus' =>
	    'name',
	    'status',
	    'error',
     ]],
     [[ 'packstatussummary' =>
	    'status',
	    'count',
     ]],
];

our $packstatuslistlist = [
    'packstatuslistlist' =>
    'state',
    'retryafter',
     [ $packstatuslist ],
];

our $linkpatch = [
    '' =>
      [ 'add' =>
	    'name',
	    'type',
	    'after',
	    'popt',
	    'dir',
      ],
      [ 'apply' =>
	    'name',
      ],
      [ 'delete' =>
	    'name',
      ],
        'topadd',
];

our $link = [
    'link' =>
	'project',
	'package',
	'rev',
	'cicount',
      [ 'patches' =>
	  [ $linkpatch ],
      ],
];

our $workerstatus = [
    'workerstatus' =>
	'clients',
     [[ 'idle' =>
	    'uri',
	    'workerid',
	    'hostarch',
     ]], 
     [[ 'building' =>
	    'uri',
	    'workerid',
	    'hostarch',
	    'project',
	    'repository',
	    'package',
	    'arch',
	    'starttime',
     ]],
     [[ 'waiting', =>
	    'arch',
	    'jobs',
     ]],
     [[ 'scheduler' =>
	    'arch',
	    'state',
	    'starttime',
     ]],
];

our $workerstate = [
    'workerstate' =>
	'state',
	'jobid',
];

our $jobhistlay = [
	'project',
	'repository',
	'package',
	'arch',
	'srcmd5',
	'readytime',
	'starttime',
	'endtime',
	'status',
	'uri',
	'hostarch',
];

our $jobhist = [
    'jobhist' =>
	@$jobhistlay,
];

our $jobhistlist = [
    'jobhistlist' =>
      [ $jobhist ],
];

our $ajaxstatus = [
    'ajaxstatus' =>
     [[ 'watcher' =>
	    'filename',
	    'state',
	 [[ 'job' =>
		'id',
		'ev',
		'fd',
	 ]],
     ]],
     [[ 'rpc' =>
	    'uri',
	    'state',
	    'ev',
	    'fd',
	 [[ 'job' =>
		'id',
		'ev',
		'fd',
	 ]],
     ]],
];

##################### new api stuff

our $binarylist = [
    'binarylist' =>
	'package',
     [[ 'binary' =>
	    'filename',
	    'size',
	    'mtime',
     ]],
];

our $summary = [
    'summary' =>
     [[ 'statuscount' =>
	    'code',
	    'count',
     ]],
];

our $result = [
    'result' =>
	'project',
	'repository',
	'arch',
      [ $buildstatus ],
      [ $binarylist ],
        $summary,
];

our $resultlist = [
    'resultlist' =>
	'state',
	'retryafter',
      [ $result ],
];

our $opstatus = [
    'status' =>
	'code',
	[],
	'summary',
	'details',
];

my $rpm_entry = [
    'rpm:entry' =>
        'kind',
        'name',
        'epoch',
        'ver',
        'rel',
        'flags',
];

our $pattern = [
    'pattern' =>
	'xmlns',      # obsolete, moved to patterns
	'xmlns:rpm',  # obsolete, moved to patterns
	[],
	'name',
     [[ 'summary' =>
	    'lang',
	    '_content',
     ]],
     [[ 'description' =>
	    'lang',
	    '_content',
     ]],
	'default',
	'uservisible',
     [[ 'category' =>
	    'lang',
	    '_content',
     ]],
	'icon',
	'script',
      [ 'rpm:provides' => [ $rpm_entry ], ],
      [ 'rpm:conflicts' => [ $rpm_entry ], ],
      [ 'rpm:obsoletes' => [ $rpm_entry ], ],
      [ 'rpm:requires' => [ $rpm_entry ], ],
      [ 'rpm:suggests' => [ $rpm_entry ], ],
      [ 'rpm:enhances' => [ $rpm_entry ], ],
      [ 'rpm:supplements' => [ $rpm_entry ], ],
      [ 'rpm:recommends' => [ $rpm_entry ], ],
];

our $patterns = [
    'patterns' =>
	'count',
	'xmlns',
	'xmlns:rpm',
	[],
      [ $pattern ],
];

our $ymp = [
    'metapackage' =>
        'xmlns:os',
        'xmlns',
        [],
     [[ 'group' =>
	    'recommended',
	    'distversion',
	    [],
	    'name',
	    'summary',
	    'description',
	    'remainSubscribed',
	  [ 'repositories' =>
	     [[ 'repository' =>
		    'recommended',
		    'format',
		    'producturi',
		    [],
		    'name',
		    'summary',
		    'description',
		    'url',
	     ]],
	    ],
	  [ 'software' =>
	     [[ 'item' =>
		    'type',
		    'recommended',
		    'architectures',
		    'action',
		    [],
		    'name',
		    'summary',
		    'description',
	     ]],
	  ],
      ]],
];

our $binary_id = [
    'binary' => 
	'name',
	'project',
	'package',
	'repository',
	'version',
	'arch',
	'filename',
	'filepath',
	'baseproject',
	'type',
];

our $pattern_id = [
    'pattern' => 
	'name',
	'project',
	'repository',
	'arch',
	'filename',
	'filepath',
	'baseproject',
	'type',
];

our $request = [
    'request' =>
	'id',
	'type',
      [ 'submit' =>
	  [ 'source' =>
		'project',
		'package',
		'rev',
	  ],
	  [ 'target' =>
		'project',
		'package',
	  ],
      ],
      [ 'state' =>
	    'name',
	    'who',
	    'when',
	    [],
	    'comment',
      ],
     [[ 'history' =>
	    'name',
	    'who',
	    'when',
	    [],
	    'comment',
     ]],
	'title',
	'description',
];

our $repositorystate = [
    'repositorystate' => 
      [ 'blocked' ],
];

our $collection = [
    'collection' => 
      [ $request ],
      [ $proj ],
      [ $pack ],
      [ $binary_id ],
      [ $pattern_id ],
      [ 'value' ],
];

1;

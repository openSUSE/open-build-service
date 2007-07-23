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

our $projpack = [
    'projpack' =>
     [[ 'project' =>
	    'name',
	     [],
	    'title',
	    'description',
	    'config',
	    'patternmd5',
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
];

our $linkinfo = [
    'linkinfo' =>
	'project',
	'package',
	'srcmd5',
	'error',
];


our $dir = [
    'directory' =>
	'name',
	'rev',
	'srcmd5',
        'tproject',
        'tpackage',
        'trev',
        'tsrcmd5',
        'lsrcmd5',
        'error',
        'xsrcmd5',
     [[ 'entry' =>
	    'name',
	    'md5',
	    'size',
	    'mtime',
	    'error',
     ]]
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
      [ 'subpack' ],
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

our $buildstatus = [
    'status' =>
	'package',
	'code',
	'status',	# obsolete, now code
	'error',	# obsolete, now details
	[],
	'details',
	'uri',
	'workerid',
	'hostarch',
	'readytime',
	'starttime',
	'endtime',
	'arch',		# internal, arch when building
	'job',		# internal, job when building
];

our $buildstatussum = [
    'statussum' =>
	'name',
#XXX	[],
	'status',
	'packages',
	'building',
	'delayed',
	'rpms',
	'succeeded',
	'failed',
	'error',
];

our $buildstatussumlist = [
    'statussumlist' =>
      [ $buildstatussum ],
];

our $event = [
    'event' =>
	'type',
	[],
	'project',
	'repository',
	'package',
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
];

our $workerstate = [
    'workerstate' =>
	'state'
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
      [ 'provides' => [ $rpm_entry ], ],
      [ 'conflicts' => [ $rpm_entry ], ],
      [ 'obsoletes' => [ $rpm_entry ], ],
      [ 'requires' => [ $rpm_entry ], ],
      [ 'suggests' => [ $rpm_entry ], ],
      [ 'enhances' => [ $rpm_entry ], ],
      [ 'supplements' => [ $rpm_entry ], ],
      [ 'recommends' => [ $rpm_entry ], ],
];

our $patterns = [
    'patterns' =>
	'count',
      [ $pattern ],
];

our $ymp = [
    'bw:metapackage' =>
	'xmlns:bw',
	'xmlns',
	[],
	'name',
	'summary',
	'description',
      [ 'repos' =>
	 [[ 'repo' =>
		'recommended',
		[],
		'name',
		'summary',
		'description',
		'url',
	 ]],
      ],
      [ 'packages' =>
	 [[ 'package' =>
		'recommended',
		[],
		'name',
		'summary',
		'description',
	 ]]
      ],
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
];

our $pattern_id = [
    'pattern' => 
	'name',
	'project',
	'repository',
	'arch',
	'filename',
	'filepath',
	'type',
];


our $collection = [
    'collection' => 
      [ $proj ],
      [ $pack ],
      [ $binary_id ],
      [ $pattern_id ],
      [ 'value' ],
];

1;

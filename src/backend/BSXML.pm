#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
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
#       'title',           from here on all strings become children like <title> </title>
#       'description',
#       [[ 'person' =>     creates <person> children, the [[ ]] syntax allows any number of them including zero
#           'role',        again role and userid attributes, both are required
#           'userid',    
#       ]],                this block describes a <person role="defeatist" userid="statler" /> construct
# 	@flags,            copies in the block of possible flag definitions
#       [ $repo ],         refers to the repository construct and allows again any number of them (0-X)
#];                        closes the <package> child with </package>

our $download = [
    'download' =>
	'arch',
	'repotype',
	'url',
	[],
	'archfilter',
      [ 'master' =>
	    'url',
	    'sslfingerprint',
      ],
	'pubkey',
];

# same as download, but with project/repository
our $doddata = [
    'doddata' =>
	'project',
	'repository',
	@$download[1 .. $#$download],
];

our $repo = [
   'repository' => 
	'name',
	'rebuild',
	'block',
	'linkedbuild',
      [ $download ],
     [[ 'releasetarget' =>
	    'project',
	    'repository',
	    'trigger',
     ]],
     [[ 'path' =>
	    'project',
	    'repository',
     ]],
      [ 'hostsystem' =>
	    'project',
	    'repository',
      ],
      [ 'base' =>		# expanded repo only!
	    'project',
	    'repository',
      ],
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
      [ 'lock' => @disableenable ],
      [ 'build' => @disableenable ],
      [ 'publish' => @disableenable ],
      [ 'debuginfo' => @disableenable ],
      [ 'useforbuild' => @disableenable ],
      [ 'binarydownload' => @disableenable ],
      [ 'sourceaccess' => @disableenable ],
      [ 'access' => @disableenable ],
);

our @roles = (
     [[ 'person' =>
            'userid',
            'role',
     ]],
     [[ 'group' =>
            'groupid',
            'role',
     ]],
);

our $maintenance = [
    'maintenance' =>
     [[ 'maintains' =>
            'project',
     ]],
];

our $proj = [
    'project' =>
        'name',
        'kind',
	 [],
        'title',
        'description',
        'url',
	'config',	# for 'withconfig' option
     [[	'link' =>
	    'project',
	    'vrevmode',
     ]],
	'remoteurl',
	'remoteproject',
	'mountproject',
      [ 'devel' =>
	    'project',
      ],
	@roles,
	$maintenance,
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
        'releasename',
      [ 'devel' =>
	    'project',
	    'package',
      ],
	@roles,
	@disableenable,
	@flags,
	'url',
	'bcntsynctag',
];

our $packinfo = [
    'info' =>
	'repository',
	'name',
	'file',
	'error',
	  [ 'dep' ],
	  [ 'prereq' ],
	  [ 'buildtimeservice' ],
	  [ 'imagetype' ],	# kiwi
	  [ 'imagearch' ],	# kiwi
	    'nodbgpkgs',	# kiwi
	    'nosrcpkgs',	# kiwi
	 [[ 'path' =>
		'project',
		'repository',
		'priority',
	 ]],
	 [[ 'containerpath' =>
		'project',
		'repository',
		'priority',
	 ]],
	 [[ 'extrasource' =>
		'project',
		'package',
		'srcmd5',
		'file',
	 ]],
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
	    [],
            'nosources',
	  [ 'package' ],
	  [ 'binary' ],
	 [[ 'repository' =>
		'target',
		'source',
         ]],
     ]],
];

# former: kernel - 123 - 1   123: incident
# now:    sec-123 - 1 -1
our $patchinfo = [
    'patchinfo' => 
            'incident', # optional, gets replaced on with updateinfoid on release
            'version',	# optional, defaults to 1
            [],
	  [ 'package' ],# optional
	  [ 'binary' ],	# optional
	 [[ 'releasetarget' => # optional
		'project',
		'repository',
         ]],
         [[ 'issue' =>
		'tracker',
		'id',
		'documented',
                [],
		'_content',
	 ]],
            'category',
            'rating',
            'name', # optional, old patchinfo name which will become part of incident string
            'summary',
            'description',
            'message',  # optional pop-up message
            'swampid',	# obsolete
            'packager',
            'stopped',
            'zypp_restart_needed',
            'reboot_needed',
            'relogin_needed',
];

our $channel = [
    'channel' =>
      [ 'product' =>
            'project',
            'name',
      ],
     [[ 'target' =>
	    'project',
	    'repository',
	    'id_template', # optional
	    'requires_issue', # optional
            [],
	    'disabled', # optional
     ]],
     [[ 'binaries' =>
	    'project',
	    'repository',
	    'arch',
	 [[ 'binary' =>
		'name',
		'binaryarch',
		'project',
		'repository',
		'package',
		'arch',
		'supportstatus',
	 ]],
     ]],
];

our $projpack = [
    'projpack' =>
    'repoid',
     [[ 'project' =>
	    'name',
	    'kind',
	     [],
	    'title',
	    'description',
	    'config',
	    'patternmd5',
	 [[ 'link' =>
		'project',
		'vrevmode',
	 ]],
	    'remoteurl',
	    'remoteproject',
	    @flags,
	    @roles,
	  [ $repo ],
	 [[ 'package' =>
		'name',
		'releasename',
		'rev',
		'srcmd5',	# commit id
		'versrel',
		'verifymd5',	# tree id
		'originproject',
		'revtime',
		'constraintsmd5',	# md5sum of constraints file in srcmd5
		[ $linked ],
		'error',
		[ $packinfo ],
		$aggregatelist,
		$patchinfo,
		'channelmd5',
		@flags,
		'bcntsynctag',
		'hasbuildenv',
	 ]],
	    'missingpackages',
     ]],
     [[ 'remotemap' =>
	    'project',
	    'kind',
	    'root',
	    'remoteurl', 
	    'remoteproject', 
	    'remoteroot', 
	    'partition',
	    'proto',	# project data not included
	     [],
	    'config',
	    @flags,
	    @roles,
	  [ $repo ],
	    'error',
     ]],
     [[ 'channeldata' => 
	    'md5',
	    $channel,
    ]],
];

our $linkinfo = [
    'linkinfo' =>
	# information from link
	'project',
	'package',
	'rev',
	'srcmd5',
	'baserev',
	'missingok',
	# expanded / unexpanded srcmd5
	'xsrcmd5',
	'lsrcmd5',
	'error',
	'lastworking',
      [ $linked ],
];

our $serviceinfo = [
    'serviceinfo' =>
	# information in case a source service is part of package
	'code',         # can be "running", "failed", "succeeded"
	'xsrcmd5',
	'lsrcmd5',
        [],
	'error',        # contains error message (with new lines) in case of error
];

our $dir = [
    'directory' =>
	'name',
	'count',	# obsolete, the API sets this for some requests
	'rev',
	'vrev',
	'srcmd5',
        'tproject',     # obsolete, use linkinfo
        'tpackage',     # obsolete, use linkinfo
        'trev',         # obsolete, use linkinfo
        'tsrcmd5',      # obsolete, use linkinfo
        'lsrcmd5',      # obsolete, use linkinfo
        'error',
        'xsrcmd5',      # obsolete, use linkinfo
        $linkinfo,
        $serviceinfo,
     [[ 'entry' =>
	    'name',
	    'md5',
            'hash',
	    'size',
	    'mtime',
	    'error',
	    'id',
	    'originproject',	# for package listing
	    'originpackage',	# for package listing
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
	'source',
	'summary',
	'description',
	'size',
	'mtime',
      [ 'provides' ],
      [ 'requires' ],
      [ 'prerequires' ],
      [ 'conflicts' ],
      [ 'obsoletes' ],
      [ 'recommends' ],
      [ 'supplements' ],
      [ 'suggests' ],
      [ 'enhances' ],

     [[ 'provides_ext' =>
	    'dep',
	 [[ 'requiredby' =>
		'name',
		'epoch',
		'version',
		'release',
		'arch',
		'project',
		'repository',
	 ]],
     ]],
     [[ 'requires_ext' =>
	    'dep',
	 [[ 'providedby' =>
		'name',
		'epoch',
		'version',
		'release',
		'arch',
		'project',
		'repository',
	 ]],
     ]],
];

our $sourceinfo = [
    'sourceinfo' =>
	'package',
	'rev',
	'vrev',
	'srcmd5',
	'lsrcmd5',
	'verifymd5',
	[],
	'filename',
	'error',
	'originproject',
	'originpackage',
       [ $linked ],
	'revtime',
	'changesmd5',

	'name',
	'version',
	'release',
       [ 'subpacks' ],
       [ 'deps' ],
       [ 'prereqs' ],
       [ 'exclarch' ],
       [ 'badarch' ],
];

our $sourceinfolist = [
    'sourceinfolist' =>
      [ $sourceinfo ],
];

our $buildinfo = [
    'buildinfo' =>
	'project',
	'repository',
	'package',
	'srcserver',
	'reposerver',
	'downloadurl',
	[],
	'job',
	'arch',
	'hostarch',     # for cross build
	'error',
	'srcmd5',
	'verifymd5',
	'rev',
	'disturl',
	'reason',       # just for the explain string of a build reason
	'needed',       # number of blocked
	'revtime',	# time of last commit
	'readytime',
	'specfile',	# obsolete
	'file',
	'versrel',
	'bcnt',
	'release',
	'debuginfo',
	'constraintsmd5',
      [ 'prjconfconstraint' ],
      [ 'subpack' ],
      [ 'imagetype' ],	# kiwi
	'nodbgpkgs',	# kiwi
	'nosrcpkgs',	# kiwi
	'genmetaalgo',	# internal
      [ 'dep' ],
     [[ 'bdep' =>
	'name',
	'preinstall',
	'vminstall',
	'cbpreinstall',
	'cbinstall',
	'runscripts',
	'notmeta',
	'noinstall',
	'installonly',

	'epoch',
	'version',
	'release',
	'arch',
	'hdrmd5',

	'project',
	'repository',
	'repoarch',
	'binary',	# filename
	'package',
	'srcmd5',
     ]],
      [ 'pdep' ],	# obsolete
     [[ 'path' =>
	    'project',
	    'repository',
	    'server',	# internal
	    'url',	# external
     ]],
     [[ 'syspath' =>
	    'project',
	    'repository',
	    'server',	# internal
	    'url',	# external
     ]],
     [[ 'containerpath' =>
	    'project',
	    'repository',
	    'server',	# internal
	    'url',	# external
     ]],
	'containerannotation',	# temporary hack
	'expanddebug',
	'followupfile',	# for two-stage builds
	'masterdispatched',	# dispatched through a master dispatcher
	'nounchanged',	# do not check for "unchanged" builds

      [ 'preinstallimage' =>
	    'project',
	    'repository',
	    'repoarch',
	    'package',
	    'filename',
	    'hdrmd5',
	  [ 'binary' ],
	    'url',	# external
      ],
];

our $jobstatus = [
    'jobstatus' =>
	'code',
	'result',       # succeeded, failed or unchanged
	'details',
	[],
	'starttime',
	'endtime',
	'lastduration', # optional
	'workerid',
	'hostarch',

	'uri',		# uri to reach worker

	'arch',		# our architecture
	'job',		# our jobname
	'jobid',	# md5 of job info file
	'attempt',      # number of attempts to build the job
];

our $buildreason = [
    'reason' =>
       [],
       'explain',             # Readable reason
       'time',                # unix time from start build
       'oldsource',           # last build source md5 sum, if a source change was the reason
       [[ 'packagechange' =>  # list changed files which are used for building
          'change',           # kind of change (content/meta change, additional file or removed file)
          'key',              # file name
       ]],
];

our $buildstatus = [
    'status' =>
	'package',
	'code',
	'status',	# obsolete, now code
	'error',	# obsolete, now details
	'versrel',	# for withversrel result call
	[],
	'details',

	'workerid',	# last build data
	'hostarch',
	'readytime',
	'starttime',
	'endtime',

	'buildid',	# some id identifying the build

	'job',		# internal, job when building

	'uri',		# obsolete
	'arch',		# obsolete
];

our $builddepinfo = [
    'builddepinfo' =>
     [[ 'package' =>
	    'name',
	    [],
	    'source',
	  [ 'pkgdep' ],
	  [ 'subpkg' ],
     ]],
     [[ 'cycle' =>
	  [ 'package' ],
     ]],
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
	'worker',
	'due',
	'srcmd5',		# for type=servicedispatch
	'rev',			# for type=servicedispatch
	'linksrcmd5',		# for type=servicedispatch
	'projectservicesmd5',	# for type=servicedispatch
	'oldsrcmd5',		# for type=servicedispatch
	'details',              # for type=dispatchdetails
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
	'requestid',
];

our $revision_acceptinfo = [
    @$revision,
      [ 'acceptinfo' =>
	    'rev',
	    'srcmd5',
	    'osrcmd5',
	    'xsrcmd5',
	    'oxsrcmd5',
      ],
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
	    'duration',
     ]],
];

our $binaryversionlist = [
    'binaryversionlist' =>
     [[ 'binary' =>
	    'name',	# should be filename instead. sigh.
	    'sizek',
	    'error',
	    'hdrmd5',
	    'metamd5',
	    'leadsigmd5',
     ]],
];

our $packagebinaryversionlist = [
    'packagebinaryversionlist' =>
     [[ 'binaryversionlist' =>
	    'package',
	    'code',
         [[ 'binary' =>
		'name',
		'sizek',
		'error',
		'hdrmd5',
		'metamd5',
		'leadsigmd5',
	 ]],
     ]],
];

our $worker = [
    'worker' =>
	'hostarch',
	'ip',
	'port',
	'registerserver',
	'workerid',
      [ 'buildarch' ],
      [ 'hostlabel' ],
	'sandbox',
      [ 'linux' =>
        [],
        'version',
        'flavor'
      ],
      [ 'hardware' =>
        [ 'cpu' =>
          [ 'flag' ],
        ],
        'processors',
        'jobs',
        'nativeonly',   # don't allow usage via the helper script
	'memory',	# in MBytes
	'swap',		# in MBytes
	'disk',		# in MBytes
      ],
	'owner',
	'tellnojob',

	'job',		# set when worker is busy
	'arch',		# set when worker is busy
	'jobid',	# set when worker is busy
	'reposerver',	# set when worker is busy and job was masterdispatched
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
        'branch',
        'topadd',
];

our $link = [
    'link' =>
	'project',
	'package',
	'rev',
	'vrev',
	'cicount',
	'baserev',
	'missingok',
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
     [[ 'down' =>
	    'workerid',
	    'hostarch',
     ]],
     [[ 'dead' =>
	    'workerid',
	    'hostarch',
     ]],
     [[ 'away' =>
	    'workerid',
	    'hostarch',
     ]],
     [[ 'waiting' =>
	    'arch',
	    'jobs',
     ]],
     [[ 'blocked' =>
	    'arch',
	    'jobs',
     ]],
     [[ 'buildavg' =>
            'arch',
	    'buildavg',
     ]],
     [[ 'partition' =>
	    'name',
         [[ 'daemon' =>
		'type',        # scheduler/dispatcher/signer/publisher/warden
                'arch',        # scheduler only
                'state',
                'starttime',
              [ 'queue' =>     # scheduler only 
                    'high',
                    'med',
                    'low',
                    'next',
              ],
         ]],
     ]],
];

our $workerstate = [
    'workerstate' =>
	'state',
	'nextstate',	# for exit/restart
	'jobid',
	'pid',		# pid of building worker process
];

our $jobhistlay = [
	'package',
	'rev',
	'srcmd5',
	'versrel',
	'bcnt',
	'readytime',
	'starttime',
	'endtime',
	'code',
	'uri',
	'workerid',
	'hostarch',
	'reason',
	'verifymd5',
];

our $jobhist = [
    'jobhist' =>
	@$jobhistlay,
];

our $jobhistlist = [
    'jobhistlist' =>
      [ $jobhist ],
];

our $ajaxjob = [
    'job' =>
	'ev',
	'fd',
	'starttime',
	'peer',
	'request',
	'state',
];

our $ajaxstatus = [
    'ajaxstatus' =>
	'starttime',
	'ev',
     [[ 'watcher' =>
	    'filename',
	    'state',
	  [ $ajaxjob ],
     ]],
     [[ 'rpc' =>
	    'uri',
	    'state',
	    'ev',
	    'fd',
	    'starttime',
	  [ $ajaxjob ],
     ]],
     [[ 'serialize' =>
	    'filename',
	  [ $ajaxjob ],
     ]],
      [ 'joblist' =>
	  [ $ajaxjob ],
      ],
];

our $serverstatus = [
    'serverstatus' =>
	'starttime',
     [[ 'job' =>
	    'id',
	    'starttime',
	    'pid',
	    'peer',
	    'request',
	    'group',
     ]],
];

##################### new api stuff

our $binarylist = [
    'binarylist' =>
	'package',
     [[ 'binary' =>
	    'filename',
	    'md5',
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

our $schedulerstats = [
    'stats' =>
	'lastchecked',
	'checktime',
	'lastfinished',
	'lastpublished',
];

our $result = [
    'result' =>
	'project',
	'repository',
	'arch',
	'code',	# pra state, can be "unknown", "broken", "scheduling", "blocked", "building", "finished", "publishing", "published" or "unpublished"
	'state', # old name of 'code', to be removed
	'details',
	'dirty', # marked for re-scheduling if element exists, state might not be correct anymore
      [ $buildstatus ],
      [ $binarylist ],
        $summary,
	$schedulerstats,
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
	'origin',
	[],
	'summary',
	'details',
     [[ 'data' =>
	    'name',
	    '_content',
     ]],
      [ 'exception' =>
	    'type',
	    'message',
	  [ 'backtrace' =>
	      [ 'line' ],
	  ],
      ],
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
    'arch',
     [[ 'version' =>
        'epoch',
        'ver',
        'rel',
     ]],
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
	'release',
	'arch',
	'filename',
	'filepath',
	'baseproject',
	'type',
	'downloadurl',
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
	'downloadurl',
];

our $request = [
    'request' =>
	'id',
	'creator',
	'type',		# obsolete, still here to handle OBS pre-1.5 requests
	'key',		# cache key, not really in request
	'retryafter',	# timed out waiting for a key change
     [[ 'action' =>
	    'type',	# currently submit, delete, change_devel, add_role, maintenance_release, maintenance_incident, set_bugowner
	  [ 'source' =>
	        'project',
	        'package',
	        'rev',        # belongs to package attribute
	        'repository', # for merge request
	  ],
	  [ 'target' =>
		'project',
		'package',
		'releaseproject', # for incident request
	        'repository', # for release and delete request
	  ],
	  [ 'person' =>
		'name',
		'role',
	  ],
	  [ 'group' =>
		'name',
		'role',
	  ],
          [ 'options' =>
		[],
		'sourceupdate',    # can be cleanup, update or noupdate
		'updatelink',      # can be true or false
		'makeoriginolder', # can be true or false
          ],
	  [ 'acceptinfo' =>
	        'rev',
	        'srcmd5',
	        'osrcmd5',
	        'xsrcmd5',
	        'oxsrcmd5',
          ],
     ]],
      [ 'submit' =>          # this is old style, obsolete by request, but still supported
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
      'priority',
      [ 'state' =>
	    'name',
	    'who',
	    'when',
	    'superseded_by', # set when state.name is "superseded"
	    [],
	    'comment',
      ],
     [[ 'review' =>
            'state',         # review state (new/accepted or declined)
            'by_user',       # this user shall review it
            'by_group',      # one of this groupd shall review it
                             # either user or group must be used, never both
            'by_project',    # any maintainer of this project can review it
            'by_package',    # any maintainer of this package can review it (requires by_project)
            'who',           # this user has reviewed it
	    'when',
	    [],
	    'comment',
            [[ 'history' =>
                   'who',
                   'when',
                   [],
                   'comment',
                   'description',
            ]],
     ]],
     [[ 'history' =>
	    'name',
	    'who',
	    'when',
	    'superseded_by',
	    [],
	    'comment',
	    'description',
     ]],
	'accept_at',
	'title',
	'description',
];

our $repositorystate = [
    'repositorystate' => 
      [ 'blocked' ],
];

our $collection = [
    'collection' => 
	'matches',
	'limited',
      [ $request ],
      [ $proj ],
      [ $pack ],
      [ $binary_id ],
      [ $pattern_id ],
      [ 'value' ],
];

our $quota = [
    'quota' =>
	'packages',
     [[ 'project' =>
	    'name',
	    'packages',
     ]],
];

our $schedulerinfo = [
  'schedulerinfo' =>
	'arch',
	'started',
	'time',
	[],
	'slept',
	'booting',
	'notready',
      [ 'queue' =>
	    'high',
	    'med',
	    'low',
	    'next',
      ],
	'projects',
	'repositories',
     [[ 'worst' =>
	    'project',
	    'repository',
	    'packages',
	    'time',
     ]],
        'buildavg',
	'avg',
	'variance',
];

our $person = [
  'person' =>
	'login',
	'email',
	'realname',
      [ 'owner' =>
                'userid',
        ],
	'state',
      [ 'globalrole' ],
	'ignore_auth_services',
      [ 'watchlist' =>
	 [[ 'project' =>
		'name',
	 ]],
      ],
];

our $comps = [
    'comps' =>
     [[ 'group' =>
	[],
	'id',
	 [[ 'description' =>
	    'xml:lang',
	    '_content',
	 ]],
	 [[ 'name' =>
	    'xml:lang',
	    '_content',
	 ]],
	  [ 'packagelist' =>
	     [[ 'packagereq' =>
		'type',
		'_content',
	     ]],
	  ],
    ]],
];

our $dispatchprios = [
    'dispatchprios' =>
     [[ 'prio' =>
	    'project',
	    'repository',
	    'arch',
	    'adjust',
     ]],
];

# list of used services for a package or project
our $services = [
    'services' =>
     [[ 'service' =>
            'name',
            'mode', # "localonly" is skipping this service on server side, "trylocal" is trying to merge changes directly in local files, "disabled" is just skipping it
         [[ 'param' =>
	        'name',
                '_content'
         ]],
    ]],
];

# service type definitions
our $servicetype = [
    'service' =>
        'name',
        'hidden', # "true" to suppress it from service list in GUIs
        [],
        'summary',
        'description',
     [[ 'parameter' =>
	    'name',
	    [],
	    'description',
	    'required',		# don't run without this parameter
	    'allowmultiple',	# This parameter can be used multiple times
          [ 'allowedvalue' ],	# list of possible values
     ]],
];

our $servicelist = [
    'servicelist' =>
      [ $servicetype ],
];

our $updateinfoitem = [
    'update' =>
	'from',
	'status',
	'type',
	'version',
	[],
	'id',
	'title',
	'severity',
	'release',
      [ 'issued' =>
	    'date',
      ],
      [ 'updated' =>
	    'date',
      ],
	'reboot_suggested',
      [ 'references' =>
	 [[ 'reference' =>
		'href',
		'id',
		'title',
		'type',
	 ]],
      ],
	'description',
	'message',     #optional popup message
      [ 'pkglist',
	 [[ 'collection' =>
		'short',
		[],
		'name',
	     [[ 'package' =>
		    'name',
		    'epoch',
		    'version',
		    'release',
		    'arch',
		    'src',
		    'supportstatus',	# extension
		    [],
		    'filename',
		  [ 'sum' =>	# obsolete?
			'type',
			'_content',
		  ],
		    'reboot_suggested',
		    'restart_suggested',
		    'relogin_suggested',
	     ]],
	 ]],
      ],
	'patchinforef',			# extension, "project/package"
];

our $updateinfo = [
    'updates' =>
	'xmlns',
      [ $updateinfoitem ],
];

our $deltapackage = [
    'newpackage' =>
	'name',
	'epoch',
	'version',
	'release',
	'arch',
     [[ 'delta' =>
	    'oldepoch',
	    'oldversion',
	    'oldrelease',
	    [],
	    'filename',
	    'sequence',
	    'size',
	  [ 'checksum' =>
		'type',
		'_content',
	  ],
     ]],
];

our $deltainfo = [
    'deltainfo' =>
      [ $deltapackage ],
];

our $prestodelta = [
    'prestodelta' =>
      [ $deltapackage ],
];

our $sourcediff = [
    'sourcediff' =>
	'key',
      [ 'old' =>
	    'project',
	    'package',
	    'rev',
	    'srcmd5',
      ],
      [ 'new' =>
	    'project',
	    'package',
	    'rev',
	    'srcmd5',
      ],
      [ 'files' =>
	 [[ 'file' =>
		'state',	# added, deleted, changed
	      [ 'old' =>
		    'name',
		    'md5',
		    'size',
		    'mtime',
	      ],
	      [ 'new' =>
		    'name',
		    'md5',
		    'size',
		    'mtime',
	      ],
	      [ 'diff' =>
		    'binary',
		    'lines',
		    'shown',
		    '_content',
              ],
         ]],
      ],
      [ 'issues' =>
	 [[ 'issue' =>
		'state',
		'tracker',
		'name',
		'label',
		'url',
	 ]]
      ],
];

our $configuration = [
    'configuration' =>
	[],
	'title',        #webui only
	'description',  #webui only
	'name',         #obsname
	'anonymous',
	'registration',
	'default_access_disabled',
	'default_tracker',
	'allow_user_to_create_home_project',
	'multiaction_notify_support',
	'disallow_group_creation',
	'change_password',
	'cleanup_after_days',
	'hide_private_options',
	'gravatar',
	'enforce_project_keys',
	'download_on_demand',
	'download_url',
	'obs_url',
	'api_url',
	'ymp_url',
	'errbit_url',
	'bugzilla_url',
	'http_proxy',
	'no_proxy',
	'admin_email',
	'theme',
	'cleanup_empty_projects',
	'disable_publish_for_branches',
      [ 'schedulers' =>
	  [ 'arch' ],
      ],
  'unlisted_projects_filter',
  'unlisted_projects_filter_description'
];

our $issue_trackers = [
    'issue-trackers' =>
     [[ 'issue-tracker' =>
	    [],
	    'name',
	    'description',
	    'kind',
            'label',
            'enable-fetch',
	    'regex',
	    'user',
#	    'password',    commented out on purpose, should not reach backend
	    'show-url',
	    'url',
            'issues-updated',
     ]],
];

our $appdataitem = [ 
    'application' =>
      [ 'id' => 
	    'type', 
	    '_content'
      ],
	'pkgname',
	'name',
	'summary',
      [ 'icon' => 
	    'type', 
	    [],
	    'name',
	 [[ 'filecontent' =>
		'file',
		'_content'
         ]],
      ],
      [ 'appcategories' => 
          [ 'appcategory' ] 
      ],
      [ 'mimetypes' =>
          [ 'mimetype' ]
      ],
      [ 'keywords' => 
          [ 'keyword' ]
      ],
      [ 'url' => 
	    'type', 
	    '_content' 
      ]
];
    
our $appdata = [
    'applications' =>
	'version',
      [ $appdataitem ]
];

our $attribute = [
    'attribute' => 
	'namespace', 
        'name', 
        'binary', 
      [ 'value' ],
     [[ 'issue' =>
	    'name',
	    'tracker'
     ]],
];

our $attributes = [
    'attributes' => 
      [ $attribute ],
];

our $size = [
    'size' => 
        'unit',
        [],
        '_content',
];

our $time = [
    'time' => 
        'unit',
        [],
        '_content',
];

# define constraints for build jobs in packages or projects.
our @constraint = (
     [[ 'hostlabel' =>
        'exclude',   # true or false. default is false.
        [],
        '_content' # workers might get labels defined by admin, for example for benchmarking.
     ]],
      [ 'sandbox' =>
	    'exclude',   # true or false. default is false.
	    [],
	    '_content' # xen/kvm/zvm/lxc/emulator/chroot/secure
      ],
      [ 'linux' =>
	  [ 'version' =>
		[],
		'max' ,
		'min' ,
	  ],
	'flavor',
      ],
      [ 'hardware' =>
	  [ 'cpu' =>
	      [ 'flag' ],
	  ],
	    'processors',
	    'jobs',
	  [ 'disk' => $size ],
	  [ 'memory' => $size ],
	  [ 'physicalmemory' => $size ],
      ]
);

our $constraints = [
    'constraints' => 
        @constraint,
     [[ 'overwrite' =>
	  [ 'conditions' =>
              [ 'arch' ],
              [ 'package' ],
          ],
          @constraint,
     ]]
];

our $buildstatistics = [
    'buildstatistics' =>
      [ 'disk' =>
	  [ 'usage' => 
	      [ 'size' =>
		    'unit',
		    [],
		    '_content',
	      ],
	    'io_requests',
	    'io_sectors',
	  ],
      ],
      [ 'memory' =>
	  [ 'usage' => $size ],
      ],
      [ 'times' =>
	  [ 'total' => $time ],
	  [ 'preinstall' => $time ],
	  [ 'install' => $time ],
	  [ 'main' => $time ],
	  [ 'download' => $time ],
      ],
      [ 'download' =>
	    [],
	    $size,
	    'binaries',
	    'cachehits',
	    'preinstallimage',
      ],
];

our $notifications = [
    'notifications' =>
	'next',
	'sync',
	'limit_reached',
     [[ 'notification' =>
	    'type',
	    'time',
	 [[ 'data' =>
		'key',
		'_content',
	 ]],
     ]],
];

our $frozenlinks = [
    'frozenlinks' =>
     [[ 'frozenlink' =>
	    'project',
	 [[ 'package' =>
		'name',
		'srcmd5',
		'vrev',
	 ]],
     ]],
];

our $report = [
    'report' =>
	'epoch',
	'version',
	'release',
	'binaryarch',
	'buildtime',
	'buildhost',
	'disturl',
	'binaryid',
     [[ 'binary' =>
	    'name',
	    'epoch',
	    'version',
	    'release',
	    'binaryarch',
	    'buildtime',
	    'buildhost',
	    'disturl',
	    'binaryid',
	    'supportstatus',

	    'project',
	    'repository',
	    'package',
	    'arch',		# schedulerarch

	    '_content',
     ]],
];

our $publishedpath = [
    'publishedpath' =>
	'project',
	'repository',
	'medium',
	[],
	'path',
	'url',
];

our $multibuild = [
    'multibuild' =>
	  [ 'package' ],	# obsolete
	  [ 'flavor' ],
];

our $pubkeyinfo = [
    'pubkey' =>
	'keyid',
	'algo',
	'keysize',
	'expires',
	'fingerprint',
	'_content',
];

our $keyinfo = [
    'keyinfo' =>
	'project',
        $pubkeyinfo,
	'sslcert',
];

our $binannotation = [
    'annotation' =>
     [[ 'repo' =>
	    'url',
	    'project',
	    'repository',
	    'priority',
     ]],
	'buildtime',
	'buildhost',
	'disturl',
	'binaryid',
	'package',		# only in build job annotation
	'epoch',		# only in build job annotation
	'version',		# only in build job annotation
	'release',		# only in build job annotation
	'binaryarch',		# only in build job annotation
	'hdrmd5',		# only in build job annotation
];

our $availablebinaries = [
    'availablebinaries' =>
     [[ 'packages' =>
	  [ 'arch' ],
	  [ 'name' ],
    ]],
     [[ 'products' =>
	  [ 'arch' ],
	  [ 'name' ],
    ]],
     [[ 'patterns' =>
	  [ 'arch' ],
	  [ 'name' ],
    ]],
];

our $clouduploadjob = [
    'clouduploadjob' =>
	'name',
	[],
	'state',		# created, receiving, scheduled, uploading, succeeded, waiting, failed
	'details',		# error messages, upload result string
	'progress',		# percentage completed
	'try',			# retry count
	'created',		# when was this job created

	'user',			# who did this
	'target',		# where to upload to

	'project',
	'repository',
	'package',
	'arch',
	'filename',		# what to upload
	'size',

	'pid',		# internal
];

our $clouduploadjoblist = [
    'clouduploadjoblist' =>
      [ $clouduploadjob ],
];

our $regrepoowner = [
    'regrepoowner' =>
	'regrepo',
	'project',
	'repository',
];

1;

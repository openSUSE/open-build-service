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
# Build Service Configuration
#

package BSConfig;

our $srcserver = 'http://127.0.42.1:5352';
our $reposerver = 'http://127.0.42.1:5252';
#our $stageserver = 'rsync://127.0.42.1/put-repos-main';
#our $stageserver_sync = 'rsync://127.0.42.1/trigger-repos-sync';
our $repodownload = 'http://127.0.42.1/repositories';
our $sign = '/usr/bin/sign';
our $bsdir = '/srv/obs';
#our $keyfile = '/srv/obs/my-public-key-file.asc';

#our @reposervers = ('http://127.0.42.1:5252', 'http://127.0.42.1:6262');
our @reposervers = ('http://127.0.42.1:5252');

our $bsuser = 'adrian';
our $bsgroup = 'users';

1;

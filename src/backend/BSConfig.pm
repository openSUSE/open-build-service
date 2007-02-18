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

our $srcserver = 'http://storage:5352';
our $reposerver = 'http://storage:5252';
our $stageserver = 'rsync://149.44.161.5/put-repos-main';
our $stageserver_sync = 'rsync://149.44.161.5/trigger-repos-sync';
our $repodownload = 'http://software.opensuse.org/download/repositories';
our $sign = '/root/bin/sign';
our $bsdir = '/bs';
our $keyfile = '/bs/openSUSE-Build-Service.asc';

our @reposervers = ('http://storage:5252', 'http://storage:6262');

our $bsuser = 'bsrun';
our $bsgroup = 'bsrun';

1;

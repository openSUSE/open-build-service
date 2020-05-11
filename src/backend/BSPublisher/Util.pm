#
# Copyright (c) 2018 SUSE LLC
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
# utility functions for the publisher
#

package BSPublisher::Util;

use BSUtil;

use strict;

=head1 qsystem - secure execution of system calls with output redirection

 Examples:

   qsystem('stdout', $tempfile, $decomp, $in);

   qsystem('chdir', $extrep, 'stdout', 'Packages.new', 'dpkg-scanpackages', '-m', '.', '/dev/null')

=cut

sub qsystem {
  my @args = @_;
  my $pid;
  my ($rh, $wh);
  if ($args[0] eq 'echo') {
    pipe($rh, $wh) || die("pipe: $!\n");
  }
  if (!($pid = xfork())) {
    if ($rh) {
      close $wh;
      open(STDIN, '<&', $rh);
      close $rh;
      splice(@args, 0, 2);
    }
    if ($args[0] eq 'chdir') {
      chdir($args[1]) || die("chdir $args[1]: $!\n");
      splice(@args, 0, 2);
    }
    if ($args[0] eq 'stdout') {
      if ($args[1] ne '') {
        open(STDOUT, '>', $args[1]) || die("$args[1]: $!\n");
      }
      splice(@args, 0, 2);
    } else {
      open(STDOUT, '>', '/dev/null');
    }
    eval {
      exec(@args);
      die("$args[0]: $!\n");
    };
    warn($@) if $@;
    exit 1;
  }
  if ($rh) {
    close $rh;
    print $wh $args[1];
    close $wh;
  }
  waitpid($pid, 0) == $pid || die("waitpid $pid: $!\n");
  return $?;
}

1;

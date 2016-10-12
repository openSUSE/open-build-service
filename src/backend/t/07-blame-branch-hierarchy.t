#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 25;

use BSBlameTest qw(blame_is list_like create commit branch);

# This testcase tests different levels of branch hierarchies (a branch of
# a branch etc.) and the latest automerge code in such scenarios.

create("origin", "opkg5");
commit("origin", "opkg5", {time => 1}, testfile => <<EOF);
This will be a file with
three sections.
EOF
commit("origin", "opkg5", {time => 3}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
EOF

create("branch", "pkg51");
branch("branch", "pkg51", "origin", "opkg5", time => 4);
commit("branch", "pkg51", {keeplink => 1, time => 5}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
Section 1 end.
Section 2 start:
A line from branch/pkg51.
Section 2 end.
Section 3 start:
Section 3 end.
EOF
commit("origin", "opkg5", {time => 7}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
EOF
blame_is("pkg51 at r2", "branch", "pkg51", "testfile", expected => <<EOF);
origin/opkg5/r2: This is a file with
origin/opkg5/r1: three sections.
origin/opkg5/r2: Section 1 start:
origin/opkg5/r3: A line from origin/opkg5.
origin/opkg5/r2: Section 1 end.
origin/opkg5/r2: Section 2 start:
branch/pkg51/r2: A line from branch/pkg51.
origin/opkg5/r2: Section 2 end.
origin/opkg5/r2: Section 3 start:
origin/opkg5/r2: Section 3 end.
EOF

create("branch", "pkg52");
branch("branch", "pkg52", "branch", "pkg51", time => 8);
list_like("opkg52 at r1: check baserev", "branch", "pkg52",
  xpath => './linkinfo[@baserev = "ac8101a21ae17c3e6ed9fce8aa525d2a"]');
commit("branch", "pkg52", {keeplink => 1, time => 10}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Section 1 end.
Section 2 start:
A line from branch/pkg51.
Section 2 end.
Section 3 start:
A line from branch/pkg52.
Section 3 end.
EOF
list_like("pkg52 at r2: check baserev", "branch", "pkg52",
  xpath => './linkinfo[@baserev = "ac8101a21ae17c3e6ed9fce8aa525d2a"]');
blame_is("pkg52 at r2", "branch", "pkg52", "testfile", expected => <<EOF);
origin/opkg5/r2: This is a file with
origin/opkg5/r1: three sections.
origin/opkg5/r2: Section 1 start:
origin/opkg5/r3: A line from origin/opkg5.
origin/opkg5/r2: Section 1 end.
origin/opkg5/r2: Section 2 start:
branch/pkg51/r2: A line from branch/pkg51.
origin/opkg5/r2: Section 2 end.
origin/opkg5/r2: Section 3 start:
branch/pkg52/r2: A line from branch/pkg52.
origin/opkg5/r2: Section 3 end.
EOF

# change origin
commit("origin", "opkg5", {time => 17}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
EOF
list_like("origin at r4", "origin", "opkg5",
  xpath => '@rev = 4 and @srcmd5 = "0651c080ed80a45fbbb5bbc5aca5a292"');
blame_is("pkg52 at r2 (origin changed)", "branch", "pkg52", "testfile", expected => <<EOF);
origin/opkg5/r2: This is a file with
origin/opkg5/r1: three sections.
origin/opkg5/r2: Section 1 start:
origin/opkg5/r3: A line from origin/opkg5.
origin/opkg5/r4: Yet another line from origin/opkg5.
origin/opkg5/r2: Section 1 end.
origin/opkg5/r2: Section 2 start:
branch/pkg51/r2: A line from branch/pkg51.
origin/opkg5/r2: Section 2 end.
origin/opkg5/r2: Section 3 start:
branch/pkg52/r2: A line from branch/pkg52.
origin/opkg5/r2: Section 3 end.
EOF

# change branch/pkg51
commit("branch", "pkg51", {keeplink => 1, time => 18}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
A line from branch/pkg51.
Yet another line from branch/pkg51.
Section 2 end.
Section 3 start:
Section 3 end.
EOF
# and another change to branch/pkg51
commit("branch", "pkg51", {keeplink => 1, time => 22}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
A line from branch/pkg51.
Yet another line from branch/pkg51.
A third line from branch/pkg51.
Section 2 end.
Section 3 start:
Section 3 end.
EOF
list_like("pkg51: check baserev at r4", "branch", "pkg51",
  xpath => '@rev = 4 and ./linkinfo[@baserev = "0651c080ed80a45fbbb5bbc5aca5a292"]');
blame_is("pkg52 at r2 (pkg51 changed)", "branch", "pkg52", "testfile", expected => <<EOF);
origin/opkg5/r2: This is a file with
origin/opkg5/r1: three sections.
origin/opkg5/r2: Section 1 start:
origin/opkg5/r3: A line from origin/opkg5.
origin/opkg5/r4: Yet another line from origin/opkg5.
origin/opkg5/r2: Section 1 end.
origin/opkg5/r2: Section 2 start:
branch/pkg51/r2: A line from branch/pkg51.
branch/pkg51/r3: Yet another line from branch/pkg51.
branch/pkg51/r4: A third line from branch/pkg51.
origin/opkg5/r2: Section 2 end.
origin/opkg5/r2: Section 3 start:
branch/pkg52/r2: A line from branch/pkg52.
origin/opkg5/r2: Section 3 end.
EOF

# construct several conflicts to test the "latest automerge" code
# no conflict
commit("origin", "opkg5", {time => 29}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
EOF
list_like("pkg52 at r2: no conflict (origin changed)", "branch", "pkg52",
  xpath => 'not(./linkinfo/@error)');
# conflict
commit("origin", "opkg5", {time => 30}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
A temporary line.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Conflict from origin.
Section 3 end.
A line from the origin at EOF.
EOF
list_like("origin at r6", "origin", "opkg5", xpath => '@rev = 6');
list_like("pkg52 at r2: conflict (origin changed)", "branch", "pkg52",
  xpath => './linkinfo/@error');
# no conflict
commit("origin", "opkg5", {time => 33}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
A line from the origin at EOF.
A second line from the origin at EOF.
EOF
list_like("pkg52 at r2: no conflict (origin changed)", "branch", "pkg52",
  xpath => 'not(./linkinfo/@error)');
# and a conflict again (without the last two lines)
commit("origin", "opkg5", {time => 34}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Conflict from origin.
Section 3 end.
EOF
# r8 ^^
# add the two last lines again (still a conflict)
commit("origin", "opkg5", {time => 35}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Conflict from origin.
Section 3 end.
A line from the origin at EOF.
A second line from the origin at EOF.
EOF
# remove the last two lines again (same as in r8)
commit("origin", "opkg5", {time => 37}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Conflict from origin.
Section 3 end.
EOF
list_like("origin at r10", "origin", "opkg5", xpath => '@rev = 10');
list_like("pkg52 at r2: conflict (origin changed)", "branch", "pkg52",
  xpath => './linkinfo/@error');
# but no conflict in pkg51
list_like("pkg51 at r4: no conflict (origin changed)", "branch", "pkg51",
  xpath => 'not(./linkinfo/@error)');
# commit in pkg51
commit("branch", "pkg51", {keeplink => 1, time => 39}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
A line from branch/pkg51.
Yet another line from branch/pkg51.
A third line from branch/pkg51.
A fourth line from branch/pkg51.
Section 2 end.
Section 3 start:
Conflict from origin.
Section 3 end.
EOF
# yet another commit in pkg51
commit("branch", "pkg51", {keeplink => 1, time => 41}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
A line from branch/pkg51.
Yet another line from branch/pkg51.
A third line from branch/pkg51.
A fourth line from branch/pkg51.
A fifth line from branch/pkg51.
Section 2 end.
Section 3 start:
Conflict from branch/pkg51.
Section 3 end.
EOF
list_like("pkg51 at r6: check baserev", "branch", "pkg51",
  xpath => '@rev = 6 and ./linkinfo[@baserev = "ec10c813e05d7852616cedb7618455e7"]');
# introduce a conflict for pkg51 (conflict in section 3)
commit("origin", "opkg5", {time => 42}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Conflict from origin.
(Affects: pkg51 and pkg52).
Section 3 end.
EOF
list_like("origin at r11", "origin", "opkg5", xpath => '@rev = 11');
list_like("pkg51 at r6: conflict (origin changed)", "branch", "pkg51",
  xpath => '@rev = 6 and ./linkinfo/@error');
# resolve conflict in pkg51
commit("branch", "pkg51", {keeplink => 1, repairlink => 1, linkrev => "cbdda8e56f0cbc572b41551e6044e0a7", time => 47, newcontent => 1},
  testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
A line from branch/pkg51.
Yet another line from branch/pkg51.
A third line from branch/pkg51.
A fourth line from branch/pkg51.
A fifth line from branch/pkg51.
Section 2 end.
Section 3 start:
Resolved pkg51:
Conflict from branch/pkg51.
Conflict from origin.
(Affects: pkg51 and pkg52).
Resolved pkg51 end.
Section 3 end.
EOF
blame_is("pkg51 at r7 (resolved conflict)", "branch", "pkg51", "testfile", expected => <<EOF);
origin/opkg5/r2: This is a file with
origin/opkg5/r1: three sections.
origin/opkg5/r2: Section 1 start:
origin/opkg5/r3: A line from origin/opkg5.
origin/opkg5/r7: Yet another line from origin/opkg5.
origin/opkg5/r2: Section 1 end.
origin/opkg5/r2: Section 2 start:
branch/pkg51/r2: A line from branch/pkg51.
branch/pkg51/r3: Yet another line from branch/pkg51.
branch/pkg51/r4: A third line from branch/pkg51.
branch/pkg51/r5: A fourth line from branch/pkg51.
branch/pkg51/r6: A fifth line from branch/pkg51.
origin/opkg5/r2: Section 2 end.
origin/opkg5/r2: Section 3 start:
branch/pkg51/r7: Resolved pkg51:
branch/pkg51/r6: Conflict from branch/pkg51.
origin/opkg5/r8: Conflict from origin.
origin/opkg5/r11: (Affects: pkg51 and pkg52).
branch/pkg51/r7: Resolved pkg51 end.
origin/opkg5/r2: Section 3 end.
EOF

# still a conflict in pkg52
list_like("pkg52 at r2: conflict (origin changed)", "branch", "pkg52",
  xpath => './linkinfo/@error');
# resolve conflict in pkg52
commit("branch", "pkg52", {keeplink => 1, repairlink => 1, linkrev => "4992dda291552daaccd2d9ed31717634", time => 50, newcontent => 1},
  testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
A line from branch/pkg51.
Yet another line from branch/pkg51.
A third line from branch/pkg51.
A fourth line from branch/pkg51.
A fifth line from branch/pkg51.
Section 2 end.
Section 3 start:
Resolved pkg52:
Resolved pkg51:
Conflict from branch/pkg51.
Conflict from origin.
(Affects: pkg51 and pkg52).
Resolved pkg51 end.
A line from branch/pkg52.
Resolved pkg52 end.
Section 3 end.
A line from the origin at EOF.
A second line from the origin at EOF.
EOF
list_like("pkg52 at r3: check baserev and no conflict", "branch", "pkg52",
  xpath => './linkinfo[@baserev = "4992dda291552daaccd2d9ed31717634" and not(@error)]');

blame_is("pkg52 at r3 (resolved conflict)", "branch", "pkg52", "testfile",
  expected => <<EOF);
origin/opkg5/r2: This is a file with
origin/opkg5/r1: three sections.
origin/opkg5/r2: Section 1 start:
origin/opkg5/r3: A line from origin/opkg5.
origin/opkg5/r7: Yet another line from origin/opkg5.
origin/opkg5/r2: Section 1 end.
origin/opkg5/r2: Section 2 start:
branch/pkg51/r2: A line from branch/pkg51.
branch/pkg51/r3: Yet another line from branch/pkg51.
branch/pkg51/r4: A third line from branch/pkg51.
branch/pkg51/r5: A fourth line from branch/pkg51.
branch/pkg51/r6: A fifth line from branch/pkg51.
origin/opkg5/r2: Section 2 end.
origin/opkg5/r2: Section 3 start:
branch/pkg52/r3: Resolved pkg52:
branch/pkg51/r7: Resolved pkg51:
branch/pkg51/r6: Conflict from branch/pkg51.
origin/opkg5/r8: Conflict from origin.
origin/opkg5/r11: (Affects: pkg51 and pkg52).
branch/pkg51/r7: Resolved pkg51 end.
branch/pkg52/r2: A line from branch/pkg52.
branch/pkg52/r3: Resolved pkg52 end.
origin/opkg5/r2: Section 3 end.
origin/opkg5/r6: A line from the origin at EOF.
origin/opkg5/r7: A second line from the origin at EOF.
EOF

# introduce two more hierarchy levels
create("branch", "pkg53");
create("branch", "pkg54");
branch("branch", "pkg53", "branch", "pkg52", time => 51);
branch("branch", "pkg54", "branch", "pkg53", time => 57);
# simplify testfile in pkg54 a bit
commit("branch", "pkg54", {keeplink => 1, time => 61}, testfile => <<EOF);
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
A line from branch/pkg51.
Yet another line from branch/pkg51.
A third line from branch/pkg51.
A fourth line from branch/pkg51.
A fifth line from branch/pkg51.
Section 2 end.
A line from the origin at EOF.
A second line from the origin at EOF.
EOF
# change origin
commit("origin", "opkg5", {time => 82}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Conflict from origin.
(Affects: pkg51 and pkg52).
Section 3 end.
A line from the origin at EOF.
A second line from the origin at EOF.
EOF
list_like("origin at r12", "origin", "opkg5", xpath => '@rev = 12');
# change pkg51
commit("branch", "pkg51", {keeplink => 1, time => 99}, testfile => <<EOF);
This is a file with
three sections.
Section 1 start:
A line from origin/opkg5.
Yet another line from origin/opkg5.
Section 1 end.
Section 2 start:
Only this line is left.
Section 2 end.
Section 3 start:
Resolved pkg51:
Conflict from branch/pkg51.
Conflict from origin.
(Affects: pkg51 and pkg52).
Resolved pkg51 end.
Section 3 end.
EOF
list_like("pkg51 at r8", "branch", "pkg51", xpath => '@rev = 8');

blame_is("pkg54 at r2", "branch", "pkg54", "testfile", expected => <<EOF);
origin/opkg5/r2: Section 1 start:
origin/opkg5/r3: A line from origin/opkg5.
origin/opkg5/r7: Yet another line from origin/opkg5.
origin/opkg5/r2: Section 1 end.
origin/opkg5/r2: Section 2 start:
branch/pkg51/r8: Only this line is left.
origin/opkg5/r2: Section 2 end.
origin/opkg5/r6: A line from the origin at EOF.
origin/opkg5/r7: A second line from the origin at EOF.
EOF

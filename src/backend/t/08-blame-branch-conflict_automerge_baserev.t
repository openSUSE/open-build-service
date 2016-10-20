#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;

use BSBlameTest qw(blame_is list_like create commit branch);

# The goal of this testcase is to construct a scenario where the latest
# automerge code is only able to return the baserev. Also, we sneak in an
# expandable rev that violates the latest automerge semantics (hence, it is
# not supposed to be found by the latest automerge code).

create("branch", "pkg61");
commit("branch", "pkg61", {time => 1}, testfile => <<EOF);
Section 1 start:
First line.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Section 4 end.
EOF
create("branch", "pkg62");
branch("branch", "pkg62", "branch", "pkg61", time => 3);
commit("branch", "pkg61", {time => 4}, testfile => <<EOF);
Section 1 start:
First line changed.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Section 4 end.
EOF
commit("branch", "pkg62", {keeplink => 1, time => 8}, testfile => <<EOF);
Section 1 start:
First line changed.
Section 1 end.
Section 2 start:
Second line.
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Section 4 end.
EOF
create("branch", "pkg63");
branch("branch", "pkg63", "branch", "pkg62", time => 9);
commit("branch", "pkg62", {keeplink => 1, time => 10}, testfile => <<EOF);
Section 1 start:
First line changed.
Section 1 end.
Section 2 start:
Second line changed again.
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Section 4 end.
EOF
commit("branch", "pkg63", {keeplink => 1, time => 12}, testfile => <<EOF);
Section 1 start:
First line changed.
Section 1 end.
Section 2 start:
Second line changed again.
Section 2 end.
Section 3 start:
Third line.
Section 3 end.
Section 4 start:
Section 4 end.
EOF
create("branch", "pkg64");
branch("branch", "pkg64", "branch", "pkg63", time => 15);
commit("branch", "pkg64", {keeplink => 1, time => 17}, testfile => <<EOF);
Section 1 start:
First line changed.
Section 1 end.
Section 2 start:
Second line changed again.
Section 2 end.
Section 3 start:
Third line.
Section 3 end.
Section 4 start:
Fourth line.
Section 4 end.
EOF
# later, we construct a conflict such that the automerge code is only able
# to return pkg64's baserev
blame_is("blame: pkg64 at r2 (against baserev)", "branch", "pkg64", "testfile", expected => <<EOF);
branch/pkg61/r1: Section 1 start:
branch/pkg61/r2: First line changed.
branch/pkg61/r1: Section 1 end.
branch/pkg61/r1: Section 2 start:
branch/pkg62/r3: Second line changed again.
branch/pkg61/r1: Section 2 end.
branch/pkg61/r1: Section 3 start:
branch/pkg63/r2: Third line.
branch/pkg61/r1: Section 3 end.
branch/pkg61/r1: Section 4 start:
branch/pkg64/r2: Fourth line.
branch/pkg61/r1: Section 4 end.
EOF

commit("branch", "pkg61", {time => 20}, testfile => <<EOF);
Section 1 start:
First line changed again.
This line occurs in the resolved file.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Conflict.
Section 4 end.
EOF
list_like("pkg61 at r3: check rev", "branch", "pkg61",
  xpath => '@rev = 3');
commit("branch", "pkg62", {keeplink => 1, time => 24}, testfile => <<EOF);
Section 1 start:
First line changed again.
This line occurs in the resolved file.
Section 1 end.
Section 2 start:
Yet another change in the second line.
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Conflict.
Section 4 end.
EOF
commit("branch", "pkg62", {keeplink => 1, time => 27}, testfile => <<EOF);
Section 1 start:
First line changed again.
This line occurs in the resolved file.
Section 1 end.
Section 2 start:
Last change in the second line.
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Conflict.
Section 4 end.
EOF

# pkg61 at r4: introduce a change that conflicts with pkg62/r2,
#              pkg62/r4, pkg62/r5, but not with pkg62/r3
commit("branch", "pkg61", {time => 30}, testfile => <<EOF);
Section 1 start:
First line changed again.
This line occurs in the resolved file.
Section 1 end.
Section 2 start:
Second line changed again.
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Section 4 end.
EOF
list_like("pkg62 at r3: no conflict", "branch", "pkg62", rev => '3',
  xpath => '@rev = 3 and not(./linkinfo/@error)');
list_like("pkg62 at r4: conflict", "branch", "pkg62", rev => '4',
  xpath => '@rev = 4 and ./linkinfo/@error');
list_like("pkg62 at r5: conflict", "branch", "pkg62",
  xpath => '@rev = 5 and ./linkinfo/@error');
# remove conflict for pkg62, but introduce conflict line for pkg64 again
commit("branch", "pkg61", {time => 30}, testfile => <<EOF);
Section 1 start:
First line changed again.
This line occurs in the resolved file.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Conflict.
Section 4 end.
EOF

list_like("pkg62 at r5: no conflict", "branch", "pkg62",
  xpath => '@rev = 5 and not(./linkinfo/@error)');

commit("branch", "pkg63", {keeplink => 1, time => 35}, testfile => <<EOF);
Section 1 start:
First line changed again.
This line occurs in the resolved file.
Section 1 end.
Section 2 start:
Last change in the second line.
Section 2 end.
Section 3 start:
Third line changed.
Section 3 end.
Section 4 start:
Conflict.
Section 4 end.
EOF
list_like("pkg63 at r3: no conflict", "branch", "pkg63",
  xpath => '@rev = 3 and not(./linkinfo/@error)');
blame_is("blame: pkg63 at r3", "branch", "pkg63", "testfile", expected => <<EOF);
branch/pkg61/r1: Section 1 start:
branch/pkg61/r3: First line changed again.
branch/pkg61/r3: This line occurs in the resolved file.
branch/pkg61/r1: Section 1 end.
branch/pkg61/r1: Section 2 start:
branch/pkg62/r5: Last change in the second line.
branch/pkg61/r1: Section 2 end.
branch/pkg61/r1: Section 3 start:
branch/pkg63/r3: Third line changed.
branch/pkg61/r1: Section 3 end.
branch/pkg61/r1: Section 4 start:
branch/pkg61/r3: Conflict.
branch/pkg61/r1: Section 4 end.
EOF

list_like("pkg64 at r2: conflict", "branch", "pkg64",
  xpath => '@rev = 2 and ./linkinfo/@error');
# note that the line "This line occurs in the resolved file." is removed
commit("branch", "pkg61", {time => 37}, testfile => <<EOF);
Section 1 start:
Yet another change in the first line.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Conflict.
Section 4 end.
EOF
commit("branch", "pkg63", {keeplink => 1, time => 39}, testfile => <<EOF);
Section 1 start:
Yet another change in the first line.
Section 1 end.
Section 2 start:
Last change in the second line.
Section 2 end.
Section 3 start:
Last change in the third line.
Section 3 end.
Section 4 start:
Conflict.
Section 4 end.
EOF
commit("branch", "pkg61", {time => 42}, testfile => <<EOF);
Section 1 start:
Last change in the first line.
Section 1 end.
Section 2 start:
Section 2 end.
Section 3 start:
Section 3 end.
Section 4 start:
Conflict.
Section 4 end.
EOF
list_like("pkg63 at r4: no conflict", "branch", "pkg63",
  xpath => '@rev = 4 and not(./linkinfo/@error)');
blame_is("blame: pkg63 at r4", "branch", "pkg63", "testfile", expected => <<EOF);
branch/pkg61/r1: Section 1 start:
branch/pkg61/r7: Last change in the first line.
branch/pkg61/r1: Section 1 end.
branch/pkg61/r1: Section 2 start:
branch/pkg62/r5: Last change in the second line.
branch/pkg61/r1: Section 2 end.
branch/pkg61/r1: Section 3 start:
branch/pkg63/r4: Last change in the third line.
branch/pkg61/r1: Section 3 end.
branch/pkg61/r1: Section 4 start:
branch/pkg61/r3: Conflict.
branch/pkg61/r1: Section 4 end.
EOF
#list_like("pkg63 at r4: check xsrcmd5", "branch", "pkg63",
#  xpath => './linkinfo[@xsrcmd5 = "ebe6004cc0ec9690ea35e25823ab3846"]');
list_like("pkg63 at r4: check xsrcmd5", "branch", "pkg63",
  xpath => './linkinfo[@xsrcmd5 = "1551eb8db01539dd0dfd87760f5e1714"]');
list_like("pkg64 at r2: conflict", "branch", "pkg64",
  xpath => '@rev = 2 and ./linkinfo/@error');
# now resolve the conflict
#commit("branch", "pkg64", {keeplink => 1, repairlink => 1, linkrev => "ebe6004cc0ec9690ea35e25823ab3846", time => 47, newcontent => 1},
commit("branch", "pkg64", {keeplink => 1, repairlink => 1, linkrev => "1551eb8db01539dd0dfd87760f5e1714", time => 47, newcontent => 1},
  testfile => <<EOF);
Section 1 start:
Last change in the first line.
This line occurs in the resolved file.
Section 1 end.
Section 2 start:
Last change in the second line.
Second line changed again.
Section 2 end.
Section 3 start:
Last change in the third line.
Third line.
Section 3 end.
Section 4 start:
Conflict.
Fourth line.
Section 4 end.
And an additional last line.
EOF
list_like("pkg64 at r3 and no conflict", "branch", "pkg64",
  xpath => '@rev = 3 and not(./linkinfo/@error)');
# pkg64/496280d71af069b9d08f862dc56f13ca represents an expanded rev and
# the "testfile" file, which is part of this rev, contains the line
# "This line occurs in the resolved file.". The latest automerge code is
# not supposed to find this rev (if it would, the following blame_is will
# fail, because the line "This line occurs in the resolved file." would
# originate from pkg61/r3).
# This rev "comprises": pkg64/r2, pkg63/r2, pkg62/r3, pkg61/r4
# (pkg61/r4 "violates" the automerge semantics)
list_like("pkg64: illegal rev has no conflict", "branch", "pkg64",
  rev => '496280d71af069b9d08f862dc56f13ca',
  xpath => 'not(./linkinfo/@error)');
# here, the latest automerge code is supposed to find the baserev
blame_is("blame: pkg64 at r3 after conflict resolution", "branch", "pkg64",
  "testfile", expected => <<EOF);
branch/pkg61/r1: Section 1 start:
branch/pkg61/r7: Last change in the first line.
branch/pkg64/r3: This line occurs in the resolved file.
branch/pkg61/r1: Section 1 end.
branch/pkg61/r1: Section 2 start:
branch/pkg62/r5: Last change in the second line.
branch/pkg62/r3: Second line changed again.
branch/pkg61/r1: Section 2 end.
branch/pkg61/r1: Section 3 start:
branch/pkg63/r4: Last change in the third line.
branch/pkg63/r2: Third line.
branch/pkg61/r1: Section 3 end.
branch/pkg61/r1: Section 4 start:
branch/pkg61/r3: Conflict.
branch/pkg64/r2: Fourth line.
branch/pkg61/r1: Section 4 end.
branch/pkg64/r3: And an additional last line.
EOF

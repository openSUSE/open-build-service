#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 27;

use BSBlameTest qw(blame_is list_like create commit del branch);

create("origin", "opkg4");
commit("origin", "opkg4", {}, testfile => <<EOF);
This is a
simple text.

Section start:
Here, we will have a conflict soon.
Section end.
EOF

create("branch", "pkg4");
branch("branch", "pkg4", "origin", "opkg4");
list_like("check baserev", "branch", "pkg4", xpath => './linkinfo[@baserev = "14d20514b8eb04c5477b0a31df2a32b8"]');
blame_is("directly after branch", "branch", "pkg4", "testfile", expected => <<EOF);
origin/opkg4/r1: This is a
origin/opkg4/r1: simple text.
origin/opkg4/r1: 
origin/opkg4/r1: Section start:
origin/opkg4/r1: Here, we will have a conflict soon.
origin/opkg4/r1: Section end.
EOF

commit("branch", "pkg4", {keeplink => 1}, testfile => <<EOF);
This is a
simple text.

Section start:
A line from the branch.
Section end.
EOF
blame_is("branch at r2", "branch", "pkg4", "testfile", expected => <<EOF);
origin/opkg4/r1: This is a
origin/opkg4/r1: simple text.
origin/opkg4/r1: 
origin/opkg4/r1: Section start:
branch/pkg4/r2: A line from the branch.
origin/opkg4/r1: Section end.
EOF

commit("origin", "opkg4", {}, testfile => <<EOF);
This is a
simple text.

Section start:
Here, we will have a conflict soon.
Section end.

This line does not cause a conflict.
EOF
blame_is("branch at r1 (origin changed)", "branch", "pkg4", "testfile", expected => <<EOF);
origin/opkg4/r1: This is a
origin/opkg4/r1: simple text.
origin/opkg4/r1: 
origin/opkg4/r1: Section start:
branch/pkg4/r2: A line from the branch.
origin/opkg4/r1: Section end.
origin/opkg4/r2: 
origin/opkg4/r2: This line does not cause a conflict.
EOF

commit("origin", "opkg4", {}, testfile => undef);
list_like("conflict since testfile was removed from origin", "branch", "pkg4", xpath => './linkinfo/@error');
commit("origin", "opkg4", {}, testfile => <<EOF);
This is a
simple text.

Section start:
A line from the origin.
Section end.
EOF
list_like("origin/opkg4 is at r4", "origin", "opkg4",
  xpath => '@rev = 4 and @srcmd5 = "2b4b0e8d610f44d9fb9d6b934cef4c39"');
list_like("check baserev and conflict", "branch", "pkg4",
  xpath => './linkinfo[@baserev = "14d20514b8eb04c5477b0a31df2a32b8" and @error]');

# resolve conflict in the branch
commit("branch", "pkg4", {keeplink => 1, repairlink => 1, linkrev => "2b4b0e8d610f44d9fb9d6b934cef4c39", newcontent => 1},
  testfile => <<EOF);
This is a
simple text.

Section start:
Resolved:
A line from the branch.
A line from the origin.
Section end.

This line does not cause a conflict.
EOF
list_like("check baserev and no conflict", "branch", "pkg4",
  xpath => './linkinfo[@baserev = "2b4b0e8d610f44d9fb9d6b934cef4c39" and not(@error)]');

# the last two lines come from the last working automerge
blame_is("branch at r3 (resolved conflict)", "branch", "pkg4", "testfile", expected => <<EOF);
origin/opkg4/r4: This is a
origin/opkg4/r4: simple text.
origin/opkg4/r4: 
origin/opkg4/r4: Section start:
branch/pkg4/r3: Resolved:
branch/pkg4/r2: A line from the branch.
origin/opkg4/r4: A line from the origin.
origin/opkg4/r4: Section end.
origin/opkg4/r2: 
origin/opkg4/r2: This line does not cause a conflict.
EOF

# change file in the branch
commit("branch", "pkg4", {keeplink => 1}, testfile => <<EOF);
This is a
quite
simple text.

Section start:
Resolved:
A line from the branch.
Another line from the branch.
A line from the origin.
Section end.
EOF
# change file in origin
commit("origin", "opkg4", {}, testfile => <<EOF);
This is a
simple text.

Section start:
A line from the origin.
Section end.
EOF
list_like("check baserev and no conflict in r4", "branch", "pkg4",
  xpath => './linkinfo[@baserev = "2b4b0e8d610f44d9fb9d6b934cef4c39" and not(@error)]');
# introduce a conflict
commit("origin", "opkg4", {}, testfile => <<EOF);
This is a
short file.
EOF
list_like("conflict (origin at r6)", "branch", "pkg4",
  xpath => './linkinfo/@error');
# introduce another conflict
commit("origin", "opkg4", {}, testfile => <<EOF);
This is a
simple text.

Section 1 start:
Nested section start:
Nested section end.
Section 1 end.

Section start:
Conflict.
Section end.
EOF
list_like("conflict (origin at r7)", "branch", "pkg4",
  xpath => './linkinfo/@error');
# "resolve" conflict in the origin
commit("origin", "opkg4", {}, testfile => <<EOF);
This is a
simple text.

Section 1 start:
Nested section start:
Nested section end.
Section 1 end.

Section start:
A line from the origin.
Section end.

Yet another line from the origin.
EOF
# this is only needed for understanding the testcase
blame_is("origin at r8", "origin", "opkg4", "testfile", expected => <<EOF);
origin/opkg4/r4: This is a
origin/opkg4/r7: simple text.
origin/opkg4/r7: 
origin/opkg4/r7: Section 1 start:
origin/opkg4/r7: Nested section start:
origin/opkg4/r7: Nested section end.
origin/opkg4/r7: Section 1 end.
origin/opkg4/r7: 
origin/opkg4/r7: Section start:
origin/opkg4/r8: A line from the origin.
origin/opkg4/r7: Section end.
origin/opkg4/r8: 
origin/opkg4/r8: Yet another line from the origin.
EOF

list_like("no conflict (origin at r8)", "branch", "pkg4",
  xpath => 'not(./linkinfo/@error)');
# introduce yet another conflict
commit("origin", "opkg4", {}, testfile => <<EOF);
This is a
simple text.

Section 1 start:
Nested section start:
Nested section end.
Section 1 end.

Section start:
Another line from the origin.
Section end.
EOF
list_like("origin at r9", "origin", "opkg4",
  xpath => '@rev = 9 and @srcmd5 = "417a4a60603b8f8fdb0bca16ecafa910"');
list_like("check baserev and conflict in r4 (origin at r9)", "branch", "pkg4",
  xpath => '@rev = 4 and ./linkinfo[@baserev = "2b4b0e8d610f44d9fb9d6b934cef4c39" and @error]');

# resolve conflict in the branch
commit("branch", "pkg4", {keeplink => 1, repairlink => 1, linkrev => "417a4a60603b8f8fdb0bca16ecafa910", newcontent => 1},
  testfile => <<EOF);
This is a
simple text.

Section 1 start:
A line from the branch.
Section 1 end.

Section start:
Resolved:
A line from the branch.
Another line from the branch.
A line from the origin.
Another line from the origin.
Section end.

Yet another line from the origin.
EOF
list_like("check baserev and no conflict in r5", "branch", "pkg4",
  xpath => './linkinfo[@baserev = "417a4a60603b8f8fdb0bca16ecafa910" and not(@error)]');
blame_is("branch at r5", "branch", "pkg4", "testfile", expected => <<EOF);
origin/opkg4/r4: This is a
origin/opkg4/r7: simple text.
origin/opkg4/r7: 
origin/opkg4/r7: Section 1 start:
branch/pkg4/r5: A line from the branch.
origin/opkg4/r7: Section 1 end.
origin/opkg4/r7: 
origin/opkg4/r7: Section start:
branch/pkg4/r3: Resolved:
branch/pkg4/r2: A line from the branch.
branch/pkg4/r4: Another line from the branch.
origin/opkg4/r4: A line from the origin.
origin/opkg4/r9: Another line from the origin.
origin/opkg4/r7: Section end.
origin/opkg4/r8: 
origin/opkg4/r8: Yet another line from the origin.
EOF

# check that we associate the last working automerge with
# the correct rev

# simplify the testfile
commit("branch", "pkg4", {keeplink => 1}, testfile => <<EOF);
A simple file.
Section start:
A line.
Section end.
EOF
# commit the same file to the origin
commit("origin", "opkg4", {}, testfile => <<EOF);
A simple file.
Section start:
A line.
Section end.
EOF
list_like("check origin's srcmd5 at r10", "origin", "opkg4",
  xpath => '@rev = 10 and @srcmd5 = "ce715b27f97e1f246fc37676dc6a58c7"');
blame_is("branch at r6", "branch", "pkg4", "testfile", expected => <<EOF);
origin/opkg4/r10: A simple file.
origin/opkg4/r7: Section start:
origin/opkg4/r10: A line.
origin/opkg4/r7: Section end.
EOF

# introduce a conflict
commit("origin", "opkg4", {}, testfile => <<EOF);
A simple file.
A line.
EOF
list_like("conflict (origin at r11)", "branch", "pkg4",
  xpath => './linkinfo/@error');
# resolve conflict in origin again (same content as in r10)
commit("origin", "opkg4", {}, testfile => <<EOF);
A simple file.
Section start:
A line.
Section end.
EOF
list_like("check origin's srcmd5 at r12", "origin", "opkg4",
  xpath => '@rev = 12 and @srcmd5 = "ce715b27f97e1f246fc37676dc6a58c7"');
# just do a "pseudo" commit to bump the rev (same content as in r12 and r10)
commit("origin", "opkg4", {}, testfile => <<EOF);
A simple file.
Section start:
A line.
Section end.
EOF
list_like("check origin's srcmd5 at r13", "origin", "opkg4",
  xpath => '@rev = 13 and @srcmd5 = "ce715b27f97e1f246fc37676dc6a58c7"');
# same as in r13 (and r12 and r10), except the last line was added
commit("origin", "opkg4", {}, testfile => <<EOF);
A simple file.
Section start:
A line.
Section end.
Yet another line from the origin.
EOF
# introduce a conflict
commit("origin", "opkg4", {}, testfile => <<EOF);
A line from the origin.
EOF
list_like("origin at r15", "origin", "opkg4",
  xpath => '@rev = 15 and @srcmd5 = "0c8c56d65146aea45eea2c3dd3cbf5a4"');
list_like("check baserev and conflict in r7", "branch", "pkg4",
  xpath => './linkinfo[@baserev = "417a4a60603b8f8fdb0bca16ecafa910" and @error]');

# resolve conflict in the branch
commit("branch", "pkg4", {keeplink => 1, repairlink => 1, linkrev => "0c8c56d65146aea45eea2c3dd3cbf5a4", newcontent => 1},
  testfile => <<EOF);
Resolved file:
A line from the origin.
A simple file.
Section start:
A line.
Section end.
Yet another line from the origin.
EOF
list_like("check baserev and no conflict at r7", "branch", "pkg4",
  xpath => './linkinfo[@baserev = "0c8c56d65146aea45eea2c3dd3cbf5a4" and not(@error)]');
blame_is("branch at r7 (resolved conflict)", "branch", "pkg4", "testfile", expected => <<EOF);
branch/pkg4/r7: Resolved file:
origin/opkg4/r15: A line from the origin.
origin/opkg4/r10: A simple file.
origin/opkg4/r7: Section start:
origin/opkg4/r10: A line.
origin/opkg4/r7: Section end.
origin/opkg4/r14: Yet another line from the origin.
EOF

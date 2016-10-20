#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 22;

use BSBlameTest qw(blame_is list_like create commit del branch);

create("origin", "opkg3");
commit("origin", "opkg3", {}, filea => <<EOF);
This is
a file.

Section start:
Here, we will have a conflict.
Section end.
EOF

create("branch", "pkg3");
branch("branch", "pkg3", "origin", "opkg3");
list_like("check baserev after branch", "branch", "pkg3",
  xpath => './linkinfo[@baserev = "638615aab4e0cca145e5fab193bb8ad5" and not(@error)]');
blame_is("branch at r1", "branch", "pkg3", "filea", expected => <<EOF);
origin/opkg3/r1: This is
origin/opkg3/r1: a file.
origin/opkg3/r1: 
origin/opkg3/r1: Section start:
origin/opkg3/r1: Here, we will have a conflict.
origin/opkg3/r1: Section end.
EOF

commit("branch", "pkg3", {keeplink => 1}, filea => <<EOF);
This is
a file.

Section start:
A line from the branch.
Section end.
EOF
blame_is("branch at r2", "branch", "pkg3", "filea", expected => <<EOF);
origin/opkg3/r1: This is
origin/opkg3/r1: a file.
origin/opkg3/r1: 
origin/opkg3/r1: Section start:
branch/pkg3/r2: A line from the branch.
origin/opkg3/r1: Section end.
EOF

commit("origin", "opkg3", {}, filea => <<EOF);
This is
a file.

Section start:
A line from the origin.
Section end.
EOF
list_like("check baserev and conflict", "branch", "pkg3",
  xpath => './linkinfo[@baserev = "638615aab4e0cca145e5fab193bb8ad5" and @error]');
list_like("origin at r2", "origin", "opkg3",
  xpath => '@rev = 2 and @srcmd5 = "871c68cb49eb4224a2b89bd188709b33"');

# resolve conflict in branch/pkg3
commit("branch", "pkg3", {keeplink => 1, repairlink => 1, linkrev => "871c68cb49eb4224a2b89bd188709b33", newcontent => 1},
  filea => <<EOF);
This is
a file after conflict resolution.

Section start:
Resolved:
A line from the branch.
A line from the origin.
Section end.
EOF
blame_is("branch at r3 (resolved conflict)", "branch", "pkg3", "filea", expected => <<EOF);
origin/opkg3/r1: This is
branch/pkg3/r3: a file after conflict resolution.
origin/opkg3/r1: 
origin/opkg3/r1: Section start:
branch/pkg3/r3: Resolved:
branch/pkg3/r2: A line from the branch.
origin/opkg3/r2: A line from the origin.
origin/opkg3/r1: Section end.
EOF
list_like("check baserev and no conflict at r3", "branch", "pkg3",
  xpath => './linkinfo[@baserev = "871c68cb49eb4224a2b89bd188709b33" and not(@error)]');

# introduce a new conflict
commit("origin", "opkg3", {}, filea => <<EOF);
This is
a quite simple file.

Section start:
A line from the origin.
Section end.
EOF
list_like("check baserev and conflict", "branch", "pkg3",
  xpath => './linkinfo[@baserev = "871c68cb49eb4224a2b89bd188709b33" and @error]');
list_like("origin at r3", "origin", "opkg3",
  xpath => '@rev = 3 and @srcmd5 = "f3a9ffdb44276cf4fa7e30ac873a2ca6"');

# resolve conflict in branch/pkg3
commit("branch", "pkg3", {keeplink => 1, repairlink => 1, linkrev => "f3a9ffdb44276cf4fa7e30ac873a2ca6", newcontent => 1},
  filea => <<EOF);
This is
a file after conflict resolution.
But still
a quite simple file.

Section start:
Resolved:
A line from the branch.
A line from the origin.
Section end.
EOF
blame_is("branch at r4", "branch", "pkg3", "filea", expected => <<EOF);
origin/opkg3/r1: This is
branch/pkg3/r3: a file after conflict resolution.
branch/pkg3/r4: But still
origin/opkg3/r3: a quite simple file.
origin/opkg3/r1: 
origin/opkg3/r1: Section start:
branch/pkg3/r3: Resolved:
branch/pkg3/r2: A line from the branch.
origin/opkg3/r2: A line from the origin.
origin/opkg3/r1: Section end.
EOF
list_like("check baserev and no conflict at r4", "branch", "pkg3",
  xpath => './linkinfo[@baserev = "f3a9ffdb44276cf4fa7e30ac873a2ca6" and not(@error)]');

# introduce a new conflict by removing filea from origin
commit("origin", "opkg3", {}, filea => undef);
list_like("origin at r4", "origin", "opkg3",
  xpath => '@rev = 4 and srcmd5 = "d41d8cd98f00b204e9800998ecf8427e"');
list_like("branch at r4 (conflict: filea removed in origin)", "branch", "pkg3",
  xpath => './linkinfo/@error');

# resolve conflict in branch/pkg3 by simply keeping the file
commit("branch", "pkg3", {keeplink => 1, repairlink => 1, linkrev => "d41d8cd98f00b204e9800998ecf8427e", newcontent => 1},
  filea => <<EOF);
This is
a file after conflict resolution.
But still
a quite simple file.

Section start:
Resolved:
A line from the branch.
A line from the origin.
Section end.
EOF
list_like("check baserev and no conflict at r5", "branch", "pkg3",
  xpath => './linkinfo[@baserev = "d41d8cd98f00b204e9800998ecf8427e" and not(@error)]');
blame_is("branch at r5 (same as in r4)", "branch", "pkg3", "filea", expected => <<EOF);
origin/opkg3/r1: This is
branch/pkg3/r3: a file after conflict resolution.
branch/pkg3/r4: But still
origin/opkg3/r3: a quite simple file.
origin/opkg3/r1: 
origin/opkg3/r1: Section start:
branch/pkg3/r3: Resolved:
branch/pkg3/r2: A line from the branch.
origin/opkg3/r2: A line from the origin.
origin/opkg3/r1: Section end.
EOF

# introduce a new filea and fileb and add some conflicts
# to fileb
commit("branch", "pkg3", {keeplink => 1}, filea => <<EOF);
This is filea with 2 sections.
Section start:
Section end.
Section start:
Section end.
EOF
# readd filea to the origin (r5) (the same file as in the branch)
commit("origin", "opkg3", {}, filea => <<EOF);
This is filea with 2 sections.
Section start:
Section end.
Section start:
Section end.
EOF
# change filea in the branch (r7)
commit("branch", "pkg3", {keeplink => 1}, filea => <<EOF);
This is filea with 2 sections.
Section start:
Section end.
Section start:
A line from the branch.
Here ends the last section.
EOF
# change filea in the origin (r6)
commit("origin", "opkg3", {}, filea => <<EOF);
This is filea with 2 sections.
Section 1 start:
A line from the origin.
Section 1 end.
Section start:
Section end.
EOF
blame_is("simple blame for filea at r7", "branch", "pkg3", "filea", expected => <<EOF);
origin/opkg3/r5: This is filea with 2 sections.
origin/opkg3/r6: Section 1 start:
origin/opkg3/r6: A line from the origin.
origin/opkg3/r6: Section 1 end.
origin/opkg3/r5: Section start:
branch/pkg3/r7: A line from the branch.
branch/pkg3/r7: Here ends the last section.
EOF

# add a new fileb to the branch
commit("branch", "pkg3", {keeplink => 1}, fileb => <<EOF);
This is
the new
fileb.
EOF
blame_is("branch at r8", "branch", "pkg3", "fileb", expected => <<EOF);
branch/pkg3/r8: This is
branch/pkg3/r8: the new
branch/pkg3/r8: fileb.
EOF

# introduce a conflict by adding a new/different fileb to the origin
commit("origin", "opkg3", {}, fileb => <<EOF);
This is
the new/different
fileb.
EOF
list_like("origin at r7", "origin", "opkg3",
  xpath => '@rev = "7" and @srcmd5 = "508d66737cb3da3e8b00b8b3bbae5982"');
list_like("check baserev and conflict", "branch", "pkg3",
  xpath => './linkinfo[@baserev = "d914a0356a47580f85b43216cae19f72" and @error]');

# resolve conflict in branch/pkg3
# (no changes to filea (from the expanded POV), we just keep it as it was)
commit("branch", "pkg3", {keeplink => 1, repairlink => 1, linkrev => "508d66737cb3da3e8b00b8b3bbae5982", newcontent => 1},
  filea => <<EOF, fileb => <<EOF);
This is filea with 2 sections.
Section 1 start:
A line from the origin.
Section 1 end.
Section start:
A line from the branch.
Here ends the last section.
EOF
This is
the new
resolved
fileb.
EOF
list_like("check baserev and no conflict at r9", "branch", "pkg3",
  xpath => '@rev = "9" and ./linkinfo[@baserev = "508d66737cb3da3e8b00b8b3bbae5982" and not(@error)]');
blame_is("branch at r9", "branch", "pkg3", "fileb", expected => <<EOF);
origin/opkg3/r7: This is
branch/pkg3/r8: the new
branch/pkg3/r9: resolved
origin/opkg3/r7: fileb.
EOF
# same blame for filea as in r7 of the branch
# (filea was not affected by the conflict, but its blame was computed
# by the automerge code)
blame_is("filea at r9 (after conflict in fileb)", "branch", "pkg3", "filea", expected => <<EOF);
origin/opkg3/r5: This is filea with 2 sections.
origin/opkg3/r6: Section 1 start:
origin/opkg3/r6: A line from the origin.
origin/opkg3/r6: Section 1 end.
origin/opkg3/r5: Section start:
branch/pkg3/r7: A line from the branch.
branch/pkg3/r7: Here ends the last section.
EOF

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 17;

use BSBlameTest qw(blame_is list_like create commit del branch);

create("origin", "opkg2");
commit("origin", "opkg2", {}, filea => <<EOF);
This is
some content
for file
filea.
EOF

create("branch", "pkg2");
branch("branch", "pkg2", "origin", "opkg2");
blame_is("branch at r1", "branch", "pkg2", "filea", expected => <<EOF);
origin/opkg2/r1: This is
origin/opkg2/r1: some content
origin/opkg2/r1: for file
origin/opkg2/r1: filea.
EOF

commit("origin", "opkg2", {}, fileb => <<EOF);
This is
the new file
fileb.
EOF
list_like("origin/opkg2 is at r2", "origin", "opkg2",
  xpath => '@rev = 2 and srcmd5 = "f5a596008989db5e881fcdade1781a6d"');
list_like("check baserev at r1", "branch", "pkg2",
  xpath => './linkinfo[@baserev = "cfc4c51c6700fe920459c6022af1c5b8"]');
blame_is("branch at r1 (origin changed)", "branch", "pkg2", "fileb", expected => <<EOF);
origin/opkg2/r2: This is
origin/opkg2/r2: the new file
origin/opkg2/r2: fileb.
EOF

commit("branch", "pkg2", {keeplink => 1}, fileb => <<EOF);
This is
the
modified file
fileb.
EOF
list_like("check baserev at r2", "branch", "pkg2",
  xpath => './linkinfo[@baserev = "f5a596008989db5e881fcdade1781a6d"]');
blame_is("branch at r2 (fileb changed)", "branch", "pkg2", "fileb", expected => <<EOF);
origin/opkg2/r2: This is
branch/pkg2/r2: the
branch/pkg2/r2: modified file
origin/opkg2/r2: fileb.
EOF

commit("branch", "pkg2", {keeplink => 1}, fileb => undef);
blame_is("fileb does not exist in branch", "branch", "pkg2", "fileb", code => 404);

commit("branch", "pkg2", {keeplink => 1}, fileb => <<EOF);
This is
a quite different
file fileb.
EOF
blame_is("fileb was added to branch again", "branch", "pkg2", "fileb", expected => <<EOF);
origin/opkg2/r2: This is
branch/pkg2/r4: a quite different
branch/pkg2/r4: file fileb.
EOF

commit("origin", "opkg2", {}, filea => undef);
blame_is("filea was removed from origin", "branch", "pkg2", "filea", code => 404);

commit("branch", "pkg2", {keeplink => 1}, filea => <<EOF);
This is
the new
file
filea.
EOF
blame_is("branch at r5", "branch", "pkg2", "filea", expected => <<EOF);
branch/pkg2/r5: This is
branch/pkg2/r5: the new
branch/pkg2/r5: file
branch/pkg2/r5: filea.
EOF

commit("origin", "opkg2", {}, filea => <<EOF);
This is
the new
file
filea that causes a conflict.
EOF
list_like("conflict in the branch", "branch", "pkg2", xpath => '@rev = 5 and ./linkinfo/@error');
commit("origin", "opkg2", {}, filea => <<EOF);
This is
the new
file
filea.
EOF
list_like("no conflict in the branch", "branch", "pkg2", xpath => 'not(./linkinfo/@error)');
# filea in the branch and filea in the origin have the same content
# (hence, all changes common from the filea in the origin (due to the
# default for $ctie in BSSrcBlame::merge))
blame_is("branch at r5 (after origin changed)", "branch", "pkg2", "filea", expected => <<EOF);
origin/opkg2/r4: This is
origin/opkg2/r4: the new
origin/opkg2/r4: file
origin/opkg2/r5: filea.
EOF

commit("branch", "pkg2", {keeplink => 1}, filec => <<EOF);
The file
filec was firstly added
to the branch and then
to the origin.
EOF
blame_is("branch at r6", "branch", "pkg2", "filec", expected => <<EOF);
branch/pkg2/r6: The file
branch/pkg2/r6: filec was firstly added
branch/pkg2/r6: to the branch and then
branch/pkg2/r6: to the origin.
EOF

commit("origin", "opkg2", {}, filec => <<EOF);
This commit (r6)
causes a conflict
which we won't notice.
EOF
list_like("conflict in the branch at r6", "branch", "pkg2", xpath => './linkinfo/@error');
commit("origin", "opkg2", {}, filec => <<EOF);
The file
filec was firstly added
to the branch and then
to the origin.
EOF
list_like("conflict in the branch at r6", "branch", "pkg2", xpath => 'not(./linkinfo/@error)');
blame_is("branch at r6 (origin changed)", "branch", "pkg2", "filec", expected => <<EOF);
origin/opkg2/r7: The file
origin/opkg2/r7: filec was firstly added
origin/opkg2/r7: to the branch and then
origin/opkg2/r7: to the origin.
EOF

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 11;

use BSBlameTest qw(blame_is list_like create commit del branch);

create("origin", "opkg1");
commit("origin", "opkg1", {}, testfile => <<EOF);
We start with
a very very
simple text
file.
EOF
commit("origin", "opkg1", {}, testfile => <<EOF);
We start with
a very
very
simple text
file.
EOF
blame_is("blame origin", "origin", "opkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
origin/opkg1/r2: a very
origin/opkg1/r2: very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
EOF

create("branch", "pkg1");
branch("branch", "pkg1", "origin", "opkg1");
list_like("check baserev", "branch", "pkg1", xpath => './linkinfo[@baserev = "6c23f5262aaeec2e50d46c9a630f1fd0"]');
blame_is("branch at r1", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
origin/opkg1/r2: a very
origin/opkg1/r2: very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
EOF

commit("branch", "pkg1", {keeplink => 1}, testfile => <<EOF);
We start with
a very
very
simple text
file.

And add some
new lines in
the branch.
EOF
blame_is("branch at r2", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
origin/opkg1/r2: a very
origin/opkg1/r2: very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
branch/pkg1/r2: 
branch/pkg1/r2: And add some
branch/pkg1/r2: new lines in
branch/pkg1/r2: the branch.
EOF

commit("branch", "pkg1", {keeplink => 1}, testfile => <<EOF);
We start with
three lines that were first added in
the branch and will be added to the
origin in a future commit. However, this is still
a very
very
simple text
file.

This is a very cool line.

And add some
new lines and modify
a line in
the branch.
EOF
blame_is("branch at r3", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
branch/pkg1/r3: three lines that were first added in
branch/pkg1/r3: the branch and will be added to the
branch/pkg1/r3: origin in a future commit. However, this is still
origin/opkg1/r2: a very
origin/opkg1/r2: very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
branch/pkg1/r2: 
branch/pkg1/r3: This is a very cool line.
branch/pkg1/r3: 
branch/pkg1/r2: And add some
branch/pkg1/r3: new lines and modify
branch/pkg1/r3: a line in
branch/pkg1/r2: the branch.
EOF

commit("origin", "opkg1", {}, testfile => <<EOF);
We start with
a very
simple text
file.
EOF
list_like("baserev still at r2", "branch", "pkg1", xpath => './linkinfo[@baserev = "6c23f5262aaeec2e50d46c9a630f1fd0" and not(@error)]');
blame_is("origin changed (a line was removed)", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
branch/pkg1/r3: three lines that were first added in
branch/pkg1/r3: the branch and will be added to the
branch/pkg1/r3: origin in a future commit. However, this is still
origin/opkg1/r2: a very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
branch/pkg1/r2: 
branch/pkg1/r3: This is a very cool line.
branch/pkg1/r3: 
branch/pkg1/r2: And add some
branch/pkg1/r3: new lines and modify
branch/pkg1/r3: a line in
branch/pkg1/r2: the branch.
EOF

commit("origin", "opkg1", {}, testfile => <<EOF);
We start with
three lines that were first added in
the branch and will be added to the
origin in a future commit. However, this is still
a very
simple text
file.
EOF
list_like("baserev still at r2", "branch", "pkg1", xpath => './linkinfo[@baserev = "6c23f5262aaeec2e50d46c9a630f1fd0" and not(@error)]');
blame_is("origin changed (the three lines were added)", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
origin/opkg1/r4: three lines that were first added in
origin/opkg1/r4: the branch and will be added to the
origin/opkg1/r4: origin in a future commit. However, this is still
origin/opkg1/r2: a very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
branch/pkg1/r2: 
branch/pkg1/r3: This is a very cool line.
branch/pkg1/r3: 
branch/pkg1/r2: And add some
branch/pkg1/r3: new lines and modify
branch/pkg1/r3: a line in
branch/pkg1/r2: the branch.
EOF

commit("branch", "pkg1", {keeplink => 1}, otherfile => "added otherfile in r5");
commit("branch", "pkg1", {keeplink => 1}, otherfile => "changed otherfile in r6");
commit("branch", "pkg1", {keeplink => 1}, testfile => <<EOF);
We start with
some text and realize that
this file changed
quite a lot and evolved into
a not so
simple text
file.
This is a very cool line.
EOF
list_like("baserev points to r4", "branch", "pkg1", xpath => '@rev = 6 and ./linkinfo[@baserev = "701a3c4af1cdebd05bdf0c40e12dbb3d" and not(@error)]');
blame_is("branch at r6", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
branch/pkg1/r6: some text and realize that
branch/pkg1/r6: this file changed
branch/pkg1/r6: quite a lot and evolved into
branch/pkg1/r6: a not so
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
branch/pkg1/r3: This is a very cool line.
EOF

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 13;

use BSBlameTest qw(blame_is create commit del);

create("simple", "pkg1");
commit("simple", "pkg1", {}, testfile => <<EOF);
This is a very
simple test
file.
EOF
blame_is("blame initial commit", "simple", "pkg1", "testfile", expected => <<EOF);
simple/pkg1/r1: This is a very
simple/pkg1/r1: simple test
simple/pkg1/r1: file.
EOF

commit("simple", "pkg1", {}, testfile => <<EOF);
This is still a very
simple test
file.
EOF
blame_is("changed first line", "simple", "pkg1", "testfile", expected => <<EOF);
simple/pkg1/r2: This is still a very
simple/pkg1/r1: simple test
simple/pkg1/r1: file.
EOF

commit("simple", "pkg1", {}, otherfile => "some content");
blame_is("changed first line", "simple", "pkg1", "testfile", expected => <<EOF);
simple/pkg1/r2: This is still a very
simple/pkg1/r1: simple test
simple/pkg1/r1: file.
EOF

commit("simple", "pkg1", {}, testfile => <<EOF);
This is still a very
simple test
file.

Added some
new content
here.
EOF
blame_is("new content in r4", "simple", "pkg1", "testfile", expected => <<EOF);
simple/pkg1/r2: This is still a very
simple/pkg1/r1: simple test
simple/pkg1/r1: file.
simple/pkg1/r4: 
simple/pkg1/r4: Added some
simple/pkg1/r4: new content
simple/pkg1/r4: here.
EOF

commit("simple", "pkg1", {}, testfile => undef);
blame_is("testfile was removed", "simple", "pkg1", "testfile", code => 404);

commit("simple", "pkg1", {}, testfile => <<EOF);
A brand
new first
section.

Old:
Added some
new content
here.
EOF
blame_is("readd in r6", "simple", "pkg1", "testfile", expected => <<EOF);
simple/pkg1/r6: A brand
simple/pkg1/r6: new first
simple/pkg1/r6: section.
simple/pkg1/r6: 
simple/pkg1/r6: Old:
simple/pkg1/r6: Added some
simple/pkg1/r6: new content
simple/pkg1/r6: here.
EOF

commit("simple", "pkg1", {}, testfile => <<EOF);
This is the first
section.

With some changes.

Old:
Added some
content and
changed some content
here.
EOF
blame_is("various changes in r7", "simple", "pkg1", "testfile", expected => <<EOF);
simple/pkg1/r7: This is the first
simple/pkg1/r6: section.
simple/pkg1/r6: 
simple/pkg1/r7: With some changes.
simple/pkg1/r7: 
simple/pkg1/r6: Old:
simple/pkg1/r6: Added some
simple/pkg1/r7: content and
simple/pkg1/r7: changed some content
simple/pkg1/r6: here.
EOF

blame_is("testfile in r4", "simple", "pkg1", "testfile", rev => 4, expected => <<EOF);
simple/pkg1/r2: This is still a very
simple/pkg1/r1: simple test
simple/pkg1/r1: file.
simple/pkg1/r4: 
simple/pkg1/r4: Added some
simple/pkg1/r4: new content
simple/pkg1/r4: here.
EOF

del("simple", "pkg1");
blame_is("nonexistent pkg1", "simple", "pkg1", "testfile", code => 404);

create("simple", "pkg1");
# add content from previous r4 again
commit("simple", "pkg1", {}, testfile => <<EOF);
This is still a very
simple test
file.

Added some
new content
here.
EOF
blame_is("initial commit after deletion", "simple", "pkg1", "testfile", expected => <<EOF);
simple/pkg1/r1: This is still a very
simple/pkg1/r1: simple test
simple/pkg1/r1: file.
simple/pkg1/r1: 
simple/pkg1/r1: Added some
simple/pkg1/r1: new content
simple/pkg1/r1: here.
EOF

blame_is("nonexistent file", "simple", "pkg1", "otherfile", code => 404);
blame_is("nonexistent pkg", "simple", "pkgnonexistent", "testfile", code => 404);
blame_is("nonexistent prj", "prjnonexistent", "pkg1", "testfile", code => 404);

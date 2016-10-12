#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;

use BSBlameTest qw(blame_is create commit branch);

# This testcase just documents that it is possible to encounter a "partially"
# resolved localrev during the initial resolving
# (BSBlame::RangeFirstStrategy::resolve) - a partially resolved resolved
# localrev means that the localrev itself is resolved, but a direct or indirect
# targetrev is not resolved
#
# In this testcase, we eventually try to resolve the expanded rev
# pkg85/e78beea74b88e7b6f38df59cc7ebc4a4 (its lsrcmd5 corresponds to
# pkg85/r1). pkg85/r1 is resolved, its targetrev is resolved, and its
# targetrev's targetrev is resolved. However, the targetrev's targetrev's
# targetrev (pkg72/f07cfaa85605d996f2f9957b0130a928) is not resolved.
# Hence, we need to take this situation into account when implementing the
# constraint handling ("satisfies" method) for an expanded rev (e.g., how
# to handle a time constraint in this case (cf. test
# 09-blame-branch-fully_resolved_lrev.t)).

create("branch", "pkg81");
commit("branch", "pkg81", {time => 1}, testfile => <<EOF);
foo
EOF

create("branch", "pkg82");
branch("branch", "pkg82", "branch", "pkg81", time => 1);
create("branch", "pkg83");
branch("branch", "pkg83", "branch", "pkg82", time => 1);
create("branch", "pkg84");
branch("branch", "pkg84", "branch", "pkg83", time => 1);
create("branch", "pkg85");
branch("branch", "pkg85", "branch", "pkg84", time => 1);

branch("branch", "pkg83", "branch", "pkg85", time => 1);
branch("branch", "pkg84", "branch", "pkg83", time => 1, olinkrev => 'base');
branch("branch", "pkg85", "branch", "pkg84", time => 1, olinkrev => 'base');

# needed in order to expand pkg85
commit("branch", "pkg84", {time => 2, newcontent => 1}, testfile => <<EOF);
foo
EOF

blame_is("blame: pkg85 at r2", "branch", "pkg85", "testfile", expected => <<EOF);
branch/pkg81/r1: foo
EOF

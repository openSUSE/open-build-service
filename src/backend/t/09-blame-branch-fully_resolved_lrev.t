#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;

use BSBlameTest qw(blame_is create commit branch);

# This testcase just documents that it is possible to encounter a "fully"
# resolved localrev during the initial resolving
# (BSBlame::RangeFirstStrategy::resolve) - a fully resolved localrev means
# that the localrev is resolved, and its targetrev is resolved (+ the
# targetrev's localrev), and its targetrev's targetrev is resolved...
#
# In this testcase, we eventually try to resolve the expanded rev
# pkg73/096db417ca7c61531058c33e436c4771 (its lsrcmd5 corresponds to
# pkg73/r1). At this point, pkg73/r1 is fully resolved and satisfies
# all constraints. Hence, it is checked whether pkg73/r1's targetrev,
# which is an expanded rev, also satisfies all constraints. Since the
# constraints also include time constraints, an expanded rev should be
# able to support the "time()" method.

create("branch", "pkg71");
commit("branch", "pkg71", {time => 1}, testfile => <<EOF);
foo
EOF

create("branch", "pkg72");
branch("branch", "pkg72", "branch", "pkg71", time => 1);
create("branch", "pkg73");
branch("branch", "pkg73", "branch", "pkg72", time => 1);

create("branch", "pkg70");
branch("branch", "pkg70", "branch", "pkg73", time => 1);

branch("branch", "pkg71", "branch", "pkg70", time => 1);
branch("branch", "pkg72", "branch", "pkg71", time => 1, olinkrev => 'base');
branch("branch", "pkg73", "branch", "pkg72", time => 1, olinkrev => 'base');

# needed in order to expand pkg73
commit("branch", "pkg72", {time=> 2, newcontent => 1}, testfile => <<EOF);
foo
EOF

blame_is("blame: pkg73 at r2", "branch", "pkg73", "testfile", expected => <<EOF);
branch/pkg71/r1: foo
EOF

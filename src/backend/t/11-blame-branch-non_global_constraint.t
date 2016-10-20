#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;

use BSBlameTest qw(blame_is create commit branch);

# This testcase documents the need for non-global constraints. In particular,
# it shows that we need a non-global constraint when resolving an expanded
# rev (see BSBlame::RangeFirstStrategy::resolve_expanded) and when resolving
# a branch rev (see BSBlame::RangeFirstStrategy::resolve_branch).

# When resolving the expanded rev pkg92/27b4125b2c30e7dcff96382d81c33345,
# the corresponding localrev (pkg92/r2), which we are trying to find, is
# already fully resolved _and_ the localrev's targetrev's targetrev is pkg92/r1
# (see t/09-blame-resolved_expandedrev.t for an explanation of
# "fully resolved). Hence, it is crucial that the lsrcmd5 constraint,
# which is generated in BSBlame::RevisionManager::find, is non-global,
# because otherwise we would check whether pkg92/r1 satisfies the lsrcmd5
# constraint as well (which it does not) => we are unable to find the
# localrev.
# When resolving the branch rev pkg93/r1, the targetrev's localrev is
# pkg92/r2 (which are trying to find) is already fully resolved (see above).
# By the same line of argument, the lsrcmd5 constraint, which is generated
# in BSBlame::RangeFirstStrategy::resolve_branch, has to be non-global.

create("branch", "pkg91");
create("branch", "pkg92");
commit("branch", "pkg92", {time => 1}, testfile => <<EOF);
foobar
EOF

branch("branch", "pkg91", "branch", "pkg92", time => 2);
branch("branch", "pkg92", "branch", "pkg91", time => 3);

# intermediate packages (we need some intermediate packages so that
# pkg93/r1's targetrev's localrev is fully resolved (when we try to
# resolve pkg93/r1's targetrev (BSBlame::RangeFirstStrategy::resolve_branch
# codepath))
create("branch", "pkg93");
branch("branch", "pkg93", "branch", "pkg92", time => 4, olinkrev => 'base');
create("branch", "pkg931");
branch("branch", "pkg931", "branch", "pkg93", time => 4, olinkrev => 'base');
create("branch", "pkg932");
branch("branch", "pkg932", "branch", "pkg931", time => 4, olinkrev => 'base');
# end intermediate packages

create("branch", "pkg94");
branch("branch", "pkg94", "branch", "pkg932", time => 5, olinkrev => 'base');

create("branch", "pkg95");
branch("branch", "pkg95", "branch", "pkg94", time => 6, olinkrev => 'base');

branch("branch", "pkg94", "branch", "pkg92", time => 6, olinkrev => 'base');
branch("branch", "pkg95", "branch", "pkg94", time => 6, olinkrev => 'base');

commit("branch", "pkg92", {time => 9, newcontent => 1}, testfile => <<EOF);
foobar
EOF

blame_is("blame: pkg95 at r2", "branch", "pkg95", "testfile", expected => <<EOF);
branch/pkg92/r1: foobar
EOF

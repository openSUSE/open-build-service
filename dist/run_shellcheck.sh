#!/bin/bash

# Script that retrieves the files to be checked with shellcheck,
# and that runs shellcheck on them.

#DIRECTORIES_ARRAY=( contrib dist src/api/script src/api/test src/backend )
DIRECTORIES_ARRAY=( dist )

DIRECTORIES=$(printf "../%s " "${DIRECTORIES_ARRAY[@]}")

# shellcheck disable=SC2086
find $DIRECTORIES \
  -name run_shellcheck.sh \
    -o -name 0000-check_users_and_group.ts \
  -type f -exec sh -c "head -n 1 {} | grep -Eq '^#!(.*/|.*env +)(sh|bash)'" \; -print |
  while IFS="" read -r file
  do
    shellcheck "$file"
  done

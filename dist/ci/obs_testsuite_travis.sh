#!/bin/bash
# This script runs the test suites for the CI build

# Be verbose and fail script on the first error
set -xe

# Which test suite should run? By default: all
if [ -z $1 ]; then
  TEST_SUITE="all"
else
  TEST_SUITE="$1"
fi 

pushd src/api

if test -z "$SUBTEST"; then
  export DO_COVERAGE=1
  export TESTOPTS="-v"
  case $TEST_SUITE in
    api)
      bundle exec rake test:api
      ;;
    webui)
      bundle exec rake test:webui
      ;;
    rubocop)
      bundle exec rake rubocop 
      ;;
    *)
      bundle exec rake test:api
      bundle exec rake test:webui
      bundle exec rake rubocop
      ;;
  esac
fi

cd ../..

echo "Killing backend processes"
if fuser -v $PWD | egrep 'perl|ruby'; then
  list=`fuser -v $PWD 2>&1 | egrep 'perl|ruby' | sed -e "s,^ *$USER *,,;"  | cut '-d ' -f1`
  for p in $list; do
    echo "Kill $p"
    # the process might have gone away on its own, so use || true
    kill $p || true
  done
fi

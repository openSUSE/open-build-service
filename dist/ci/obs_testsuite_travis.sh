#!/bin/bash
# This script runs the test suites for the CI build

# Be verbose and fail script on the first error
set -xe

# Everything happens here
pushd src/api

# Which test suite should run? By default: all
if [ -z $1 ]; then
  TEST_SUITE="all"
else
  TEST_SUITE="$1"
fi 


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
      bundle exec rake rubocop
      bundle exec rake test:api
      bundle exec rake test:webui
      ;;
  esac
fi

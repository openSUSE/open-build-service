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
      bundle exec rails test:api
      ;;
    webui)
      bundle exec rails test:webui
      ;;
    spider)
      unset DO_COVERAGE
      bundle exec rails test:spider
      ;;
    rspec)
      bundle exec rspec
      ;;
    jshint)
      jshint .
      ;;
    backend)
      pushd ../backend
      make test_unit
      ;;
    *)
      bundle exec rails test:api
      bundle exec rails test:webui
      bundle exec rspec
      jshint .
      unset DO_COVERAGE
      bundle exec rails test:spider
      ;;
  esac
fi

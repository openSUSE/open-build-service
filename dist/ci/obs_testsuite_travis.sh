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
    spider)
      unset DO_COVERAGE
      bundle exec rake test:spider
      ;;
    rubocop)
      bundle exec rake rubocop
      ;;
    rspec)
      bundle exec rspec
      ;;
    backend)
      pushd ../backend
      bundle exec make test_unit
      popd
      ;;
    *)
      bundle exec rake rubocop
      bundle exec rake test:api
      bundle exec rake test:webui
      bundle exec rspec
      pushd ../backend
      bundle exec make test_unit
      popd
      unset DO_COVERAGE
      bundle exec rake test:spider
      ;;
  esac
fi

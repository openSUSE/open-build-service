#!/bin/bash
# This script runs the test suites for the CI build

# Be verbose and fail script on the first error
set -xe

if test -z "$SUBTEST"; then
  export DO_COVERAGE=1
  export EAGER_LOAD=1
  export TESTOPTS="-v"
  case $TEST_SUITE in
    api)
      rake docker:test:minitest
      ;;
    spider)
      DO_COVERAGE=1
      rake docker:test:spider
      ;;
    linter)
      rake docker:test:lint
      ;;
    rspec)
      rake docker:test:rspec
      ;;
    backend)
      rake docker:test:backend
      ;;
    *)
      echo "ERROR: test suite is not matching"
      exit 1
      ;;
  esac
fi

#!/bin/bash
# This script runs the test suites for the CI build

# Be verbose and fail script on the first error
set -xe

# Everything happens here
pushd src/api

if test -z "$SUBTEST"; then
  export DO_COVERAGE=1
  export TESTOPTS="-v"
  case $TEST_SUITE in
    api)
      bundle exec rails assets:precompile &> /dev/null
      bundle exec rails test:api
      ;;
    webui)
      bundle exec rails assets:precompile &> /dev/null
      bundle exec rails test:webui
      ;;
    spider)
      unset DO_COVERAGE
      bundle exec rails assets:precompile &> /dev/null
      bundle exec rails test:spider
      ;;
    linter)
      bundle exec rake db:structure:verify
      bundle exec rake db:structure:verify_no_bigint
      make -C ../../ rubocop
      bundle exec rake haml_lint
      jshint .
      bundle exec git-cop --police
      ;;
    rspec)
      bundle exec rails assets:precompile &> /dev/null
      bundle exec rspec
      ;;
    backend)
      pushd ../backend
      make test_unit
      ;;
    *)
      echo "ERROR: test suite is not matching"
      exit 1
      ;;
  esac
fi

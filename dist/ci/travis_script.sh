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
      make -C ../../ rubocop
      bundle exec rake haml_lint
      jshint .
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
      make -C ../../ rubocop
      bundle exec rails assets:precompile &> /dev/null
      bundle exec rails test:api
      bundle exec rails test:webui
      bundle exec rspec
      jshint .
      unset DO_COVERAGE
      bundle exec rails test:spider
      ;;
  esac
fi

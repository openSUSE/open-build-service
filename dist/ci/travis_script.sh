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
      perl -pi -e 's/source_port: 5352/source_port: 3200/' config/options.yml
      bundle exec rails test:api
      ;;
    spider)
      unset DO_COVERAGE
      bundle exec rails assets:precompile &> /dev/null
      perl -pi -e 's/source_port: 5352/source_port: 3200/' config/options.yml
      bundle exec rails test:spider
      ;;
    linter)
      bundle exec rake db:structure:verify
      bundle exec rake db:structure:verify_no_bigint
      make -C ../../ rubocop
      bundle exec rake haml_lint
      jshint app/assets/javascripts/
      bundle exec git-cop --police
      ;;
    rspec)
      perl -pi -e 's/source_host: localhost/source_host: backend/' config/options.yml
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

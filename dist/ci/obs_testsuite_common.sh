#!/bin/sh
#
# This script prepares the API test database for both the API and the WEBUI test suites
#

setup_git() {
  echo "Checking status"
  git status

  echo "Setup git submodules"
  git submodule init
  git submodule update

  echo "Setup backend configuration template"
  sed -i -e "s|my \$hostname = .*$|my \$hostname = 'localhost';|" \
         -e "s|our \$bsuser = 'obsrun';|our \$bsuser = 'jenkins';|" \
         -e "s|our \$bsgroup = 'obsrun';|our \$bsgroup = 'jenkins';|" src/backend/BSConfig.pm.template
  cp src/backend/BSConfig.pm.template src/backend/BSConfig.pm

  echo "Set environment variables"
  export RAILS_ENV=test
  
  ret=0
}

setup_api() {

  echo "Enter API rails root"
  cd src/api

  echo "Setup database configuration"
  cp config/database.yml.example config/database.yml
  sed -i "s|database: api|database: ci_api|" config/database.yml

  echo "Setup additional configuration"
  cp config/options.yml.example config/options.yml
  cp config/thinking_sphinx.yml.example config/thinking_sphinx.yml
  chmod a+x script/start_test_backend
  chmod a+x script/start_test_api

  echo "Initialize test database, load seed data"
  bundle exec rake db:drop db:create db:setup --trace
  rm -f log/* tmp/*
  cd ../..

  cd docs/api
  make
  cd ../..
}

cleanup() {
  echo "Killing backend processes"
  if fuser -v $PWD | egrep 'perl|ruby'; then
    list=`fuser -v $PWD 2>&1 | egrep 'perl|ruby' | sed -e "s,^ *$USER *,,;"  | cut '-d ' -f1`
    for p in $list; do
      echo "Kill $p"
      # the process might have gone away on its own, so use || true
      kill $p || true
    done
  fi
}

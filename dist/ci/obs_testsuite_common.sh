#!/bin/sh
#
# This script prepares the API test database for both the API and the WEBUI test suites
#

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

echo "Enter API rails root"
cd src/api

echo "Setup database configuration"
cp config/database.yml.example config/database.yml
sed -i "s|database: api|database: ci_api|" config/database.yml

echo "Setup additional configuration"
cp config/options.yml.example config/options.yml

echo "Install missing gems locally"
rake --trace gems:install

echo "Set environment variables"
export RAILS_ENV=test

echo "Initialize test database, run migrations, load seed data"
rake --trace db:drop db:create db:setup db:migrate


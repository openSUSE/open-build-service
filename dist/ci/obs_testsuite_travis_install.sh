#!/bin/bash
# This script installs dependencies for the CI build 

# Be verbose and fail script on the first error
set -xe

# Install updates from our own repository
sudo chmod a+w /etc/apt/sources.list.d
echo 'deb http://download.opensuse.org/repositories/OBS:/Server:/Unstable/xUbuntu_12.04 /' > /etc/apt/sources.list.d/opensuse.list
sudo apt-get update -o Dir::Etc::sourcelist="sources.list.d/opensuse.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

# Install the dependencies of the backend
sudo apt-get install --force-yes travis-deps libxml-parser-perl libfile-sync-perl python-rpm python-urlgrabber python-sqlitecachec python-libxml2 createrepo libbssolv-perl sphinxsearch libjson-xs-perl libxml-simple-perl libgd-gd2-perl

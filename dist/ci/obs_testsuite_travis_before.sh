#!/bin/sh
#
# This script installs dependencies on travis 
#

###############################################################################
# Script content for 'Build' step
###############################################################################
#
# Either invoke as described above or copy into an 'Execute shell' 'Command'.
#

set -xe

mysql -e 'create database ci_api_test;'
sed -e 's,password:.*,password:,' -i src/api/config/database.yml.example

pushd src/api
if test "$REMOVEGEMLOCK" = true; then
  rm Gemfile.lock
fi  
bundle install
popd

# dependencies of backend
sudo apt-get install liblzma-dev librpm-dev libxml-parser-perl libfile-sync-perl python-rpm python-urlgrabber python-sqlitecachec python-libxml2

case "$SUBTEST" in
 webui*)
  sudo apt-get install firefox
  pushd src/webui-testsuite
  if test "$REMOVEGEMLOCK" = true; then
    rm Gemfile.lock
  fi
  bundle install
  cd ../webui
  if test "$REMOVEGEMLOCK" = true; then
    rm Gemfile.lock
  fi
  bundle install
  popd

  for file in $GEM_HOME/gems/activesupport-2.3.14/lib/active_support/core_ext/load_error.rb; do
    sudo sed -i -e 's,no such file to load,cannot load such file,' $file
  done
  ;;
esac

pushd `mktemp -d`

wget https://api.opensuse.org/public/source/openSUSE:Factory/perl-BSSolv/libsolv-0.1.0.tar.bz2
tar xf libsolv-0.1.0.tar.bz2
mv libsolv-0.1.0 libsolv
pushd libsolv
cmake   -DFEDORA=1 \
        -DDISABLE_SHARED=1 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SKIP_RPATH=1 \
        -DENABLE_RPMDB=1 \
        -DENABLE_DEBIAN=1 \
        -DENABLE_ARCHREPO=1 \
        -DENABLE_LZMA_COMPRESSION=1 \
        -DMULTI_SEMANTICS=1
pushd src; make ; popd
pushd ext; make ; popd
popd
for f in Makefile.PL BSSolv.pm BSSolv.xs typemap; do
  wget https://api.opensuse.org/public/source/openSUSE:Factory/perl-BSSolv/$f
done
perl Makefile.PL
make
sudo make install_vendor

wget https://api.opensuse.org/public/source/openSUSE:Factory/perl-Socket-MsgHdr/Socket-MsgHdr-0.04.tar.gz
tar xvf Socket-MsgHdr-0.04.tar.gz
pushd Socket-MsgHdr-0.04
perl Makefile.PL
make
sudo make install_vendor
popd

wget https://api.opensuse.org/public/source/openSUSE:Factory/yum/yum-3.4.3.tar.gz
tar xf yum-3.4.3.tar.gz
pushd yum-3.4.3
make
sudo make install
cd yum
sudo make install 'PKGDIR=$(PYLIBDIR)/$(PACKAGE)'
cd ../rpmUtils
sudo make install 'PKGDIR=$(PYLIBDIR)/$(PACKAGE)'
popd

wget https://api.opensuse.org/public/source/openSUSE:Factory/createrepo/createrepo-0.9.9.tar.gz
tar xf createrepo-0.9.9.tar.gz
cd createrepo-0.9.9
sed -i -e 's,import deltarpms,#no delta', createrepo/__init__.py
# ubuntu doesn't seem to have site-packages in their python
sudo make install 'PKGDIR=$(PYLIBDIR)/$(PKGNAME)'

popd

. `dirname $0`/obs_testsuite_common.sh

setup_git
setup_api

case "$SUBTEST" in
  webui*)
    setup_webui
    ;;
esac


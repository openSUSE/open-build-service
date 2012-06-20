#! /bin/bash

# little script to install all perl modules needed for backend (for travis-ci.org)

cd `mktemp -d`

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

wget http://search.cpan.org/CPAN/authors/id/M/MJ/MJP/Socket-MsgHdr-0.04.tar.gz
tar xvf Socket-MsgHdr-0.04.tar.gz
cd Socket-MsgHdr-0.04
perl Makefile.PL
make
sudo make install_vendor


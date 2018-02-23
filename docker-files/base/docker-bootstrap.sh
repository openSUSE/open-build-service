#!/bin/bash

for option in "$@"
do
  case "${option}" in
  frontend)
    zypper -n install --no-recommends --replacefiles \
      sphinx \
      phantomjs \
      nodejs6 npm6 \
      mariadb-client \
      sqlite3-devel \
      git-core \
      ruby2.5-devel cyrus-sasl-devel openldap2-devel libxml2-devel zlib-devel libxslt-devel \
      perl-XML-Parser \
      libffi48-devel autoconf \
      ruby2.5-rubygem-mysql2 \
      ruby2.5-rubygem-bundler
    ;;

  backend)
    zypper -n install --no-recommends --replacefiles \
      inst-source-utils \
      obs-server obs-signd \
      obs-service-download_src_package obs-service-download_files \
      obs-service-download_url \
      obs-service-format_spec_file obs-service-kiwi_import \
      perl-Devel-Cover perl-Diff-LibXDiff \
      osc
    ;;

  memcached)
    zypper -n install --no-recommends --replacefiles memcached
    ;;

  *)
    echo "Error: possible options are: frontend|backend|memcached"
    exit
    ;;

  esac
done

#!/bin/bash

for option in "$@"
do
  case "${option}" in
  frontend)
    zypper -n install --no-recommends --replacefiles \
      sphinx \
      nodejs6 npm6 \
      mariadb-client \
      mysql-devel \
      sqlite3-devel \
      git-core \
      ruby2.5-devel cyrus-sasl-devel openldap2-devel libxml2-devel zlib-devel libxslt-devel \
      perl-XML-Parser \
      libffi48-devel autoconf \
      ruby2.5-rubygem-bundler
    ;;

  backend)
    zypper ar -f https://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Leap_42.3/Cloud:Tools.repo
    zypper ar -f https://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Leap_42.3/devel:languages:python.repo
    zypper --gpg-auto-import-keys refresh
    zypper -n install --no-recommends --replacefiles \
      inst-source-utils \
      obs-server obs-signd \
      obs-service-download_src_package obs-service-download_files \
      obs-service-download_url \
      obs-service-format_spec_file obs-service-kiwi_import \
      perl-Devel-Cover perl-Diff-LibXDiff \
      osc \
      python3-setuptools \
      python3-ec2uploadimg \
      aws-cli \
      azure-cli
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

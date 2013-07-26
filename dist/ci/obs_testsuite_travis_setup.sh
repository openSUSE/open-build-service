#! /bin/sh

. `dirname $0`/obs_testsuite_common.sh

setup_git
setup_api

case "$SUBTEST" in
  webui*)
    setup_webui
    ;;
esac


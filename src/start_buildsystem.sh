#!/bin/bash

basedir=/srv/www/opensuse

webclient_port=3000
frontend_port=3001
backend_dummy_port=3002

#terminate running servers
for i in `ps aux | grep -P "\sruby script/server" | awk '{ print $2 }'`; do
  echo "killing script/server process with pid $i..."
  kill -9 $i;
done

for service in webclient frontend backend_dummy; do
  echo "starting $service..."
  pushd $basedir/$service/current > /dev/null
  portvarname=${service}_port
  logfile=log/$service.log

  script/server webrick -p ${!portvarname} >>$logfile 2>&1 &
  server_pid=`ps aux | grep -P "\sruby script/server webrick -p ${!portvarname}" | awk '{ print $2 }'`
  if [ -n $server_pid ]; then
    echo "$service started with pid $server_pid"
  else
    echo "failed to start $service, check $basedir/$service/shared/log/$service.log"
    exit 1
  fi

  popd > /dev/null
done

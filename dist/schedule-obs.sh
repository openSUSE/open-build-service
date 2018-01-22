#! /bin/sh

set -e
unset OPENQA_CONFIG

function trigger_run {
  OBS_VERSION="$1"
  FULL_URL="http://download.opensuse.org/repositories/OBS:/$2/"
  filename=`curl -s $FULL_URL | grep "obs-server.x86_64-.*qcow2" | head -n1 | sed -e 's,.*href=",,; s,".*,,; s,\.mirrorlist,,'`
  ofilename=`cat /tmp/.last.obs_$OBS_VERSION`
  if test "x$ofilename" != "x$filename"; then
    /usr/share/openqa/script/client isos post --host https://openqa.opensuse.org HDD_1_URL=$FULL_URL$filename DISTRI=obs ARCH=x86_64 VERSION=$OBS_VERSION BUILD=`echo $filename | sed -e 's,obs-server.x86_64-,,; s,Build,,; s,\.qcow2,,'` FLAVOR=Appliance --apikey B21ADBFF1E8C26AD --apisecret BD471AE6BA32781D > /dev/null
    echo $filename > /tmp/.last.obs_$OBS_VERSION
  fi
}

trigger_run Unstable Server:/Unstable/images
trigger_run 2.8 Server:/2.8:/Staging/images
trigger_run 2.9 Server:/2.9:/Staging/images

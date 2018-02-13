#!/bin/bash

DAEMON_UID=2
DAEMON_GID=2

SUSE=$( . /etc/os-release; echo $ID )
VERSION=$( . /etc/os-release; echo $VERSION )

if [ -z "$DOCKER_IMAGE" ];then
  DOCKER_IMAGE="obs-source-service:latest"
fi

if [ $UID != 0 ];then
  echo "You must be root!"
  exit 1
fi

if [ "$SUSE" == "opensuse" ]; then
  SUSE=openSUSE
  downloadserver="http://download.opensuse.org"
  echo "Adding repository for docker containers"
  zypper ar --refresh -n --no-gpg-checks $downloadserver/repositories/Virtualization:/containers/$SUSE"_Leap_"$VERSION/Virtualization:containers.repo
  echo "Adding repository for source service containment"
  zypper ar --refresh -n --no-gpg-checks -t rpm-md $downloadserver/repositories/OBS:/Server:/Unstable/containment/ Containment
  echo "Adding main obs repository"
  zypper ar --refresh -n --no-gpg-checks $downloadserver/repositories/OBS:/Server:/Unstable/$SUSE\_$VERSION/OBS:Server:Unstable.repo

  docker_install="obs-source-service-docker-image"
elif [ "$SUSE" == "SLE" -o "$SUSE" == "sles" ]; then
  SUSE=SLE_
  VERSION=${VERSION/-/_}
  echo "Adding repository for source service containment"
  zypper ar --refresh -n --no-gpg-checks -t rpm-md $downloadserver/repositories/OBS:/Server:/Unstable/containment/ Containment
  docker_install="obs-source-service-docker-image"
  # If we are on a SLE the download server and repositories must be different. 
  # Must be clarified. Until clarification the installer only works on openSUSE Distributions.
else
  echo "Something wrong with the OS brand. Must be SLE or opensuse ($SUSE)."
  exit
fi

function check_vg_opts {
  VG_NAME="`echo $HOSTNAME|perl -p -e 's/-/_/g'`_docker"

  if [ -z "$PV_DEVICE" ];then
    echo "Please enter pv device"
    read PV_DEVICE
  fi

  if [ -z "$NON_INTERACTIVE_MODE" ];then
    echo "PV device $PV_DEVICE is used"
    echo "VG name $VG_NAME is used."
    echo "Please confirm with 'yes'"
    read YES
  else
    YES=yes
  fi

  if [[ $YES != 'yes' ]];then
    exit 1
  fi
}

function install_docker_vg {
  # setup is now done by docker daemon

cat <<EOF > /etc/docker/daemon.json
{
  "storage-driver": "devicemapper",
   "storage-opts": [
    "dm.directlvm_device=$PV_DEVICE",
    "dm.thinp_percent=95",
    "dm.thinp_metapercent=1",
    "dm.thinp_autoextend_threshold=80",
    "dm.thinp_autoextend_percent=20",
    "dm.directlvm_device_force=false"
   ]
}
EOF
}

echo "Refreshing repositories"
zypper -n --gpg-auto-import-keys ref -s

# Install the software we need
echo "Installing required software"
zypper -n remove kernel-default-base
zypper -n install kernel-default
zypper -n install obs-server obs-source_service perl-XML-Structured acl
zypper -n install docker sle2docker

echo "creating run directory for service"
mkdir -p /srv/obs/run
chown obsrun:obsrun /srv/obs/run

echo "set extended acl feature on /srv/obs/run/"
setfacl -m u:obsservicerun:rwx /srv/obs/run/

echo "Setting correct bsservicegroup"
if grep -q "^our \$bsservicegroup =.*" /usr/lib/obs/server/BSConfig.pm; then
  echo "Changing service group ..."
  sed -i "s,^our \$bsservicegroup =.*,our \$bsservicegroup = 'docker';," /usr/lib/obs/server/BSConfig.pm
fi

echo "Setting service wrapper"
if ! grep -q "^our \$service_wrapper =.*" /usr/lib/obs/server/BSConfig.pm; then
  echo "No service wrapper defined. We must create one..."
  echo "our \$service_wrapper = { '*' => '/usr/lib/obs/server/call-service-in-docker.sh' };1;" >> /usr/lib/obs/server/BSConfig.pm
fi

echo "Setting docker image"
if ! grep -q "^our \$docker_image =.*" /usr/lib/obs/server/BSConfig.pm; then
  echo "No docker image configured. Will configure the docker image..."
  echo "our \$docker_image = '$DOCKER_IMAGE';1;" >> /usr/lib/obs/server/BSConfig.pm
fi

echo "Altering default docker opts"
sed -i 's,DOCKER_OPTS=.*, DOCKER_OPTS="--userns-remap=obsservicerun:obsrun",' /etc/sysconfig/docker

echo "creating subuid and subgid"
grep -q -P '^obsservicerun:' /etc/subuid || \
  echo "obsservicerun:"$(($( id -u obsservicerun ) - $DAEMON_UID ))":65536" >> /etc/subuid
grep -q -P '^obsrun:' /etc/subgid || \
  echo "obsrun:"$(($( id -g obsservicerun ) - $DAEMON_GID ))":65536" >> /etc/subgid

check_vg_opts

install_docker_vg

echo "enable and start docker"
systemctl enable docker
systemctl restart docker

echo "enable and start obsservice"
systemctl enable obsservice
systemctl restart obsservice

echo "install and register containment"
zypper -n install --replacefiles $docker_install

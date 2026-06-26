* Create an separate project e.g. "OBS"
* Create flavors
  * nova flavor-create obs-server auto 4096 32 4
  * nova flavor-create obs-flavor auto 1024 32 1
* Create security groups 
  * dist/openstack/create-secgroups.sh

# OBS-Server

* Download obs-server and upload it to openstack "OBS" Project
  * wget http://download.opensuse.org/repositories/OBS:/Server:/Unstable/images/obs-server.x86_64.qcow2
  * glance image-create --name obs-server-2.7.52 --file obs-server.x86_64.qcow2 --progress --container-format bare --disk-format qcow2
* Create volume from obs-server image
  * cinder create --image obs-server-2.7.52 --name obs-server-root 32
* Make volume bootable 
  * cinder  set-bootable $VOL_ID true
* Start instance with create volume
  * nova boot --flavor obs-server --boot-volume $VOL_ID --nic net-name=fixed obs-server
* Associate floating ip
  * FIXEDIPADDR=`nova show obs-server|grep "fixed network"|cut -f 3 -d\| |cut -f 1 -d,|perl -p -e 's/\s//g'`
  * PORT_ID=`neutron port-list |grep $FIXEDIPADDR|cut -f2 -d\| | perl -p -e 's/\s//g'`
  + neutron floatingip-list 
  * neutron floatingip-associate <FLOATING_IP_ID> $PORT_ID
* Set security groups for obs-server
  * nova  remove-secgroup obs-server default
  * nova  add-secgroup obs-server obs-server
* Login on console, set password and start sshd
  * passwd root
  * systemctl start sshd
  * systemctl enable sshd
* Login and stop worker
  * systemctl stop obsworker
  * systemctl disable obsworker
* DONT FORGET TO CHECK YOUR GRUB CONFIG

# OBS-Worker

* Download JeOS image and upload it to openstack "OBS" Project
  * wget http://download.opensuse.org/repositories/openSUSE:/infrastructure:/Images:/openSUSE_Leap_42.2/images/admin-openSUSE-Leap-42.2.x86_64-0.1.0-Build9.35.raw.xz
  * xzcat admin-openSUSE-Leap-42.2.x86_64-0.1.0-Build9.35.raw.xz > admin-openSUSE-Leap-42.2.x86_64-0.1.0-Build9.35.raw
  * glance image-create --name admin-openSUSE-Leap-42.2 --file admin-openSUSE-Leap-42.2.x86_64-0.1.0-Build9.35.raw --progress --container-format bare --disk-format raw
* Create volume from JeOS image
  * cinder create --image admin-openSUSE-Leap-42.2 --name obs-worker-root 16
* Make volume bootable
  * cinder  set-bootable $VOL_ID true
* Start instance from uploaded image
  * nova boot --flavor obs-worker --boot-volume $VOL_ID --nic net-name=fixed  obs-worker
  * Associate IP
* configure hostname and dhcp
* SSHD (optional)
  * passwd root
  * systemctl start sshd
  * systemctl enable sshd
* Add O:S:U
  * zypper -n ar http://download.opensuse.org/repositories/OBS:/Server:/Unstable/openSUSE_42.2/OBS:Server:Unstable.repo
  * zypper ar http://download.opensuse.org/update/leap/42.2/oss/ repo-update
  * zypper ar -t yast http://download.opensuse.org/distribution/leap/42.2/repo/oss/ repo-oss
  * zypper ref -s
* install obs-worker and openstack related packages
  * zypper -n in obs-worker python-websocket-client python-glanceclient python-cinderclient python-novaclient python-neutronclient

* get access settings (OBS-openrc.sh)
* source OBS-openrc.sh
* Create and upload grub-image
  (dist/openstack/create-grub-image.sh)
* Configure OBS worker in /etc/sysconfig/obs-server
  * You have to configure at least the following variables
    * OBS_SRC_SERVER="$OBSSERVER_IP:5352"
    * OBS_REPO_SERVERS="$OBSSERVER_IP:5252"
    * OBS_VM_TYPE="openstack"
    * OBS_WORKER_CONTROL_INSTANCE=
    * OBS_WORKER_OS_FLAVOR=
    * OS_AUTH_URL=
    * OS_PROJECT_ID=
    * OS_PROJECT_NAME=
    * OS_USER_DOMAIN_NAME=
    * OS_USERNAME=
    * OS_PASSWORD=
    * OS_REGION_NAME=

* Configure OpenStack settings (in /etc/sysconfig/obs-server)
* create Volumes (boot/root/swap) for NUM of workers
  (dist/openstack/create-vm-volumes.sh)
* Configure SecGroup for access to worker
 * 

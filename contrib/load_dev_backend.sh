#!/bin/bash

#set perl include path to our development backend
PERL5LIB=/vagrant/src/backend
export PERL5LIB

#create BSConfig.pm and change hostname to localhost
if [ ! -f /vagrant/src/backend/BSConfig.pm ]; then
  cp /vagrant/src/backend/BSConfig.pm.template /vagrant/src/backend/BSConfig.pm
fi
perl -pi -e 's/my \$hostname.*/my \$hostname="localhost";/' /vagrant/src/backend/BSConfig.pm


#start backend services (the minimum needed) with two arch(i586/x86_64) schedulers and one worker
echo "Starting bs_srcserver"
sudo /vagrant/src/backend/bs_srcserver &
echo "Starting bs_repserver"
sudo /vagrant/src/backend/bs_repserver &
echo "Starting bs_sched"
sudo /vagrant/src/backend/bs_sched i586 &
sudo /vagrant/src/backend/bs_sched x86_64 &
echo "Starting bs_dispatch"
sudo /vagrant/src/backend/bs_dispatch &
echo "Starting bs_publish"
sudo /vagrant/src/backend/bs_publish &
if [ ! -d /srv/obs/run/worker/1 ]; then
	sudo mkdir -p /srv/obs/run/worker/1
fi
if [ ! -d /var/cache/obs/worker/root_1 ]; then
	sudo mkdir -p /var/cache/obs/worker/root_1
fi
sudo chown -R obsrun:obsrun /srv/obs/run/
echo "Starting bs_worker"
sudo /vagrant/src/backend/bs_worker --hardstatus --root /var/cache/obs/worker/root_1 --statedir /srv/obs/run/worker/1 --id vagrant-obs:1 --reposerver http://localhost:5252 --hostlabel OBS_WORKER_SECURITY_LEVEL_ --jobs 1 --cachedir /var/cache/obs/worker/cache --cachesize 3967 &

#Cleanup function to terminate all backend services
function clean_up {
	echo -e "\ncleaning up and exit"
	echo -e "Terminating Services"
	sudo killall bs_srcserver
	echo -e "Terminated SRC Server"
	sudo killall bs_repserver
	echo -e "Terminated REP Server"
	sudo killall bs_sched
	echo -e "Terminated Scheduler"
	sudo killall bs_dispatch
	echo -e "Terminated Dispatcher"
	sudo killall bs_worker
	echo -e "Terminated Worker"
        sudo killall bs_publish
	echo -e "Terminated Publisher"
	exit;
}

echo "If you want to terminate the backend, just hit Ctrl-C"
while true; do
	trap clean_up SIGHUP SIGINT SIGTERM SIGKILL
done


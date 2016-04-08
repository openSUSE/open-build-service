# Manual Setup Guide

## <a name="toc"> Table of Contents
* [Table of Contents](#toc)
* [Basic Setup of OBS Server](#basic_setup)
    * [Prerequisites](#prerequisites)
        * [Install/Configure the SQL Database](#install_mysql)
        * [Install the Memcache Daemon](#install_memcached)
    * [Install/Configure the Open Build Service](#install_obs)
        * [Howto install the OBS backend](#install_obs_backend)
        * [Howto install the OBS frontend](#install_obs_frontend)
* [Advanced Setup](#advanced_setup)
    * [Distributed Workers](#advanced_setup_distributed_workers)
    * [Distributed Backend](#advanced_setup_distributed_backend)

## <a name="basic_setup"/> Basic Setup of OBS Server

  **WARNING:**

  **The following HOWTO will start services which are accessible from the outside. 
  Do not do this on a system connected to an untrusted network!**

### <a name="prerequisites"/> Prerequisites

  The OBS needs a SQL database for persistent and a memcache daemon for volatile data.

#### <a name="install_mysql"/> Install/Configure the SQL Database

  Here is an example on how to setup [MariaDB](https://mariadb.org/) on the [openSUSE Linux Distribution](http://www.opensuse.org). 
  If you use another Linux distribution or another OS please refer to your manuals on how to get this running.

  1. Install the mysql package:

        zypper in mariadb

  2. Start the database permanently:

        systemctl enable mysql.service
        systemctl start mysql.service

  3. Secure the database and set a database (root) password:

        mysql_secure_installation

  **WARNING**:
  If you use the SQL database for other services too,
  it's recommended to [add a separate SQL user](https://dev.mysql.com/doc/refman/5.1/en/adding-users.html).

#### <a name="install_memcached"/> Install the Memcache Daemon

  Here is an example on how to setup [memcached](http://www.memcached.org/) on the [openSUSE Linux Distribution](http://www.opensuse.org). 
  If you use another Linux distribution or another OS please refer to your manuals on how to get this running.

  1. Install the memcachd package:

        zypper in memcached

  2. Start the memcache daemon permanently:

        systemctl enable memcached
        systemctl start memcached

### <a name="install_obs"/> Install/Configure the Open Build Service

  **Note:**

  We maintain an [OBS package repository](https://build.opensuse.org/project/show/OBS:Server:2.7) 
  which provides all the necessary packages and dependencies to run an OBS backend on the 
  [SUSE Linux Enterprise](https://www.suse.com/products/server/) or 
  [openSUSE](http://www.opensuse.org) operating systems. 

  We highly recommend, and in fact only test these host systems, for OBS backend installations. 
  The OBS backend is not a monolithic server, 
  it consists of [multiple daemons that fulfill different tasks](https://github.com/openSUSE/open-build-service/blob/master/src/backend/DESIGN) 
  and is written mostly in [Perl](http://www.perl.org/).

  The following guide describes, how to install on the latest version of the
  [openSUSE Linux Distribution](http://www.opensuse.org)

  First of all you need to activate the OBS Server repository for the latest stable version (or the version you want to install)

        zypper ar -f http://download.opensuse.org/repositories/OBS:/Server:/2.7/openSUSE_42.1/OBS:Server:2.7.repo

#### <a name="install_obs_backend"/> Howto install the OBS backend

  1. Install the packages:

        zypper in obs-server


  2. Enable and Start the required services

    2.1 Start the repository server:

         systemctl enable obsrepserver.service
         systemctl start obsrepserver.service

    2.2 Start the source server:

        systemctl enable obssrcserver.service
        systemctl start obssrcserver.service

    2.3 Start the scheduler:

        systemctl enable obsscheduler.service
        systemctl start obsscheduler.service

    2.4 Start the dispatcher:

        systemctl enable obsdispatcher.service
        systemctl start obsdispatcher.service

    2.5 Start the publisher:

        systemctl enable obspublisher.service
        systemctl start obspublisher.service

    2.6 Start one or more workers:

        systemctl enable obsworker.service
        systemctl start obsworker.service


  3. Enable and Start the *optinal* services

    3.1 Start the signer in case you want to sign packages

        systemctl enable obssigner.service
        systemctl start obssigner.service

    3.2 Start the warden in case you want to monitor workers

        systemctl enable obswarden.service
        systemctl start obswarden.service


### <a name="install_obs_frontend"/> Howto install the OBS frontend


  The OBS frontend is a [Ruby on Rails](http://rubyonrails.org/) application that collects the OBS data and serves the HTML and XML views.


  1. Install the packages:

        zypper in obs-api

  2. Configure the database password you have set previously:

    In */srv/www/obs/api/config/database.yml*:

        production:
          adapter: mysql2
          database: api_production
          username: root
          password: YOUR_PASSWORD
          encoding: utf8

  3. Allow anonymous access to your API:

    In */srv/www/obs/api/config/options.yml*:

        allow_anonymous: true
        read_only_hosts: [ "127.0.0.1", 'localhost' ]

  4. Setup the production databases:

        RAILS_ENV=production rake -f /srv/www/obs/api/Rakefile db:create
        RAILS_ENV=production rake -f /srv/www/obs/api/Rakefile db:setup

  5. Setup the Apache webserver:

    In the apache2 configuration file */etc/sysconfig/apache2*
    append the following apache modules to the variable *APACHE_MODULES*:

        APACHE_MODULES="... passenger rewrite proxy proxy_http xforward headers"

    and enable SSL in the *APACHE_SERVER_FLAGS* by adding:

        APACHE_SERVER_FLAGS="-DSSL"

    The obs-api package comes with an apache configuration file.

        /etc/apache2/vhosts.d/obs.conf

    In the mod_passenger configuration file */etc/apache2/conf.d/mod_passenger.conf*
    change the ruby interpreter to ruby 2.3


        PassengerRuby "/usr/bin/ruby.ruby2.3"


  6. Enable the xforward mode:

     In */srv/www/obs/api/config/options.yml*:

        use_xforward: true


  7. Create a self-signed SSL certificate:

        mkdir /srv/obs/certs
        openssl genrsa -out /srv/obs/certs/server.key 1024
        openssl req -new -key /srv/obs/certs/server.key -out /srv/obs/certs/server.csr
        openssl x509 -req -days 365 -in /srv/obs/certs/server.csr -signkey /srv/obs/certs/server.key -out /srv/obs/certs/server.crt
        cat /srv/obs/certs/server.key /srv/obs/certs/server.crt > /srv/obs/certs/server.pem

  8. Trust this certificate on your host: *TODO M0ses: obsolete in Leap: rework* 


        cp /srv/obs/certs/server.pem /usr/share/pki/trust/anchors/server.`hostname`.pem
        update-ca-certificates


  9. Start the web server permanently:

        systemctl enable apache2
        systemctl start apache2

  10. Start the OBS delayed job daemon:

        systemctl enable obsapidelayed.service
        systemctl start obsapidelayed.service

  11. Check out your OBS frontend:

    By default, you can see the HTML views on port 443 (e.g: https://localhost) and the repos on port 82 (once some packages are built). 
    The default admin user is "Admin" with the password "opensuse".

## <a name="advanced_setup"/> Advanced Setup

### <a name="advanced_setup_distributed_workers"/> Distributed Workers

  To not burden your OBS backend daemons with the unpredictable load package builds can produce (think someone builds a monstrous package like LibreOffice) you should not run OBS workers on the same host as the rest of the backend daemons. 

  Here is an example on how to setup a remote OBS worker on the [openSUSE Linux Distribution](http://www.opensuse.org).

    1. Install the worker packages:

        zypper ar -f http://download.opensuse.org/repositories/OBS:/Server:/2.6/openSUSE_13.2/OBS:Server:2.6.repo
        zypper in obs-worker


    2. Configure the OBS repository server address:

    In the file */etc/sysconfig/obs-server* change a variable *OBS_REPO_SERVERS* to the hostname of the machine where the repository server is running:

        OBS_REPO_SERVERS="myreposerver.example:5252"

    3. Start the worker:

        systemctl enable obsworker
        systemctl start obsworker

### <a name="advanced_setup_distributed_backend"/> Distributed Backend

  All OBS backend daemons can also be started on individual machines in your network. 
  Especially for large scale OBS installations this is the recommended setup. 
  You can configure all of this in the file

        /usr/lib/obs/server/BSConfig.pm

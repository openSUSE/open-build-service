[![Build Status](https://secure.travis-ci.org/openSUSE/open-build-service.png?branch=master)](https://travis-ci.org/openSUSE/open-build-service)
[![Code Climate](https://codeclimate.com/github/openSUSE/open-build-service.png)](https://codeclimate.com/github/openSUSE/open-build-service)
[![Coverage Status](https://coveralls.io/repos/openSUSE/open-build-service/badge.png)](https://coveralls.io/r/openSUSE/open-build-service)

# Open Build Service
The [Open Build Service (OBS)](http://www.open-build-service.org) is a generic system to build and distribute binary packages from sources in an automatic, consistent and reproducible way. You can release packages as well as updates, add-ons, appliances and entire distributions for a wide range of operating systems and hardware architectures. More information can be found on [openbuildservice.org](http://www.openbuildservice.org).

The OBS consists of the backend and the frontend. The backend implements all the core functionality (i.e. building packages), whereas the frontend provides an interface to the backend. You can access the frontend either via a browser or using our XML API. Additionally there is a command line client (osc) for the API which is developed in a [separate repository](https://github.com/openSUSE/osc).

## Licensing
The Open Build Service is Free Software and is released under the terms of the GPL, except where noted. Additionally, 3rd-party content (like, but not exclusively, the webui icon theme) may be released under a different license. Please check the respective files for details.

## Community
You can discuss with the OBS Team via IRC on the channel [#opensuse-buildservice](irc://freenode.net/opensuse-buildservice). Or you can use our mailing list [opensuse-buildservice@opensuse.org](mailto:opensuse-buildservice+subscribe@opensuse.org)

## Source Code Repository Layout
The OBS source code repository is hosted on [Github](http://github.com/opensuse/open-build-service) and organized like this:

        dist          Files relevant for our distribution packages
        docs          Documentation, examples and schema files
        src/api       Rails app (Ruby on Rails)
        src/backend   Backend code (Perl)

## Setup
There are 3 scenarios for which you can setup an OBS instance. Running it in *production* for your users, for *development* on it and for executing the *test* suite.

To run the OBS in production we recommend to use our [OBS appliance](http://openbuildservice.org/download/) which is the whole package: a recent and stable Linux Operating System ([openSUSE](http://www.opensuse.org)) bundled and pre-configured with all the server and OBS components you need to get going.

If an appliance isn’t an option for you, read on for how to setup OBS with packages or from the source code repository. 

### Prerequisites
The OBS needs a SQL database for persistent and a memcache daemon for volatile data.

#### Install/Configure the SQL Database
Here is an example on how to setup [MariaDB](https://mariadb.org/) on the [openSUSE Linux Distribution](http://www.opensuse.org). If you use another Linux distribution or another OS please refer to your manuals on how to get this running.

1. Install the mysql package:
```
zypper in mariadb
```

2. Start the database permanently:
```
systemctl enable mysql.service
systemctl start mysql.service
```

3. Secure the database and set a database (root) password:
```
mysql_secure_installation
```

**WARNING**: If you use the SQL database for other services, too, then it's recommended to [add a separate SQL user](https://dev.mysql.com/doc/refman/5.1/en/adding-users.html). 

#### Install the Memcache Daemon
Here is an example on how to setup [memcached](http://www.memcached.org/) on the [openSUSE Linux Distribution](http://www.opensuse.org). If you use another Linux distribution or another OS please refer to your manuals on how to get this running.

1. Install the memcachd package:
```
zypper in memcached
```

2. Start the memcache daemon permanently:
```
systemctl enable memcached
systemctl start memcached
```

### Install/Configure the OBS Backend
The OBS backend is not a monolithic server, it consists of [multiple daemons that fulfill different tasks](https://github.com/openSUSE/open-build-service/blob/master/src/backend/DESIGN) and is written mostly in [Perl](http://www.perl.org/). 

#### Setup an OBS backend for production use
We maintain an [OBS package repository](https://build.opensuse.org/project/show/OBS:Server:2.4)  which provides all the neccesarry packages and dependencies to run an OBS backend on the [SUSE Linux Enterprise](https://www.suse.com/products/server/) or [openSUSE](http://www.opensuse.org) operating systems. We highly recommend, and in fact only test these host systems, for OBS backend installations. Here is an example on how to setup the backend on the [openSUSE Linux Distribution](http://www.opensuse.org). 

**WARNING**: The following commands start services which are accessible from the outside. Do not do this on a system connected to an untrusted network!

1. Install the packages
```
zypper ar -f http://download.opensuse.org/repositories/OBS:/Server:/2.4/openSUSE_12.3/OBS:Server:2.4.repo
zypper in obs-server
```

2. Start the repository server
```
systemctl enable obsrepserver.service
systemctl start obsrepserver.service
```

3. Start the source server
```
systemctl enable obssrcserver.service
systemctl start obssrcserver.service
```

4. Start the scheduler
```
systemctl enable obsscheduler.service
systemctl start obsscheduler.service
```

5. Start the dispatcher
```
systemctl enable obsdispatcher.service
systemctl start obsdispatcher.service
```

6. Start the publisher
```
systemctl enable obspublisher.service
systemctl start obspublisher.service
```

7. Start one or more workers
```
systemctl enable obsworker.service
systemctl start obsworker.service
```

8. Start the signer in case you want to sign packages (**OPTIONAL**)
```
systemctl enable obssigner.service
systemctl start obssigner.service
```

9. Start the warden in case you want to monitor workers (**OPTIONAL**)
```
systemctl enable obswarden.service
systemctl start obswarden.service
```

##### Distributed Backend
All OBS backend daemons can also be started on individual machines in your network. Especially for large scale OBS installations this is the recommended setup. You can configure all of this in the file

```
/usr/lib/obs/server/BSConfig.pm
```

##### Distributed Workers 
To not burden your OBS backend daemons with the unpredictable load package builds can produce (think someone builds a monstrous package like LibreOffice) you should not run OBS workers on the same host as the rest of the backend daemons. Here is an example on how to setup a remote OBS worker on the [openSUSE Linux Distribution](http://www.opensuse.org).

1. Install the worker packages
```
zypper ar -f http://download.opensuse.org/repositories/OBS:/Server:/2.4/openSUSE_12.3/OBS:Server:2.4.repo
zypper in obs-worker
```

2. Configure the OBS repository server address
In the file
```
/etc/sysconfig/obs-server
```
change a variable *OBS_REPO_SERVERS* to the hostname of the machine where the repository server is running.
```
OBS_REPO_SERVERS="myreposerver.example:5252"
```

3. Start the worker
```
systemctl enable obsworker
systemctl start obsworker
```

##### Importing Distributions (*OPTIONAL*)
The easiest and recommended way is to reuse projects hosted on the [OBS reference server](http://build.openSUSE.org). See the **frontend** section on how to make use of this. 

In addition to that, it is also possible to copy base projects with the OBS admin scripts. 

1. Install the packages
```
zypper in osc obs-utils
```

2. As root, enter your [OBS reference server](http://build.opensuse.org) account data.
```
osc
```

3. Run the *obs_mirror_project* script to fetch the project *openSUSE:13.1* from the reference server.
```
obs_mirror_project openSUSE:13.1 standard i586
```

4. Restart the scheduler to scan the new project
```
systemctl restart obsscheduler.service
```

#### Setup an OBS backend for development
Check [src/backend/README](https://github.com/openSUSE/open-build-service/blob/master/src/backend/README) how to run the backend from the source code repository. 

### Install/Configure the OBS Frontend
The OBS frontend is a [Ruby on Rails](http://rubyonrails.org/) application that collects the OBS data and serves the HTML and XML views.

#### Setup an OBS frontend for production use
We maintain an [OBS package repository](https://build.opensuse.org/project/show/OBS:Server:2.4)  which provides all the necessary packages and dependencies to run an OBS frontend on the [SUSE Linux Enterprise](https://www.suse.com/products/server/) or [openSUSE](http://www.opensuse.org) operating systems. We highly recommend, and in fact only test these host systems, for OBS frontend installations. Here is an example on how to setup the frontend on the [openSUSE Linux Distribution](http://www.opensuse.org). 

1. Install the packages
```
zypper ar -f http://download.opensuse.org/repositories/OBS:/Server:/2.4/openSUSE_12.3/OBS:Server:2.4.repo
zypper in obs-api
```

2. Configure the database password you have set previously.
<br>
In */srv/www/obs/api/config/database.yml*
```
production:
  adapter: mysql2
  database: api_production
  username: root
  password: YOUR_PASSWORD
  encoding: utf8
```
In */srv/www/obs/webui/config/database.yml*
```
production:
  adapter: mysql2
  database: webui_production
  username: root
  password: YOUR_PASSWORD
```

3. Allow anonymous access to your API
<br>
In */srv/www/obs/api/config/options.yml*
```
allow_anonymous: true
read_only_hosts: [ "127.0.0.1", 'localhost' ]
```

4. Point the webui to your API
<br>
In */srv/www/obs/webui/config/options.yml*
```
frontend_host: localhost
frontend_port: 444
```

5. Setup the production databases and log permissions
```
RAILS_ENV=production rake -f /srv/www/obs/api/Rakefile db:create
RAILS_ENV=production rake -f /srv/www/obs/api/Rakefile db:setup
RAILS_ENV=production rake -f /srv/www/obs/webui/Rakefile db:create
RAILS_ENV=production rake -f /srv/www/obs/webui/Rakefile db:setup
chown -R wwwrun.www /srv/www/obs/{api,webui}/{log,tmp}
```

6. Setup the Apache webserver
In the apache2 configuration file
```
/etc/sysconfig/apache2
```
append the following apache modules to the variable *APACHE_MODULES*
```
APACHE_MODULES="... passenger rewrite proxy proxy_http xforward headers"
```
and enable SSL in the *APACHE_SERVER_FLAGS* by adding
```
APACHE_SERVER_FLAGS="-DSSL"
```
The obs-api package comes with an apache configuration file.
```
/etc/apache2/vhosts.d/obs.conf
```

7. Enable the xforward mode.
<br>
In the files:
```
/srv/www/obs/webui/config/options.yml
/srv/www/obs/api/config/options.yml
```
enable set use_xforward to true
```
use_xforward: true
```

8. Create a self-signed SSL certificate
```
mkdir /srv/obs/certs
openssl genrsa -out /srv/obs/certs/server.key 1024
openssl req -new -key /srv/obs/certs/server.key -out /srv/obs/certs/server.csr
openssl x509 -req -days 365 -in /srv/obs/certs/server.csr -signkey /srv/obs/certs/server.key -out /srv/obs/certs/server.crt
cat /srv/obs/certs/server.key /srv/obs/certs/server.crt > /srv/obs/certs/server.pem
```

9. Trust this certificate on your host
```
cp /srv/obs/certs/server.pem /etc/ssl/certs/
c_rehash /etc/ssl/certs/
```

10. Start the web server permanently
```
systemctl enable apache2
systemctl start apache2
```

11. Start the OBS delayed job daemon
```
systemctl enable obsapidelayed.service
systemctl start obsapidelayed.service
```

12. Check out your OBS frontend
By default, you can see the HTML views on port 443 (e.g: https://localhost), the XML api on port 444 (e.g. https://localhost:444), and the repos on port 82 (once some packages are built). The default admin user is "Admin" with the password "opensuse".

#### Development

#### Test

##### Apache
##### openSSL

:heart: Your Open Build Service Team

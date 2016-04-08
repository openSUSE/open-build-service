[![Build Status](https://secure.travis-ci.org/openSUSE/open-build-service.svg?branch=master)](https://travis-ci.org/openSUSE/open-build-service)
[![Code Climate](https://codeclimate.com/github/openSUSE/open-build-service.png)](https://codeclimate.com/github/openSUSE/open-build-service)
[![Coverage Status](https://img.shields.io/coveralls/openSUSE/open-build-service.svg)](https://coveralls.io/r/openSUSE/open-build-service)

# Open Build Service
The [Open Build Service (OBS)](http://www.open-build-service.org) is a generic system to build and distribute binary packages from sources in an automatic, consistent and reproducible way. You can release packages as well as updates, add-ons, appliances and entire distributions for a wide range of operating systems and hardware architectures. More information can be found on [openbuildservice.org](http://www.openbuildservice.org).

The OBS consists of a backend and a frontend. The backend implements all the core functionality (i.e. building packages). The frontend provides a web application and XML API for interacting with the backend. Additionally there is a command line client (osc) for the API which is developed in a [separate repository](https://github.com/openSUSE/osc).

## Licensing
The Open Build Service is Free Software and is released under the terms of the GPL, except where noted. Additionally, 3rd-party content (like, but not exclusively, the webui icon theme) may be released under a different license. Please check the respective files for details.

## Community
You can discuss with the OBS Team via IRC on the channel [#opensuse-buildservice](irc://freenode.net/opensuse-buildservice). Or you can use our mailing list [opensuse-buildservice@opensuse.org](mailto:opensuse-buildservice+subscribe@opensuse.org).

### Contribution
If you want to contribute to the OBS please checkout our [contribution readme](CONTRIBUTING.md):-)

## Source Code Repository Layout
The OBS source code repository is hosted on [Github](http://github.com/opensuse/open-build-service) and organized like this:

        dist          Files relevant for our distribution packages
        docs          Documentation, examples and schema files
        src/api       Rails app (Ruby on Rails)
        src/backend   Backend code (Perl)

## Setup
There are 3 scenarios for which you can setup an OBS instance. Running it in *production* for your users, for *development* on it and for executing the *test* suite.

1. Use the OBS appliance

    To run the OBS in production we recommend using our [OBS appliance](http://openbuildservice.org/download/) which is the whole package: a recent and stable Linux Operating System ([openSUSE](http://www.opensuse.org)) bundled and pre-configured with all the server and OBS components you need to get going.

2. Install packages and run the setup wizard


3. Install packages and configure your system manually

    If you have a more complex setup (e.g. a distributed backend) we recommend to follow our [manual setup guide](dist/README.SETUP.md)


#### Setup an OBS backend for development
Check [src/backend/README](https://github.com/openSUSE/open-build-service/blob/master/src/backend/README) how to run the backend from the source code repository.


#### Development
We are using [Vagrant](https://www.vagrantup.com/) to create our development environments.

1. Install [Vagrant](https://www.vagrantup.com/downloads.html) and [VirtualBox](https://www.virtualbox.org/wiki/Downloads). Both tools support Linux, MacOS and Windows and in principal setting up your OBS development environment works similar.

2. Install [vagrant-exec](https://github.com/p0deje/vagrant-exec):

    ```
    vagrant plugin install vagrant-exec
    vagrant plugin install vagrant-reload
    # optional if you are running vagrant with libvirt (e.g. kvm)
    vagrant plugin install vagrant-libvirt
    ```

3. Clone this code repository:

    ```
    git clone --depth 1 git@github.com:openSUSE/open-build-service.git
    ```

4. Inside your clone update the backend submodule

   ```
   git submodule init
   git submodule update 
   ```   

5. Execute Vagrant:

    ```
    vagrant up
    ```

6. Start your development backend with:

    ```
    vagrant exec RAILS_ENV=development ./script/start_test_backend
    ```

7. Start your development OBS frontend:

    ```
    vagrant exec rails s
    ```

8. Check out your OBS frontend:
You can access the frontend at [localhost:3000](http://localhost:3000). Whatever you change in your cloned repository will have effect in the development environment. 

9. Changed something? Test your changes!:

    ```
    vagrant exec rake test
    ```

10. Explore the development environment:

    ```
    vagrant ssh
    ```

**Note**: The vagrant instances are configured to use the test fixtures in development mode. That includes users. Default user password is 'buildservice'. The admin user is king with password 'sunflower'.


:heart: Your Open Build Service Team

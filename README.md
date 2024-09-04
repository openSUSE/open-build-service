[![Build Status](https://circleci.com/gh/openSUSE/open-build-service.svg?style=svg)](https://circleci.com/gh/openSUSE/open-build-service)
[![Code Coverage](https://codecov.io/gh/openSUSE/open-build-service/branch/master/graph/badge.svg)](https://codecov.io/gh/openSUSE/open-build-service)
[![Code Climate](https://codeclimate.com/github/openSUSE/open-build-service.png)](https://codeclimate.com/github/openSUSE/open-build-service)
[![Depfu](https://badges.depfu.com/badges/3c5817c5855d9da3eabf1b71d64c46c1/overview.svg)](https://depfu.com/github/openSUSE/open-build-service?project=src%2Fapi%40Bundler)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/6411/badge)](https://bestpractices.coreinfrastructure.org/projects/6411)
[![build result](https://build.opensuse.org/projects/OBS:Server:Unstable/packages/obs-server/badge.svg?type=default&repository=15.6&architecture=x86_64)](https://build.opensuse.org/package/show/OBS:Server:Unstable/obs-server)

# Open Build Service
The [Open Build Service (OBS)](https://www.openbuildservice.org) is a generic system to build and distribute binary packages from sources in an automatic, consistent, and reproducible way. You can release packages as well as updates, add-ons, appliances, and entire distributions for a wide range of operating systems and hardware architectures. More information can be found on [openbuildservice.org](https://www.openbuildservice.org).

The OBS consists of a backend and a frontend. The backend implements all the core functionality (i.e. building packages). The frontend provides a web application and XML API for interacting with the backend. Additionally, there is a command line client (osc) for the API which is developed in a [separate repository](https://github.com/openSUSE/osc).

## Licensing
The Open Build Service is Free Software and is released under the terms of the GPL, except where noted. Additionally, 3rd-party content (like, but not exclusively, the webui icon theme) may be released under a different license. Please check the respective files for details.

## Community
You can discuss with the OBS Team via IRC on the channel [#opensuse-buildservice](irc://irc.libera.chat/opensuse-buildservice) or you can use our mailing list [opensuse-buildservice@opensuse.org](mailto:opensuse-buildservice+subscribe@opensuse.org). Please refer to the openSUSE Mailing Lists [page](https://en.opensuse.org/openSUSE:Mailing_lists_subscription#Subscribing) to learn about our mailing list subscription and additional information.

### Development / Contribution
If you want to contribute to the OBS, please checkout our [contribution readme](CONTRIBUTING.md):-)

![Contribution Analytics Image](https://repobeats.axiom.co/api/embed/3b8f8218c75ecc879ac59b8acc2279f66c177bb7.svg "Repobeats analytics image")

## Source Code Repository Layout
The OBS source code repository is hosted on [Github](https://github.com/opensuse/open-build-service) and organized like this:

        dist          Files relevant for our distribution packages
        docs          Documentation, examples and schema files
        src/api       Rails app (Ruby on Rails)
        src/backend   Backend code (Perl)

## Installation
To run the OBS in production, we recommend using our [appliance](https://openbuildservice.org/download/) which is the whole package: A recent and stable Linux Operating System ([openSUSE](https://www.opensuse.org)) bundled and pre-configured with all the server and OBS components you need to get going.

If that is not for you because you have some special needs for your setup (e.g. different partition schema, SLES as base system, etc.), you can also install our packages and run a setup wizard. The docker compose setup is meant only for development.

After finishing the installation of your base system, follow these steps:

1. Add the OBS software repository with zypper. Please be aware, that the needed URL differs, depending on your Base Operating System. We use openSUSE Leap 15.4 in this example.

    ```shell
    zypper ar -f https://download.opensuse.org/repositories/OBS:/Server:/2.10/15.4/OBS:Server:2.10.repo
    ```

2. Install the package

   ```shell
   zypper in -t pattern OBS_Server
   ```

3. Run our setup wizard

   ```shell
   /usr/lib/obs/server/setup-appliance.sh --force
   ```

## Advanced Setup

If you have a more complex setup (e.g. a distributed backend), we recommend to read the High-level Overview
chapter in our [Administrator Guide](https://openbuildservice.org/help/manuals/obs-admin-guide/cha-obs-admin).

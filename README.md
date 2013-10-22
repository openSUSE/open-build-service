[![Build Status](https://secure.travis-ci.org/openSUSE/open-build-service.png?branch=master)](https://travis-ci.org/openSUSE/open-build-service)
[![Code Climate](https://codeclimate.com/github/openSUSE/open-build-service.png)](https://codeclimate.com/github/openSUSE/open-build-service)
[![Coverage Status](https://coveralls.io/repos/openSUSE/open-build-service/badge.png)](https://coveralls.io/r/openSUSE/open-build-service)


Open Build Service
==================

[The Open Build Service (OBS)](http://www.open-build-service.org) is a generic system
to build and distribute binary packages from sources in an automatic, consistent and
reproducible way. You can release packages as well as updates, add-ons, appliances and
entire distributions for a wide range of operating systems and hardware architectures.

More information can be found on [openbuildservice.org](http://www.openbuildservice.org),
including the official books for OBS.

Organization
------------

The Open Build Service consists of several parts, namely the backend and the
Rails app. The backend implements all the core functionality (i.e. the
business logic), whereas the Rails app provides an interface to the backend.
You can access the Rails app either using a browser or using our API.
Therefore the source code is organized like this:

###Directory Description

	dist          Files relevant for (distro) packaging
	docs          Documentation, examples and schema files
	src/api       Rails app (Ruby / Ruby on Rails)
	src/backend   Backend code (Perl)

Note that the two parts each also have their own documentation found in their
respective subdirectories.

Installation, deployment and development
----------------------------------------

These topics are covered in the INSTALL file and on the
[openSUSE wiki](http://en.opensuse.org/Portal:Build_Service).

###Licensing

The Open Build Service is Free Software and is released under the terms of
the GPL, except where noted. Additionally, 3rd-party content (like, but not
exclusively, the webui icon theme) may be released under a different license.
Please check the respective files for details.

###Contact

The Build Service project is hosted on [Github](http://github.com/opensuse/open-build-service)
and you can discuss with the OBS Team via IRC on the channel
[#opensuse-buildservice](irc://freenode.net/opensuse-buildservice). Or you can use our mailing list
[opensuse-buildservice@opensuse.org](mailto:opensuse-buildservice+subscribe@opensuse.org)

> Your Open Build Service Team

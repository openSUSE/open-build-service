[![Build Status](https://secure.travis-ci.org/openSUSE/open-build-service.png?branch=master)](https://travis-ci.org/openSUSE/open-build-service)
[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/openSUSE/open-build-service)

Open Build Service
==================

[The Open Build Service (OBS)](http://www.open-build-service.org) is a generic system
to build and distribute binary packages from sources in an automatic, consistent and
reproducible way. You can release packages as well as updates, add-ons, appliances and
entire distributions for a wide range of operating systems and hardware architectures.

More information can be found on [openbuildservice.org](http://www.openbuildservice.org)

Organization
------------

The Open Build Service consists of several parts, namely the backend, the
api and the webui. The backend implements all the core functionality (i.e. the
business logic), whereas the webui provides a neat browser interface. The api
forms the glue between those components and also serves as the integration
point to other external tools (hence it's name). Therefore the source code is
organized like this:

###Directory Description

	dist          Files relevant for (distro) packaging
	docs          Documentation, examples and the Build Service book
	src/api       Api code (Ruby / Ruby on Rails)
	src/backend   Backend code (Perl)
	src/webui     Webui code (Ruby / Ruby on Rails)
	shared        Stuff shared across the different parts

Note that the three parts each also have their own documentation found in their
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
[#openbuildservice](irc://freenode.net/openbuildservice). Or you can use our mailing list
[opensuse-buildservice@opensuse.org](mailto:opensuse-buildservice+subscribe@opensuse.org)

> Your Open Build Service Team

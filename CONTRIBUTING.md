# Table of Contents

1. [Request for contributions](#request-for-contributions)
2. [How to contribute code](#how-to-contribute-code)
3. [How to contribute issues](#how-to-contribute-issues)
4. [How to contribute documentation](#how-to-contribute-documentation)
5. [How to conduct yourself when contributing](#how-to-conduct-yourself-when-contributing)
6. [How to setup an OBS development environment](#how-to-setup-an-obs-development-environment)

# Request for contributions
We are always looking for contributions to the Open Build Service. Read this guide on how to do that.

In particular, this community seeks the following types of contributions:

* code: contribute your expertise in an area by helping us expand the Open Build Service
* ideas: participate in an issues thread or start your own to have your voice heard.
* copy editing: fix typos, clarify language, and generally improve the quality of the content of the Open Build Service

# How to contribute code
* Prerequisites: familiarity with [GitHub Pull Requests](https://help.github.com/articles/using-pull-requests.)
* Fork the repository and make a pull-request with your changes
  * Please make sure to mind what our test suite in [travis](https://travis-ci.org/openSUSE/open-build-service) tells you
  * Please always increase our [code coverage](https://codeclimate.com/github/openSUSE/open-build-service) by your pull request
  * To help to write better commit messages we use a [template](https://github.com/openSUSE/open-build-service/blob/master/.gitmessage).
    Set it up with the following command:
    ```
    git config commit.template .gitmessage
    ```

* A developer of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) will review your pull-request
  * If the pull request gets a positive review the reviewer will merge it


## How to write proper commit messages

- **Tag your commits**

  We tag our commits depending on the area that is affected by the change. All commits should start with at least one tag from:

  * [api]     - Changes in api related parts of app/model/ and lib/ as well as app/controllers/\*.rb and it's views
  * [backend] - Changes in the perl-written backend of OBS
  * [ci]      - Changes that affect our test suite
  * [dist]    - Modifies something inside /dist directory
  * [doc]     - Any documentation related changes
  * [webui]   - Changes in webui related parts of app/model/ and lib/ as well as app/controllers/webui/ and it's views

  In case of having more than one tag, they should be alphabetically ordered.
  
- **Leave a blank line between the commit subject and body**

  Tools like rebase could not work properly otherwise.

- **Preferably include a commit description**
  
  There is always some useful information to add in your commit. If you don't include a commit description, more likely you are missing something.

- **Try that the commit subject is not longer than 50 characters**

- **Try that each line of the commit body is not longer than 72 characters**

- **Try to avoid meaningless words/phrases**

  When possible avoid using words/phrases such as _obviously_, _basically_, _simply_, _of course_, _everyone knows_ and _easy_.

- **Preferably use `-` for lists**

  Do not use `*` as it is also used for _emphasis_.

## How to review code submissions
We make use of github [pull request reviews](https://help.github.com/articles/about-pull-request-reviews/) and we...

- ...mark nitpicks inside the comment somehow (with the 💭 emoji or *nitpick*: blah blah)
- ...aprove the pull request if our review only contains nitpicks
- ...request changes on the pull request if our review contains one non-nitpick
- ...just submit the review as comment if we can not review all of the code and just want to leave a comment

Nitpicks are things you as reviewer don't care about if they end up in the code-base. Things like

- Style changes we have not agreed on in rubocop rules yet
- Bigger refactorings that are out of scope for the pull-request
- Things new to you that you don't understand and would like to have an explanation for

# How to contribute issues
* Prerequisites: familiarity with [GitHub Issues](https://guides.github.com/features/issues/).
* Enter your issue and a member of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) will label and prioritize it for you.

We are using priority labels from **P1** to **P4** for our issues. So if you are a member of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) you are supposed to
* P1: Urgent - Fix this next even if you still have other issues assigned to you.
* P2: High   - Fix this after you have fixed all your other issues.
* P3: Medium - Fix this when you have time.
* P4: Low  - Fix this when you don't see any issues with the other priorities.

# How to contribute documentation
The Open Build Service documentation is hosted in a separated repository called [obs-docu](https://github.com/openSUSE/obs-docu). Please send pull-requests against this repository. 

# How to conduct yourself when contributing
The Open Build Service is part of the openSUSE project. We follow all the [openSUSE Guiding
Principles!](http://en.opensuse.org/openSUSE:Guiding_principles) If you think
someone doesn't do that, please let any of the [openSUSE
owners](https:/en.openSUSE.org/openSUSE:Board) know!

# How to setup an OBS development environment
We are using [docker](https://www.docker.com/) to create our development
environment. All the tools needed for this are available for Linux, MacOS and
Windows.

**Please note** that the OBS backend uses advanced filesystem features
that require an case sensitive filesystem (default in Linux, configurable in MacOS/Windows),
make sure you run all this from a filesystem that supports this.

1. Install [docker](https://www.docker.com) and [docker-compose](https://docs.docker.com/compose/).
   There is documentation about this for [openSUSE](https://en.opensuse.org/SDB:Docker) and various
   [other operating systems](https://docs.docker.com/engine/installation/)

2. Install [rake](https://github.com/ruby/rake)

3. Clone this code repository:

    ```
    git clone --depth 1 git@github.com:openSUSE/open-build-service.git
    ```

4. Inside your clone update the backend submodule

   ```
   git submodule init
   git submodule update
   ```

5. Build your development environment with:

    ```
    rake docker:build
    ```

6. Start your development environment with:

    ```
    docker-compose up
    ```

7. Check out your OBS frontend:
You can access the frontend at [localhost:3000](http://localhost:3000). Whatever you change in your cloned repository will have effect in the development environment.
**Note**: The development environment is configured with a default user 'Admin' and password 'opensuse'.

8. Building packages:
     The easiest way to start building is to create an interconnect to our reference server. All resources from the openSUSE instance, including the base distributions, can be used that way.
     To set this up, follow these steps:
     * Login as Admin and go to 'Configuration' page.
     * Go to the 'Interconnect' tab and press 'Save changes'. That creates an interconnect to build.opensuse.org.
     * Now in any other project you can choose from a wide range of distributions to build your packages on the 'Repositories' tab.

9. Changed something in the frontend? Test your changes!

    ```
    rake docker:test:frontend
    rake docker:test:lint
    ```

10. Changed something in the backend? Test your changes!

    ```
    rake docker:test:backend
    ```

11. You can find more details about the development environment [in our wiki](https://github.com/openSUSE/open-build-service/wiki/Development-Environment).

Happy Hacking! - :heart: Your Open Build Service Team

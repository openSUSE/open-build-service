# <a name="toc">Table of Contents

1. [Request for contributions](#request)
2. [How to contribute code](#contribute_code)
3. [How to contribute issues](#contribute_issues)
4. [Contribute to the OBS documentation](#contribute_docu)
5. [Conduct](#conduct)
6. [Communication](#communication)
7. [Rubocop](#rubocop)
8. [Setup an OBS backend for development](#setup_backend)
9. [Quick Start Guid (Howto setup a developer VM)](#quick_start)

# <a name="request"/> Request for contributions
We are always looking for contributions to the Open Build Service. Read this guide on how to do that.

In particular, this community seeks the following types of contributions:

* code: contribute your expertise in an area by helping us expand the Open Build Service
* ideas: participate in an issues thread or start your own to have your voice heard.
* copy editing: fix typos, clarify language, and generally improve the quality of the content of the Open Build Service

# <a name="" />How to contribute code
* Prerequisites: familiarity with [GitHub Pull Requests](https://help.github.com/articles/using-pull-requests.)
* Fork the repository and make a pull-request with your changes
  * Please make sure to mind what our test suite in [travis](https://travis-ci.org/openSUSE/open-build-service) tells you! :-)
  * Please increase our [code coverage](https://codeclimate.com/github/openSUSE/open-build-service) by your pull request!

* One of the Open Build Service maintainers will review your pull-request
  * If you are already a contributor (means you're in the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service)) and you get a positive review, you can merge your pull-request yourself
  * If you are not a contributor already the reviewer will merge your pull-request

# <a name="" />How to contribute issues
* Prerequisites: familiarity with [GitHub Issues](https://guides.github.com/features/issues/).
* Enter your issue and a member of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) will label and prioritize it for you.

We are using priority labels from **P0** to **P4** for our issues. So if you are a memer of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) you are supposed to
* P0: Critical Situation - Drop what you are doing and fix this issue now!
* P1: Urgent - Fix this next even if you still have other issues assigned to you.
* P2: High   - Fix this after you have fixed all your other issues.
* P3: Medium - Fix this when you have time.
* P4: Low  - Fix this when you don't see any issues with the other priorities.

# <a name="contribute_docu" />Contribute to the OBS documentation

The Open Build Service documentation is hosted in a separated repository available on [GitHub](https://github.com/openSUSE/obs-docu). How you can contribute to our documentation is described on our [project page](http://openbuildservice.org/help/manuals/obs-reference-guide/appendix.work_on_obs_book.html). Needless to say that contributions are highly welcome, right?;-)

# <a name="conduct" />Conduct
The Open Build Service is part of the openSUSE project. We follow all the [openSUSE Guiding
Principles!](http://en.opensuse.org/openSUSE:Guiding_principles) If you think
someone doesn't do that, please let any of the [openSUSE
owners](https://github.com/orgs/openSUSE/teams/owners) know!

# <a name="communication" />Communication
GitHub issues are the primary way for communicating about specific proposed
changes to this project. If you have other problems please use one of the other
[support channels](http://openbuildservice.org/support/)

# <a name="rubocop" />Rubocop
We are currently in the process of adding rubocop rules to OBS. For that we
frequently meet, decide on new rules to add and afterwards go through that list
and fix those.

Since we want to make sure that the number of merge conflicts stays as small as
possible, we mark rubocop offenses with name tags (in .rubocop.yml). Developers are
only supposed to work on a rubocop offense, if there is no name tag above theirs;-)

If you want to take part of this please follow this process:

* Make sure noone else is working on rubocop issues. (By Checking that your name
  is on top of the .rubocop.yml file).

* Pick one rubocop rule and enable it in .rubocop.yml. Make sure there are no
  excludes for that offense in the .rubocop_todo.yml.

* Run rubocop and fix reported offenses.

* Run rubocop --auto-gen-config to update .rubocop_todo.yml.

* Create a commit with all changes.

* Go to the next rubocop offense.

# <a name="setup_backend"/>Setup an OBS backend for development

Check [src/backend/README](https://github.com/openSUSE/open-build-service/blob/master/src/backend/README) how to run the backend from the source code repository.


# <a name="quick_start"/>Quick Start Guid (Howto setup a developer VM)

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

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

* A developer of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) will review your pull-request
  * If the pull request gets a positive review the reviewer will merge it

# How to contribute issues
* Prerequisites: familiarity with [GitHub Issues](https://guides.github.com/features/issues/).
* Enter your issue and a member of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) will label and prioritize it for you.

We are using priority labels from **P0** to **P4** for our issues. So if you are a memer of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) you are supposed to
* P0: Critical Situation - Drop what you are doing and fix this issue now!
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
owners](https://github.com/orgs/openSUSE/teams/owners) know!

# How to setup an OBS development environment

We are using [Vagrant](https://www.vagrantup.com/) to create our development environment.

1. Install [Vagrant](https://www.vagrantup.com/downloads.html) and [VirtualBox](https://www.virtualbox.org/wiki/Downloads). Both tools support Linux, MacOS and Windows.

2. Install [vagrant-exec](https://github.com/p0deje/vagrant-exec):

    ```
    vagrant plugin install vagrant-exec
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
    vagrant exec contrib/start_development_backend
    ```

7. Start your development frontend with:

    ```
    vagrant exec rails s
    ```

8. Check out your OBS frontend:
You can access the frontend at [localhost:3000](http://localhost:3000). Whatever you change in your cloned repository will have effect in the development environment.
**Note**: The vagrant instance is configured with a default user 'Admin' and password 'buildservice'.

9. Building packages:
     The easiest way to start building is to create an interconnect to build.opensuse.org. All resources, including the base distributions can be used that way directly.
     To set this up, follow these steps:
     * Login as admin and go to cofiguration page.
     * Go to the 'Interconnect' tab and press 'Save changes'. That creates an interconnect to build.opensuse.org.
     * Switch back to the 'Configuration' tab and press 'Update' to send your changes to the backend.
     * Restart the backend.
     * Now you can choose from a wide range of repositories to build your packages and images for.

10. Changed something in the frontend? Test your changes!

    ```
    vagrant exec rake test
    vagrant exec rspec
    ```

11. Changed something in the backend? Test your changes!

    ```
    vagrant exec make -C src/backend test
    ```

12. Explore the development environment:

    ```
    vagrant ssh
    ```

Happy Hacking! - :heart: Your Open Build Service Team

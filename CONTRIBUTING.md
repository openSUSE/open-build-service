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


## How to write proper commit messages

### Tag your commits

We tag our commits depending on the area that is affected by the change. **All commits should start with at least one tag** from:

* [api]     - Changes in api related parts of app/model/ and lib/ as well as app/controllers/*.rb and it's views
* [backend] - Changes in the perl-written backend of OBS
* [ci]      - Changes that affect our test suite
* [dist]    - Modifies something inside /dist directory
* [doc]     - Any documentation related changes
* [webui]   - Changes in webui related parts of app/model/ and lib/ as well as app/controllers/webui/ and it's views

In case of having more than one tag, they should be **alphabetically** ordered.


### Useful commit subject with maximum 50 characters in imperative mode

Commit subject/title should have **maximum 50 characters**, you can have as much information as you want in the commit body. Try to make the commit message useful, avoiding writing things such as the number of issue it is fixing. Nobody can remember issues numbers.

The commit message should be writen in imperative mode and **start by one of the following words**:

- Fix
- Add
- Change
- Update
- Remove
- Refactor
- Merge
- Split
- Enable
- Disable

*Do not end the summary line with a period.*


### Write proper commit descriptions

Writing a proper commit description/body is important. There is always some more useful information to add.

- **Leave empty lines between the commit subject/title** and the commit body/description. Separate also commit description/body paragraphs with empty lines and end them with a period.
- Each line of the commit body is no longer than **72 characters**.
- **Avoid meaningless words/phrases** such as: *obviously*, *basically*, *simply*, *of course*, *everyone knows*, *easy*.
- When writing lists in your commit body, do not use `*` or `•`. **Use `-` for lists** instead.
- End the commit message with a separate line in which you **mention the issue you are fixing** if any. Include the whole Github link, and not only the number. Use one of the following words:
 - Close
 - Fix
 - Resolve


### Example

```
[api][ci] Short (50 chars or less) commit title

Commit subject/description, detailed text explaining the changes. Wrap
it to 72 characters. Leave an empty line separating the commit
title/subject from the body. Do not use meaningless word/phrases. End
paragraphs with a period.

Separate paragraphs with empty lines.

  - When writing lists use `-`.

  - And only `-`. Do not use `*` or `•`.
  
Fix https://github.com/openSUSE/open-build-service/issues/1
```

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
owners](https://github.com/orgs/openSUSE/teams/owners) know!

# How to setup an OBS development environment
We are using [Vagrant](https://www.vagrantup.com/) to create our development
environment. All the tools needed for this are available for Linux, MacOS and
Windows. **Please note** that the OBS backend uses advanced filesystem features
that require an case sensitive filesystem (default in Linux, configurable in MacOS/Windows),
make sure you run all this from a filesystem that supports this.

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

6. Start your development environment with:

    ```
    vagrant exec foreman start
    ```

7. Check out your OBS frontend:
You can access the frontend at [localhost:3000](http://localhost:3000). Whatever you change in your cloned repository will have effect in the development environment.
**Note**: The vagrant instance is configured with a default user 'Admin' and password 'opensuse'.

8. Building packages:
     The easiest way to start building is to create an interconnect to build.opensuse.org. All resources, including the base distributions can be used that way directly.
     To set this up, follow these steps:
     * Login as admin and go to configuration page.
     * Go to the 'Interconnect' tab and press 'Save changes'. That creates an interconnect to build.opensuse.org.
     * Switch back to the 'Configuration' tab and press 'Update' to send your changes to the backend.
     * Restart the backend.
     * Now you can choose from a wide range of repositories to build your packages and images for.

9. Changed something in the frontend? Test your changes!

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

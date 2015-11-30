# Request for contributions
We are always looking for contributions to the Open Build Service. Read this guide on how to do that. 

In particular, this community seeks the following types of contributions:

* code: contribute your expertise in an area by helping us expand the Open Build Service
* ideas: participate in an issues thread or start your own to have your voice heard.
* copy editing: fix typos, clarify language, and generally improve the quality of the content of the Open Build Service

# How to contribute code
* Prerequisites: familiarity with [GitHub Pull Requests](https://help.github.com/articles/using-pull-requests.)
* Fork the repository and make a pull-request with your changes
  * Please make sure to mind what our test suite in [travis](https://travis-ci.org/openSUSE/open-build-service) tells you! :-)
  * Please increase our [code coverage](https://codeclimate.com/github/openSUSE/open-build-service) by your pull request!

* One of the Open Build Service maintainers will review your pull-request
  * If you are already a contributor (means you're in the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service)) and you get a positive review, you can merge your pull-request yourself
  * If you are not a contributor already the reviewer will merge your pull-request

# How to contribute issues
* Prerequisites: familiarity with [GitHub Issues](https://guides.github.com/features/issues/).
* Enter your issue and a member of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) will label and prioritize it for you.

We are using priority labels from **P0** to **P4** for our issues. So if you are a memer of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) you are supposed to
* P0: Critical Situation - Drop what you are doing and fix this issue now!
* P1: Urgent - Fix this next even if you still have other issues assigned to you.
* P2: High   - Fix this after you have fixed all your other issues.
* P3: Medium - Fix this when you have time.
* P4: Low  - Fix this when you don't see any issues with the other priorities.

# Conduct
The Open Build Service is part of the openSUSE project. We follow all the [openSUSE Guiding
Principles!](http://en.opensuse.org/openSUSE:Guiding_principles) If you think
someone doesn't do that, please let any of the [openSUSE
owners](https://github.com/orgs/openSUSE/teams/owners) know!

# Communication
GitHub issues are the primary way for communicating about specific proposed
changes to this project. If you have other problems please use one of the other
[support channels](http://openbuildservice.org/support/)

# Rubocop
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

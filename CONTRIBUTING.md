# Request for Contributions
We are always looking for contributions to the Open Build Service.

In particular, this community seeks the following types of contributions:

* code: contribute your expertise in an area by helping us expand the Open Build Service
* ideas: participate in an issues thread or start your own to have your voice heard.
* copy editing: fix typos, clarify language, and generally improve the quality of the content of the Open Build Service

Read this guide on how to do that.

1. [How to contribute code](#how-to-contribute-code)
1. [How to review code submissions](#how-to-review-code-submissions)
1. [How to contribute issues](#how-to-contribute-issues)
1. [How to contribute documentation](#how-to-contribute-documentation)
1. [How to conduct yourself when contributing](#how-to-conduct-yourself-when-contributing)
1. [How to setup an OBS development environment](#how-to-setup-an-obs-development-environment)


# How to Contribute Code
**Prerequisites**: familiarity with [GitHub Pull Requests](https://help.github.com/articles/using-pull-requests)

If you want to contribute code, fork the repository and make a pull-request
with your changes. A developer of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service)
will review your pull-request. And if the pull request gets a positive review
the reviewer will merge it.

However, please bear in mind the following things:

## Discuss Large Changes in Advance

If you see a glaring flaw within the Open Build Service, resist the urge to
jump into the code and make sweeping changes right away. We know it can be
tempting, but especially for large, structural changes(bug fixes or features)
it's a wiser choice to first discuss them on the
developer [mailing list](https://lists.opensuse.org/obs-devel).
It may turn out that someone is already working on this or that someone already
has tried to solve this and hit a roadblock, maybe there even is a good reason
why that flaw exists. If nothing else, a discussion of the change will usually
familiarize the reviewer with your proposed changes and streamline the review
process when you finally create a pull request.

A good rule of thumb for when you should discuss on the mailing list is to
estimate how much time would be wasted if the pull request was rejected. If
it's a couple of hours then you can probably dive head first and eat the loss
in the worst case. Otherwise, making a quick check with the other developers
could save you lots of time down the line.

## Small Commits & Pull Request Scope

A commit should contain a single logical change, the scope should be as small
as possible. And a pull request should only consist of the commits that you
need for your change (bug fix or feature). If it's possible for you to split
larger changes into smaller blocks please do so.

Limiting the scope of commits/pull requests makes reviewing much easier.
Because it will usually mean each commit can be evaluated independently and a
smaller amount of commits per pull request usually also means a smaller amount
of code to be reviewed.

## Proper Commit Messages

We are keen on proper commit messages because they will help us to maintain
this piece of code in the future.

- The title of your commit should summarizes **what** has been done
  - If the title is to small to explain **what** you have done then elaborate on it in the body
- Explain **why** you have changed this instead of the *how*. This is the most important content of the message.
- Explain potential side-effects of this change, if there are any

Please also:

- **Leave a blank line between the commit subject and body**

  Tools like rebase could not work properly otherwise.

- **Mention related issues**

  If this commit fixes an issue you need to mention it like `Fixes #1234`
  
- **Give kudos to Co-authors**

  If the commit has more than one author tag them with `Co-authored-by: name <name@example.com>`.

- **Try that the commit subject is not longer than 50 characters**

- **Try that each line of the commit body is not longer than 72 characters**

- **Try to avoid meaningless words/phrases**

  When possible avoid using words/phrases such as _obviously_, _basically_, _simply_, _of course_, _everyone knows_ and _easy_.

- **Preferably use `-` for lists**

  Do not use `*` as it is also used for _emphasis_.

**Please note** that we used to tag our commits to specify the areas affected by the change.
We are not tagging commits anymore, but these are the labels and their descriptions in case you review some old code:

  * [api]     - Changes in api related parts of app/model/ and lib/ as well as app/controllers/\*.rb and its views
  * [backend] - Changes in the perl-written backend of OBS
  * [ci]      - Changes that affect our test suite
  * [dist]    - Modifies something inside /dist directory
  * [doc]     - Any documentation related changes
  * [webui]   - Changes in webui related parts of app/model/ and lib/ as well as app/controllers/webui/ and its views

## Mind the Automated Reviews
Please make sure to mind our continuous integration cycle that includes:

- code style linting with tools like rubocop, jshint, haml-lint etc.
- static code analysis with [codeclimate](https://codeclimate.com/github/openSUSE/open-build-service)
- security code analysis with [hakiri](https://hakiri.io/github/openSUSE/open-build-service/)
- automated test runs for the frontend and backend test suites with [circle-ci](https://circleci.com/gh/openSUSE/workflows/open-build-service)

If one of the goes wrong for your pull request please address the issue.

## Tell Us If You Need Help

The Open Build Service developer community is here for you. If you are stuck
with some problem or decision, have no time to drive a pull-request over the
finishing line or if you just want to ask a simple question just get in contact
with us in the pull-request, over the
developer [mailing list](https://lists.opensuse.org/obs-devel) or our
IRC channel (irc://irc.freenode.net/openSUSE-buildservice).

# How to Review Code Submissions
We make use of GitHub [pull request reviews](https://help.github.com/articles/about-pull-request-reviews/) and we...

- ...mark nitpicks inside the comment somehow (with the 💭 emoji or *nitpick*: blah blah)
- ...approve the pull request if our review only contains nitpicks
- ...request changes on the pull request if our review contains one non-nitpick
- ...just submit the review as comment if we can not review all of the code and just want to leave a comment

Nitpicks are things you as reviewer don't care about if they end up in the code-base. Things like

- Style changes we have not agreed on in rubocop rules yet
- Bigger refactorings that are out of scope for the pull-request
- Things new to you that you don't understand and would like to have an explanation for

# How to Contribute Bug Reports
* Prerequisites: familiarity with [GitHub Issues](https://guides.github.com/features/issues/).
* Enter your issue and a member of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) will label and prioritize it for you.

We are using priority labels from **P1** to **P4** for our issues. So if you are a member of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service) you are supposed to
* P1: Urgent - Fix this next even if you still have other issues assigned to you.
* P2: High   - Fix this after you have fixed all your other issues.
* P3: Medium - Fix this when you have time.
* P4: Low  - Fix this when you don't see any issues with the other priorities.

# How to Contribute Documentation
The Open Build Service documentation is hosted in a separated repository called [obs-docu](https://github.com/openSUSE/obs-docu). Please send pull-requests against this repository. 

# How to Conduct Yourself when Contributing
The Open Build Service is part of the openSUSE project. We follow all the [openSUSE Guiding
Principles!](http://en.opensuse.org/openSUSE:Guiding_principles) If you think
someone doesn't do that, please let any of the [openSUSE
owners](https:/en.openSUSE.org/openSUSE:Board) know!

# How to Setup an OBS Development Environment
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
    docker-compose run --rm frontend bundle exec rspec
    docker-compose run --rm frontend bundle exec rake dev:lint
    ```

10. Changed something in the backend? Test your changes!

    ```
    docker-compose run  --rm backend make -C src/backend test
    ```

11. You can find more details about the development environment [in our wiki](https://github.com/openSUSE/open-build-service/wiki/Development-Environment).

# Happy Hacking! - :heart: Your Open Build Service Team


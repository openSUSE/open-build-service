# Request for Contributions
We are always looking for contributions to the Open Build Service.

In particular, this community seeks the following types of contributions:

* code: contribute your expertise in an area by helping us expand the Open Build Service
* ideas: participate in an issues thread or start your own to have your voice heard.
* copy editing: fix typos, clarify language, and generally improve the quality of the content of the Open Build Service

Read this guide on how to do that.

1. [How to contribute code](#how-to-contribute-code)
2. [The perfect pull request review](#the-perfect-pull-request-review)
3. [How to contribute bug reports](#how-to-contribute-bug-reports)
4. [How to contribute documentation](#how-to-contribute-documentation)
5. [How to conduct yourself when contributing](#how-to-conduct-yourself-when-contributing)
6. [How to setup an OBS development environment](#how-to-setup-an-obs-development-environment)


# How to Contribute Code
**Prerequisites**: familiarity with [GitHub Pull Requests](https://help.github.com/articles/using-pull-requests)

If you want to contribute code, fork the repository and make a pull-request
with your changes. A developer of the [open-build-service team](https://github.com/orgs/openSUSE/teams/open-build-service)
will review your pull-request. And if the pull request gets a positive review
the reviewer will merge it.

But first, please bear in mind the following guidelines to create the perfect pull request:

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
this piece of code in the future. So for the benefit of all the people who will
look at this commit now and in the future, follow this style:

- The title of your commit should summarizes **what** has been done
  - If the title is to small to explain **what** you have done then elaborate on it in the body
- The body of your commit should explain **why** you have changed this. This is
  the most important content of the message!
- Make sure you also explain potential side-effects of this change, if there are any.

Please also mind common sense rules for commit messages, we wrote some down in our wiki
https://github.com/openSUSE/open-build-service/wiki/Commit-Style

## Proper Pull Request

In order to make it as easy as possible for other developers to review your pull request we ask you to
follow what we ask in the pull request template that comes up if you open a new one.

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

# How to review code submissions
Prerequisites: familiarity with [GitHub pull request reviews](https://help.github.com/articles/about-pull-request-reviews).

We believe every code submission should be reviewed by another developer to determine its *maintainability*.
That means you, the reviewer, should check that the submitted code is:

- functional
- tested
- secure
- effective
- understandable

We also consider code reviews to be one of the best ways to share knowledge about language features/syntax, design and software architecture. So please take this seriously.

## How to Test Code Submissions
Changes to the business logic/behavior of the Open Build Service should alway be accompanied by tests
([frontend](https://github.com/openSUSE/open-build-service/tree/master/src/api/spec)/
[backend](https://github.com/openSUSE/open-build-service/tree/master/src/backend/t)) that will be run
by our continuous integration.

However there is often a significant difference between something functional and something usable.
So we strongly encourage manual testing during the code review. For this you should either check
out the changes locally (see the "view command line instructions" link at the bottom of every PR)
and run them in your development environment.

Or you make use of our [review app bot](https://github.com/openSUSE/open-build-service/wiki/Review-apps)
(by applying the `review-app` label to the PR) which will deploy the code to
our review server and tell you how to access it in a comment.

## How to Provide Feedback

The tone of your code review will greatly influence morale within our community.

Harsh language in code reviews creates a hostile environment, opinionated language turns people defensive. Often leading to heated discussions and hurt feelings. On the other hand a positive tone can contribute to a more inclusive environment. People start to feel safe, healthy and lively discussions evolve.

So here are some basic rules we aspire to follow (we took inspiration from [GitLab](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/development/code_review.md) for these) to foster constructive, positive feedback.

- **Be respectful** to each other: We are in this together!
- **Be humble**: Reviews aren't about showing off (Example: "I'm not sure - let's look it up.")
- **Be explicit**: People don't always understand your intentions online.
- **Be careful about the use of sarcasm**: Everything we do is public; what seems like good-natured kidding to you and a long-time friend, might come off as mean and unwelcoming to a person new to the project
- Accept that many decisions are opinions: Discuss trade-offs and preferences openly
- Propose solutions instead of only requesting changes. (Example: *"What do you think about naming this `:user_id` instead of `:db_user`?"*)
- Ask for clarification instead of assuming things (Example: *"I don't understand this change. Can you clarify this for me please?"*)
- Consider one-on-one chats or video calls if there are too many things that are not clear. Afterward post a follow-up comment summarizing the discussion you had, so everybody can follow your decision.
- Avoid expressing selective ownership of code (*"my code"*, *"not my code"*, *"your code"*), we are a community and share ownership
- Avoid using terms that could be seen as referring to personal traits. (Example: *"dumb"*, *"stupid"*, *"simple"*). Assume everyone is attractive, intelligent, and well-meaning, because everyone is!
- Don't use hyperbole. (Example: *"always"*, *"never"*, *"endlessly"*, *"nothing"*).
- Avoid asking for changes which are out of scope. Things out of scope should be addressed at another time (open an issue or send a PR).

## How to Merge Pull Requests

In order to merge a pull request, it needs:

- The **required** GitHub checks to pass (waiting for all checks to pass is recommended)
- A review from at least one OBS developer
- All requested changes to be addressed*

\* Dismissing a review with requested changes should only be done if we know the reviewer is not reachable for a while.

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
that require an case sensitive filesystem (default in Linux, configurable in **MacOS/Windows**),
make sure you run all this from a filesystem that supports this.

1. Install [docker](https://www.docker.com) and [docker-compose (version >= 1.20.0)¹](https://docs.docker.com/compose/).
   There is documentation about this for [openSUSE](https://en.opensuse.org/SDB:Docker) and various
   [other operating systems](https://docs.docker.com/engine/installation/).

   ¹ A version equal to or greater than _1.20.0_ is required for _docker-compose_ as we depend on the
   `--use-aliases` flag for the command `docker-compose run` in our development environment.

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
     * Go to the 'Interconnect' tab and press 'Connect' on 'Standard OBS instance'. That creates an interconnect to build.opensuse.org.
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

11. You can find more details about the development environment [in our wiki](https://github.com/openSUSE/open-build-service/wiki/Development-Environment-Tips-&-Tricks).

# Happy Hacking! - :heart: Your Open Build Service Team


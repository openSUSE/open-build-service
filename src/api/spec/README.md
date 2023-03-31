# Open Build Service Test Suite

This is a test suite based on [RSpec](http://rspec.info/). We are trying to
test things based on the following rules:

* Every method that isn't private must be tested
* Every main workflow has a feature test

## Running Specs

```bundle exec rspec```

and to run a single test file:

```
bundle exec rspec spec/models/user_spec.rb
```

## Directory Structure

All specs live under the [spec](https://github.com/openSUSE/open-build-service/tree/master/src/api/spec) directory and files matching `spec/**/*_spec.rb` are run by default.
Ruby files with custom matchers, macros or configuration belong in [spec/support/](https://github.com/openSUSE/open-build-service/tree/master/src/api/spec/support) and its subdirectories.
Require them in the individual `*_spec.rb` or `_helper.rb` files.

Shared examples that are shared among different spec files are stored in [spec/support/shared_examples/](https://github.com/openSUSE/open-build-service/tree/master/src/api/spec/support/shared_examples).
Use subdirectories to group them depending on the type of specs they are meant for (_features_, _controllers_, etc...).

## Spec Types

There are many different [types of specs](https://relishapp.com/rspec/rspec-rails/docs/directory-structure) possible in RSpec. We concentrate on 3 types:

* [Model specs](https://relishapp.com/rspec/rspec-rails/docs/model-specs) reside in the `spec/models` directory and test methods in Models.
* [Controller specs](https://relishapp.com/rspec/rspec-rails/docs/controller-specs) reside in the `spec/controllers` directory and test methods in Controllers.
* [Feature specs](https://relishapp.com/rspec/rspec-rails/docs/feature-specs/feature-spec) reside in the `spec/features` directory and test workflows through the webui.

## Adding Specs

We are using the standard [RSpec generators](https://relishapp.com/rspec/rspec-rails/docs/generators) like:

`rails generate rspec:model package` or `rails generate rspec:controller webui::blah`

### Factory Bot

We use [Factory Bot](https://github.com/thoughtbot/factory_bot_rails) to create our Ruby objects.
Unlike fixtures, factories run through ActiveRecord validations.
All factories reside under [spec/factories/](https://github.com/openSUSE/open-build-service/tree/master/src/api/spec/factories).

#### has_many associations

For creating has_many associations we use `create_list`:

```ruby
project.packages = create_list(:package, 2)
```

Please also have a look at the [Factory Bot documentation](https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md#associations).

#### Use a sequence for unique values

It's necessary to use a [sequence](https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md#sequences) for attributes which have to be unique like project.title or user.login.

```ruby
sequence(:login) { |n| "user_#{n}" }
```

Please keep in mind that you have to overwrite these attributes if they are part of the URI and you use it in combination with VCR.
Otherwise, your tests will fail as VCR matches the cassette by the URI.

```
let!(:user) { create(:confirmed_user, login: "proxy_user") }
```

By passing ```login: "proxy_user"``` to the create statement, the username is now always proxy_user and not random (e.g. user_42).

#### Factories should be the bare minimum

Different to fixtures, Factory Bot runs through your ActiveRecord validations.
That said, only add the bare minimum to your factory which is required to be valid.
You can use an inherited factory to add or override attributes.

```
  factory :user do
    email { Faker::Internet.email }
    realname { Faker::Name.name }
    sequence(:login) { |n| "user_#{n}" }
    password 'buildservice'

    factory :confirmed_user do
      state 2
    end
```

See this [blog article](https://robots.thoughtbot.com/factories-should-be-the-bare-minimum) for the reasoning behind this.

#### When Transient Attributes Make Sense

Use [transient attributes](https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md#transient-attributes) to DRY your factories.

```
  factory :project_with_package do
    transient do
      package_name nil
    end

    after(:create) do |project, evaluator|
      new_package = if evaluator.package_name
                      create(:package, project_id: project.id, name: evaluator.package_name)
                    else
                      create(:package, project_id: project.id)
                    end
      project.packages << new_package
    end
  end
```

Without the transient attribute package_name it would be necessary to explicit create a package with a different name.
Now you can just do:

```
create(:project_with_package, package_name: 'foobar')
```

#### Generating Fake Data

We use the [faker gem](https://github.com/stympy/faker) to generate more realistic test data.
However, we don't use this in cases where we use the data to identify objects (like user.login or project.title), to simplify debugging.
In that case, please use a simple sequence.
Attention: Faker generates random but **NOT** unique data!

### Backend Responses

We use [VCR](https://github.com/vcr/vcr) to record the response from the backend.
VCR records the HTTP interactions with the backend and replays them during future test runs for fast, deterministic, accurate tests.
Once your test ran successfully for the first time, [VCR](https://github.com/vcr/vcr) will have recorded a new cassette (a simple yml file) in `spec/cassettes`.

#### VCR Cassette Matching

VCR matches cassettes to responses you request from the backend by comparing the `request.uri`.
That means you should avoid random parts, like project/package names, in the URL requested.
Otherwise the cassette will not match and VCR tries record a new cassette each time which will fail because the backend is not running anymore.

```ruby
  let(:apache_project) { create(:project, name: 'Apache') }
```

#### Enable VCR

You may want to store a backend response in a spec test.
Make sure you enable VCR in the test metadata like this:

```
  RSpec.describe Package, vcr: true do
    ...
  end
```

#### Remove All Cassettes and Run the Test Again Before You Commit

Before you finally commit your test, you should remove the generated cassettes and run your test again.
This ensures that only by the test needed responses are included in the cassette and nothing more.
You can also review the cassette manually (but **NEVER** edit them manually)!

### Shared Examples

To DRY our specs we use in rare situations [shared examples](https://www.relishapp.com/rspec/rspec-core/docs/example-groups/shared-examples).
You should only use shared examples where you have the exact same functionality (e.g. package/project or user/group tab).
Otherwise, these specs are a nightmare to refactor and review.
In our experience, shared examples are used mainly for controllers. Since models are pretty different from each other, they (usually) do not share much logic.

#### Setup

In both services we use docker containers for running our tests. The docker containers are built with OBS in the container subprojects of [O:S:U](https://build.opensuse.org/project/subprojects/OBS:Server:Unstable) (e.g. https://build.opensuse.org/project/show/OBS:Server:Unstable:container:SLE12:SP3). With this approach we can test on our supported platforms like openSUSE or SLE and easily migrate to new platforms if necessary.

More information about the setup can be found in our wiki [here](https://github.com/openSUSE/open-build-service/wiki/Development-Environment-Overview) and [here](https://github.com/openSUSE/open-build-service/wiki/Development-Environment-Tips-&-Tricks).

### Migrating Tests

When migrating tests from the old minitest based suite to rspec, please add the
file path of the new one to every test covered.

### Untested Methods

When you work on the test suite and you notice a method or part of a feature that
is not tested, please add a test for it.

## Better Specs
As a set of "rules" to follow in our specs we use [BetterSpecs.org](http://betterspecs.org/).
Please read those guidelines before you start coding new specs.

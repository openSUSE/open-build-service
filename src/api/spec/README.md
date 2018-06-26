# Open Build Service Test Suite
This is a test suite based on [RSpec](http://rspec.info/). We are trying to
test things based on the following rules:

* Every method that isn't private must be tested
* Every main workflow has a feature test

## Running the spec
```bundle exec rspec```

and to run a single test file:

```
bundle exec rspec spec/models/user_spec.rb
```

## Directory structure
Conventionally, all tests live under the

`spec`

directory and files matching

`spec/**/*_spec.rb`

are run by default. Ruby files with custom matchers and macros, etc, belong to

`spec/support/`

and its subdirectories. Require them in the individual `*_spec.rb` or
`_helper.rb` files.

Shared examples that are shared among different test files are stored in

`spec/support/shared_example/{features,controller,model,helper}/*`

depending on the type of spec it is meant for.

## Test types
There are many different [types of specs](https://relishapp.com/rspec/rspec-rails/docs/directory-structure)
possible in RSpec. We concentrate on 4 types:

* [Model specs](https://relishapp.com/rspec/rspec-rails/docs/model-specs) reside in the `spec/models` directory and test methods in Models.
* [Controller specs](https://relishapp.com/rspec/rspec-rails/docs/controller-specs) reside in the `spec/controllers` directory and test methods in Controllers.
* [Helper specs](https://relishapp.com/rspec/rspec-rails/docs/helper-specs/helper-spec) reside in the `spec/helpers` directory and test methods in Helpers.
* [Feature specs](https://relishapp.com/rspec/rspec-rails/docs/feature-specs/feature-spec) reside in the `spec/features` directory and test workflows through the webui.

We agreed that we wan to focus on model and feature tests.
While migrating the old test suite, we review all controller tests and try to translate most of them to model tests.

### Property testing

Property tests give a property (high-level specification of behavior) and generate random examples which must verify the property. They are used when we want to ensure the correctness of the code and testing the code with one or some concrete examples is not enough. A good example of use case are regular expressions, as it sometimes difficult to choose concrete example that cover all cases and they are naturally and easily tested with property tests.

We are using Rantly gem which extends RSpec for property testing. Information about how to write property tests can be found in the [Rantly documentation](https://github.com/abargnesi/rantly/blob/master/README.textile).

## Adding tests
We are using the standard [RSpec generators](https://relishapp.com/rspec/rspec-rails/docs/generators) like:

`rails generate rspec:model package` or
`rails generate rspec:controller webui::blah`

### Factory Bot
We use [Factory Bot](https://github.com/thoughtbot/factory_bot_rails) to create our ruby objects, make sure to get familiar with the factory bot [features and syntax](http://www.rubydoc.info/gems/factory_bot/file/GETTING_STARTED.md).
Be aware of that factories, other than fixtures, run through ActiveRecord validations.
All OBS factories reside in `spec/factories`.

#### has_many associations
For creating has_many associations we prefer ```create_list```:

```
project.packages = create_list(:package, 2)
```

Please also have a look at the [factory bot documentation](https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md#associations)

#### Use a sequence for unique values
It's necessary to use a [sequence](https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md#sequences) for attributes which have to be unique like project.title or user.login.

```
sequence(:login) { |n| "user_#{n}" }
```

Please keep in mind that you have to overwrite these attributes if they are part of the URI and you use it in combination with VCR.
Otherwise your tests will fail as VCR matches the cassette by the URI.

```
let!(:user) { create(:confirmed_user, login: "proxy_user") }
```

By passing ```login: "proxy_user"``` to the create statement, the username is now always proxy_user and not random (e.g. user_42).

#### Factories should be the bare minimum
Different to fixtures, factory bot runs through your ActiveRecord validations.
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

See this [blog article](https://robots.thoughtbot.com/factories-should-be-the-bare-minimum) for a detailed explanation.

#### When Transient Attributes make sense
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

#### Generating fake data
We use the [faker gem](https://github.com/stympy/faker) to generate more realistic test data.
However, we don't use this in cases where we use the data to identify objects (like user.login or project.title), to simplify debugging.
In that case, please use a simple sequence.
Attention: Faker generates random but **NOT** unique data!

### Backend responses

If you require a response from the OBS backend for your new test you need to
start it with

```
docker-compose run --rm frontend bundle exec rake db:fixtures:load RAILS_ENV=test
docker-compose run --rm frontend script/start_test_backend
```

We use [VCR](https://github.com/vcr/vcr) to record the response from the backend.
VCR records the HTTP interactions with the backend and replays them during future test runs for fast, deterministic, accurate tests.
Once your test ran successfully for the first time [VCR](https://github.com/vcr/vcr) will have recorded a new cassette (a simple yml file) in `spec/cassettes`.

#### VCR cassette matching
VCR matches cassettes to responses you request from the backend by comparing the `request.uri`.
That means you should avoid random parts, like project/package names, in the URL requested.
Otherwise the cassette will not match and VCR tries record a new cassette each time which will fail because the backend is not running anymore.

```
  let(:apache_project) { create(:project, name: 'Apache') }
```

#### Enable VCR for model and controller tests
To make loading tests faster, we only include VCR in feature tests by default.
However, sometimes you also get and want to verify a backend response in a model or controller test.
Make sure you enable VCR in the test metadata like this:

```
  RSpec.describe Package, vcr: true do
    ...
  end
```

#### Remove all cassettes and run the test again before you commit
Before you finally commit your test, you should remove the generated cassettes and run your test again.
This ensures that only by the test needed responses are included in the cassette and nothing more.
You can also review the cassette manually (but **NEVER** edit them manually)!

### Shared examples
To DRY our tests we use in rare situations [shared examples](https://www.relishapp.com/rspec/rspec-core/docs/example-groups/shared-examples).
You should only use shared examples where you have the exact same functionality (e.g. package/project or user/group tab).
Otherwise these tests get fast hard to refactor and review.
In our experience, shared examples are used mainly for controllers. Since models are pretty different from each other, they (usually) do not share much logic.

### Travis
We use [travis-ci](https://travis-ci.org/) for continues integration.

#### Setup
As travis-ci runs on an Ubuntu machine, we need to add the OBS repository and install some OBS specific Ubuntu packages first.
We do this in [dist/ci/obs_testsuite_travis_install.sh](https://github.com/openSUSE/open-build-service/blob/master/dist/ci/obs_testsuite_travis_install.sh).
You can find the Ubuntu specific packages in this repository [http://download.opensuse.org/repositories/OBS:/Server:/Unstable/xUbuntu_12.04/](http://download.opensuse.org/repositories/OBS:/Server:/Unstable/xUbuntu_12.04/).
We do not package the rubygems for Ubuntu, instead we use bundler to install them.

#### Skipped tests
Some tests we run only on SUSE/openSUSE systems due to significant package differences to other distributions.
However, travis-ci runs on an Ubuntu machine.
To find out which tests we skip, you can ```grep``` for:

```
fillup-templates
```

#### Flaky tests
Sometimes a feature test is flaky and it fails the first run. This is especially a problem in the package build in OBS as the test suite run is significant longer as it is not parallelized. As a workaround we use [rspec-retry](https://github.com/NoRedInk/rspec-retry) which runs a test again if it fails.

However, it should be desired to fix the test that it always succeeds. Therefore you need to flag the test with ``retry: 3``, otherwise rspec-retry will not run the test again. In the package build, we always retry feature tests.

### Migrating tests
When migrating tests from the old minitest based suite to rspec, please add the
file path of the new one to every test covered.

### Untested methods
When you work on the test suite and you notice a method or part of a feature that
is not tested please add a test for it.

### Bootstrap theming
As we are in the progress of migrating our views to a new bootstrap based theming, we currently run our feature tests twice (we do not have view tests). In CircleCI we run the feature tests one time with bootstrap enabled and one time disabled (regardless of the logged in user). Sometimes it can happen that a feature test fails with the bootstrap enabled. The desired solution should be to update the feature test that it works with and without bootstrap. If this is not easily possible, you have the possibility to skip this test for bootstrap by adding ```skip_if_bootstrap``` to the first line of the spec. After that, you should copy over the test to the ```spec/bootstrap/features``` directory and adapt it as necessary.

## Better Specs
As a set of "rules" to follow in our specs we use [BetterSpecs.org](http://betterspecs.org/).
Please read those guidelines before you start coding new specs.

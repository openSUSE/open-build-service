# Open Build Service Test Suite
This is a test suite based on [RSpec](http://rspec.info/). We are trying to
test things based on the following rules:

* Every method that isn't private must be tested
* Every main workflow has a feature test

## Running the spec
`bundle exec rake spec`

## Directory structure
Conventionally, all tests live under the

`spec`

directory and files matching

`spec/**/*_spec.rb`

are run by default. Ruby files with custom matchers and macros, etc, belong to

`spec/support/`

and its subdirectories. Require them in the individual `*_spec.rb` or
`_helper.rb` files.

## Test types
There are many different [types of specs](https://relishapp.com/rspec/rspec-rails/docs/directory-structure)
possible in RSpec. We concentrate on 4 types:

* [Model specs](https://relishapp.com/rspec/rspec-rails/docs/model-specs) reside in the `spec/models` directory and test methods in Models.
* [Controller specs](https://relishapp.com/rspec/rspec-rails/docs/controller-specs) reside in the `spec/controllers` directory and test methods in Controllers.
* [Helper specs](https://relishapp.com/rspec/rspec-rails/docs/helper-specs/helper-spec) reside in the `spec/helpers` directory and test methods in Helpers.
* [Feature specs](https://relishapp.com/rspec/rspec-rails/docs/feature-specs/feature-spec) reside in the `spec/features` directory and test workflows through the webui.

## Adding tests
We are using the standard [RSpec generators](https://relishapp.com/rspec/rspec-rails/docs/generators) like:

`rails generate rspec:model package` or
`rails generate rspec:controller webui::blah`

### Backend responses

If you require a response from the OBS backend for your new test you need to
start it with

```
vagrant exec rake db:fixtures:obs
vagrant exec RAILS_ENV=test ./script/start_test_backend
```

Once your test ran successfully for the first time [VCR](https://github.com/vcr/vcr)
will have recorded a new cassette in `spec/cassettes` and will use this for
playing back the backend response in the next run.

### VCR gotchas
VCR matches cassettes to responses you request from the backend by comparing the
`request.uri`. That means you should avoid random parts, like project/package
names, in it.

### Migrating tests
When migrating tests from the old minitest based suite to rspec, please add the
file path of the new one to every test covered.

### Untested methods
When you work on the test suite and you notice a method or part of a feature that
is not tested please either add a test for it or at least add a skipped test case
like this

```ruby
describe "some method/feature" do
 skip
end
```

## Better Specs
As a set of "rules" to follow in our specs we use [BetterSpecs.org](http://betterspecs.org/).
Please read those guidelines before you start coding new specs.

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

and its subdirectories. Require them in the individual `*_spec.rb` or `_helper.rb` files.

## Test types
There are many different [types of specs](https://relishapp.com/rspec/rspec-rails/docs/directory-structure)
possible in RSpec. We concentrate on 4 types:

* [Model specs](https://relishapp.com/rspec/rspec-rails/docs/model-specs) reside in the `spec/models` directory and test methods in Models.
* [Controller specs](https://relishapp.com/rspec/rspec-rails/docs/controller-specs) reside in the `spec/controllers` directory and test methods in Controllers.
* [Helper specs](https://relishapp.com/rspec/rspec-rails/docs/helper-specs/helper-spec) reside in the `spec/helpers` directory and test methods in Helpers.
* [Feature specs](https://relishapp.com/rspec/rspec-rails/docs/feature-specs/feature-spec) reside in the `spec/features` directory and test workflows through the webui.

## Adding tests
We are using the standard [RSpec generators](https://relishapp.com/rspec/rspec-rails/docs/generators) like:

`rails generate rspec:model package`

If you require response from the OBS backend for your new test you need to start it with

```
vagrant exec rake db:fixtures:obs
vagrant exec RAILS_ENV=test ./script/start_test_backend
```

Once your test ran sucessfully for the first time [VCR](https://github.com/vcr/vcr) will have recorded a new cassette in `spec/cassettes`
and will use this for playback in the next run.

## Migrating tests
When migrating tests from the old minitest based suite to rspec, please add the file path of the new one to every test covered.

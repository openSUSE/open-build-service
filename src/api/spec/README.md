# Open Build Service Test Suite

This is a test suite based on [RSpec](http://rspec.info/).

## Using the Test Suite

Run the whole suite

```shell
bundle exec rspec
```

run a single spec

```shell
bundle exec rspec spec/models/user_spec.rb
```

run the tests on line 33 in a spec

```shell
bundle exec rspec spec/models/user_spec.rb:33
```

### Configuration

- To extend the suite with custom configuration or custom methods we use ruby modules in `spec/support`
- To configure how it's run by default we use an [.rspec](https://github.com/openSUSE/open-build-service/blob/master/src/api/.rspec) file.

## What to Test and How

You *can* test a lot of different things in a Ruby on Rails test suite. From behavior of units (as in methods of a Ruby object), to interactions between different units end-to-end (as in plugging different Ruby objects together to provide a feature). Like testing that `ActionDispatch`+`ActionController`+`ActiveRecord`+`ActionView` behave in a certain way from a browser, accessibility testing or even more esoteric things like visual testing.

But as we all know, too many cooks spoil the broth! That is why we are trying really hard to:

- limit the amount of code involved in running the test
- limit the amount of times we test the same code
- limit the specs to "custom" logic we wrote ourselves

First and foremost because a test suite is code that needs to be maintained and that is work, a lot of work. So writing the right type of spec, that tests *once* the code we have influence on, means *less* specs. Less specs, less code, less time spent on maintaining it. Secondly we think that CI time is developer time. A fast feedback loop from the test suite makes you wait for it less. So with those limitations we are trying to save the most precious thing we have as a project: The time you developer have, to work on something.

### Limit the Amount of Code Involved in Running the Test

Please use the type of spec with the least amount if computing time required to run it. You can test the four branch logic of your `ThingController#update` action by firing up four browsers, clicking through 4 web pages until you reach a form, fill the form in 4 different ways, click submit and then expect 4 different responses. Or you use a controller unit spec, doing that removes the need to run the browser every time you run the spec. If the logic that branches 4 times is in the `Thing` model and not in the `ThingsController`, rather write *one* model spec.
This will remove the need to run all of `ActionDispatch` every time you run the spec.

### Limit the Amount of Times the Same Code Is Tested

Please test your code *once*. If you wrote a custom validation with complex logic and an awesome model spec for it, please do not test the results of this validation logic again from a controller spec and then again by clicking in a browser through the feature that you built upon this model. No need to make the CI jump through the same hoop three times or worse have a fellow developer adapt all three specs because they changed your logic.

### Limit the Specs to “Custom” Logic We Wrote Ourselves

Please avoid testing code that is a scaffold or that consists of very simple Ruby / Ruby on Rails "standard" logic. No need to test a simple `case`, a variable assignment or `Array.count`. The Ruby test suite does this and if any of those things do not work anymore our test suite will not even reach the spec you write. Because Ruby is broken and *everything* around you will be on fire 🔥🔥🔥.

Same reason to not test a standard ActiveRecord presence validation, a resourceful route or even a scaffolded controller action. The Ruby on Rails test suite does this and if those features are broken in Ruby on Rails, you'll be in panic because GitHub will be offline 💥💥💥.

## Unit Specs

Unit specs are limited in scope and only test a single "unit"/"object" without testing interactions between different "units". Their purpose is to test each unit's functionality in isolation before integrating them into the larger system.

There are several types of "units"/"objects" in every rails app so there are also several types of unit specs in our test suite.

Unit specs:

- for the respective classes are in `spec/[models, controllers, components, policies]` etc.
- are configured in and inherit from `spec/spec_helper.rb`
- use `login(user)` and `logout(user)` for authenticating users
- truncate the database after each example (we omit truncating what we have set up in `db/seeds.rb``)
- reset the User.session after each example
- disable HTTP requests
- automatically mock the responses from the OBS backend with [VCR](https://github.com/vcr/vcr)

## Feature Specs

Feature specs test user workflows (features) end-to-end through our web user interface by operating the UI with a browser.

Feature specs:

- are in `spec/features`
- are configured in and inherit from `spec/browser_helper.rb`
- do everything that unit specs do (`spec/browser_helper.rb` inherits from `spec/spec_helper.rb`)
- run a Chromium browser
- run in a desktop sized browser window by default
- run twice in CI, once with a desktop and once with a mobile sized browser window
- that failed save the HTML of the page to `tmp/capybara/#{example_filename}.html`
- that failed save a screenshot of the page to `tmp/capybara/#{example_filename}.png`

## Fixtures / Factories / Mocks

To generate test data we use [FactoryBot](https://thoughtbot.github.io/factory_bot/) factories in `spec/factories/` and lint them with [rubocop-factory_bot](https://docs.rubocop.org/rubocop-factory_bot/cops_factorybot.html).

### Fake Data

To generate fake test data in factories (like names/words/sentences etc.) we use [faker](https://github.com/stympy/faker) . Attention: Faker generates random but **NOT** unique data!

### VCR

To automatically mock the response from the OBS backend we use [VCR](https://github.com/vcr/vcr).
VCR records the HTTP interactions with the backend and replays them during future test runs.

- VCR cassettes are recorded to `spec/cassettes`
- There is more documentation about [using VCR in specs our wiki](https://github.com/openSUSE/open-build-service/wiki/Testing-with-VCR)

## Shared Examples

To DRY our specs we use in rare situations [shared examples](https://rspec.info/documentation/3.12/rspec-core/RSpec/Core/SharedExampleGroup.html).

- only use shared examples if you must, they are a nightmare to refactor and review
- shared examples are in `spec/shared/examples`
- shared contexts are in `spec/shared/contexts`

## Resources

- [BetterSpecs.org](http://betterspecs.org/)
- [RSpec Styleguide](https://rspec.rubystyle.guide/) (we lint this with rubocop)
- [Martin Fowlers Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html)
- [Kent C. Dodds Talk: Write tests. Not too many. Mostly integration.](https://www.youtube.com/watch?v=Fha2bVoC8SE)
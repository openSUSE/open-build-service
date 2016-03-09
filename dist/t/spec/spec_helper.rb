# OBS Appliance spec helper.
#
RSpec.configure do |config|
  # rspec-expectations config goes here.
  config.expect_with :rspec do |expectations|
    # to disable deprecated should syntax
    expectations.syntax = :expect
  end

  # Limits the available syntax to the non-monkey patched
  config.disable_monkey_patching!

  # Run specs in random order to surface order dependencies
  config.order = :random
end

# for capybara rspec support
require 'support/capybara'

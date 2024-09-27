# as our base helper
require 'spec_helper'

# for capybara rspec support
require 'support/capybara'

# helper methods for authentication in features tests
require 'support/features/features_authentication'
require 'support/features/features_attribute'
require 'support/features/features_custom_checkbox'
require 'support/features/features_responsive'
require 'support/wait_helpers'

# Shared examples. Per recommendation of RSpec,
# https://www.relishapp.com/rspec/rspec-core/v/2-12/docs/example-groups/shared-examples
Dir['./spec/shared/examples/features/**/*.rb'].each { |example| require example }

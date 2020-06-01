# as our base helper
require 'rails_helper'

# for capybara rspec support
require 'support/capybara'

# helper methods for authentication in features tests
require 'support/features/features_authentication'
require 'support/features/features_attribute'
require 'support/features/features_beta'
require 'support/features/features_custom_checkbox'
require 'support/wait_for_ajax'

# Shared examples. Per recommendation of RSpec,
# https://www.relishapp.com/rspec/rspec-core/v/2-12/docs/example-groups/shared-examples
Dir['./spec/support/shared_examples/features/**/*.rb'].sort.each { |example| require example }

# frozen_string_literal: true

# as our base helper
require 'rails_helper'

# for capybara rspec support
require 'support/capybara'

# helper methods for authentication in features tests
require 'support/features/features_authentication'

# Shared examples. Per recommendation of RSpec,
# https://www.relishapp.com/rspec/rspec-core/v/2-12/docs/example-groups/shared-examples
Dir['./spec/support/shared_examples/features/*.rb'].each { |example| require example }

require 'rspec/retry'
RSpec.configure do |config|
  # show retry status in spec process
  config.verbose_retry = true
  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  # run retry only on features
  config.around :each, :js do |ex|
    ex.run_with_retry retry: 3
  end

  # callback to be run between retries
  config.retry_callback = proc do |ex|
    # run some additional clean up task - can be filtered by example metadata
    if ex.metadata[:js]
      Capybara.reset!
    end
  end
end

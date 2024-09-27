# OBS spec helper. See README.md in this directory for details.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration

# for generating test coverage
require 'simplecov'
SimpleCov.start

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?

# for rails
require 'rspec/rails'
# for pundit policy
require 'pundit/rspec'

RSpec.configure do |config|
  # rspec-expectations config goes here.
  config.expect_with :rspec do |expectations|
    # This option makes the `description` and `failure_message` of custom matchers
    # include text for helper methods defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true

    # to disable deprecated should syntax
    expectations.syntax = :expect
  end

  # Allows RSpec to persist some state between runs in order to support
  # the `--only-failures` and `--next-failure` CLI options. We recommend
  # you configure your source control system to ignore this file.
  config.example_status_persistence_file_path = 'spec/examples.txt'

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  #   - http://rspec.info/blog/2012/06/rspecs-new-expectation-syntax/
  #   - http://www.teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  #   - http://rspec.info/blog/2014/05/notable-changes-in-rspec-3/#zero-monkey-patching-mode
  config.disable_monkey_patching!

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  # config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  config.order = :random

  # Tag all groups and examples in the spec/features/beta directory with
  # :beta => :true
  config.define_derived_metadata(file_path: %r{/spec/features/beta/}) do |metadata|
    metadata[:beta] = true
  end

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand(config.seed)

  # set spec type based on their file location
  config.infer_spec_type_from_file_location!

  # filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end

# We never want the OBS backend to autostart itself...
ENV['BACKEND_STARTED'] = '1'

### Our own spec extensions
# support logging
require 'support/logging'

require 'support/view_component'

# support fixtures
require 'support/factory_bot'

# support database cleanup
require 'support/database_cleaner'

# support Suse::backend
require 'support/backend'

# support shoulda matcher
require 'support/shoulda_matchers'

# helper methods for authentication
require 'support/controllers/controllers_authentication'
require 'support/models/models_authentication'

# support Delayed Jobs
require 'support/delayed_job'

# Cache reset
require 'support/cache'

# silence migration tests
require 'support/migration'

# support rabbitmq
require 'support/rabbitmq'

# support thinking_sphinx
require 'support/thinking_sphinx'

# support beta
require 'support/beta'

# support time helpers
require 'support/time_helpers'

# support HTTP_REFERER
require 'support/redirect_back'

# support bullet
require 'support/bullet'

# support haml
require 'support/haml'

# support paper_trail, versioning is disabled by default during tests
# and has to be opted in when required
require 'paper_trail/frameworks/rspec'

Dir['./spec/shared/contexts/*.rb'].each { |file| require file }
Dir['./spec/shared/examples/*.rb'].each { |file| require file }

# Generate 30 tests for every property test
ENV['RANTLY_COUNT'] = '30'
# To have quiet output from Rantly, it is not needed
ENV['RANTLY_VERBOSE'] = '0'

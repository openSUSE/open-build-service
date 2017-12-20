# OBS spec helper. See README.md in this directory for details.
#
# WARNING: Given that it is always loaded, you are strongly encouraged to keep
# this file as light-weight as possible!
# Requiring heavyweight dependencies from this file will add to the boot time of
# the test suite on EVERY test run, even for an individual file that may not need
# all of that loaded. Instead, consider making a separate helper file that requires
# the additional dependencies and performs the additional setup, and require it from
# the spec files that actually need it. Exactly this is done in the `rails_helper`
# which loads the complete rails app.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
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

  # rspec-mocks config goes here.

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

  # Tag all groups and examples in the spec/features directory with
  # :vcr => :true
  config.define_derived_metadata(file_path: %r{/spec/features/}) do |metadata|
    metadata[:vcr] = true
  end

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  # Custom formatter, but not in Travis-CI and neither during package build
  unless ENV['TRAVIS'] || ENV['RPM_BUILD_ROOT']
    # users who tend to run test cases manually and may need to debug travis issues
    calling_user = %x(id -u -n)
    unless ['adrian', 'mls', 'frontend'].include? calling_user.chomp
      puts "calling user: #{calling_user}"
      config.formatter = 'NyanUnicornFormatter'
    end
  end
end

# We never want the backend to autostart itself...
ENV['BACKEND_STARTED'] = '1'

# Generate 30 tests for every property test
ENV['RANTLY_COUNT'] = '30'

# To have quiet output from Rantly, it is not needed and looks horrible with the Unicorn
ENV['RANTLY_VERBOSE'] = '0'

# support logging
require 'support/logging'

Dir['./spec/support/shared_contexts/*.rb'].each { |file| require file }
Dir['./spec/support/shared_examples/*.rb'].each { |file| require file }

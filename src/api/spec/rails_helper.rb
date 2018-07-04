# for generating test coverage
require 'simplecov'
# Avoid codecov failures outside of travis
if ENV['CIRCLECI']
  # support test coverage
  require 'support/coverage'
end
# to clean old unused cassettes
if ENV['CLEAN_UNUSED_CASSETTES']
  require 'cassette_rewinder'
end

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
# as our base helper
require 'spec_helper'
# for rails
require 'rspec/rails'
# for pundit policy
require 'pundit/rspec'

# check for pending migration and apply them before tests are run.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.include Haml::Helpers

  # load ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # set spec type based on their file location
  config.infer_spec_type_from_file_location!

  # filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Delete all cassettes which arent used
  if ENV['CLEAN_UNUSED_CASSETTES']
    config.after(:suite) do
      files = (Dir[File.join(Rails.root, 'spec', 'cassettes', '**', '*.yml')] - USED_CASSETTES.to_a)
      files.each { |v| File.delete(v) } unless files.empty?
    end
  end

  # Wrap each test in Bullet api.
  if Bullet.enable?
    config.before(:each) do
      Bullet.start_request
    end

    config.after(:each) do
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end
  end
end

# support fixtures
require 'support/factory_bot'

# support database cleanup
require 'support/database_cleaner'

# support Suse::backend
require 'support/backend'

# support shoulda matcher
require 'support/shoulda_matchers'

# helper methods for authentication in controllers tests
require 'support/controllers/controllers_authentication'

# helper methods for authentication in models tests
require 'support/models/models_authentication'

# support feature switch testing
require 'feature/testing'

# support Delayed Jobs
require 'support/delayed_job'

# Cache reset
require 'support/cache'

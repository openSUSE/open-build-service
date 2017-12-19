require 'database_cleaner'

RSpec.configure do |config|
  STATIC_TABLES = %w[roles roles_static_permissions
                     static_permissions configurations
                     architectures attrib_types
                     attrib_namespaces issue_trackers].freeze

  # We are using factory_bot to set up everything the test needs up front,
  # instead of loading a set of fixtures in the beginning of the suite
  config.use_transactional_fixtures = false

  config.before(:suite) do
    # Before the test suites runs make sure the database is empty
    log_level = Rails.logger.level
    Rails.logger.level = :fatal
    DatabaseCleaner.clean_with(:truncation)
    # and is seeded
    load "#{Rails.root}/db/seeds.rb"
    Rails.logger.level = log_level
    # Truncate all tables loaded in db/seeds.rb, except the static ones, in the
    # beginning to be consistent.
    DatabaseCleaner.clean_with(:truncation, except: STATIC_TABLES)
  end

  config.before(:each) do |example|
    # For feature test we use truncation instead of transactions because the
    # test suite and the capybara driver do not use the same server thread.
    if example.metadata[:type] == :feature
      # Omit truncating what we have set up in db/seeds.rb except users and roles_user
      DatabaseCleaner.strategy = :truncation, { except: STATIC_TABLES }
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

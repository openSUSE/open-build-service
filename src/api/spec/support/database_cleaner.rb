require 'database_cleaner/active_record'

STATIC_TABLES = %w[roles roles_static_permissions static_permissions configurations
                   architectures issue_trackers
                   attrib_namespaces attrib_namespace_modifiable_bies attrib_types attrib_allowed_values].freeze

RSpec.configure do |config|
  # We are using factory_bot to set up everything the test needs up front,
  # instead of loading a set of fixtures in the beginning of the suite
  config.use_transactional_fixtures = false

  config.before(:suite) do
    # Truncate all tables loaded in db/seeds.rb, except the static ones, in the
    # beginning to be consistent.
    DatabaseCleaner.clean_with(:deletion, except: STATIC_TABLES)
  end

  config.before do |example|
    # For feature test we use deletion instead of transactions because the
    # test suite and the capybara driver do not use the same server thread.
    DatabaseCleaner.strategy = if %i[feature migration].include?(example.metadata[:type]) || example.metadata[:thinking_sphinx] == true
                                 # Omit truncating what we have set up in db/seeds.rb
                                 [:deletion, { except: STATIC_TABLES }]
                               else
                                 :transaction
                               end
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
    User.session = nil
  end
end

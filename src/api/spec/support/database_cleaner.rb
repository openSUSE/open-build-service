require 'database_cleaner'

RSpec.configure do |config|
  STATIC_TABLES = ['roles', 'roles_static_permissions', 'static_permissions', 'configurations',
                   'architectures', 'issue_trackers'].freeze

  # We are using factory_bot to set up everything the test needs up front,
  # instead of loading a set of fixtures in the beginning of the suite
  config.use_transactional_fixtures = false

  config.before(:suite) do
    # Truncate all tables loaded in db/seeds.rb, except the static ones, in the
    # beginning to be consistent.
    DatabaseCleaner.clean_with(:truncation, except: STATIC_TABLES)
  end

  config.before(:each) do |example|
    # For feature test we use truncation instead of transactions because the
    # test suite and the capybara driver do not use the same server thread.
    if example.metadata[:type] == :feature || example.metadata[:type] == :migration
      # Omit truncating what we have set up in db/seeds.rb except users and roles_user
      DatabaseCleaner.strategy = :truncation, { except: STATIC_TABLES }
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start
    # create default attributes
    create(:attrib_namespace, name: 'OBS')
    create(:obs_attrib_type, name: 'ApprovedRequestSource', value_count: 0)
    create(:obs_attrib_type, name: 'AutoCleanup', value_count: 1)
    create(:obs_attrib_type, name: 'ImageTemplates')
    create(:obs_attrib_type, name: 'Issues', value_count: 0, issue_list: true)
    create(:obs_attrib_type, name: 'Maintained', value_count: 0)
    create(:obs_attrib_type, name: 'MaintenanceProject', value_count: 0)
    create(:obs_attrib_type, name: 'MakeOriginOlder', value_count: 0)
    create(:obs_attrib_type, name: 'OwnerRootProject')
    create(:obs_attrib_type, name: 'ProjectStatusPackageFailComment')
    create(:obs_attrib_type, name: 'UpdateProject')
    create(:obs_attrib_type, name: 'VeryImportantProject')
  end

  config.after(:each) do
    DatabaseCleaner.clean
    User.current = nil
  end
end

require 'database_cleaner/active_record'

RSpec.configure do |config|
  STATIC_TABLES = ['roles', 'roles_static_permissions', 'static_permissions', 'configurations',
                   'architectures', 'issue_trackers'].freeze

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
    DatabaseCleaner.strategy = if example.metadata[:type] == :feature || example.metadata[:type] == :migration || example.metadata[:thinking_sphinx] == true
                                 # Omit truncating what we have set up in db/seeds.rb
                                 [:deletion, { except: STATIC_TABLES }]
                               else
                                 :transaction
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
    create(:obs_attrib_type, name: 'DelegateRequestTarget')
    create(:obs_attrib_type, name: 'EmbargoDate', value_count: 1)
    create(:obs_attrib_type, name: 'CreatorCannotAcceptOwnRequests', value_count: 0)
    Configuration.first_or_create(name: 'private', title: 'Open Build Service').update(allow_user_to_create_home_project: false)
  end

  config.after do
    DatabaseCleaner.clean
    User.session = nil
  end
end

# Everything that needs to be done before you can use this app

require 'fileutils'
require 'yaml'
require 'tasks/dev/rake_support'

namespace :dev do
  task :prepare do
    puts 'Setting up the database configuration...'
    RakeSupport.copy_example_file('config/database.yml')
    database_yml = YAML.load_file('config/database.yml') || {}
    database_yml['test']['host'] = 'db'
    database_yml['development']['host'] = 'db'
    database_yml['production']['host'] = 'db'
    File.write('config/database.yml', YAML.dump(database_yml))

    puts 'Setting up the application configuration...'
    RakeSupport.copy_example_file('config/options.yml')
    puts 'Copying thinking sphinx example...'
    RakeSupport.copy_example_file('config/thinking_sphinx.yml')

    puts 'Setting up the cloud uploader'
    RakeSupport.copy_example_file('../../dist/aws_credentials')
    RakeSupport.copy_example_file('../../dist/ec2utils.conf')
  end

  task development_environment: :environment do
    unless Rails.env.development?
      puts "You are running this rake task in #{Rails.env} environment."
      puts 'Please only run this task with RAILS_ENV=development'
      puts 'otherwise it will destroy your database data.'
      exit(1)
    end
  end

  task test_environment: :environment do
    unless Rails.env.test?
      puts "You are running this rake task in #{Rails.env} environment."
      puts 'Please only run this task with RAILS_ENV=test'
      puts 'otherwise it will destroy your database data.'
      exit(1)
    end
  end

  desc 'Bootstrap the application'
  task :bootstrap, [:old_test_suite] => %i[prepare environment] do |_t, args|
    args.with_defaults(old_test_suite: false)

    database_exists = false

    puts 'Checking if database exists...'
    if RailsVersion.is_7_2?
      # Since Rails 7.2 `Rake::Task['db:version'].invoke` does not raise exception anymore if the database does not exist.
      # So we need to check if the database exists before running the task.
      database_exists = true if ActiveRecord::Base.connection.database_exists?
    else
      begin
        Rake::Task['db:version'].invoke
        database_exists = true
      rescue StandardError
        nil
      end
    end

    unless database_exists
      puts 'Database does not exist. Creating and seeding the database...'
      Rake::Task['db:setup'].invoke
      if args.old_test_suite
        puts 'Old test suite. Loading fixtures...'
        Rake::Task['db:fixtures:load'].invoke
      end
    end

    if Rails.env.test?
      puts 'Prepare assets'
      Rake::Task['assets:clobber'].invoke
      Rake::Task['assets:precompile'].invoke
      if args.old_test_suite
        puts 'Old test suite. Enforcing project keys...'
        Configuration.update(enforce_project_keys: true)
      end
    end

    if Rails.env.development?
      # This is needed to make the signer setup
      puts 'Configure default signing'
      Rake::Task['assets:clobber'].invoke
      Configuration.update(enforce_project_keys: true)
    end

    puts 'Enable feature toggles for their group'
    Rake::Task['flipper:enable_features_for_group'].invoke
  end

  # This is automatically run in Review App or manually in development env.
  namespace :test_data do
    desc 'Creates test data to play with in dev and CI environments'
    task create: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods
      require 'active_support/testing/time_helpers'
      include ActiveSupport::Testing::TimeHelpers
      require 'tasks/dev/test_data/maintenance'
      include TestData::Maintenance

      Rails.cache.clear
      Rake::Task['db:reset'].invoke

      puts 'Enable feature toggles for their group'
      Rake::Task['flipper:enable_features_for_group'].invoke

      # Issue trackers were seeded into the database but never written to the backend.
      # If they are not in the backend, the issues won't be tracked from changes files or patchinfos.
      puts 'Writing issue trackers into backend'
      IssueTrackerWriteToBackendJob.perform_now

      iggy = create(:staff_user, login: 'Iggy')
      admin = User.default_admin
      User.session = admin

      interconnect = create(:remote_project, name: 'openSUSE.org', remoteurl: 'https://api.opensuse.org/public')
      # The interconnect doesn't work unless we set the distributions
      FetchRemoteDistributionsJob.perform_now
      tw_repository = create(:repository, name: 'snapshot', project: interconnect, remote_project_name: 'openSUSE:Factory')

      # the home:Admin is not created because the Admin user is created in seeds.rb
      # therefore we need to create it manually and also set the proper relationship
      home_admin = create(:project, name: admin.home_project_name)
      create(:relationship, project: home_admin, user: admin, role: Role.hashed['maintainer'])
      admin_repository = create(:repository, project: home_admin, name: 'openSUSE_Tumbleweed', architectures: ['x86_64'])
      create(:path_element, link: tw_repository, repository: admin_repository)
      ruby_admin = create(:package_with_file, name: 'ruby', project: home_admin, file_content: 'from admin home')

      branches_iggy = RakeSupport.find_or_create_project(iggy.branch_project_name('home:Admin'), iggy)
      ruby_iggy = create(:package_with_files, name: 'ruby', project: branches_iggy)

      create(
        :bs_request_with_submit_action,
        creator: iggy,
        target_project: home_admin,
        target_package: ruby_admin,
        source_project: branches_iggy,
        source_package: ruby_iggy
      )

      create(:package_with_files, name: 'hello_world', project: home_admin)

      leap = create(:project, name: 'openSUSE:Leap:15.0')
      leap_apache = create(:package_with_file, name: 'apache2', project: leap)
      leap_repository = create(:repository, project: leap, name: 'openSUSE_Tumbleweed', architectures: ['x86_64'])
      create(:path_element, link: tw_repository, repository: leap_repository)

      # we need to set the user again because some factories set the user back to nil :(
      User.session = admin
      # Create factory dashboard projects
      factory = create(:project, name: 'openSUSE:Factory')
      sworkflow = create(:staging_workflow, project: factory)
      checker = create(:confirmed_user, login: 'repo-checker')
      create(:relationship, project: factory, user: checker, role: Role.hashed['reviewer'])
      osrt = create(:group, title: 'review-team')
      reviewhero = create(:confirmed_user, login: 'reviewhero')
      osrt.users << reviewhero
      osrt.save
      create(:relationship, project: factory, group: osrt, role: Role.hashed['reviewer'])
      tw_apache = create(:package_with_file, name: 'apache2', project: factory)

      req = travel_to(90.minutes.ago) do
        new_package1 = create(
          :bs_request_with_submit_action,
          creator: iggy,
          target_package: 'inreview',
          target_project: factory,
          source_package: leap_apache
        )
        new_package1.staging_project = sworkflow.staging_projects.first
        new_package1.save
        create(:review, by_project: new_package1.staging_project, bs_request: new_package1)
        new_package1.change_review_state(:accepted, by_group: sworkflow.managers_group.title)

        new_package2 = create(
          :bs_request_with_submit_action,
          creator: iggy,
          target_package: 'reviewed',
          target_project: factory,
          source_package: leap_apache
        )
        new_package2.staging_project = sworkflow.staging_projects.second
        new_package2.save
        create(:review, by_project: new_package2.staging_project, bs_request: new_package2)
        new_package2.change_review_state(:accepted, by_group: sworkflow.managers_group.title)
        new_package2.change_review_state(:accepted, by_user: checker.login)
        new_package2.change_review_state(:accepted, by_group: osrt.title)
        new_package2.change_review_state(:accepted, by_package: 'apache2', by_project: leap.name)

        req = create(
          :bs_request_with_submit_action,
          creator: iggy,
          target_package: tw_apache,
          source_package: leap_apache,
          review_by_user: checker
        )
        User.session = iggy
        req.reviews.create(by_group: osrt.title)
        req
      end

      travel_to(88.minutes.ago) do
        User.session = checker
        req.change_review_state(:accepted, by_user: checker.login, comment: 'passed')
      end

      travel_to(20.minutes.ago) do
        # accepting last review - new state
        User.session = reviewhero
        req.change_review_state(:accepted, by_group: osrt.title, comment: 'looks good')
      end

      comment = travel_to(85.minutes.ago) do
        create(:comment, commentable: req)
      end
      create(:comment, commentable: req, parent: comment)

      User.session = iggy
      req.addreview(by_user: admin.login, comment: 'is this really fine?')

      create(:project, name: 'openSUSE:Factory:Rings:0-Bootstrap')
      create(:project, name: 'openSUSE:Factory:Rings:1-MinimalX')

      Configuration.download_url = 'https://download.opensuse.org'
      Configuration.save

      # Other special projects and packages
      create(:project, name: 'linked_project', link_to: home_admin)
      create(:multibuild_package, project: home_admin, name: 'multibuild_package')
      create(:package_with_link, project: home_admin, name: 'linked_package')
      create(:package_with_remote_link, project: home_admin, name: 'remotely_linked_package', remote_project_name: 'openSUSE.org:openSUSE:Factory', remote_package_name: 'aaa_base')

      # Trigger package builds for home:Admin
      home_admin.store

      create_list(:label_template, 5, project: home_admin)

      # Create some Reports
      Rake::Task['dev:reports:data'].invoke

      # Create some Decisions on existing Reports
      Rake::Task['dev:reports:decisions'].invoke

      # Create a workflow token, some workflow runs and their related data
      Rake::Task['dev:workflows:create_workflow_runs'].invoke

      # Create a request with multiple actions and mentioned issues which produce build results
      Rake::Task['dev:requests:multiple_actions_request'].invoke

      # Create a request with multiple submit actions and diffs
      Rake::Task['dev:requests:request_with_multiple_submit_actions_builds_and_diffs'].invoke

      # Create a maintenance environment with maintenance requests
      create_maintenance_setup

      # Create a request with a delete request action
      Rake::Task['dev:requests:request_with_delete_action'].invoke

      # Create news
      Rake::Task['dev:news:data'].invoke

      # Create notifications by running the `dev:notifications:data` task two times
      Rake::Task['dev:notifications:data'].invoke(2)
      Rake::Task['dev:assignments'].invoke
    end

    desc 'Create more data'
    task :create_more_data, [:repetitions] => :development_environment do |_t, args|
      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i

      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      admin = User.default_admin
      User.session = admin

      # Create n project with n packages each
      repetitions.times do |repetition|
        new_project_name = "#{Faker::Lorem.words.join(':')}_#{repetition}"
        new_project = create(:project, name: new_project_name, commit_user: admin)
        repetitions.times do |repetition_package|
          create(:package_with_file, name: "#{Faker::Lorem.words.join('_')}_#{repetition_package}", project: new_project, file_content: 'some content')
        end
      end

      Rake::Task['dev:requests:multiple_actions_request'].invoke(repetitions)
      Rake::Task['dev:requests:request_with_multiple_submit_actions_builds_and_diffs'].invoke(repetitions)

      actions_count_for_small_request = 10
      actions_count_for_medium_request = 100
      actions_count_for_large_request = 1000
      Rake::Task['dev:requests:request_with_multiple_submit_actions_builds_and_diffs'].invoke(10, actions_count_for_small_request)
      Rake::Task['dev:requests:request_with_multiple_submit_actions_builds_and_diffs'].invoke(2, actions_count_for_medium_request)
      Rake::Task['dev:requests:request_with_multiple_submit_actions_builds_and_diffs'].invoke(1, actions_count_for_large_request)

      Rake::Task['dev:requests:request_with_delete_action'].invoke(repetitions)

      # TODO: refactor the task, it is very slow compared to the others
      Rake::Task['dev:notifications:data'].invoke(repetitions)

      Rake::Task['dev:news:data'].invoke(repetitions)
    end
  end
end

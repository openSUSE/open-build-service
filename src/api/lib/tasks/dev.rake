# Everything that needs to be done before you can use this app

require 'fileutils'
require 'yaml'

ENABLED_FEATURE_FLAGS = [:notifications_redesign, :user_profile_redesign, :trigger_workflow].freeze

namespace :dev do
  task :prepare do
    puts 'Setting up the database configuration...'
    copy_example_file('config/database.yml')
    database_yml = YAML.load_file('config/database.yml') || {}
    database_yml['test']['host'] = 'db'
    database_yml['development']['host'] = 'db'
    File.open('config/database.yml', 'w') do |f|
      f.write(YAML.dump(database_yml))
    end

    puts 'Setting up the application configuration...'
    copy_example_file('config/options.yml')
    puts 'Copying thinking sphinx example...'
    copy_example_file('config/thinking_sphinx.yml')

    puts 'Setting up the cloud uploader'
    copy_example_file('../../dist/aws_credentials')
    copy_example_file('../../dist/ec2utils.conf')
  end

  desc 'Bootstrap the application'
  task :bootstrap, [:old_test_suite] => [:prepare, :environment] do |_t, args|
    args.with_defaults(old_test_suite: false)

    puts 'Creating the database...'
    begin
      Rake::Task['db:version'].invoke
    rescue StandardError
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
        ::Configuration.update(enforce_project_keys: true)
      end
    end

    if Rails.env.development?
      # This is needed to make the signer setup
      puts 'Configure default signing'
      Rake::Task['assets:clobber'].invoke
      ::Configuration.update(enforce_project_keys: true)
      # Enable all feature flags for all beta users in the development environment to easily join the beta and test changes
      # related to feature flags while also being able to test changes for non-beta users, so without any feature flag enabled
      ENABLED_FEATURE_FLAGS.each do |feature_flag|
        puts "Enabling feature flag #{feature_flag} for all beta users"
        Flipper.disable(feature_flag) # making sure we are starting from a clean state since the database is not overwritten if already present
        Flipper.enable(feature_flag, :beta)
      end
    end
  end

  desc 'Run all linters we use'
  task :lint do
    Rake::Task['haml_lint'].invoke
    Rake::Task['dev:lint:rubocop:all'].invoke
    sh 'jshint ./app/assets/javascripts/'
  end

  namespace :lint do
    namespace :rubocop do
      desc 'Run the ruby linter in rails and in root'
      task all: [:root, :rails]

      desc 'Run the ruby linter in rails'
      task :rails do
        sh 'rubocop', '--fail-fast', '--display-style-guide', '--fail-level', 'convention', '--ignore_parent_exclusion'
      end

      desc 'Run the ruby linter in root'
      task :root do
        Dir.chdir('../..') do
          sh 'rubocop', '--fail-fast', '--display-style-guide', '--fail-level', 'convention'
        end
      end

      namespace :auto_gen_config do
        desc 'Autogenerate rubocop config in rails and in root'
        task all: [:root, :rails]

        desc 'Autogenerate rubocop config in rails'
        task :rails do
          # We set `exclude-limit` to 100 (from the default of 15) to make it easier to tackle TODOs one file at a time
          # A cop will be disabled only if it triggered offenses for more than 100 files
          sh 'rubocop --auto-gen-config --ignore_parent_exclusion --auto-gen-only-exclude --exclude-limit 100'
        end

        desc 'Run the ruby linter in root'
        task :root do
          Dir.chdir('../..') do
            # We set `exclude-limit` to 100 (from the default of 15) to make it easier to tackle TODOs one file at a time
            # A cop will be disabled only if it triggered offenses for more than 100 files
            sh 'rubocop --auto-gen-config --auto-gen-only-exclude --exclude-limit 100'
          end
        end
      end

      desc 'Autocorrect rubocop offenses in rails and in root'
      task :auto_correct do
        sh 'rubocop --auto-correct --ignore_parent_exclusion'
        Dir.chdir('../..') do
          sh 'rubocop --auto-correct'
        end
      end
    end
    desc 'Run the haml linter'
    task :haml do
      Rake::Task['haml_lint'].invoke
    end
  end

  namespace :sre do
    desc 'Configure the rails app to publish application health monitoring stats'
    task :configure do
      unless Rails.env.development?
        puts "You are running this rake task in #{Rails.env} environment."
        puts 'Please only run this task with RAILS_ENV=development'
        return
      end

      copy_example_file('config/options.yml')
      options_yml = YAML.load_file('config/options.yml') || {}
      options_yml['development']['influxdb_hosts'] = ['influx']
      options_yml['development']['amqp_namespace'] = 'opensuse.obs'
      options_yml['development']['amqp_options'] = { host: 'rabbit', port: '5672', user: 'guest', pass: 'guest', vhost: '/' }
      options_yml['development']['amqp_exchange_name'] = 'pubsub'
      options_yml['development']['amqp_exchange_options'] = { type: :topic, persistent: 'true', passive: 'true' }
      File.open('config/options.yml', 'w') do |f|
        f.write(YAML.dump(options_yml))
      end
    end
  end

  namespace :staging do
    desc 'Creates a staging workflow with a project and a confirmed user'
    task data: :environment do
      unless Rails.env.development?
        puts "You are running this rake task in #{Rails.env} environment."
        puts 'Please only run this task with RAILS_ENV=development'
        puts 'otherwise it will destroy your database data.'
        return
      end

      require 'factory_bot'
      include FactoryBot::Syntax::Methods
      timestamp = Time.now.to_i
      maintainer = create(:confirmed_user, login: "maintainer_#{timestamp}")
      User.session = maintainer
      managers_group = create(:group, title: "managers_group_#{timestamp}")
      staging_workflow = create(:staging_workflow_with_staging_projects, project: maintainer.home_project, managers_group: managers_group)
      staging_workflow.managers_group.add_user(maintainer)

      staging_workflow.staging_projects.each do |staging_project|
        2.times { |i| request_for_staging(staging_project, maintainer.home_project, "#{staging_project.id}_#{timestamp}_#{i}") }
      end

      puts "**** Created staging workflow project: /staging_workflows/#{staging_workflow.project} ****"
    end
  end

  # Run this task with: rails "dev:notifications:data[3]"
  # replacing 3 with any number to indicate how many times you want this code to be executed.
  namespace :notifications do
    desc 'Creates a notification and all its dependencies'
    task :data, [:repetitions] => :environment do |_t, args|
      unless Rails.env.development?
        puts "You are running this rake task in #{Rails.env} environment."
        puts 'Please only run this task with RAILS_ENV=development'
        puts 'otherwise it will destroy your database data.'
        return
      end

      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      # Users
      admin = User.where(login: 'Admin').first || create(:admin_user, login: 'Admin')
      subscribe_to_all_notifications(admin)
      requestor = User.where(login: 'Requestor').first || create(:confirmed_user, login: 'Requestor')
      User.session = requestor

      # Projects
      admin_home_project = admin.home_project || create_and_assign_project(admin.home_project_name, admin)
      requestor_project = Project.find_by(name: 'requestor_project') || create_and_assign_project('requestor_project', requestor)

      repetitions.times do |repetition|
        package_name = "package_#{Time.now.to_i}_#{repetition}"
        admin_package = create(:package_with_file, name: package_name, project: admin_home_project)
        requestor_package = create(:package_with_file, name: admin_package.name, project: requestor_project)

        # Will create a notification (RequestCreate event) for this request.
        request = create(
          :bs_request_with_submit_action,
          creator: requestor,
          target_project: admin_home_project,
          target_package: admin_package,
          source_project: requestor_project,
          source_package: requestor_package
        )

        # Will create a notification (ReviewWanted event) for this review.
        request.addreview(by_user: admin, comment: Faker::Lorem.paragraph)

        # Will create a notification (CommentForRequest event) for this comment.
        create(:comment_request, commentable: request, user: requestor)
        # Will create a notification (CommentForProject event) for this comment.
        create(:comment_project, commentable: admin_home_project, user: requestor)
        # Will create a notification (CommentForPackage event) for this comment.
        create(:comment_package, commentable: admin_package, user: requestor)

        # Admin requests changes to requestor, so a RequestStatechange notification will appear
        # as soon as the requestor changes the state of the request.
        request2 = create(
          :bs_request_with_submit_action,
          creator: admin,
          target_project: requestor_project,
          target_package: requestor_package,
          source_project: admin_home_project,
          source_package: admin_package
        )
        # Will create a notification (RequestStatechange event) for this request change.
        request2.change_state(newstate: ['accepted', 'declined'].sample, force: true, user: requestor.login, comment: 'Declined by requestor')

        # Process notifications immediately to see them in the web UI
        SendEventEmailsJob.new.perform_now
      end
    end
  end

  # This is automatically run in Review App or manually in development env.
  namespace :development_testdata do
    desc 'Creates test data to play with in dev and CI environments'
    task create: :environment do
      unless Rails.env.development?
        puts "You are running this rake task in #{Rails.env} environment."
        puts 'Please only run this task with RAILS_ENV=development'
        puts 'otherwise it will destroy your database data.'
        return
      end
      require 'factory_bot'
      include FactoryBot::Syntax::Methods
      require 'active_support/testing/time_helpers'
      include ActiveSupport::Testing::TimeHelpers

      Rails.cache.clear
      Rake::Task['db:reset'].invoke

      # Enable all the feature flags for all logged-in and not-logged-in users in development env.
      ENABLED_FEATURE_FLAGS.each do |feature_flag|
        Flipper[feature_flag].enable
      end

      iggy = create(:confirmed_user, login: 'Iggy')
      admin = User.get_default_admin
      User.session = admin

      interconnect = create(:project, name: 'openSUSE.org', remoteurl: 'https://api.opensuse.org/public')
      tw_repository = create(:repository, name: 'snapshot', project: interconnect, remote_project_name: 'openSUSE:Factory')

      # the home:admin is not created because the Admin user is created in seeds.rb
      # therefore we need to create it manually and also set the proper relationship
      home_admin = create(:project, name: admin.home_project_name)
      create(:relationship, project: home_admin, user: admin, role: Role.hashed['maintainer'])
      admin_repository = create(:repository, project: home_admin, name: 'openSUSE_Tumbleweed', architectures: ['x86_64'])
      create(:path_element, link: tw_repository, repository: admin_repository)
      ruby_admin = create(:package_with_file, name: 'ruby', project: home_admin, file_content: 'from admin home')

      branches_iggy = create(:project, name: iggy.branch_project_name('home:Admin'))
      ruby_iggy = create(:package_with_file, name: 'ruby', project: branches_iggy, file_content: 'from iggies branch')
      create(
        :bs_request_with_submit_action,
        creator: iggy,
        target_project: home_admin,
        target_package: ruby_admin,
        source_project: branches_iggy,
        source_package: ruby_iggy
      )

      test_package = create(:package, name: 'hello_world', project: home_admin)
      backend_url = "/source/#{CGI.escape(home_admin.name)}/#{CGI.escape(test_package.name)}"
      Backend::Connection.put("#{backend_url}/hello_world.spec", File.read('../../dist/t/spec/fixtures/hello_world.spec'))

      leap = create(:project, name: 'openSUSE:Leap:15.0')
      leap_apache = create(:package_with_file, name: 'apache2', project: leap)
      leap_repository = create(:repository, project: leap, name: 'openSUSE_Tumbleweed')
      create(:path_element, link: tw_repository, repository: leap_repository)

      # we need to set the user again because some factories set the user back to nil :(
      User.session = admin
      update_project = create(:update_project, target_project: leap, name: "#{leap.name}:Update")
      create(
        :maintenance_project,
        name: 'MaintenanceProject',
        title: 'official maintenance space',
        target_project: update_project,
        maintainer: admin
      )

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
        new_package1.reviews << create(:review, by_project: new_package1.staging_project)
        new_package1.save
        new_package1.change_review_state(:accepted, by_group: sworkflow.managers_group.title)

        new_package2 = create(
          :bs_request_with_submit_action,
          creator: iggy,
          target_package: 'reviewed',
          target_project: factory,
          source_package: leap_apache
        )
        new_package2.staging_project = sworkflow.staging_projects.second
        new_package2.reviews << create(:review, by_project: new_package2.staging_project)
        new_package2.save
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

      # Trigger package builds for home:admin
      home_admin.store

      # Create notifications by running the `dev:notifications:data` task two times
      Rake::Task['dev:notifications:data'].invoke(2)
    end
  end
end

def copy_example_file(example_file)
  if File.exist?(example_file) && !ENV['FORCE_EXAMPLE_FILES']
    example_file = File.join(File.expand_path(File.dirname(__FILE__) + '/../..'), example_file)
    puts "WARNING: You already have the config file #{example_file}, make sure it works with docker"
  else
    puts "Creating config/#{example_file} from config/#{example_file}.example"
    FileUtils.copy_file("#{example_file}.example", example_file)
  end
end

def request_for_staging(staging_project, maintainer_project, suffix)
  requester = create(:confirmed_user, login: "requester_#{suffix}")
  source_project = create(:project, name: "source_project_#{suffix}")
  target_package = create(:package, name: "target_package_#{suffix}", project: maintainer_project)
  source_package = create(:package, name: "source_package_#{suffix}", project: source_project)
  request = create(
    :bs_request_with_submit_action,
    state: :new,
    creator: requester,
    target_package: target_package,
    source_package: source_package,
    staging_project: staging_project
  )

  request.reviews.each { |review| review.change_state(:accepted, 'Accepted') }
end

def create_and_assign_project(project_name, user)
  create(:project, name: project_name).tap do |project|
    create(:relationship, project: project, user: user, role: Role.hashed['maintainer'])
  end
end

def subscribe_to_all_notifications(user)
  create(:event_subscription_request_created, channel: :web, user: user, receiver_role: 'target_maintainer')
  create(:event_subscription_review_wanted, channel: 'web', user: user, receiver_role: 'reviewer')
  create(:event_subscription_request_statechange, channel: :web, user: user, receiver_role: 'target_maintainer')
  create(:event_subscription_request_statechange, channel: :web, user: user, receiver_role: 'source_maintainer')
  create(:event_subscription_comment_for_project, channel: :web, user: user, receiver_role: 'maintainer')
  create(:event_subscription_comment_for_package, channel: :web, user: user, receiver_role: 'maintainer')
  create(:event_subscription_comment_for_request, channel: :web, user: user, receiver_role: 'target_maintainer')
end

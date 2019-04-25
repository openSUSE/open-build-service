# Everything that needs to be done before you can use this app

require 'fileutils'
require 'yaml'

namespace :dev do
  task :prepare do |_t, args|
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
    if args.old_test_suite
      puts 'Old test suite. Copying thinking sphinx example...'
      copy_example_file('config/thinking_sphinx.yml')
    end

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
    rescue
      Rake::Task['db:create'].invoke
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
    end
  end

  desc 'Run all linters we use'
  task :lint do
    Rake::Task['dev:lint:rubocop:all'].invoke
    sh 'jshint ./app/assets/javascripts/'
  end

  namespace :lint do
    task :db do
      desc 'Verify DB structure'
      Rake::Task['db:structure:verify'].invoke
      Rake::Task['db:structure:verify_no_bigint'].invoke
    end

    namespace :rubocop do
      desc 'Run the ruby linter in rails and in root'
      task all: [:root, :rails] do
      end

      desc 'Run the ruby linter in rails'
      task :rails do
        sh 'rubocop', '-D', '-F', '-S', '--fail-level', 'convention', '--ignore_parent_exclusion'
      end

      desc 'Run the ruby linter in root'
      task :root do
        Dir.chdir('../..') do
          sh 'rubocop', '-D', '-F', '-S', '--fail-level', 'convention'
        end
      end

      namespace :auto_gen_config do
        desc 'Autogenerate rubocop config in rails and in root'
        task all: [:root, :rails] do
        end

        desc 'Autogenerate rubocop config in rails'
        task :rails do
          sh 'rubocop --auto-gen-config --ignore_parent_exclusion --auto-gen-only-exclude'
        end

        desc 'Run the ruby linter in root'
        task :root do
          Dir.chdir('../..') do
            sh 'rubocop --auto-gen-config --auto-gen-only-exclude'
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
  end

  namespace :ahm do
    desc 'Configure the rails app to publish application health monitoring stats'
    task :configure do
      unless Rails.env.development?
        puts "You are running this rake task in #{Rails.env} environment."
        puts 'Please only run this task with RAILS_ENV=development'
        return
      end

      copy_example_file('config/options.yml')
      options_yml = YAML.load_file('config/options.yml') || {}
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
      User.current = maintainer
      managers_group = create(:group, title: "managers_group_#{timestamp}")
      staging_workflow = create(:staging_workflow_with_staging_projects, project: maintainer.home_project, managers_group: managers_group)
      staging_workflow.managers_group.add_user(maintainer)

      staging_workflow.staging_projects.each do |staging_project|
        2.times { |i| request_for_staging(staging_project, maintainer.home_project, "#{staging_project.id}_#{timestamp}_#{i}") }
      end

      puts "**** Created staging workflow project: /staging_workflows/#{staging_workflow.id} ****"
    end
  end

  namespace :development_testdata do
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
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      Rake::Task['db:setup'].invoke

      iggy = create(:confirmed_user, login: 'Iggy')
      admin = User.where(login: 'Admin').first
      User.current = admin

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

      test_package = create(:package, name: 'ctris', project: home_admin)
      backend_url = "/source/#{CGI.escape(home_admin.name)}/#{CGI.escape(test_package.name)}"
      Backend::Connection.put("#{backend_url}/ctris.spec", File.read('../../dist/t/spec/fixtures/ctris.spec'))
      Backend::Connection.put("#{backend_url}/ctris-0.42.tar.bz2", File.read('../../dist/t/spec/fixtures/ctris-0.42.tar.bz2'))

      leap = create(:project, name: 'openSUSE:Leap:15.0')
      leap_apache = create(:package_with_file, name: 'apache2', project: leap)
      leap_repository = create(:repository, project: leap, name: 'openSUSE_Tumbleweed')
      create(:path_element, link: tw_repository, repository: leap_repository)

      # we need to set the user again because some factories set the user back to nil :(
      User.current = admin
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
      checker = create(:confirmed_user, login: 'repo-checker')
      create(:relationship, project: factory, user: checker, role: Role.hashed['reviewer'])
      osrt = create(:group, title: 'review-team')
      reviewhero = create(:confirmed_user, login: 'reviewhero')
      osrt.users << reviewhero
      osrt.save
      create(:relationship, project: factory, group: osrt, role: Role.hashed['reviewer'])
      tw_apache = create(:package_with_file, name: 'apache2', project: factory)

      req = travel_to(90.minutes.ago) do
        req = create(
          :bs_request_with_submit_action,
          creator: iggy,
          target_package: tw_apache,
          source_package: leap_apache,
          review_by_user: checker
        )
        User.current = iggy
        req.reviews.create(by_group: osrt.title)
        req
      end

      travel_to(88.minutes.ago) do
        User.current = checker
        req.change_review_state(:accepted, by_user: checker.login, comment: 'passed')
      end

      travel_to(20.minutes.ago) do
        # accepting last review - new state
        User.current = reviewhero
        req.change_review_state(:accepted, by_group: osrt.title, comment: 'looks good')
      end

      comment = travel_to(85.minutes.ago) do
        create(:comment, commentable: req)
      end
      create(:comment, commentable: req, parent: comment)

      User.current = iggy
      req.addreview(by_user: admin.login, comment: 'is this really fine?')

      create(:project, name: 'openSUSE:Factory:Rings:0-Bootstrap')
      create(:project, name: 'openSUSE:Factory:Rings:1-MinimalX')
      create(:project, name: 'openSUSE:Factory:Staging:A', description: 'requests:')

      Configuration.download_url = 'https://download.opensuse.org'
      Configuration.save

      # Trigger package builds for home:admin
      home_admin.store
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

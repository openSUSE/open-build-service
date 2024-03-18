namespace :dev do
  namespace :requests do
    # Run this task with: rails dev:requests:multiple_actions_request
    desc 'Creates a request with multiple actions'
    task :multiple_actions_request, [:repetitions] => :development_environment do |_t, args|
      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i

      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      repetitions.times do
        admin = User.default_admin
        User.session = admin
        iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')

        # Set target project and package
        target_project = Project.find_by(name: 'openSUSE:Factory') || create(:project, name: 'openSUSE:Factory') # openSUSE:Factory
        target_package_a = Package.where(name: 'package_a', project: target_project).first ||
                           create(:package_with_files, name: 'package_a', project: target_project)

        # Simulate the branching of source project by Iggy, then it modifies some packages
        source_project = RakeSupport.find_or_create_project(iggy.branch_project_name(target_project.name), iggy) # home:Iggy:branches:openSUSE:Factory
        source_package_a = Package.where(name: 'package_a', project: source_project).first ||
                           create(:package_with_files, name: 'package_a', project: source_project, changes_file_content: '- Fixes boo#2222222 and CVE-2011-2222')

        # Create request to submit new files to the target package A
        request = create(
          :bs_request_with_submit_action,
          creator: iggy,
          target_project: target_project,
          target_package: target_package_a,
          source_project: source_project,
          source_package: source_package_a
        )

        target_package_b = Package.where(name: 'package_b', project: target_project).first ||
                           create(:package, name: 'package_b', project: target_project)

        # Create more actions to submit new files from different packages to package_b
        ('b'..'z').each_with_index do |char, index|
          figure = (index + 1).to_s.rjust(2, '0') # Generate the last two figures for the issue code
          changes_file_content = "- Fixes boo#11111#{figure} CVE-2011-11#{figure}"

          source_package = Package.where(name: "package_#{char}", project: source_project).first ||
                           create(:package_with_files, name: "package_#{char}", project: source_project, changes_file_content: changes_file_content)

          action_attributes = {
            source_package: source_package,
            source_project: source_project,
            target_project: target_project,
            target_package: target_package_b
          }
          bs_req_action = build(:bs_request_action, action_attributes.merge(type: 'submit', bs_request: request))
          bs_req_action.save!
        end

        # Create an action to add role
        action_attributes = {
          target_project: target_project,
          target_package: target_package_a,
          person_name: User.last.login,
          role: Role.find_by_title!('maintainer'),
          type: 'add_role',
          bs_request: request
        }
        bs_req_action = build(:bs_request_action, action_attributes)
        bs_req_action.save!

        # Create an action to set a user as bugowner
        action_attributes = {
          target_project: target_project,
          target_package: target_package_b,
          person_name: 'user_1',
          type: 'set_bugowner',
          bs_request: request
        }
        bs_req_action = build(:bs_request_action, action_attributes)
        bs_req_action.save!

        # Create an action to set a group as bugowner
        action_attributes = {
          target_project: target_project,
          target_package: target_package_a,
          group_name: 'group_1',
          type: 'set_bugowner',
          bs_request: request
        }
        bs_req_action = build(:bs_request_action, action_attributes)
        bs_req_action.save!

        create(:bs_request_action_delete,
               target_project: target_project,
               bs_request: request)

        create(:bs_request_action_delete,
               target_project: target_project,
               target_package: target_package_a,
               bs_request: request)

        # Create an action to change devel

        # Package to be developed in another place (target)
        # target_project -> openSUSE:Factory
        apache2_factory = Package.find_by_project_and_name('openSUSE:Factory', 'apache2')

        # Current devel package
        servers_project = Project.find_by(name: 'servers') || create(:project, name: 'servers')
        apache2_servers = Package.find_by_project_and_name(servers_project.name, 'apache2') || create(:package_with_file, project: servers_project, name: 'apache2')

        # Future devel package (source)
        # source_project -> home:Iggy:branches:openSUSE:Factory
        Package.find_by_project_and_name(source_project.name, 'apache2') || create(:package, project: source_project, name: 'apache2')

        # Set development package
        apache2_factory.update(develpackage: apache2_servers)

        action_attributes = {
          source_project_name: source_project.name,
          target_project_name: target_project.name,
          target_package_name: apache2_factory.name,
          bs_request: request
        }
        bs_req_action = build(:bs_request_action_change_devel, action_attributes)
        bs_req_action.save!

        puts "* Request #{request.number} contains multiple actions and mentioned issues."
        puts 'To start the builds confirm or perfom the following steps:'
        puts '- Create the interconnect with openSUSE.org'
        puts "- Create a couple of repositories in project #{source_project.name}"
      end
    end

    # Creates a request with two actions of the same type: 'submit'.
    desc 'Creates a request with only submit actions and some diffs'
    task :request_with_multiple_submit_actions_builds_and_diffs, %i[repetitions actions_count] => :development_environment do |_t, args|
      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i

      args.with_defaults(actions_count: 2)
      actions_count = args.actions_count.to_i

      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      User.session = iggy
      admin = User.default_admin
      iggy_home_project = RakeSupport.find_or_create_project(iggy.home_project_name, iggy)
      home_admin_project = RakeSupport.find_or_create_project(admin.home_project_name, admin)

      repetitions.times do |repetition|
        source_package_name = "source_package_with_multiple_submit_request_and_diff_#{Time.now.to_i}_#{repetition}"
        source_package =
          Package.find_by_project_and_name(iggy_home_project, source_package_name) || create(:package_with_files,
                                                                                             project: iggy_home_project,
                                                                                             name: source_package_name,
                                                                                             file_content: '# New content')

        target_package_name = "target_package_with_diff_#{Time.now.to_i - 1.second}_#{repetition}"
        target_package =
          Package.find_by_project_and_name(home_admin_project, target_package_name) || create(:package_with_files,
                                                                                              project: home_admin_project,
                                                                                              name: target_package_name,
                                                                                              file_content: '# This will be replaced')

        bs_request = create(:bs_request_with_submit_action,
                            creator: iggy,
                            source_project: iggy_home_project,
                            source_package: source_package,
                            target_project: home_admin_project,
                            target_package: target_package)

        (1..actions_count).each do |action_index|
          another_source_package_name = "another_source_package_with_multiple_submit_request_and_diff_#{Time.now.to_i}_#{repetition}_#{action_index}"
          another_source_package =
            Package.find_by_project_and_name(iggy_home_project.name, another_source_package_name) ||
            create(:package_with_files,
                   project: iggy_home_project,
                   name: another_source_package_name,
                   file_content: '# New content')

          another_target_package_name = "another_package_with_diff_#{Time.now.to_i}_#{repetition}_#{action_index}"
          another_target_package =
            Package.find_by_project_and_name(home_admin_project, another_target_package_name) || create(:package_with_files,
                                                                                                        project: home_admin_project,
                                                                                                        name: another_target_package_name,
                                                                                                        file_content: '# This will be replaced')

          create(:bs_request_action_submit_with_diff,
                 creator: iggy,
                 source_project_name: iggy_home_project.name,
                 source_package_name: another_source_package.name,
                 target_project_name: home_admin_project.name,
                 target_package_name: another_target_package.name,
                 bs_request: bs_request)
        end

        puts "* Request with #{actions_count} submit actions, builds, diffs and rpm lints."
        puts "  See http://localhost:3000/request/show/#{bs_request.number}."
        puts '  To start the builds confirm or perfom the following steps:'
        puts '  - Create the interconnect with openSUSE.org'
        puts "  - Create a couple of repositories in project #{iggy_home_project.name}"
      end
    end

    # Run this task with: rails dev:requests:request_with_delete_action
    desc 'Creates a request with a delete action'
    task :request_with_delete_action, [:repetitions] => :development_environment do |_t, args|
      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i

      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      admin = User.default_admin
      home_admin_project = RakeSupport.find_or_create_project(admin.home_project_name, admin)

      repetitions.times do |repetition|
        target_package = create(:package, project: home_admin_project, name: "#{Faker::Lorem.word}_#{Time.now.to_i}_#{repetition}")
        request = create(:delete_bs_request, target_package: target_package, creator: iggy)

        puts "* Request with delete action #{request.number} has been created."
      end
    end

    desc 'Copy 10 requests from openSUSE:Factory'
    task requests_from_opensuse_factory: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      admin = User.get_default_admin
      admin.run_as do
        # Setup interconnect
        remote_proj = Project.find_or_create_by(name: 'openSUSE.org', remoteurl: 'https://api.opensuse.org/public')
        remote_proj.store
        FetchRemoteDistributionsJob.perform_now

        clone_project(project_name: 'openSUSE:Factory')
      end
    end

    def clone_project(project_name:)
      project = Project.find_or_create_by(name: project_name)
      config = make_api_request(url: "#{base_api_url}/source/#{project.name}/_config")
      clone_prj_configs(config: config, project: project, comment: "Cloned from #{project.name}")

      request = make_api_request(url: "#{base_api_url}/source/#{project.name}/_meta")
      request_data = Xmlhash.parse(request)
    end

    def clone_prj_configs(config:, comment:, project:)
      project.config.save({ user: User.session!.login, comment: comment }, config)
    end

    def make_api_request(url:, params: {}, headers: { 'Content-Type' => 'application/xml' })
      username = ''
      password = ''
      conn = Faraday.new(
        url: url,
        params: params,
        headers: headers
      )
      conn.set_basic_auth(username, password)
      request = conn.get

      request.body
    end

    def base_api_url
      'https://api.opensuse.org'
    end

    def print_message(message)
      puts '=' * 50
      puts message
    end
  end
end

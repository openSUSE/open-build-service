namespace :dev do
  namespace :requests do
    # Run this task with: rails dev:requests:multiple_actions_request
    desc 'Creates a request with multiple actions'
    task multiple_actions_request: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      puts 'Creating a request with multiple actions...'

      admin = User.get_default_admin
      User.session = admin
      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')

      # Set target project and package
      target_project = Project.find_by(name: 'openSUSE:Factory') || create(:project, name: 'openSUSE:Factory') # openSUSE:Factory
      target_package_a = Package.where(name: 'package_a', project: target_project).first ||
                         create(:package_with_files, name: 'package_a', project: target_project)

      # Simulate the branching of source project by Iggy, then it modifies some packages
      source_project = RakeSupport.find_or_create_project(iggy.branch_project_name(target_project.name), iggy) # home:Admin:branches:openSUSE:Factory
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

      # Create more actions to submit new files from different packages to package_b
      ('b'..'z').each_with_index do |char, index|
        figure = (index + 1).to_s.rjust(2, '0') # Generate the last two figures for the issue code
        changes_file_content = "- Fixes boo#11111#{figure} CVE-2011-11#{figure}"

        source_package = Package.where(name: "package_#{char}", project: source_project).first ||
                         create(:package_with_files, name: "package_#{char}", project: source_project, changes_file_content: changes_file_content)

        target_package_b = Package.where(name: 'package_b', project: target_project).first ||
                           create(:package, name: 'package_b', project: target_project)

        action_attributes = {
          source_package: source_package,
          source_project: source_project,
          target_project: target_project,
          target_package: target_package_b
        }
        bs_req_action = build(:bs_request_action, action_attributes.merge(type: 'submit', bs_request: request))
        bs_req_action.save! if bs_req_action.valid?
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
      bs_req_action.save! if bs_req_action.valid?

      puts "* Request #{request.number} contains multiple actions and mentioned issues."
      puts 'To start the builds confirm or perfom the following steps:'
      puts '- Create the interconnect with openSUSE.org'
      puts '- Create a couple of repositories in project home:Iggy:branches:home:Admin'
    end

    desc 'Creates several requests with submit actions and diffs'
    task request_with_multiple_submit_actions_and_diffs: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      User.session = iggy
      admin = User.get_default_admin
      iggy_home_project = RakeSupport.find_or_create_project(iggy.home_project_name, iggy)
      home_admin_project = RakeSupport.find_or_create_project(admin.home_project_name, admin)

      source_package = create(:package_with_file,
                              project: iggy_home_project,
                              name: "source_package_with_multiple_submit_request_and_diff_#{Time.now.to_i}",
                              file_name: 'somefile.txt',
                              file_content: '# This will be replaced')
      target_package = create(:package_with_file,
                              project: home_admin_project,
                              name: "another_package_with_diff_#{Time.now.to_i}",
                              file_name: 'somefile.txt',
                              file_content: '# This will be replaced')

      bs_request = create(:bs_request_with_submit_action,
                          creator: iggy,
                          source_project: iggy_home_project,
                          source_package: source_package,
                          target_project: home_admin_project,
                          target_package: target_package)

      create(:bs_request_action_submit_with_diff,
             creator: iggy,
             source_project_name: iggy_home_project.name,
             source_package_name: 'source_package_with_multiple_submit_request_and_diff',
             target_project_name: home_admin_project.name,
             target_package_name: 'package_with_diff',
             bs_request: bs_request)

      puts "* Request #{bs_request.number} has been created."
    end

    desc 'Creates a request with maintenance incident actions'
    task request_with_maintenance_incident_actions: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      User.session = iggy
      admin = User.get_default_admin
      home_admin_project = RakeSupport.find_or_create_project(admin.home_project_name, admin)

      request = build(
        :bs_request_with_maintenance_incident_action,
        creator: iggy
      )

      maintenance_project = Project.find_by(kind: 'maintenance')
      release_project = Project.find_by(kind: 'maintenance_release')

      # This is the first maintenance incident action, we reuse the action created by the factory
      home_iggy_project = RakeSupport.find_or_create_project(iggy.home_project_name, iggy)
      maintenance_package = create(:package, name: "maintenance_package_#{Faker::Lorem.word}", project: home_iggy_project)
      request.bs_request_actions.first.tap do |action|
        action.source_project = home_iggy_project
        action.source_package = maintenance_package
        action.target_project = maintenance_project
        action.target_releaseproject = release_project
        action.save!
      end

      # This is the second maintenance incident action
      another_maintenance_package = create(:package, name: "another_maintenance_package_#{Faker::Lorem.word}", project: home_iggy_project)
      request.bs_request_actions << create(:bs_request_action,
                                           type: :maintenance_incident,
                                           source_project: home_iggy_project,
                                           source_package: another_maintenance_package,
                                           target_project: maintenance_project,
                                           target_releaseproject: release_project)

      create(:bs_request_action_delete,
             target_project: home_admin_project,
             bs_request: request)

      puts "* Request with maintenance incident actions #{request.number} has been created."
    end
  end
end

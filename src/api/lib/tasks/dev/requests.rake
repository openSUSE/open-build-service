namespace :dev do
  namespace :requests do
    # Run this task with: rails dev:requests:multiple_actions_request
    desc 'Creates a request with multiple actions'
    task multiple_actions_request: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      puts 'Creating a request with multiple actions...'

      requestor = User.get_default_admin
      User.session = requestor

      # Set source project, packages and files
      source_project = RakeSupport.find_or_create_project(requestor.home_project_name, requestor) # home:Admin
      source_package_a = Package.where(name: 'package_a', project: source_project).first || create(:package, name: 'package_a', project: source_project)
      source_package_b = Package.where(name: 'package_b', project: source_project).first || create(:package, name: 'package_b', project: source_project)
      # Add files to the newly created source package A
      ["#{source_package_a}.spec", "#{source_package_a}.changes"].each do |file_name|
        source_package_a.save_file({ file: Faker::Lorem.paragraph, filename: file_name })
      end
      # Add a file to the newly created source package B
      source_package_b.save_file({ file: Faker::Lorem.paragraph, filename: "#{source_package_b}.spec" })

      # Set target project and packages
      target_project = Project.find_by(name: 'openSUSE:Factory') || create(:project, name: 'openSUSE:Factory')
      target_package_a = Package.where(name: 'package_a', project: target_project).first || create(:package, name: 'package_a', project: target_project)
      target_package_b = Package.where(name: 'package_b', project: target_project).first || create(:package, name: 'package_b', project: target_project)

      # Create request to submit new files to the target package A
      request = create(
        :bs_request_with_submit_action,
        creator: requestor,
        target_project: target_project,
        target_package: target_package_a,
        source_project: source_project,
        source_package: source_package_a
      )

      # Create more actions to submit a new file to different packages
      (1..30).each do |i|
        target_package = Package.where(name: "package_#{i}", project: target_project).first || create(:package, name: "package_#{i}", project: target_project)

        # Create an action to submit a new file to package C
        action_attributes = {
          source_package: source_package_b,
          source_project: source_project,
          target_project: target_project,
          target_package: target_package
        }
        bs_req_action = build(:bs_request_action, action_attributes.merge(type: 'submit', bs_request: request))
        bs_req_action.save! if bs_req_action.valid?
      end

      # Create an action to add role
      action_attributes = {
        target_project: target_project,
        target_package: target_package_b,
        person_name: User.last.login,
        role: Role.find_by_title!('maintainer')
      }
      bs_req_action = build(:bs_request_action, action_attributes.merge(type: 'add_role', bs_request: request))
      bs_req_action.save! if bs_req_action.valid?

      puts "* Request #{request.number} has been created."
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

    desc 'Creates a request which builds and produces build results'
    task request_with_build_results: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      puts 'Creating a request which builds and produces build results...'
      admin = User.get_default_admin
      home_admin_project = RakeSupport.find_or_create_project(admin.home_project_name, admin)

      # Branch the hello_world package
      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      branches_iggy = Project.find_by(name: iggy.branch_project_name(home_admin_project.name)) || create(:project, name: iggy.branch_project_name(home_admin_project.name))
      hello_world_iggy = create(:package, name: "hello_world_#{Faker::Lorem.word}", project: branches_iggy)
      backend_url = "/source/#{CGI.escape(branches_iggy.name)}/#{CGI.escape(hello_world_iggy.name)}"
      hello_world_spec = File.read('../../dist/t/spec/fixtures/hello_world.spec')
      hello_world_spec.gsub('Most simple RPM package', Faker::Lorem.sentence(word_count: 4))
      Backend::Connection.put("#{backend_url}/hello_world.spec", hello_world_spec)

      # Create the request
      request = create(
        :bs_request_with_submit_action,
        creator: iggy,
        target_project: home_admin_project,
        target_package: 'hello_world',
        source_project: branches_iggy,
        source_package: hello_world_iggy
      )
      puts "* Request #{request.number} has been created."
      puts 'To start the builds confirm or perfom the following steps:'
      puts '- Create the interconnect with openSUSE.org'
      puts '- Create a couple of repositories in project home:Iggy:branches:home:Admin'
    end
  end
end

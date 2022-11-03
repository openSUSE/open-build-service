require 'tasks/dev/helper_methods'

namespace :requests do
  # Run this task with: rails requests:multiple_actions_request
  desc 'Creates a request with multiple actions'
  task multiple_actions_request: :environment do
    unless Rails.env.development?
      puts "You are running this rake task in #{Rails.env} environment."
      puts 'Please only run this task with RAILS_ENV=development'
      puts 'otherwise it will destroy your database data.'
      return
    end

    require 'factory_bot'
    include FactoryBot::Syntax::Methods

    puts 'Creating a request with multiple actions...'

    requestor = User.get_default_admin
    User.session = requestor

    # Set source project, packages and files
    source_project = find_or_create_project(requestor.home_project_name, requestor) # home:Admin
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

    # Create an action to submit a new file to package B
    action_attributes = {
      source_package: source_package_b,
      source_project: source_project,
      target_project: target_project,
      target_package: target_package_b
    }
    bs_req_action = build(:bs_request_action, action_attributes.merge(type: 'submit', bs_request: request))
    bs_req_action.save! if bs_req_action.valid?

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
end

# Run this task with: rails staging:data
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

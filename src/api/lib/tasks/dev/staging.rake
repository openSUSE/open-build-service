namespace :dev do
  namespace :staging do
    # Run this task with: rails dev:staging:data
    desc 'Creates a staging workflow with a project and a confirmed user'
    task data: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods
      timestamp = Time.now.to_i
      maintainer = create(:confirmed_user, login: "maintainer_#{timestamp}")
      User.session = maintainer
      managers_group = create(:group, title: "managers_group_#{timestamp}")
      staging_workflow = create(:staging_workflow_with_staging_projects, project: maintainer.home_project, managers_group: managers_group)
      staging_workflow.managers_group.add_user(maintainer)

      staging_workflow.staging_projects.each do |staging_project|
        2.times { |i| RakeSupport.request_for_staging(staging_project, maintainer.home_project, "#{staging_project.id}_#{timestamp}_#{i}") }
      end

      puts "**** Created staging workflow project: /staging_workflows/#{staging_workflow.project} ****"
    end
  end
end

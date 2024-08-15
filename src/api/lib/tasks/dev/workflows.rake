namespace :dev do
  namespace :workflows do
    # Run this task with: rails dev:workflows:create_workflow_runs
    desc 'Creates a workflow token, workflow runs, artifacts and some of their dependencies'
    task create_workflow_runs: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      puts 'Creating workflow token and workflow runs...'

      admin = User.default_admin
      User.session = admin
      project = RakeSupport.find_or_create_project(admin.home_project_name, admin)

      workflow_token = Token::Workflow.find_by(description: 'Testing token') || create(:workflow_token, executor: admin, description: 'Testing token')

      # This automatically subscribes everyone to the workflow run related events
      EventSubscription.create!(eventtype: Event::WorkflowRunFail.name, channel: :web, receiver_role: :token_executor, enabled: true)

      # GitHub
      create(:workflow_run, token: workflow_token)
      create(:workflow_run, :failed, token: workflow_token)
      create(:workflow_run, :succeeded, :push, token: workflow_token)
      create(:workflow_run, :succeeded, :tag_push, token: workflow_token)
      create(:workflow_run, :succeeded, token: workflow_token)
      create(:workflow_run, :succeeded, :pull_request_closed, token: workflow_token)
      create(:workflow_run, :with_url, token: workflow_token)
      create(:workflow_run, :without_configuration_data, token: workflow_token)

      # GitLab
      create(:workflow_run_gitlab, token: workflow_token)
      create(:workflow_run_gitlab, :failed, token: workflow_token)
      create(:workflow_run_gitlab, :succeeded, :push, token: workflow_token)
      create(:workflow_run_gitlab, :succeeded, :tag_push, token: workflow_token)
      create(:workflow_run_gitlab, :succeeded, token: workflow_token)
      create(:workflow_run_gitlab, :succeeded, :pull_request_closed, token: workflow_token)

      workflow_runs_with_artifacts = WorkflowRun.where(status: 'success')

      source_project_name = project.name
      target_project_name = "#{project.name}:CI:repo:PR-1"

      workflow_runs_with_artifacts.each do |workflow_run|
        create(:workflow_artifacts_per_step_branch_package, workflow_run: workflow_run, source_project_name: source_project_name, target_project_name: target_project_name)
        create(:workflow_artifacts_per_step_link_package, workflow_run: workflow_run, source_project_name: source_project_name, target_project_name: target_project_name)
        create(:workflow_artifacts_per_step_rebuild_package, workflow_run: workflow_run, source_project_name: source_project_name, target_project_name: target_project_name)
        create(:workflow_artifacts_per_step_config_repositories, workflow_run: workflow_run, source_project_name: source_project_name, target_project_name: target_project_name)
        create(:workflow_artifacts_per_step_set_flags, workflow_run: workflow_run, source_project_name: source_project_name, target_project_name: target_project_name)
      end
    end

    desc 'Remove projects that were not closed as expected and set workflow run status to running'
    task cleanup_non_closed_projects: :environment do
      workflow_runs = WorkflowRun.where(status: 'running')
                                 .select do |workflow_run|
        workflow_run.hook_event.in?(['pull_request', 'Merge Request Hook']) &&
          workflow_run.hook_action.in?(%w[closed close merge])
      end

      puts "There are #{workflow_runs.count} workflow runs affected"

      workflow_runs.each do |workflow_run|
        projects = Project.where('name LIKE ?', "%#{target_project_name_postfix(workflow_run)}")

        # If there is more than one project, we don't know which of them is the one related to the current
        # workflow run (as we only can get the postfix, we don't have the full project name).
        next if projects.count > 1

        # If there is no project to remove (previously removed), the workflow run should change the status anyway.
        User.default_admin.run_as { projects.first.destroy } if projects.count == 1
        workflow_run.update(status: 'success')
      rescue StandardError => e
        Airbrake.notify("Failed to remove project created by the workflow: #{e}")
        next
      end
    end
  end
end

# If the name of the project created by the workflow is "home:Iggy:iggy:hello_world:PR-68", its postfix
# is "iggy:hello_world:PR-68". This is the only information we can extract from the workflow_run.
def target_project_name_postfix(workflow_run)
  ":#{workflow_run.repository_owner}:#{workflow_run.repository_name}:PR-#{workflow_run.event_source_name}" if workflow_run.repository_name && workflow_run.event_source_name
end

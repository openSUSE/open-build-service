namespace :workflows do
  desc 'Remove projects that were not closed as expected and set workflow run status to running'
  task cleanup_non_closed_projects: :environment do
    workflow_runs = WorkflowRun.where(status: 'running')
                               .select do |workflow_run|
                                 workflow_run.hook_event.in?(['pull_request', 'Merge Request Hook']) &&
                                   workflow_run.hook_action.in?(['closed', 'close', 'merge'])
                               end

    puts "There are #{workflow_runs.count} workflow runs affected"

    workflow_runs.each do |workflow_run|
      projects = Project.where('name LIKE ?', "%#{target_project_name_postfix(workflow_run)}")

      # If there is more than one project, we don't know which of them is the one related to the current
      # workflow run (as we only can get the postfix, we don't have the full project name).
      next if projects.count > 1

      # If there is no project to remove (previously removed), the workflow run should change the status anyway.
      User.get_default_admin.run_as { projects.first.destroy } if projects.count == 1
      workflow_run.update(status: 'success')
    rescue StandardError => e
      Airbrake.notify("Failed to remove project created by the workflow: #{e}")
      next
    end
  end
end

# If the name of the project created by the workflow is "home:Iggy:iggy:hello_world:PR-68", its postfix
# is "iggy:hello_world:PR-68". This is the only information we can extract from the workflow_run.
def target_project_name_postfix(workflow_run)
  ":#{workflow_run.repository_name.tr('/', ':')}:PR-#{workflow_run.event_source_name}" if workflow_run.repository_name && workflow_run.event_source_name
end

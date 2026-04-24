# frozen_string_literal: true

class Workflow::Step::LinkProject < Workflow::Step
  REQUIRED_KEYS = %i[project target_project].freeze

  def call
    return if workflow_run.closed_merged_pull_request? || workflow_run.unlabeled_pull_request?

    project = Project.find_by_name(step_instructions[:project])
    target_name = step_instructions[:target_project]
    target_project = Project.find_by_name(target_name)

    project.linking_to.delete_all
    if target_project
      project.linking_to.create!(linked_db_project: target_project)
    else
      project.linking_to.create!(linked_remote_project_name: target_name)
    end

    project.store(
      comment: "Linked project to #{target_name}",
      login: token.executor.login
    )
  end
end

class Workflow::Step::LinkProject < Workflow::Step
  REQUIRED_KEYS = %i[target_project source_project].freeze

  def call
    return unless valid?

    if Project.exists_by_name(target_project_name)
      Pundit.authorize(@token.executor, target_project, :update?)
    else
      create_target_project
    end

    case
    when workflow_run.closed_merged_pull_request?, workflow_run.unlabeled_pull_request?
      target_project.remove_project_link(linked_project_name: step_instructions[:source_project])
    when workflow_run.new_pull_request?, workflow_run.reopened_pull_request?, workflow_run.push_event?, workflow_run.tag_push_event?, workflow_run.labeled_pull_request?
      target_project.add_project_link(source_project_name: step_instructions[:source_project])
    end
  end

  private

  def target_project_name
    case
    when workflow_run.push_event?
      "#{target_project_base_name}:#{workflow_run.commit_sha.slice(0, SHORT_COMMIT_SHA_LENGTH)}"
    when workflow_run.tag_push_event?
      "#{target_project_base_name}:#{workflow_run.tag_name}"
    else
      super
    end
  end

  # This is the project the packages are going to land into
  def target_project_base_name
    step_instructions[:target_project]
  end

  def create_target_project
    project = Project.new(name: target_project_name, url: workflow_run.event_source_url)
    Pundit.authorize(@token.executor, project, :create?)

    project.relationships.build(user: @token.executor,
                                role: Role.find_by_title('maintainer'))
    project.commit_user = User.session
    project.store(comment: 'SCI/CI integration, link_project step')
    project
  end
end

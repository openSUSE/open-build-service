class Workflow::Step::LinkProject < Workflow::Step

  REQUIRED_KEYS = %i[target_project source_project].freeze

  validate :validate_existence_of_projects

  def call
    return unless valid?

    Pundit.authorize(@token.executor, @project, :update?)

    case
    when workflow_run.closed_merged_pull_request?, workflow_run.unlabeled_pull_request?
      @project.remove_project_link(linked_project_name: source_project_name)
    when workflow_run.new_pull_request?, workflow_run.reopened_pull_request?, workflow_run.push_event?, workflow_run.tag_push_event?, workflow_run.labeled_pull_request?
      @project.add_project_link(source_project_name: source_project_name)
    end
  end

  private

  # This is the project the packages are going to land into
  def target_project_base_name
    step_instructions[:target_project]
  end

  # This is the project the packages are going to be pulled from
  def source_project_name
    step_instructions[:source_project]
  end

  def validate_existence_of_projects
    project_name = target_project_base_name
    return if project_name.blank? || source_project_name.blank?

    if Project.exists_by_name(project_name)
      @project = Project.get_by_name(project_name)
    else
      @project = create_target_project(project_name)
    end

    # exists_by_name handles both local and remote (interconnect) projects
    return if Project.exists_by_name(source_project_name)

    errors.add(:base, "The project '#{source_project_name}' does not exist.")
  end

  def create_target_project(project_name)
    project = Project.new(name: target_project_base_name, url: workflow_run.event_source_url)
    Pundit.authorize(@token.executor, project, :create?)

    project.relationships.build(user: @token.executor,
                                role: Role.find_by_title('maintainer'))
    project.commit_user = User.session
    project.store(comment: 'SCI/CI integration, link_project step')
    project
  end
end

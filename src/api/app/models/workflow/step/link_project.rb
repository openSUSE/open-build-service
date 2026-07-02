class Workflow::Step::LinkProject < Workflow::Step

  REQUIRED_KEYS = %i[target_project source_project].freeze

  validate :validate_required_keys_not_empty
  validate :validate_source_project_exists

  def call
    return unless valid?

    @target_project = target_project
    Pundit.authorize(@token.executor, @target_project, :update?)

    case
    when workflow_run.closed_merged_pull_request?, workflow_run.unlabeled_pull_request?
      @target_project.remove_project_link(linked_project_name: source_project_name)
    when workflow_run.new_pull_request?, workflow_run.reopened_pull_request?, workflow_run.push_event?, workflow_run.tag_push_event?, workflow_run.labeled_pull_request?
      @target_project.add_project_link(source_project_name: source_project_name)
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

  def validate_required_keys_not_empty
    errors.add(:base, 'The target_project is empty') if target_project_base_name.blank?
    errors.add(:base, 'The source_project is empty') if source_project_name.blank?
  end

  def validate_source_project_exists
    # exists_by_name handles both local and remote (interconnect) projects
    return if Project.exists_by_name(source_project_name)

    errors.add(:base, "The project '#{source_project_name}' does not exist.")
  end
end

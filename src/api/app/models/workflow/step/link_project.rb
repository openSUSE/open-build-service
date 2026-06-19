class Workflow::Step::LinkProject < Workflow::Step

  REQUIRED_KEYS = %i[project project_to_link_against].freeze

  validate :validate_existence_of_projects

  def call
    return unless valid?

    case
    when workflow_run.closed_merged_pull_request?, workflow_run.unlabeled_pull_request?
      @project.remove_project_link(linked_project_name: project_name_to_link_against)
    when workflow_run.new_pull_request?, workflow_run.reopened_pull_request?, workflow_run.push_event?, workflow_run.tag_push_event?, workflow_run.labeled_pull_request?
      @project.add_project_link(project_name_to_link_against: project_name_to_link_against)
    end
  end

  private

  def project_name
    step_instructions[:project]
  end

  def project_name_to_link_against
    step_instructions[:project_to_link_against]
  end

  def validate_existence_of_projects
    return if project_name.blank? || project_name_to_link_against.blank?

    @project = Project.find_by_name(project_name)
    errors.add(:base, "The project '#{project_name}' does not exist.") if @project.blank?

    # exists_by_name handles both local and remote (interconnect) projects
    return if Project.exists_by_name(project_name_to_link_against)

    errors.add(:base, "The project '#{project_name_to_link_against}' does not exist.")
  end
end

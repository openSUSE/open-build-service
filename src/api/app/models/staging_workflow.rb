class StagingWorkflow < ApplicationRecord
  belongs_to :project, inverse_of: :staging
  has_many :staging_projects, class_name: 'Project', inverse_of: :staging_workflow, dependent: :nullify

  validates :project_id, presence: true

  def unassigned_requests
    project_requests - staging_projects_requests - ignored_requests
  end

  private

  def project_requests
    project.bs_requests
  end

  def staging_projects_requests
    staging_projects.map(&:bs_requests).flatten
  end

  def ignored_requests
    # TODO: define this method
    []
  end
end

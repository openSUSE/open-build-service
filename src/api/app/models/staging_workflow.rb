class StagingWorkflow < ApplicationRecord
  belongs_to :project, inverse_of: :staging
  has_many :staging_projects, class_name: 'Project', inverse_of: :staging_workflow, dependent: :nullify

  validates :project_id, presence: true

  def unassigned_requests
    project_requests - staging_projects_requests - ignored_requests
  end

  private

  def project_requests
    BsRequest.where(id: BsRequestAction.bs_request_ids_of_involved_projects(project_id))
  end

  def staging_projects_requests
    BsRequest.where(id: StagedRequest.where(project: staging_projects).pluck(:bs_request_id))
  end

  def ignored_requests
    # TODO: define this method
    []
  end
end

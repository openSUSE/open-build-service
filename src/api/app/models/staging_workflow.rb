class StagingWorkflow < ApplicationRecord
  belongs_to :project, inverse_of: :staging
  has_many :staging_projects, class_name: 'Project', inverse_of: :staging_workflow, dependent: :nullify

  has_many :target_of_bs_requests, through: :project
  has_many :staged_requests, class_name: 'BsRequest', through: :staging_projects

  has_and_belongs_to_many :managers, class_name: 'User', join_table: 'staging_workflows_managers'

  def unassigned_requests
    target_of_bs_requests.in_states(['new', 'review']) - staged_requests - ignored_requests
  end

  def ignored_requests
    BsRequest.none # TODO: define this method
  end
end

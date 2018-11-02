class StagingWorkflow < ApplicationRecord
  belongs_to :project, inverse_of: :staging
  has_many :staging_projects, class_name: 'Project', inverse_of: :staging_workflow, dependent: :nullify, autosave: true do
    def without_staged_requests
      includes(:staged_requests).where(bs_requests: { id: nil })
    end
  end
  has_many :target_of_bs_requests, through: :project
  has_many :staged_requests, class_name: 'BsRequest', through: :staging_projects

  after_initialize :init_staging_projects

  def unassigned_requests
    target_of_bs_requests.in_states(['new', 'review']) - staged_requests - ignored_requests
  end

  def ignored_requests
    BsRequest.none # TODO: define this method
  end

  private

  def init_staging_projects
    return unless new_record?
    ['A', 'B'].each do |letter|
      staging_projects << Project.find_or_initialize_by(name: "#{project.name}:Staging:#{letter}")
    end
  end
end

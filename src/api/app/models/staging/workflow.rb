class Staging::Workflow < ApplicationRecord
  def self.table_name_prefix
    'staging_'
  end

  belongs_to :project, inverse_of: :staging
  has_many :staging_projects, class_name: 'Staging::StagingProject', inverse_of: :staging_workflow, dependent: :nullify,
    foreign_key: 'staging_workflow_id' do
    def without_staged_requests
      left_outer_joins(:staged_requests).where(bs_requests: { id: nil })
    end
  end

  has_many :target_of_bs_requests, through: :project, foreign_key: 'staging_workflow_id' do
    def stageable
      in_states(['new', 'review'])
    end

    def ready_to_stage
      in_states('new')
    end
  end

  has_many :staged_requests, class_name: 'BsRequest', through: :staging_projects

  after_create :create_staging_projects

  def unassigned_requests
    target_of_bs_requests.stageable - staged_requests - ignored_requests
  end

  def ready_requests
    target_of_bs_requests.ready_to_stage - staged_requests - ignored_requests
  end

  def ignored_requests
    BsRequest.none # TODO: define this method
  end

  private

  def create_staging_projects
    ['A', 'B'].each do |letter|
      staging_project = Staging::StagingProject.find_or_initialize_by(name: "#{project.name}:Staging:#{letter}")
      next if staging_project.staging_workflow # if it belongs to another staging workflow skip it
      staging_project.staging_workflow = self
      staging_project.store
    end
  end
end

class Staging::Workflow < ApplicationRecord
  def self.table_name_prefix
    'staging_'
  end

  include CanRenderModel

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
    target_of_bs_requests.stageable.where.not(id: ignored_requests | staged_requests)
  end

  def ready_requests
    target_of_bs_requests.ready_to_stage.where.not(id: ignored_requests | staged_requests)
  end

  def ignored_requests
    BsRequest.none # TODO: define this method
  end

  def write_to_backend
    return unless CONFIG['global_write_through']

    Backend::Api::Sources::Project.write_staging_workflow(project.name, User.current_login, render_xml)
  end

  private

  def create_staging_projects
    ['A', 'B'].each do |letter|
      parent = Project.find_or_initialize_by(name: "#{project.name}:Staging:#{letter}")
      staging_project = parent.becomes(Staging::StagingProject)
      next if staging_project.staging_workflow # if it belongs to another staging workflow skip it
      staging_project.staging_workflow = self
      staging_project.store
    end
  end
end

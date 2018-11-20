class Staging::Workflow < ApplicationRecord
  def self.table_name_prefix
    'staging_'
  end

  include CanRenderModel

  belongs_to :project, inverse_of: :staging
  belongs_to :managers_group, class_name: 'Group'

  has_many :staging_projects, class_name: 'Staging::StagingProject', inverse_of: :staging_workflow, dependent: :nullify,
                              foreign_key: 'staging_workflow_id' do
    def without_staged_requests
      left_outer_joins(:staged_requests).where(bs_requests: { id: nil })
    end
  end

  has_many :target_of_bs_requests, through: :project, foreign_key: 'staging_workflow_id' do
    def stageable
      managers_group_title = proxy_association.owner.managers_group.try(:title)
      includes(:reviews).where(state: :review, reviews: { state: :new, by_group: managers_group_title })
    end

    def ready_to_stage
      in_states('new')
    end
  end

  has_many :staged_requests, class_name: 'BsRequest', through: :staging_projects
  has_many :request_exclusions, class_name: 'Staging::RequestExclusion', foreign_key: 'staging_workflow_id', dependent: :destroy
  has_many :excluded_requests, through: :request_exclusions, source: :bs_request

  validates :managers_group, presence: true

  after_create :create_staging_projects
  before_update :update_staging_projects_managers_group

  def unassigned_requests
    target_of_bs_requests.stageable.where.not(id: excluded_requests)
  end

  def ready_requests
    target_of_bs_requests.ready_to_stage.where.not(id: excluded_requests)
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

  def update_staging_projects_managers_group
    return unless changes[:managers_group_id]

    old_managers_group = Group.find(changes[:managers_group_id].first)
    new_managers_group = managers_group

    staging_projects.each do |staging_project|
      staging_project.unassign_managers_group(old_managers_group)
      staging_project.assign_managers_group(new_managers_group)
      staging_project.store
    end

    # FIXME: This assignation is need because after store a staging_project
    # the object is reloaded and we lost the changes.
    self.managers_group = new_managers_group
  end
end

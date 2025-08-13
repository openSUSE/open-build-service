class Staging::Workflow < ApplicationRecord
  def self.table_name_prefix
    'staging_'
  end

  include CanRenderModel

  belongs_to :project, inverse_of: :staging
  belongs_to :managers_group, class_name: 'Group'

  has_many :staging_projects, class_name: 'Project', inverse_of: :staging_workflow, dependent: :nullify,
                              foreign_key: 'staging_workflow_id' do
    def without_staged_requests
      left_outer_joins(:staged_requests).where(bs_requests: { id: nil })
    end
  end

  has_many :target_of_bs_requests, through: :project, foreign_key: 'staging_workflow_id' do
    def stageable(managers_group_title = nil)
      managers_group_title ||= proxy_association.owner.managers_group.try(:title)
      includes(:reviews).where(state: :review, staging_project_id: nil, reviews: { state: :new, by_group: managers_group_title })
    end
  end

  has_many :staged_requests, class_name: 'BsRequest', through: :staging_projects
  has_many :request_exclusions, class_name: 'Staging::RequestExclusion', foreign_key: 'staging_workflow_id', dependent: :destroy
  has_many :excluded_requests, through: :request_exclusions, source: :bs_request

  after_create :create_staging_projects
  after_create :add_reviewer_group
  before_update :update_managers_group

  attr_accessor :commit_user

  after_initialize do
    @commit_user = User.session
  end

  def unassigned_requests
    target_of_bs_requests.stageable.where.not(id: excluded_requests)
  end

  def ready_requests
    target_of_bs_requests.where(state: :new).where.not(id: excluded_requests)
  end

  def write_to_backend
    raise ArgumentError, 'no commit user set' unless commit_user
    return unless CONFIG['global_write_through']

    Backend::Api::Sources::Project.write_staging_workflow(project.name, commit_user.login, render_xml)
  end

  def self.load_groups
    # as it is not expected that there are many groups (~30) we cache all of them. Otherwise use this instead:
    # group_ids = Review.where(bs_request: BsRequest.where(staging_project: @staging_projects)).select('group_id').distinct
    # Group.where(id: group_ids).each do |group|
    #
    # TODO: Refactor this code using to_h when updating to Ruby 2.6 (performance improvement)
    Rails.cache.fetch("groups_hash_#{Group.all.cache_key_with_version}") do
      groups_hash = {}
      Group.find_each do |group|
        groups_hash[group.title] = group
      end
      groups_hash
    end
  end

  def self.load_users(staging_projects)
    # TODO: Refactor this code using to_h when updating to Ruby 2.6 (performance improvement)
    users_hash = {}
    user_ids = Review.where(bs_request: BsRequest.where(staging_project: staging_projects)).select('user_id').distinct
    User.where(id: user_ids).find_each do |user|
      users_hash[user.login] = user
    end
    users_hash
  end

  def autocomplete(num)
    unassigned_requests.where('CAST(bs_requests.number AS CHAR) LIKE ?', "%#{num}%")
  end

  private

  def create_staging_projects
    raise ArgumentError, 'no commit user set' unless commit_user

    %w[A B].each do |letter|
      staging_project = Project.find_or_initialize_by(name: "#{project.name}:Staging:#{letter}")
      next if staging_project.staging_workflow # if it belongs to another staging workflow skip it

      staging_project.staging_workflow = self
      staging_project.commit_user = commit_user
      staging_project.store
    end
  end

  def add_reviewer_group
    role = Role.find_by_title('reviewer')
    project.relationships.find_or_create_by(group: managers_group, role: role)
    project.commit_user = commit_user
    project.store
  end

  def update_managers_group
    return unless changes[:managers_group_id]

    old_managers_group = Group.find(changes[:managers_group_id].first)
    new_managers_group = managers_group

    # update reviewer group in backlog requests
    target_of_bs_requests.stageable(old_managers_group.title).each do |bs_request|
      bs_request.addreview(by_group: new_managers_group.title, comment: 'Staging manager group changed')
      bs_request.change_review_state(:accepted, by_group: old_managers_group.title, comment: 'Staging manager group changed')
    end

    # update managers group in staging projects
    staging_projects.each do |staging_project|
      staging_project.unassign_managers_group(old_managers_group)
      staging_project.assign_managers_group(new_managers_group)
      staging_project.store
    end

    # FIXME: This assignation is need because after store a staging_project
    # the object is reloaded and we lost the changes.
    self.managers_group = new_managers_group

    reviewer_role = Role.find_by_title('reviewer')
    project.relationships.find_by(group: old_managers_group, role: reviewer_role)&.destroy   # Remove reviewer role for old managers group
    project.relationships.find_or_create_by!(group: new_managers_group, role: reviewer_role) # Add reviewer role for new managers group

    project.store
  end
end
# == Schema Information
#
# Table name: staging_workflows
#
#  id                :integer          not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  managers_group_id :integer          indexed
#  project_id        :integer          indexed
#
# Indexes
#
#  index_staging_workflows_on_managers_group_id  (managers_group_id)
#  index_staging_workflows_on_project_id         (project_id) UNIQUE
#

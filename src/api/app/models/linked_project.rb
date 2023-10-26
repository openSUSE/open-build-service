class LinkedProject < ApplicationRecord
  belongs_to :project, foreign_key: :db_project_id
  belongs_to :linked_db_project, class_name: 'Project', optional: true

  validates :linked_db_project, presence: true, unless: -> { linked_remote_project_name.present? }
  validates :linked_remote_project_name, presence: true, unless: -> { linked_db_project.present? }
  validates :linked_remote_project_name, length: { maximum: 255 }
  validates :db_project_id, uniqueness: {
    scope: :linked_db_project_id,
    if: -> { linked_db_project_id.present? },
    message: ->(object, _data) { "already linked with '#{object.linked_db_project}'" },
    on: :create
  }
  validates :db_project_id, uniqueness: {
    scope: :linked_remote_project_name,
    if: -> { linked_remote_project_name.present? },
    message: ->(object, _data) { "already linked with '#{object.linked_remote_project_name}'" },
    on: :create
  }
  validate :validate_target
  validate :validate_cycles
  validate :validate_access_flag_equality

  scope :local, -> { where.not(linked_db_project: nil) }

  protected

  def validate_target
    return unless linked_db_project && linked_remote_project_name

    errors.add(:base, 'can not have both linked_db_project and linked_remote_project_name')
  end

  def validate_cycles
    return unless linked_db_project

    all_linked_projects = Project.find_by(id: linked_db_project)&.expand_all_projects(project_map: {}, allow_remote_projects: false)
    return unless all_linked_projects&.include?(project)

    errors.add(:base, "The link target '#{linked_db_project}' links to a project that links to us, cycles are not allowed")
  end

  def validate_access_flag_equality
    return unless linked_db_project

    linked_project_access_disabled = linked_db_project.disabled_for?('access', nil, nil)
    return unless linked_project_access_disabled

    project_access_disabled = project.disabled_for?('access', nil, nil)
    return if linked_project_access_disabled == project_access_disabled

    errors.add(:base, "The link target '#{linked_db_project}' needs to have the same read access protection level")
  end
end

# == Schema Information
#
# Table name: linked_projects
#
#  id                         :integer          not null, primary key
#  linked_remote_project_name :string(255)
#  position                   :integer
#  vrevmode                   :string           default("standard")
#  db_project_id              :integer          not null, indexed => [linked_db_project_id]
#  linked_db_project_id       :integer          indexed => [db_project_id]
#
# Indexes
#
#  linked_projects_index  (db_project_id,linked_db_project_id) UNIQUE
#

# typed: false
class Status::Report < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :checkable, polymorphic: true
  has_many :checks, class_name: 'Status::Check', dependent: :destroy, foreign_key: 'status_reports_id'

  #### Callbacks macros: before_save, after_save, etc.
  after_initialize :set_request_uuid, if: proc { |record| record.checkable.is_a?(BsRequest) }

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :checkable, presence: true
  validates :uuid, presence: true

  validates_each :checkable do |record, attr, value|
    record.errors.add(attr, "invalid class #{value.class}") unless %w[BsRequest Repository RepositoryArchitecture].include?(value.class.to_s)
  end

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  def set_request_uuid
    self.uuid = checkable.number
  end

  def missing_checks
    checkable.required_checks - checks.pluck(:name)
  end

  def projects
    case checkable
    when BsRequest
      checkable.bs_request_actions.map(&:target_project_object).flatten
    when Repository
      [checkable.project]
    when RepositoryArchitecture
      [checkable.repository.project]
    end
  end

  # TODO: prefer duck typing - also for above
  def notify_params
    case checkable
    when BsRequest
      { number: checkable.number }
    when Repository
      { project: checkable.project.name, repo: checkable.name, buildid: uuid }
    when RepositoryArchitecture
      { project: checkable.repository.project.name, repo: checkable.repository.name, arch: checkable.architecture.name, buildid: uuid }
    end
  end

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

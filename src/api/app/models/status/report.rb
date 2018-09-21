class Status::Report < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :checkable, polymorphic: true
  has_many :checks, class_name: 'Status::Check', dependent: :destroy, foreign_key: 'status_reports_id'

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :checkable, presence: true
  validates :uuid, presence: true, if: proc { |record| record.checkable.is_a?(Repository) }

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  def missing_checks
    checkable.required_checks - checks.pluck(:name)
  end

  def projects
    case checkable
    when BsRequest
      checkable.bs_request_actions.map(&:target_project_object).flatten
    when Repository
      [checkable.project]
    else
      []
    end
  end

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

class Status::RepositoryPublish < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes
  validates :repository, :build_id, presence: true

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :repository
  has_many :checks, as: :checkable, dependent: :destroy
  has_one :project, through: :repository
  has_many :relationships, through: :project
  has_many :groups, through: :relationships
  has_many :groups_users, through: :groups

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def missing_checks
    repository.required_checks - checks.pluck(:name)
  end

  #### Alias of methods
end

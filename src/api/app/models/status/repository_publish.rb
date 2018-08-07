# TODO: Please overwrite this comment with something explaining the model target
class Status::RepositoryPublish < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes
  validates :repository, :build_id, presence: true

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :repository
  has_many :checks, as: :checkable, dependent: :destroy

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

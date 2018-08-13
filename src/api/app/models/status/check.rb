# TODO: Please overwrite this comment with something explaining the model target
class Status::Check < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes
  validates :state, :name, :checkable, presence: true
  validates :state, inclusion: { in: %w[pending error failure success] }

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :checkable, polymorphic: true

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

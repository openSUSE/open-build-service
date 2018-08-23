class Announcement < ApplicationRecord
  DEFAULT_RENDER_PARAMS = { only: [:id, :content, :title], dasherize: true, skip_types: true, skip_instruct: true }.freeze
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  has_and_belongs_to_many :users

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)
  default_scope { order(:created_at) }

  #### Validations macros

  validates :title, :content, presence: true
  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

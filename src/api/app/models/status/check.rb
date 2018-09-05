# TODO: Please overwrite this comment with something explaining the model target
class Status::Check < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes
  validates :state, :name, :checkable, presence: true
  # TODO: This should be an ENUM
  validates :state, inclusion: { in: %w[pending error failure success] }
  validates :name, uniqueness: { scope: :checkable }

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :checkable, polymorphic: true

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def required?
    # TODO: we will remove the checkable polymorphic Association
    # in a follow up refactoring and this will be then
    # report.checkable.required_checks.include?(name)
    checkable.repository.required_checks.include?(name)
  end

  #### Alias of methods
end

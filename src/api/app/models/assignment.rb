# TODO: Please overwrite this comment with something explaining the model target
class Assignment < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :assignee, class_name: 'User', optional: false
  belongs_to :assigner, class_name: 'User', optional: false
  belongs_to :package, optional: false

  #### Callbacks macros: before_save, after_save, etc.
  after_create :create_event

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validate :assignee do
    errors.add(:assignee, 'must be in confirmed state') unless assignee.state == 'confirmed'
  end
  validates :package, uniqueness: true

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
  private

  def create_event
    Event::Assignment.create(event_parameters)
  end

  def event_parameters
    { id: id, assignee: assignee.login, assigner: assigner.login, project: package.project.name, package: package.name }
  end
end

# == Schema Information
#
# Table name: assignments
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  assignee_id :integer          not null, indexed
#  assigner_id :integer          not null, indexed
#  package_id  :integer          not null, indexed
#
# Indexes
#
#  index_assignments_on_assignee_id  (assignee_id)
#  index_assignments_on_assigner_id  (assigner_id)
#  index_assignments_on_package_id   (package_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (assigner_id => users.id)
#  fk_rails_...  (package_id => packages.id)
#

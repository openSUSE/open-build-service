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
  after_create :trigger_event_on_creation
  before_destroy :trigger_event_on_deletion

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validate :assignee do
    errors.add(:assignee, 'must be in confirmed state') unless assignee && assignee.state == 'confirmed'
    errors.add(:assignee, 'must have the role maintainer, bugowner, reviewer on the project or package') unless assignee_has_required_role_to_be_assigned?
  end
  validates :package, uniqueness: true

  #### Instance methods (public and then protected/private)

  private

  def assignee_has_required_role_to_be_assigned?
    return false if assignee.nil?

    (package.relationships.joins(:role).where(roles: { title: %w[maintainer bugowner
                                                                 reviewer] }).where(user_id: assignee) + package.project.relationships.joins(:role).where(roles: { title: %w[maintainer bugowner
                                                                                                                                                                             reviewer] }).where(user_id: assignee)).any?
  end

  def trigger_event_on_creation
    Event::AssignmentCreate.create(event_parameters)
  end

  def trigger_event_on_deletion
    Event::AssignmentDelete.create(event_parameters)
  end

  def event_parameters
    { id: id, assignee: assignee.login, who: assigner.login, project: package.project.name, package: package.name }
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
#  package_id  :integer          not null, uniquely indexed
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

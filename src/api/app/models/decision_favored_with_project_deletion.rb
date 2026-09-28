class DecisionFavoredWithProjectDeletion < Decision
  validate :check_reportable_type
  validate :project_can_be_deleted, if: -> { errors[:reportable_type].empty? }

  after_create :create_event
  after_create :delete_project

  def description
    'The moderator decided to favor the report and initiated the project deletion'
  end

  def self.display_name
    'favor and delete the project'
  end

  def self.display?(reportable)
    return false unless reportable.is_a?(Project)

    true
  end

  def deletes_target_record?
    true
  end

  def delete_project
    reports.first.reportable.destroy
  end

  private

  def check_reportable_type
    return if reports.first.reportable.is_a?(Project)

    errors.add(:reportable_type, 'The reportable must be a project for this decision type.')
  end

  def project_can_be_deleted
    project = reports.first.reportable
    return if project.check_weak_dependencies?

    errors.add(:base, "The project can't be removed: #{project.errors.full_messages.to_sentence}")
  end

  def create_event
    Event::FavoredDecision.create(event_parameters)
  end
end

# == Schema Information
#
# Table name: decisions
#
#  id           :bigint           not null, primary key
#  reason       :text(65535)      not null
#  type         :string(255)      default("DecisionCleared"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  moderator_id :integer          not null, indexed
#
# Indexes
#
#  index_decisions_on_moderator_id  (moderator_id)
#
# Foreign Keys
#
#  fk_rails_...  (moderator_id => users.id)

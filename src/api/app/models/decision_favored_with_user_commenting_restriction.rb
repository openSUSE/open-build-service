class DecisionFavoredWithUserCommentingRestriction < Decision
  after_create :create_event
  after_create :block_user

  # TODO: Add who the user is
  def description
    'The moderator decided to favor the report and apply user commenting restrictions'
  end

  def self.display_name
    'favor and apply user commenting restrictions'
  end

  def self.display?(reportable)
    return false unless reportable.is_a?(Comment)
    return false if reportable.user.censored

    true
  end

  private

  def create_event
    Event::FavoredDecision.create(event_parameters)
  end

  def block_user
    reports.first.reportable.user.update(censored: true)
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
#

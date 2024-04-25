class DecisionFavoredWithUserCommentingRestriction < Decision
  after_create :create_event
  after_create :block_user

  # TODO: Add who the user is
  def description
    'The moderator decided to favor the report and apply user commenting restrictions'
  end

  def self.display_name
    'favored with applying user commenting restrictions'
  end

  def self.display?(reportable)
    return false unless reportable.is_a?(Comment)
    return false if reportable.user.blocked_from_commenting

    true
  end

  private

  def create_event
    Event::FavoredDecision.create(event_parameters)
  end

  def block_user
    reports.first.reportable.user.update(blocked_from_commenting: true)
  end
end

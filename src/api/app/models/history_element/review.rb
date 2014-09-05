class HistoryElement::Review < ::HistoryElement::Base
  self.description = 'Review was updated'
  self.abstract_class = true

  def review
    Review.find_by_id(self.op_object_id)
  end

  def request
    Review.find_by_id(self.op_object_id).bs_request
  end

  def review=(review)
    self.op_object_id = review.id
  end

  def render_xml(builder)
    attributes = {who: User.find_by_id(self.user_id).login, when: self.created_at.strftime('%Y-%m-%dT%H:%M:%S')}
    builder.history(attributes) do
      builder.description! self.description
      builder.comment! self.comment unless self.comment.blank?
    end
  end
end

class HistoryElement::ReviewAccepted < HistoryElement::Review
  def description
    'Review got accepted'
  end
end

class HistoryElement::ReviewDeclined < HistoryElement::Review
  def description
    'Review got declined'
  end
end

class HistoryElement::ReviewReopened < HistoryElement::Review
  def description
    'Review got reopened'
  end
end


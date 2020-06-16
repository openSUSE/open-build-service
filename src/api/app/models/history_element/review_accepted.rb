module HistoryElement
  class ReviewAccepted < HistoryElement::Review
    def description
      'Review got accepted'
    end

    def user_action
      'accepted review'
    end
  end
end

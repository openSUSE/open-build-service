module HistoryElement
  class ReviewAssigned < HistoryElement::Review
    def description
      'Review got assigned'
    end

    def user_action
      'assigned review'
    end
  end
end

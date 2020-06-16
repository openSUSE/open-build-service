module HistoryElement
  class ReviewObsoleted < HistoryElement::Review
    def description
      'Review got obsoleted'
    end

    def user_action
      'obsoleted review'
    end
  end
end

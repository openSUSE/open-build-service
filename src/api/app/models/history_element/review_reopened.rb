module HistoryElement
  class ReviewReopened < HistoryElement::Review
    def description
      'Review got reopened'
    end

    def user_action
      'reopened review'
    end
  end
end

module HistoryElement
  class ReviewDeclined < HistoryElement::Review
    def description
      'Review got declined'
    end

    def user_action
      'declined review'
    end
  end
end

module HistoryElement
  class RequestAllReviewsApproved < HistoryElement::Request
    def color
      'green'
    end

    def description
      'Request got reviewed'
    end

    def user_action
      'approved review'
    end
  end
end

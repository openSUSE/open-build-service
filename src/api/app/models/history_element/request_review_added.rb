module HistoryElement
  class RequestReviewAdded < HistoryElement::Request
    # self.description_extension is review id
    def description
      'Request got a new review request'
    end

    def user_action
      'added review'
    end
  end
end

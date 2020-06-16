module HistoryElement
  class RequestAccepted < HistoryElement::Request
    def color
      'green'
    end

    def description
      'Request got accepted'
    end

    def user_action
      'accepted request'
    end
  end
end

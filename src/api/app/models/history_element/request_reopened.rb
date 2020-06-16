module HistoryElement
  class RequestReopened < HistoryElement::Request
    def color
      'maroon'
    end

    def description
      'Request got reopened'
    end

    def user_action
      'reopened request'
    end
  end
end

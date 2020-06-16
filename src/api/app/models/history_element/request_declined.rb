module HistoryElement
  class RequestDeclined < HistoryElement::Request
    def color
      'maroon'
    end

    def description
      'Request got declined'
    end

    def user_action
      'declined request'
    end
  end
end

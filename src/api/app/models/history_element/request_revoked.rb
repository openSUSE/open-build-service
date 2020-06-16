module HistoryElement
  class RequestRevoked < HistoryElement::Request
    def color
      'orange'
    end

    def description
      'Request got revoked'
    end

    def user_action
      'revoked request'
    end
  end
end

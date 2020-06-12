module HistoryElement
  class RequestDeleted < HistoryElement::Request
    def color
      'red'
    end

    def description
      'Request was deleted'
    end

    def user_action
      'deleted request'
    end
  end
end

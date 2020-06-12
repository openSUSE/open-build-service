module HistoryElement
  class RequestPriorityChange < HistoryElement::Request
    def color
      'black'
    end

    def description
      'Request got a new priority: ' + description_extension
    end

    def user_action
      "changed priority to #{description_extension}"
    end
  end
end

module HistoryElement
  class RequestSetIncident < HistoryElement::Request
    def color
      'black'
    end

    def description
      'Maintenance target got moved to project ' + description_extension
    end

    def user_action
      "moved maintenance target to #{description_extension}"
    end
  end
end

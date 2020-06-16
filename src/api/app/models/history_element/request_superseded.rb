module HistoryElement
  class RequestSuperseded < HistoryElement::Request
    def color
      'green'
    end

    def description
      desc = 'Request got superseded'
      desc << ' by request ' << description_extension if description_extension
      desc
    end

    def user_action
      'superseded request'
    end

    def initialize(a)
      super
    end
  end
end

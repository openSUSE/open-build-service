module Event
  class StatusCheck < Base
    self.abstract_class = true
    payload_keys :who, :name, :short_description, :state, :url

    def originator
      payload_address('who')
    end
  end
end

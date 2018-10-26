module Event
  class StatusCheckForRequest < StatusCheck
    payload_keys :number

    def self.message_bus_routing_key
      'request.status_report'
    end
  end
end

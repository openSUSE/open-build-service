# typed: strict
module Event
  class StatusCheckForRequest < StatusCheck
    self.message_bus_routing_key = 'request.status_report'
    payload_keys :number
  end
end

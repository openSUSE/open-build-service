# typed: strict
module Event
  class StatusCheckForPublished < StatusCheck
    self.message_bus_routing_key = 'published.status_report'
    self.description = 'Status Check for Published Repository Created'
    payload_keys :project, :repo, :buildid
  end
end

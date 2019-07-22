# typed: strict
module Event
  class StatusCheckForBuild < StatusCheck
    self.message_bus_routing_key = 'repo.status_report'
    self.description = 'Status Check for Finished Repository Created'
    payload_keys :project, :repo, :arch, :buildid
  end
end

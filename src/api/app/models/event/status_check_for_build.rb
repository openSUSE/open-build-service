module Event
  class StatusCheckForBuild < StatusCheck
    self.description = 'Status Check for Finished Repository Created'
    payload_keys :project, :repo, :arch, :buildid

    def self.message_bus_routing_key
      'repo.status_report'
    end
  end
end

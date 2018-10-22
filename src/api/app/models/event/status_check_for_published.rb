module Event
  class StatusCheckForPublished < StatusCheck
    self.description = 'Status Check for Published Repository Created'
    payload_keys :project, :repository, :uuid
  end
end

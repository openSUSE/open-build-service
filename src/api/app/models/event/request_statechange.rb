class Event::RequestStatechange < Event::Request
  self.description = 'Request state was changed'
  payload_keys :oldstate
  receiver_roles :source_maintainer, :target_maintainer, :creator, :reviewer, :source_watcher, :target_watcher
  after_create_commit :send_to_bus

  def self.message_bus_routing_key
    "#{Configuration.amqp_namespace}.request.state_change"
  end

  def subject
    "Request #{payload['number']} changed to #{payload['state']} (#{actions_summary})"
  end
end

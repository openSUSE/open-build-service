module Event
  class UndeleteProject < Project
    self.description = 'Project was undeleted'
    payload_keys :comment, :sender
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.undelete"
    end
  end
end

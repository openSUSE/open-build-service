module Event
  class DeleteProject < Project
    self.description = 'Project was deleted'
    payload_keys :comment, :requestid, :sender
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.delete"
    end
  end
end

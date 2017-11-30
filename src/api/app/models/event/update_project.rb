module Event
  class UpdateProject < Project
    self.description = 'Project meta was updated'
    payload_keys :sender
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.update"
    end
  end
end

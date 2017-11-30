module Event
  class CreateProject < Project
    self.description = 'Project is created'
    payload_keys :sender
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.create"
    end

    def subject
      "New Project #{payload['project']}"
    end
  end
end

module Event
  class CreatePackage < Package
    self.description = 'Package was created'
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.create"
    end

    def subject
      "New Package #{payload['project']}/#{payload['package']}"
    end
  end
end

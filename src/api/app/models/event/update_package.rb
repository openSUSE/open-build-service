module Event
  class UpdatePackage < Package
    self.description = 'Package meta data was updated'
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.update"
    end
  end
end

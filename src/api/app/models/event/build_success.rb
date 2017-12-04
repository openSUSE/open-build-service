module Event
  class BuildSuccess < Build
    self.description = 'Package has succeeded building'
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.build_success"
    end
  end
end

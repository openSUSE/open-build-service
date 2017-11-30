module Event
  class Upload < Package
    self.description = 'Package sources were uploaded'
    payload_keys :project, :package, :comment, :filename, :requestid, :target, :user
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.upload"
    end
  end
end

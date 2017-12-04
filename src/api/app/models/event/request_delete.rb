module Event
  class RequestDelete < Request
    self.description = 'Request was deleted (admin only)'
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.request.delete"
    end
  end
end

module Event
  class RequestChange < Request
    self.description = 'Request XML was updated (admin only)'
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.request.change"
    end
  end
end

module Event
  class DeletePackage < Package
    self.description = 'Package was deleted'
    payload_keys :comment, :requestid
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.delete"
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
      super(attribs, keys)
    end
  end
end

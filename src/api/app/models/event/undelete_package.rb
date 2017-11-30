module Event
  class UndeletePackage < Package
    self.description = 'Package was undeleted'
    payload_keys :comment
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.undelete"
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
      super(attribs, keys)
    end
    create_jobs :update_backend_infos_job
  end
end

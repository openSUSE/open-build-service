module Event
  class VersionChange < Package
    self.description = 'Package has changed its version'
    payload_keys :comment, :requestid, :files, :rev, :newversion, :user, :oldversion
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.version_change"
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
      attribs['files'] = attribs['files'][0..800] unless attribs['files'].blank?
      super(attribs, keys)
    end
  end
end

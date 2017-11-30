module Event
  class Commit < Package
    self.description = 'New revision of a package was commited'
    payload_keys :project, :package, :comment, :user, :files, :rev, :requestid

    create_jobs :update_backend_infos_job
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.commit"
    end

    def subject
      "#{payload['project']}/#{payload['package']} r#{payload['rev']} commited"
    end

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
      attribs['files'] = attribs['files'][0..800] unless attribs['files'].blank?
      super(attribs, keys)
    end
  end
end

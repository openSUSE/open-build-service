module Event
  class ServiceFail < Package
    self.description = 'Package source service has failed'
    payload_keys :comment, :error, :package, :project, :rev, :user, :requestid
    receiver_roles :maintainer, :bugowner
    create_jobs :update_backend_infos_job
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.service_fail"
    end

    def subject
      "Source service failure of #{payload['project']}/#{payload['package']}"
    end

    def custom_headers
      h = super
      h['X-OBS-Package'] = "#{payload['project']}/#{payload['package']}"
      h
    end

    def set_payload(attribs, keys)
      # limit the error string
      attribs['error'] = attribs['error'][0..800]
      super(attribs, keys)
    end
  end
end

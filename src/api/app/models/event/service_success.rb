module Event
  class ServiceSuccess < Package
    self.description = 'Package source service has succeeded'
    payload_keys :comment, :package, :project, :rev, :user, :requestid
    receiver_roles :maintainer, :bugowner
    create_jobs :update_backend_infos_job
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.service_success"
    end

    def subject
      "Source service succeeded of #{payload['project']}/#{payload['package']}"
    end

    def custom_headers
      h = super
      h['X-OBS-Package'] = "#{payload['project']}/#{payload['package']}"
      h
    end
  end
end

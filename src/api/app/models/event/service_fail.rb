module Event
  class ServiceFail < Base
    self.description = 'Package source service has failed'
    payload_keys :project, :package, :sender, :comment, :error, :rev, :user, :requestid
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

# == Schema Information
#
# Table name: events
#
#  id             :integer          not null, primary key
#  eventtype      :string(255)      not null, indexed
#  payload        :text(16777215)
#  created_at     :datetime         indexed
#  updated_at     :datetime
#  project_logged :boolean          default(FALSE), indexed
#  undone_jobs    :integer          default(0)
#  mails_sent     :boolean          default(FALSE), indexed
#
# Indexes
#
#  index_events_on_created_at      (created_at)
#  index_events_on_eventtype       (eventtype)
#  index_events_on_mails_sent      (mails_sent)
#  index_events_on_project_logged  (project_logged)
#

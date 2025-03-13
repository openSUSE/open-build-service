module Event
  class ServiceFail < Base
    include EventObjectPackage

    self.message_bus_routing_key = 'package.service_fail'
    self.description = 'Package source service failed'
    payload_keys :project, :package, :sender, :comment, :error, :rev, :user, :requestid
    receiver_roles :maintainer, :bugowner
    create_jobs :update_backend_infos_job

    self.notification_explanation = 'Receive notifications for source service failures of packages for which you are...'

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
      super
    end

    def metric_measurement
      'service'
    end

    def metric_tags
      error = case payload['error']
              when /^bad link:/
                'bad_link'
              when /^ 400 remote error:.*.service  No such file or directory/
                'service_missing'
              when /^ 400 remote error:.*service parameter.*is not defined/
                'unknown_service_parameter'
              else
                'unknown'
              end

      {
        status: 'fail',
        error: error
      }
    end

    def metric_fields
      { value: 1 }
    end

    def involves_hidden_project?
      Project.unscoped.find_by(name: payload['project'])&.disabled_for?('access', nil, nil)
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  eventtype   :string(255)      not null, indexed
#  mails_sent  :boolean          default(FALSE), indexed
#  payload     :text(16777215)
#  undone_jobs :integer          default(0)
#  created_at  :datetime         indexed
#  updated_at  :datetime
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#

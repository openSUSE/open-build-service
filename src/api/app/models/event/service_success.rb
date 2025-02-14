module Event
  class ServiceSuccess < Base
    include EventObjectPackage

    self.message_bus_routing_key = 'package.service_success'
    self.description = 'Package source service succeeded'
    payload_keys :project, :package, :sender, :comment, :rev, :user, :requestid
    receiver_roles :maintainer, :bugowner
    create_jobs :update_backend_infos_job

    def subject
      "Source service succeeded of #{payload['project']}/#{payload['package']}"
    end

    def custom_headers
      h = super
      h['X-OBS-Package'] = "#{payload['project']}/#{payload['package']}"
      h
    end

    def metric_measurement
      'service'
    end

    def metric_tags
      {
        status: 'success'
      }
    end

    def metric_fields
      { value: 1 }
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

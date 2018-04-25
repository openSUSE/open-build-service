module Event
  class RequestStatechange < Request
    self.description = 'Request state was changed'
    payload_keys :oldstate
    receiver_roles :source_maintainer, :target_maintainer, :creator, :reviewer, :source_watcher, :target_watcher
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      'request.state_change'
    end

    def subject
      "Request #{payload['number']} changed to #{payload['state']} (#{actions_summary})"
    end

    private

    def metric_tags
      payload.slice('oldstate', 'state')
    end

    def metric_fields
      { number: payload['number'], count: BsRequest.where(state: payload['state']).count }
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :integer          not null, primary key
#  eventtype   :string(255)      not null, indexed
#  payload     :text(65535)
#  created_at  :datetime         indexed
#  updated_at  :datetime
#  undone_jobs :integer          default(0)
#  mails_sent  :boolean          default(FALSE), indexed
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#

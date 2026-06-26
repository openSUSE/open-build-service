module Event
  class RequestReviewsDone < RequestStatechange
    self.message_bus_routing_key = 'request.reviews_done'
    self.description = 'Request reviews are all done'

    def subject
      "Request #{payload['number']} fully reviewed (#{actions_summary})"
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

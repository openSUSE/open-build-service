module Event
  class StatusCheckForRequest < StatusCheck
    include EventObjectRequest

    self.message_bus_routing_key = 'request.status_report'
    payload_keys :number
  end

  def involves_hidden_project?
    bs_request = BsRequest.find_by(number: payload['number'])
    return false unless bs_request

    bs_request.involves_hidden_project?
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

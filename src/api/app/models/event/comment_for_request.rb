module Event
  class CommentForRequest < Request
    include CommentEvent
    self.message_bus_routing_key = 'request.comment'
    self.description = 'New comment for request created'
    payload_keys :request_number
    receiver_roles :source_maintainer, :target_maintainer, :creator, :reviewer, :source_watcher, :target_watcher

    def subject
      req = BsRequest.find_by_number(payload['number'])
      req_payload = req.event_parameters
      "Request #{payload['number']} commented by #{payload['commenter']} (#{BsRequest.actions_summary(req_payload)})"
    end

    def set_payload(attribs, keys)
      # limit the error string
      attribs['comment'] = attribs['comment'][0..800] if attribs['comment'].present?
      attribs['files'] = attribs['files'][0..800] if attribs['files'].present?
      super(attribs, keys)
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :integer          not null, primary key
#  eventtype   :string(255)      not null, indexed
#  mails_sent  :boolean          default(FALSE), indexed
#  payload     :text(65535)
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

module Event
  class CommentForRequest < Request
    include CommentEvent
    self.description = 'New comment for request created'
    payload_keys :request_number
    receiver_roles :source_maintainer, :target_maintainer, :creator, :reviewer, :source_watcher, :target_watcher
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.request.comment"
    end

    def subject
      req = BsRequest.find_by_number(payload['number'])
      req_payload = req.notify_parameters
      "Request #{payload['number']} commented by #{User.find(payload['commenter']).login} (#{BsRequest.actions_summary(req_payload)})"
    end

    def set_payload(attribs, keys)
      # limit the error string
      attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
      attribs['files'] = attribs['files'][0..800] unless attribs['files'].blank?
      super(attribs, keys)
    end
  end
end

module Event
  class ReviewWanted < Request
    self.description = 'Review was created'

    payload_keys :reviewers, :by_user, :by_group, :by_project, :by_package
    receiver_roles :reviewer
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.request.review_wanted"
    end

    def subject
      "Request #{payload['number']} requires review (#{actions_summary})"
    end

    def expanded_payload
      payload_with_diff
    end

    def custom_headers
      h = super
      if payload['by_user']
        h['X-OBS-Review-By_User'] = payload['by_user']
      elsif payload['by_group']
        h['X-OBS-Review-By_Group'] = payload['by_group']
      elsif payload['by_package']
        h['X-OBS-Review-By_Package'] = "#{payload['by_project']}/#{payload['by_package']}"
      else
        h['X-OBS-Review-By_Project'] = payload['by_project']
      end
      h
    end

    # for review_wanted we ignore all the other reviews
    def reviewers
      User.where(id: payload["reviewers"].map { |r| r['user_id'] }) +
          Group.where(id: payload["reviewers"].map { |r| r['group_id'] })
    end
  end
end

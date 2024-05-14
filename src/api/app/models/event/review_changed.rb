module Event
  class ReviewChanged < Request
    self.message_bus_routing_key = 'request.review_changed'
    self.description = 'Request reviewed'
    payload_keys :reviewers, :by_user, :by_group, :by_project, :by_package
    receiver_roles :source_maintainer, :target_maintainer, :creator, :source_project_watcher, :target_project_watcher

    def subject
      "Request #{payload['number']} reviewed (#{actions_summary})"
    end

    def expanded_payload
      payload_with_diff
    end

    def custom_headers
      super.merge(review_headers)
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

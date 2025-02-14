module Event
  class ReviewWanted < Request
    self.message_bus_routing_key = 'request.review_wanted'
    self.description = 'Review created'
    payload_keys :reviewers, :by_user, :by_group, :by_project, :by_package
    receiver_roles :reviewer

    self.notification_explanation = 'Receive notifications for reviews created that have you as a wanted...'

    def subject
      "Request #{payload['number']} requires review (#{actions_summary})"
    end

    def expanded_payload
      payload_with_diff
    end

    def custom_headers
      super.merge(review_headers)
    end

    # for review_wanted we ignore all the other reviews
    def reviewers
      User.where(id: payload['reviewers'].pluck('user_id')) +
        ::Group.where(id: payload['reviewers'].pluck('group_id'))
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'BsRequest', type: 'NotificationBsRequest')
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

class NotificationTokenWorkflow < Notification
  def description
    # If a notification is for a group, the notified user needs to know for which group. Otherwise, the user is simply referred to as 'you'.
    recipient = if event_payload['user_login'].present?
                  'you'
                else
                  "group '#{event_payload['group_title']}'"
                end

    token = Token::Workflow.find_by(id: event_payload['token_id'])

    if event_payload['action'] == 'share'
      "#{event_payload['who']} shared token '#{token.description}' with #{recipient}"
    else
      "#{event_payload['who']} removed #{recipient} from token '#{token.description}'"
    end
  end

  def excerpt
    ''
  end

  def avatar_objects
    User.where(login: event_payload['who'])
  end

  def link_text
    if event_payload['action'] == 'share'
      'Added to token'
    else
      'Removed from token'
    end
  end

  def link_path
    return unless event_payload['action'] == 'share'

    Rails.application.routes.url_helpers.token_path(event_payload['token_id'])
  end
end

# == Schema Information
#
# Table name: notifications
#
#  id                         :bigint           not null, primary key
#  bs_request_oldstate        :string(255)
#  bs_request_state           :string(255)
#  delivered                  :boolean          default(FALSE), indexed
#  event_payload              :text(16777215)   not null
#  event_type                 :string(255)      not null, indexed
#  last_seen_at               :datetime
#  notifiable_type            :string(255)      indexed => [notifiable_id]
#  rss                        :boolean          default(FALSE), indexed
#  subscriber_type            :string(255)      indexed => [subscriber_id]
#  subscription_receiver_role :string(255)      not null
#  title                      :string(255)
#  type                       :string(255)      indexed
#  web                        :boolean          default(FALSE), indexed
#  created_at                 :datetime         not null, indexed
#  updated_at                 :datetime         not null
#  notifiable_id              :integer          indexed => [notifiable_type]
#  subscriber_id              :integer          indexed => [subscriber_type]
#
# Indexes
#
#  index_notifications_on_created_at                         (created_at)
#  index_notifications_on_delivered                          (delivered)
#  index_notifications_on_event_type                         (event_type)
#  index_notifications_on_notifiable_type_and_notifiable_id  (notifiable_type,notifiable_id)
#  index_notifications_on_rss                                (rss)
#  index_notifications_on_subscriber_type_and_subscriber_id  (subscriber_type,subscriber_id)
#  index_notifications_on_type                               (type)
#  index_notifications_on_web                                (web)
#

class NotificationGroupsUser < Notification
  # TODO: rename to title once we get rid of Notification#title
  def summary
    case event_type
    when 'Event::AddedUserToGroup'
      "You got added to group '#{event_payload['group']}'"
    when 'Event::RemovedUserFromGroup'
      "You got removed from the group '#{event_payload['group']}'"
    end
  end

  def description
    case event_type
    when 'Event::AddedUserToGroup'
      "'#{event_payload['who']}' added you to the group '#{event_payload['group']}'"
    when 'Event::RemovedUserFromGroup'
      "'#{event_payload['who']}' removed you from the group '#{event_payload['group']}'"
    end
  end

  def excerpt
    ''
  end

  def involved_users
    [User.find_by(login: event_payload['who'])]
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
#  event_payload              :text(65535)      not null
#  event_type                 :string(255)      not null, indexed
#  last_seen_at               :datetime
#  notifiable_type            :string(255)      indexed => [notifiable_id]
#  rss                        :boolean          default(FALSE), indexed
#  subscriber_type            :string(255)      indexed => [subscriber_id]
#  subscription_receiver_role :string(255)      not null
#  title                      :string(255)
#  type                       :string(255)      default("NotificationProject"), not null
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
#  index_notifications_on_web                                (web)
#

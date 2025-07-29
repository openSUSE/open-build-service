class NotificationPackage < Notification
  def description
    # If a notification is for a group, the notified user needs to know for which group. Otherwise, the user is simply referred to as 'you'.
    recipient = event_payload.fetch('group', 'you')
    target_object = [event_payload['project'], event_payload['package']].compact.join(' / ')

    case event_type
    when 'Event::RelationshipCreate'
      "#{event_payload['who']} made #{recipient} #{event_payload['role']} of #{target_object}"
    when 'Event::RelationshipDelete'
      "#{event_payload['who']} removed #{recipient} as #{event_payload['role']} of #{target_object}"
    when 'Event::BuildFail'
      "Package: #{event_payload['project']} / #{event_payload['package']}
       Repository: #{event_payload['repository']} / #{event_payload['arch']}
       Reason: #{event_payload['reason']}"
    end
  end

  def excerpt
    ''
  end

  def avatar_objects
    User.where(login: event_payload['who'])
  end

  def link_text
    case event_type
    when 'Event::RelationshipCreate'
      "Added as #{event_payload['role']} of a package"
    when 'Event::RelationshipDelete'
      "Removed as #{event_payload['role']} of a package"
    when 'Event::BuildFail'
      'Package failed to build'
    end
  end

  def link_path
    if event_type == 'Event::BuildFail'
      Rails.application.routes.url_helpers.package_live_build_log_path(package: event_payload['package'], project: event_payload['project'],
                                                                       repository: event_payload['repository'], arch: event_payload['arch'],
                                                                       notification_id: id)
    else
      Rails.application.routes.url_helpers.package_users_path(event_payload['project'],
                                                              event_payload['package'],
                                                              notification_id: id)
    end
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

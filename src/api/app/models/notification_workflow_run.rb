class NotificationWorkflowRun < Notification
  def description
    ''
  end

  def excerpt
    "In repository #{notifiable.repository_full_name}"
  end

  def avatar_objects
    [Token.find(event_payload['token_id'])&.executor].compact
  end

  def link_text
    'Workflow Run'
  end

  def link_path
    return if notifiable.blank?

    Rails.application.routes.url_helpers.token_workflow_run_path(notifiable.token, notifiable, notification_id: id)
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

class NotificationBsRequest < Notification
  include NotificationRequest

  def description
    return "To #{request_target}" if request_source.blank?

    "From #{request_source} to #{request_target}"
  end

  def excerpt
    notifiable.description
  end

  def avatar_objects
    reviews = notifiable.reviews
    reviews.select(&:new?).map(&:reviewed_by) + User.where(login: notifiable.creator).compact
  end

  def link_text
    "#{request_type_of_action} Request ##{notifiable.number}"
  end

  def link_path
    Rails.application.routes.url_helpers.request_show_path(notifiable.number, notification_id: id)
  end

  def bs_request
    notifiable
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

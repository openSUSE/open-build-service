class NotificationCommentForRequest < Notification
  # TODO: rename to title after we remove the Notificiation#title column
  def summary
    "Comment on #{request_type_of_action(bs_request)} Request ##{bs_request.number}"
  end

  def excerpt
    truncate_to_first_new_line(notifiable.body) # comment body
  end

  private

  def bs_request
    return unless event_type == 'Event::CommentForRequest'

    if notifiable.commentable.is_a?(BsRequestAction)
      notifiable.commentable.bs_request
    else
      notifiable.commentable
    end
  end

  # FIXME: Duplicated from RequestHelper
  # Returns strings like "Add Role", "Submit", etc.
  def request_type_of_action(bs_request)
    return 'Multiple Actions' if bs_request.bs_request_actions.size > 1

    bs_request.bs_request_actions.first.type.titleize
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

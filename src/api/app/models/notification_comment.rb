class NotificationComment < Notification
  # TODO: rename to title once we get rid of Notification#title
  def summary
    case notifiable.commentable_type
    when 'BsRequest'
      "Comment on #{request_type_of_action(bs_request)} Request ##{bs_request.number}"
    when 'Project'
      'Comment on Project'
    when 'Package'
      'Comment on Package'
    end
  end

  def description
    case notifiable.commentable_type
    when 'BsRequest'
      "From #{request_source} to #{request_target}"
    when 'Project'
      notifiable.commentable.name
    when 'Package'
      commentable = notifiable.commentable
      "#{commentable.project.name} / #{commentable.name}"
    end
  end

  def excerpt
    notifiable.body
  end

  def involved_users
    comments = notifiable.commentable.comments
    comments.select { |comment| comment.updated_at >= unread_date }.map(&:user).uniq
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

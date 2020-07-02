class AdaptReviewAndDuplicatedNotifications < ActiveRecord::Migration[6.0]
  def up
    transform_review_notifications
    remove_outdated_notifications
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # associate the review notifications to the corresponding bs_request, since
  # they won't be treated separately anymore
  def transform_review_notifications
    Notification.where("notifiable_type = 'Review'").find_each do |notification|
      notification.update(notifiable_id: notification.notifiable.bs_request.id, notifiable_type: 'BsRequest')
    end
  end

  # only keep the latest comment and request notifications related to the same notifiable and subscriber
  def remove_outdated_notifications
    Notification.find_each do |notification|
      next if delete_notification_without_notifiable(notification)

      notifications = outdated_notifications(notification)

      notifications.destroy_all
    end
  end

  def outdated_notifications(notification)
    return fetch_comment_notifications(notification) if notification.notifiable_type == 'Comment'

    fetch_bsrequest_notifications(notification)
  end

  def fetch_comment_notifications(notification)
    notifiable = notification.notifiable
    Notification.for_web.where(notifiable_type: 'Comment', subscriber_id: notification.subscriber_id)
                .joins('JOIN comments ON notifications.notifiable_id = comments.id')
                .where(comments: { commentable_type: notifiable.commentable_type,
                                   commentable_id: notifiable.commentable_id }).order(id: :desc).offset(1)
  end

  def fetch_bsrequest_notifications(notification)
    Notification.for_web.where(notifiable_id: notification.notifiable_id,
                               notifiable_type: notification.notifiable_type,
                               subscriber_id: notification.subscriber_id).order(id: :desc).offset(1)
  end

  # make sure the notifiable exist, otherwise delete the notification since it refers to nothing
  def delete_notification_without_notifiable(notification)
    return false if notification.notifiable

    notification.destroy
    true
  end
end

class Decorators::Notification::Event::CommentForProject < Decorators::Notification::Common
  def description_text
    "#{notification.notifiable.commentable.name}"
  end

  def notifiable_link_text(_helpers)
    'Comment on Project'
  end

  def notifiable_link_path
    Rails.application.routes.url_helpers.project_show_path(notification.notifiable.commentable, notification_id: notification.id, anchor: 'comments-list')
  end
end

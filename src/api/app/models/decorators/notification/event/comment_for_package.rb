class Decorators::Notification::Event::CommentForPackage < Decorators::Notification::Common
  def description_text
    commentable = notification.notifiable.commentable
    "#{commentable.project.name} / #{commentable.name}"
  end

  def notifiable_link_text(_helpers)
    'Comment on Package'
  end

  def notifiable_link_path
    # TODO: It would be better to eager load the commentable association with `includes(...)`,
    #       but it's complicated since this isn't for all notifications and it's nested 2 levels deep.
    package = notification.notifiable.commentable
    Rails.application.routes.url_helpers.package_show_path(package: package,
                                                           project: package.project,
                                                           notification_id: notification.id,
                                                           anchor: 'comments-list')
  end
end

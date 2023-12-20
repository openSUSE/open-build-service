class Decorators::Notification::Event::CommentForPackage < Decorators::Notification::Common
  def description_text
    commentable = notification.notifiable.commentable
    "#{commentable.project.name} / #{commentable.name}"
  end

  def notifiable_link_text(_helpers)
    'Comment on Package'
  end
end

class Decorators::Notification::Event::CommentForPackage < Decorators::Notification::Common
  def description_text
    commentable = notification.notifiable.commentable
    "#{commentable.project.name} / #{commentable.name}"
  end
end

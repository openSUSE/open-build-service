class Decorators::Notification::Event::CommentForProject < Decorators::Notification::Common
  def description_text
    "#{notification.notifiable.commentable.name}"
  end
end

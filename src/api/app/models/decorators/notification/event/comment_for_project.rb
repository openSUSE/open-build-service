class Decorators::Notification::Event::CommentForProject < Decorators::Notification::Common
  def description_text
    "#{notification.notifiable.commentable.name}"
  end

  def notifiable_link_text(_helpers)
    'Comment on Project'
  end
end

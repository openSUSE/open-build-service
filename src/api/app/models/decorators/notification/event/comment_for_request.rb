class Decorators::Notification::Event::CommentForRequest < Decorators::Notification::Common
  def description_text
    bs_request = notification.notifiable.commentable
    BsRequestActionSourceAndTargetComponent.new(bs_request).call
  end
end

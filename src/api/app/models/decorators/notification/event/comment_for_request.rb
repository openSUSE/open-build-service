class Decorators::Notification::Event::CommentForRequest < Decorators::Notification::Common
  def description_text
    bs_request = notification.notifiable.commentable
    BsRequestActionSourceAndTargetComponent.new(bs_request).call
  end

  def notifiable_link_text(helpers)
    bs_request = notification.notifiable.commentable
    "Comment on #{helpers.request_type_of_action(bs_request)} Request ##{bs_request.number}"
  end

  def notifiable_link_path
    bs_request = notification.notifiable.commentable
    anchor = if notification.notifiable.commentable.is_a?(BsRequestAction)
               'tab-pane-changes'
             else
               'comments-list'
             end
    Rails.application.routes.url_helpers.request_show_path(bs_request.number, notification_id: notification.id, anchor: anchor)
  end
end

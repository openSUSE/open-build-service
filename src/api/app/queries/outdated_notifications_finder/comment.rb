# This class gets the associated comment from the notification and then
# tries to return all the notifications from the sibling comments.
class OutdatedNotificationsFinder::Comment
  def initialize(scope, parameters)
    @scope = scope
    @parameters = parameters
    @notifiable_id = parameters&.dig(:notifiable_id)
  end

  def call
    return [] unless @notifiable_id

    comment = Comment.find(@notifiable_id)
    @scope
      .joins('JOIN comments ON notifications.notifiable_id = comments.id')
      .where(notifiable_type: 'Comment')
      .where(comments: { commentable_type: comment.commentable_type,
                         commentable_id: comment.commentable_id })
  end
end

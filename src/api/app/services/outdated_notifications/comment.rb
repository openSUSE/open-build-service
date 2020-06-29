class OutdatedNotifications::Comment
  def initialize(scope, notifiable)
    @scope = scope
    @notifiable = notifiable
  end

  def call
    scope
      .join(:comments)
      .where(notifiable_type: 'Comment')
      .where(comments: { commentable_type: @notifiable.commentable_type,
                         commentable_id: @notifiable.commentable_id })
  end
end

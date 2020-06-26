class OutdatedCommentNotificationsCollector
  def initialize(scope, subscriber)
    @scope = scope
    @subscriber = subscriber
  end

  def collect
    scope
      .where(notifiable_type: 'Comment')
      .where(subscriber_id: @subscriber.id)
  end
end

class OutdatedRequestNotificationsCollector
  def initialize(scope, subscriber)
    @scope = scope
    @subscriber = subscriber
  end

  def collect
    @scope
      .where(notifiable_type: 'BsRequest')
      .where(subscriber_id: @subscriber.id)
  end
end

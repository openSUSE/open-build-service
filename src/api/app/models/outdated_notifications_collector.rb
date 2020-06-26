class OutdatedNotificationsCollector
  COLLECTORS = [OutdatedCommentNotificationsCollector,
                OutdatedRequestNotificationsCollector]

  def initialize(scope, subscriber)
    @scope = scope
    @subscriber = subscriber
  end
  
  def collect
    COLLECTORS.map { |collector_class| collector_class.new(@scope, @subscriber).collect }.flatten
  end
end

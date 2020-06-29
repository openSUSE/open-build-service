class OutdatedNotificationsCollector
  COLLECTORS = [OutdatedCommentNotificationsCollector,
                OutdatedRequestNotificationsCollector]

  def initialize(scope, notifiable)
    @scope = scope
    @notifiable = notifiable
  end
  
  def collect
    COLLECTORS.map { |collector_class| collector_class.new(@scope, @notifiable).collect }.flatten
  end
end

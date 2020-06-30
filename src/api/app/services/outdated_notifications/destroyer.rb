class OutdatedNotifications::Destroyer
  DESTROYABLE_NOTIFIABLES = ['BsRequest', 'Comment']

  def initialize(subscriber, notification)
    @subscriber = subscriber
    @notification = notification
  end

  def call
    return unless DESTROYABLE_NOTIFIABLES.include?(@notification.notifiable_type)

    scope = NotificationsFinder.new(@subscriber.notifications.for_web).with_notifiable
    klass = "OutdatedNotificationsFinder::#{@notification.notifiable_type}"
    klass.constantize.new(scope, @notification.notifiable).call.each(&:destroy)
  end
end

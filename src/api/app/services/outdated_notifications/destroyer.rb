class OutdatedNotifications::Destroyer
  def new(subscriber, notification)
    @subscriber = subscriber
    @notification = notification
  end

  def call
    scope = NotificationsFinder.new(@subscriber.notifications.for_web).with_notifiable
    klass = "OutdatedNotificationsFinder::#{@notification.notifiable_type}"
    klass.constantize.new(scope, @notification.notifiable).call.each(&:destroy)
  end
end

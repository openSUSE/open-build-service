# This class ensures the :web channel will have only the most up-to-date notifications
module NotificationService
  class WebChannel
    def initialize(subscription, event)
      @subscription = subscription
      @event = event
      @parameters_for_notification = @subscription.parameters_for_notification
                                                  .merge!(@event.parameters_for_notification)
    end

    def call
      # Destroy older notifications
      finder = finder_class.new(notification_scope, @parameters_for_notification)
      finder.call.destroy_all

      # Create a new, up-to-date one
      notification = Notification.create(@parameters_for_notification)
      notification.projects << NotifiedProjects.new(notification).call
      notification.update(web: true)
    end

    private

    def finder_class
      type = @parameters_for_notification[:notifiable_type]
      "OutdatedNotificationsFinder::#{type}".constantize
    end

    def notification_scope
      NotificationsFinder.new(@subscription.subscriber.notifications.for_web).with_notifiable
    end
  end
end

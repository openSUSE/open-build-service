module NotificationService
  class RSSChannel
    def initialize(subscription, event)
      @subscription = subscription
      @event = event
    end

    def call
      params = @subscription.parameters_for_notification.merge!(@event.parameters_for_notification)
      notification = Notification.find_by(params)

      unless notification
        notification = Notification.create(params)
        notification.projects << NotifiedProjects.new(notification).call
      end

      notification.update(rss: true)
    end
  end
end

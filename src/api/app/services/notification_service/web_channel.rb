# This class ensures the :web channel will have only the most up-to-date notifications
module NotificationService
  class WebChannel
    ALLOWED_FINDERS = {
      'BsRequest' => OutdatedNotificationsFinder::BsRequest,
      'Comment' => OutdatedNotificationsFinder::Comment
    }.freeze

    def initialize(subscription, event)
      @subscription = subscription
      @event = event
      @parameters_for_notification = subscription_parameters.merge(event_parameters).merge!(web: true)
    end

    def call
      return nil unless @subscription.present? && @event.present?

      # Find and delete older notifications
      finder = finder_class.new(notification_scope, @parameters_for_notification)
      outdated_notifications = finder.call
      oldest_notification = outdated_notifications.last
      outdated_notifications.destroy_all

      # Create a new, up-to-date one
      notification = Notification.create!(parameters(oldest_notification))
      notification.projects << NotifiedProjects.new(notification).call
      notification
    end

    private

    def finder_class
      ALLOWED_FINDERS[@parameters_for_notification[:notifiable_type]]
    end

    def notification_scope
      NotificationsFinder.new(@subscription.subscriber.notifications.for_web).with_notifiable
    end

    def parameters(oldest_notification)
      return @parameters_for_notification unless oldest_notification
      return @parameters_for_notification if oldest_notification.read?

      @parameters_for_notification.merge!(last_seen_at: oldest_notification.unread_date)
    end

    def subscription_parameters
      @subscription&.parameters_for_notification || {}
    end

    def event_parameters
      @event&.parameters_for_notification || {}
    end
  end
end

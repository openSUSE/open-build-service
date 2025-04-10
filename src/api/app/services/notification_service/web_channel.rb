# This class ensures the :web channel will have only the most up-to-date notifications
module NotificationService
  class WebChannel
    ALLOWED_FINDERS = {
      'BsRequest' => OutdatedNotificationsFinder::BsRequest,
      'Comment' => OutdatedNotificationsFinder::Comment,
      'Project' => OutdatedNotificationsFinder::Project,
      'Package' => OutdatedNotificationsFinder::Package,
      'Report' => OutdatedNotificationsFinder::Report,
      'Decision' => OutdatedNotificationsFinder::Decision,
      'Appeal' => OutdatedNotificationsFinder::Appeal,
      'WorkflowRun' => OutdatedNotificationsFinder::WorkflowRun,
      'Group' => OutdatedNotificationsFinder::Group
    }.freeze

    def initialize(subscription, event)
      @subscription = subscription
      @event = event
      @parameters_for_notification = subscription_parameters.merge(event_parameters).merge!(web: true)
    end

    def call
      return nil unless @subscription.present? && @event.present?

      # Create an up-to-date notification
      if @subscription.subscriber.is_a?(Group)
        # Having a single notification for a subscriber_type Group won't allow users of
        # this group to have their own notifications (like marking them as read/unread).
        # We need to create a notification for every group member.
        options = { eventtype: @subscription.eventtype, receiver_role: @subscription.receiver_role, channel: :web }
        default_subscription = EventSubscription.defaults.find_by(options)

        @subscription.subscriber.web_users.map do |user|
          next if user.blocked_users.include?(@event.originator)

          finder = finder_class.new(notification_scope(user: user), @parameters_for_notification.merge!(subscriber: user))

          renew_notification(finder: finder) if subscribed?(user, options, default_subscription)
        end
      else
        # Subscriber is a user
        finder = finder_class.new(notification_scope(user: @subscription.subscriber), @parameters_for_notification)

        [renew_notification(finder: finder)]
      end
    end

    private

    def renew_notification(finder:)
      # Find and delete older notifications
      outdated_notifications = finder.call
      oldest_notification = outdated_notifications.last
      oldest_notification_groups = oldest_notification.present? ? oldest_notification.groups.to_a : []
      outdated_notifications.destroy_all

      notification = Notification.create!(parameters(oldest_notification))
      notification.projects << NotifiedProjects.new(notification).call
      notification.groups << notification_groups(oldest_notification_groups)
      notification
    end

    def notification_groups(previous_groups)
      return previous_groups unless @subscription.subscriber.is_a?(Group)

      previous_groups | [@subscription.subscriber]
    end

    def finder_class
      ALLOWED_FINDERS[@parameters_for_notification[:notifiable_type]]
    end

    def notification_scope(user:)
      user.notifications.for_web.with_notifiable
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

    def subscribed?(user, options, default_subscription)
      # There is no filtering of subscriptions to events for individual users of the group earlier in the chain, so we are doing it here
      user_subscription = EventSubscription.for_subscriber(user).find_by(options) || default_subscription
      user != @event.originator && user_subscription.present? && user_subscription.enabled?
    end
  end
end

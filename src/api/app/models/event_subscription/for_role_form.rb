class EventSubscription
  class ForRoleForm
    attr_reader :name, :channels, :subscriber

    def initialize(role_name, event, subscriber)
      @subscriber = subscriber
      @name = role_name
      @event = event
      @channels = []
    end

    def call
      @channels = EventSubscription.without_disabled_or_internal_channels.map do |channel|
        channel_for_event_class_and_role(@event, name, channel)
      end

      self
    end

    private

    def channel_for_event_class_and_role(event_class, role, channel)
      subscription = find_subscription_for_event_class_and_role(event_class, role, channel)
      EventSubscription::ForChannelForm.new(channel, subscription, event_class)
    end

    def find_subscription_for_event_class_and_role(event_class, role, channel)
      subscriber_subscription = find_subscription_for_subscriber(event_class, role, channel)
      return subscriber_subscription if subscriber.present? && subscriber_subscription.present?

      default_subscription = find_default_subscription(event_class, role, channel)
      return default_subscription if default_subscription.present?

      EventSubscription.new(subscriber: subscriber, eventtype: event_class.to_s, receiver_role: role, channel: channel)
    end

    def find_subscription_for_subscriber(event_class, role, channel)
      subscriber_subscriptions.find { |s| s.event_class == event_class && s.receiver_role == role && s.channel == channel }
    end

    def find_default_subscription(event_class, role, channel)
      default_subscriptions.find { |s| s.event_class == event_class && s.receiver_role == role && s.channel == channel }
    end

    def subscriber_subscriptions
      @subscriber_subscriptions ||= EventSubscription.for_subscriber(subscriber)
    end

    def default_subscriptions
      @default_subscriptions ||= EventSubscription.defaults
    end
  end
end

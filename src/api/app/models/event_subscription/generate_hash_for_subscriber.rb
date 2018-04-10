# frozen_string_literal: true
class EventSubscription
  class GenerateHashForSubscriber
    attr_reader :subscriber

    def initialize(subscriber)
      @subscriber = subscriber
    end

    # Generate a hash of subscriptions for the user grouped by the subscription's event class
    def query
      event_classes = Event::Base.notification_events
      subscriptions_by_event_class = {}

      event_classes.each do |event_class|
        subscriptions_by_event_class[event_class] = event_class.receiver_roles.map do |role|
          find_subscription_for_event_class_and_role(event_class, role)
        end
      end

      subscriptions_by_event_class
    end

    private

    def find_subscription_for_event_class_and_role(event_class, role)
      subscriber_subscription = find_subscription_for_subscriber(event_class, role) || find_subscription_for_subscriber(event_class, :all)
      default_subscription = find_default_subscription(event_class, role)

      # 1. Pick the subscriber's subscription if it exists
      if subscriber.present? && subscriber_subscription.present?
        subscriber_subscription

      # 2. Pick the subscriber's subscription if it exists
      elsif default_subscription.present?
        default_subscription

      # 3. Otherwise instantiate a new subscription
      else
        EventSubscription.new(
          subscriber: subscriber,
          eventtype: event_class.to_s,
          receiver_role: role,
          channel: 'disabled'
        )
      end
    end

    def find_subscription_for_subscriber(event_class, role)
      subscriber_subscriptions.find { |s| s.event_class == event_class && s.receiver_role == role }
    end

    def find_default_subscription(event_class, role)
      default_subscriptions.find { |s| s.event_class == event_class && s.receiver_role == role }
    end

    def subscriber_subscriptions
      @subscriber_subscriptions ||= EventSubscription.for_subscriber(subscriber)
    end

    def default_subscriptions
      @default_subscriptions ||= EventSubscription.defaults
    end
  end
end

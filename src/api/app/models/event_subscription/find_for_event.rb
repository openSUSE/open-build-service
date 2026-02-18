class EventSubscription
  class FindForEvent
    attr_reader :event

    def initialize(event)
      @event = event
    end

    def subscriptions(channel = :instant_email)
      receivers_and_subscriptions = {}

      event.class.receiver_roles.each do |receiver_role|
        # Find the users/groups who are receivers for this event
        receivers_before_expand = event.send(:"#{receiver_role}s")
        next if receivers_before_expand.blank?

        receivers = expand_receivers(receivers_before_expand, channel)

        # Allow descendant events to also receive notifications if the subscription only covers the base class
        # This only supports 1 level of ancestry
        options = { eventtype: event_types, receiver_role: receiver_role, channel: channel }
        # Find the default subscription for this eventtype and receiver_role
        default_subscription = EventSubscription.defaults.find_by(options)

        receivers.each do |receiver|
          # Prevent multiple enabled subscriptions for the same subscriber & eventtype
          next if receivers_and_subscriptions[receiver].present?

          # Skip if the receiver is the originator of this event
          next if receiver == event.originator

          # Skip if the event originator is blocked by the receiver
          next if receiver.is_a?(User) && receiver.blocked_users.include?(event.originator)

          # Try to find the subscription for this receiver
          receiver_subscription = EventSubscription.for_subscriber(receiver).find_by(options)
          if receiver_subscription.present?
            # Use the receiver's subscription if it exists
            receivers_and_subscriptions[receiver] = receiver_subscription if receiver_subscription.enabled?
          # Only check the default_subscription if there is no receiver's subscription
          elsif default_subscription.present? && default_subscription.enabled?
            # Add a new subscription for the receiver based on the default subscription
            receivers_and_subscriptions[receiver] = EventSubscription.new(
              eventtype: default_subscription.eventtype,
              receiver_role: default_subscription.receiver_role,
              channel: default_subscription.channel,
              subscriber: receiver
            )
          elsif channel == :web && receiver.instance_of?(Group) && receiver.web_users.any? { |u| EventSubscription.for_subscriber(u).find_by(options).present? }
            # There is no default subscription for groups, so we are using the existing details
            # There can be only one eventtype when creating a subscription, so we use the one that came with the event
            receivers_and_subscriptions[receiver] = EventSubscription.new(options.merge({ eventtype: event.eventtype, subscriber: receiver }))
          end
        end
      end

      receivers_and_subscriptions.values.flatten
    end

    private

    def allowed_by_feature_flag?(user)
      return true if event.class.notification_feature_flag.blank?

      Flipper.enabled?(event.class.notification_feature_flag, user)
    end

    def event_types
      @event_types ||= begin
        types = [event.eventtype]
        superclass = event.class.superclass.name
        types << superclass if superclass != 'Event::Base'
        types
      end
    end

    def expand_receivers(receivers, channel)
      receivers.inject([]) do |new_receivers, receiver|
        case receiver
        when User
          new_receivers << receiver if receiver.active? && allowed_by_feature_flag?(receiver)
        when Group
          new_receivers += expand_receivers_for_groups(receiver, channel)
        end

        new_receivers
      end
    end

    def expand_receivers_for_groups(receiver, channel)
      # RSS subscriptions for groups are not supported
      return [] if channel == :rss

      # We don't split events which come through the web channel, for a group subscriber.
      # They are split in the NotificationService::WebChannel service, if needed.
      return [receiver] if channel == :web || receiver.email.present?

      receiver.email_users.select { |user| allowed_by_feature_flag?(user) }
    end
  end
end

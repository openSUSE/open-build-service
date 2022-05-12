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
        receivers = event.send("#{receiver_role}s")
        receivers = expand_receivers(receivers, channel)

        options = { eventtype: event.eventtype, receiver_role: receiver_role, channel: channel }
        # Find the default subscription for this eventtype and receiver_role
        default_subscription = EventSubscription.defaults.find_by(options)

        receivers.each do |receiver|
          # Prevent multiple enabled subscriptions for the same subscriber & eventtype
          # Also skip if the receiver is the originator of this event
          next if receivers_and_subscriptions[receiver].present? || receiver == event.originator

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
          end
        end
      end

      receivers_and_subscriptions.values.flatten
    end

    def expand_receivers(receivers, channel)
      receivers.inject([]) do |new_receivers, receiver|
        case receiver
        when User
          new_receivers << receiver if receiver.is_active?

        when Group
          new_receivers += expand_receivers_for_groups(new_receivers, receiver, channel)
        end

        new_receivers
      end
    end

    def expand_receivers_for_groups(_new_receivers, receiver, channel)
      # We don't subscribe Groups so we have to get the group's users to get the subscriptions
      return receiver.users if event.instance_of?(Event::RelationshipCreate) || event.instance_of?(Event::RelationshipDelete)
      # We don't split events which come through the web channel, for a group subscriber.
      # They are split in the NotificationService::WebChannel service, if needed.
      return [receiver] if channel == :web || receiver.email.present?

      receiver.email_users
    end
  end
end

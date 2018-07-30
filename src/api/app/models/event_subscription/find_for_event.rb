class EventSubscription
  class FindForEvent
    attr_reader :event

    def initialize(event)
      @event = event
    end

    def subscriptions
      receivers_and_subscriptions = {}

      event.class.receiver_roles.flat_map do |receiver_role|
        # Find the users/groups who are receivers for this event
        receivers = event.send("#{receiver_role}s")
        receivers = filter_and_convert_groups_without_emails_to_users(receivers)

        # Find the default subscription for this eventtype and receiver_role
        default_subscription = EventSubscription.defaults.find_by(eventtype: event.eventtype, receiver_role: receiver_role)

        receivers.each do |receiver|
          # Prevent multiple enabled subscriptions for the same subscriber & eventtype
          # Also skip if the receiver is the originator of this event
          next if receivers_and_subscriptions[receiver].present? || receiver == event.originator

          # Try to find the subscription for this receiver
          receiver_subscription = EventSubscription.for_subscriber(receiver).find_by(eventtype: event.eventtype, receiver_role: receiver_role)

          if receiver_subscription.present?
            # Use the receiver's subscription if it exists
            if receiver_subscription.enabled?
              receivers_and_subscriptions[receiver] = receiver_subscription
            end

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

    private

    def filter_and_convert_groups_without_emails_to_users(receivers)
      new_receivers = []

      receivers.each do |receiver|
        if receiver.is_a?(User)
          new_receivers << receiver

        elsif receiver.is_a?(Group)

          if receiver.email.present?
            new_receivers << receiver
          else
            new_receivers += receiver.email_users
          end
        end
      end

      new_receivers
    end
  end
end

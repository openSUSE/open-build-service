# strategy class for the event model
class EventFindSubscriptions
  attr_reader :event

  def initialize(event)
    @event = event
  end

  def subscriptions
    receivers_and_subscriptions = {}

    event.class.receiver_roles.flat_map do |receiver_role|
      receivers = event.send("#{receiver_role}s")
      receivers = filter_and_convert_groups_without_emails_to_users(receivers)

      receivers.each do  |receiver|
        # Prevent multiple enabled subscriptions for the same subscriber & eventtype
        # Also skip if the receiver is the originator of this event
        next if receivers_and_subscriptions[receiver].present? || receiver == event.originator

        default_subscription = EventSubscription.defaults.where(eventtype: event.eventtype, receiver_role: receiver_role).first
        subscriber_subscription = EventSubscription.for_subscriber(receiver).where(eventtype: event.eventtype, receiver_role: receiver_role).first

        # 1. Add the receiver's subscription if it exists and is enabled
        if subscriber_subscription.present? && subscriber_subscription.enabled?
          receivers_and_subscriptions[receiver] = subscriber_subscription

        # 2. Add a new subscription for the receiver based on the default subscription if it exists and is enabled
        elsif default_subscription.present? && default_subscription.enabled?
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
      if receiver.is_a? User
        new_receivers << receiver

      elsif receiver.is_a? Group

        if receiver.email.present?
          new_receivers << receiver
        else
          new_receivers += receiver.users
        end
      end
    end

    new_receivers
  end
end

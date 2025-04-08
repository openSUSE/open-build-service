class EventSubscription
  class FindForEvent
    attr_reader :event

    def initialize(event, debug: false)
      @event = event
      @debug = debug
    end

    # rubocop: disable Rails/Output
    def subscriptions(channel = :instant_email)
      receivers_and_subscriptions = {}

      event.class.receiver_roles.each do |receiver_role|
        # Find the users/groups who are receivers for this event
        receivers_before_expand = event.send(:"#{receiver_role}s")
        next if receivers_before_expand.blank?

        puts "Looking at #{receivers_before_expand.map(&:to_s).join(', ')} for '#{receiver_role}' and channel '#{channel}'" if @debug
        receivers = expand_receivers(receivers_before_expand, channel)
        puts "Looking at #{receivers.map(&:to_s).join(', ')} for '#{receiver_role}' and channel '#{channel}'" if @debug && (receivers_before_expand - receivers).any?

        # Allow descendant events to also receive notifications if the subscription only covers the base class
        # This only supports 1 level of ancestry
        superclass = event.class.superclass.name
        eventtypes = [event.eventtype]
        eventtypes << superclass if superclass != 'Event::Base'
        options = { eventtype: eventtypes, receiver_role: receiver_role, channel: channel }
        # Find the default subscription for this eventtype and receiver_role
        default_subscription = EventSubscription.defaults.find_by(options)

        receivers.each do |receiver|
          # Prevent multiple enabled subscriptions for the same subscriber & eventtype
          if receivers_and_subscriptions[receiver].present?
            puts "Skipped receiver #{receiver}, since it is already in the list..." if @debug
            next
          end

          # Skip if the receiver is the originator of this event
          if receiver == event.originator
            puts "Skipped receiver #{receiver}, since it is the originator of the event..." if @debug
            next
          end

          if receiver.is_a?(User) && receiver.blocked_users.include?(event.originator)
            puts "Skipped the notification for receiver #{receiver}, since the originator is blocked by them..." if @debug
            next
          end

          # Try to find the subscription for this receiver
          receiver_subscription = EventSubscription.for_subscriber(receiver).find_by(options)
          if receiver_subscription.present?
            # Use the receiver's subscription if it exists
            receivers_and_subscriptions[receiver] = receiver_subscription if receiver_subscription.enabled?
            puts "Skipped receiver #{receiver} because they have a disabled user subscription" if @debug && !receiver_subscription.enabled?
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
          elsif @debug && default_subscription.present? && !default_subscription.enabled?
            puts "Skipped receiver #{receiver} because of a disabled default subscription"
          end
        end
        puts "People to receive something: #{receivers_and_subscriptions.values.flatten.map { |subscription| subscription.subscriber.to_s }}\n\n" if @debug
      end

      receivers_and_subscriptions.values.flatten
    end

    private

    def expand_receivers(receivers, channel)
      receivers.inject([]) do |new_receivers, receiver|
        case receiver
        when User
          new_receivers << receiver if receiver.active?
          puts "Skipped receiver #{receiver} because it's inactive" if @debug && !receiver.active?
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

      puts "Expanding group #{receiver}..." if @debug
      receiver.email_users
    end
    # rubocop: enable Rails/Output
  end
end

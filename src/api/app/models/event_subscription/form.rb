class EventSubscription
  class Form
    EVENTS_FOR_CONTENT_MODERATORS = ['Event::Report', 'Event::AppealCreated'].freeze
    EVENTS_IN_CONTENT_MODERATION_BETA = ['Event::Decision'].freeze

    attr_reader :subscriber

    def initialize(subscriber = nil)
      @subscriber = subscriber
    end

    def subscriptions_by_event
      event_classes = Event::Base.notification_events
      event_classes.filter_map do |event_class|
        EventSubscription::ForEventForm.new(event_class, subscriber).call if show_form_for_content_moderation_events?(event_class: event_class, subscriber: subscriber)
      end
    end

    def update!(subscriptions_params)
      subscriptions_params.each do |_i, subscription_params|
        subscription = find_or_initialize_subscription(
          subscription_params[:eventtype],
          subscription_params[:receiver_role],
          subscription_params[:channel]
        )

        subscription.enabled = subscription_params[:enabled].present?
        subscription.save!
      end
    end

    private

    def find_or_initialize_subscription(eventtype, receiver_role, channel)
      opts = { eventtype: eventtype, receiver_role: receiver_role, channel: channel }

      if subscriber.is_a?(User) && subscriber.active?
        opts[:user] = subscriber
      elsif subscriber.is_a?(Group)
        opts[:group] = subscriber
      elsif subscriber.nil?
        opts[:user] = nil
        opts[:group] = nil
      end

      EventSubscription.find_or_initialize_by(opts)
    end

    def show_form_for_content_moderation_events?(event_class:, subscriber:)
      # There is no subscriber associated to "global" event subscriptions
      # which are set through the admin configuration interface.
      # Admin user should be able to configure all event subscription types,
      # even if they are not participating in the corresponding beta program
      return true if subscriber.blank?
      return false if EVENTS_FOR_CONTENT_MODERATORS.include?(event_class.name) && !ReportPolicy.new(subscriber, Report).notify?
      return false if EVENTS_IN_CONTENT_MODERATION_BETA.include?(event_class.name) && !Flipper.enabled?(:content_moderation, subscriber)

      true
    end
  end
end

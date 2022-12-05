class EventSubscription
  class Form
    attr_reader :subscriber

    # TODO: remove this constant after we finish renaming *watcher to *project_watcher
    RECEIVER_ROLE_MAPPING = {
      'project_watcher' => 'watcher',
      'source_project_watcher' => 'source_watcher',
      'target_project_watcher' => 'target_watcher'
    }.freeze

    def initialize(subscriber = nil)
      @subscriber = subscriber
    end

    def subscriptions_by_event
      event_classes = Event::Base.notification_events
      event_classes.map { |event_class| EventSubscription::ForEventForm.new(event_class, subscriber).call }
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
      opts = { eventtype: eventtype, channel: channel }

      if subscriber.is_a?(User) && subscriber.is_active?
        opts[:user] = subscriber
      elsif subscriber.is_a?(Group)
        opts[:group] = subscriber
      elsif subscriber.nil?
        opts[:user] = nil
        opts[:group] = nil
      end

      # TODO: remove this if clause after we finish renaming *watcher to *project_watcher
      if receiver_role.in?(RECEIVER_ROLE_MAPPING.keys)
        old_receiver_role = RECEIVER_ROLE_MAPPING[receiver_role]
        old_event_subscription = EventSubscription.find_by(opts.merge({ receiver_role: old_receiver_role }))

        return old_event_subscription if old_event_subscription.present?
      end

      EventSubscription.find_or_initialize_by(opts.merge({ receiver_role: receiver_role }))
    end
  end
end

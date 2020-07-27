module NotificationService
  class Notifier
    EVENTS_TO_NOTIFY = ['Event::RequestStatechange',
                        'Event::RequestCreate',
                        'Event::ReviewWanted',
                        'Event::CommentForProject',
                        'Event::CommentForPackage',
                        'Event::CommentForRequest'].freeze
    CHANNELS = [:web, :rss].freeze
    ALLOWED_NOTIFIABLE_TYPES = {
      'BsRequest' => ::BsRequest,
      'Comment' => ::Comment
    }.freeze
    ALLOWED_CHANNELS = {
      web: NotificationService::WebChannel,
      rss: NotificationService::RSSChannel
    }.freeze

    def initialize(event)
      @event = event
    end

    def call
      return unless @event.eventtype.in?(EVENTS_TO_NOTIFY)

      CHANNELS.each do |channel|
        @event.subscriptions(channel).each do |subscription|
          create_notification_per_subscription(subscription, channel)
        end
      end
    rescue StandardError => e
      Airbrake.notify(e, event_id: @event.id)
    end

    private

    def create_notification_per_subscription(subscription, channel)
      return unless create_notification?(subscription.subscriber, channel)

      ALLOWED_CHANNELS[channel].new(subscription, @event).call
    end

    def create_notification?(subscriber, channel)
      return false if subscriber.nil? || subscriber.away? || (channel == :rss && !subscriber.try(:rss_token))
      return false unless notifiable_exists?

      true
    end

    def notifiable_exists?
      # We need this check because the notification is created in a delayed job.
      # So the notifiable object could have been removed in the meantime.
      notifiable_type = ALLOWED_NOTIFIABLE_TYPES[@event.parameters_for_notification[:notifiable_type]]
      return false unless notifiable_type

      notifiable_id = @event.parameters_for_notification[:notifiable_id]
      notifiable_type.exists?(notifiable_id)
    end
  end
end

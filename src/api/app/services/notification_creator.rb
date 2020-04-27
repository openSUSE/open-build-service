class NotificationCreator
  EVENTS_TO_NOTIFY = ['Event::RequestStatechange',
                      'Event::RequestCreate',
                      'Event::ReviewWanted',
                      'Event::CommentForProject',
                      'Event::CommentForPackage',
                      'Event::CommentForRequest'].freeze
  CHANNELS = [:web, :rss].freeze

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
    params = subscription.parameters_for_notification.merge!(@event.parameters_for_notification)
    # TODO: Replace by Notification when we remove Notification::RssFeedItem class
    notification = Notification::RssFeedItem.find_or_create_by!(params) # avoid duplication
    notification.update("#{channel}": true)
  end

  def create_notification?(subscriber, channel)
    return false if subscriber && subscriber.away?
    return false if channel == :rss && !subscriber.try(:rss_token)
    true
  end
end

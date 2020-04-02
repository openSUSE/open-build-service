class NotificationCreator
  EVENTS_TO_NOTIFY = ['Event::RequestStatechange',
                      'Event::RequestCreate',
                      'Event::ReviewWanted',
                      'Event::CommentForProject',
                      'Event::CommentForPackage',
                      'Event::CommentForRequest'].freeze

  def initialize(event)
    @event = event
  end

  def call
    return unless @event.eventtype.in?(EVENTS_TO_NOTIFY)
    @event.subscriptions.each { |subscription| create_notification_per_subscription(subscription) }
  rescue StandardError => e
    Airbrake.notify(e, event_id: @event.id)
  end

  private

  def create_notification_per_subscription(subscription)
    return if subscription.subscriber && subscription.subscriber.away?
    params = subscription.parameters_for_notification.merge!(@event.parameters_for_notification)
    Notification::RssFeedItem.find_or_create_by!(params) # avoid duplication
  end
end

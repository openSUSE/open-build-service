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
    channel == :web ? for_web(subscription) : for_rss(subscription)
  end

  def create_notification?(subscriber, channel)
    return false if subscriber && subscriber.away?
    return false if channel == :rss && !subscriber.try(:rss_token)
    return false unless notifiable_exists?

    true
  end

  def notifiable_exists?
    # We need this check because the notification is created in a delayed job.
    # So the notifiable object could have been removed in the meantime.
    notifiable_type = @event.parameters_for_notification[:notifiable_type]
    notifiable_id = @event.parameters_for_notification[:notifiable_id]
    notifiable_type.constantize.exists?(notifiable_id)
  end

  def for_web(subscription)
    params = subscription.parameters_for_notification.merge!(@event.parameters_for_notification)
    notification = Notification.find_by(notifiable_type: params[:notifiable_type], notifiable_id:params[:notifiable_id], web: true)

    OutdatedNotifications::Destroyer.new(notification).call if notification

    notification = Notification.create(params)
    notification.projects << NotifiedProjects.new(notification).call
    notification.update(web: true)
  end

  def for_rss(subscription)
    params = subscription.parameters_for_notification.merge!(@event.parameters_for_notification)
    notification = Notification.find_by(params)

    unless notification
      notification = Notification.create(params)
      notification.projects << NotifiedProjects.new(notification).call
    end

    notification.update(rss: true)
  end
end
